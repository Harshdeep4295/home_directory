import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocalNetworkPlugin") {
      LocalNetworkPlugin.register(with: registrar)
    }
  }
}

/// iOS side of PlatformBridge (PSEUDOCODE §3.3). Kept in this file so the Xcode project
/// needs no new file references.
///
/// Channels:
///  - method `offline_home/local_network`: requestPermission → "granted"|"denied"|"unknown",
///    netInfo → {wifi, ip, prefix}
///  - event  `offline_home/local_network/events`: netInfo maps on Wi-Fi path changes
///
/// iOS cannot tell whether the Wi-Fi has internet without contacting the internet, which
/// CLAUDE.md rule 1 forbids, so `internet` is never reported (Dart treats it as unknown).
final class LocalNetworkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  /// Private Bonjour type used only to detect the Local Network permission.
  /// Must be listed in Info.plist NSBonjourServices.
  static let probeServiceType = "_offlinehome._tcp"

  private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
  private var wifiUp = false
  private var sink: FlutterEventSink?
  private var probes: [PermissionProbe] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = LocalNetworkPlugin()
    let methods = FlutterMethodChannel(
      name: "offline_home/local_network", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(
      name: "offline_home/local_network/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    instance.startMonitor()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      let probe = PermissionProbe(serviceType: LocalNetworkPlugin.probeServiceType)
      probes.append(probe)
      probe.start(timeout: 60) { [weak self] status in
        self?.probes.removeAll { $0 === probe }
        result(status)
      }
    case "netInfo":
      result(netInfo())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    events(netInfo())
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func startMonitor() {
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.wifiUp = path.status == .satisfied
        self.sink?(self.netInfo())
      }
    }
    monitor.start(queue: DispatchQueue(label: "offline_home.path"))
  }

  private func netInfo() -> [String: Any?] {
    let addr = LocalNetworkPlugin.wifiAddress()
    return [
      "wifi": wifiUp || addr != nil,
      "ip": addr?.ip,
      "prefix": addr?.prefix,
    ]
  }

  /// IPv4 address and prefix length of the Wi-Fi interface (en0).
  static func wifiAddress() -> (ip: String, prefix: Int)? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }
    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
      let ifa = ptr.pointee
      guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
        String(cString: ifa.ifa_name) == "en0"
      else { continue }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      guard
        getnameinfo(
          addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0,
          NI_NUMERICHOST) == 0
      else { continue }
      var prefix = 24
      if let mask = ifa.ifa_netmask {
        prefix = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
          $0.pointee.sin_addr.s_addr.nonzeroBitCount
        }
      }
      return (String(cString: host), prefix)
    }
    return nil
  }
}

/// Triggers the Local Network prompt and reports the outcome: advertise a Bonjour service
/// and browse for it. Seeing our own service means access is granted; the browser
/// entering `.waiting` with a PolicyDenied DNS error means it was denied.
final class PermissionProbe {
  // dns_sd.h: kDNSServiceErr_PolicyDenied = -65570. VERIFY on device (T1.5).
  private static let policyDenied: Int32 = -65570

  private let serviceType: String
  private var listener: NWListener?
  private var browser: NWBrowser?
  private var completion: ((String) -> Void)?

  init(serviceType: String) {
    self.serviceType = serviceType
  }

  func start(timeout: TimeInterval, completion: @escaping (String) -> Void) {
    self.completion = completion
    do {
      let listener = try NWListener(using: .tcp)
      listener.service = NWListener.Service(name: UUID().uuidString, type: serviceType)
      listener.newConnectionHandler = { $0.cancel() }
      listener.stateUpdateHandler = { [weak self] state in
        if case .failed = state { self?.finish("unknown") }
      }
      listener.start(queue: .main)
      self.listener = listener
    } catch {
      finish("unknown")
      return
    }
    let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: NWParameters())
    browser.stateUpdateHandler = { [weak self] state in
      switch state {
      case .waiting(let error), .failed(let error):
        if case .dns(let code) = error, code == PermissionProbe.policyDenied {
          self?.finish("denied")
        }
      default:
        break
      }
    }
    browser.browseResultsChangedHandler = { [weak self] results, _ in
      if !results.isEmpty { self?.finish("granted") }
    }
    browser.start(queue: .main)
    self.browser = browser
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
      self?.finish("unknown")
    }
  }

  private func finish(_ status: String) {
    guard let done = completion else { return }
    completion = nil
    listener?.cancel()
    browser?.cancel()
    done(status)
  }
}
