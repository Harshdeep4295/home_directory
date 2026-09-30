# Build and install on your own phones

Everything runs on your Mac; nothing is published to an app store.

## 0. One-time setup on the Mac

1. Install Flutter 3.47+ (`brew install --cask flutter`, or the zip from flutter.dev), Android
   Studio (for the Android SDK + platform tools / `adb`) and Xcode 16+ (from the App Store).
2. `make doctor` — every line you need should be green: Flutter, Android toolchain, Xcode.
   Accept Android licences if asked: `flutter doctor --android-licenses`.
3. From the repo root: `make deps` (Flutter packages + the Python simulators used by tests),
   then `make test` to confirm the checkout is healthy.

## 1. Android phone

1. On the phone: Settings → About phone → tap *Build number* 7× → Developer options →
   enable **USB debugging**. Plug it into the Mac and accept the "Allow USB debugging" prompt.
2. `adb devices` should list it.
3. `make install-apk` — builds `app/build/app/outputs/flutter-apk/app-release.apk` and
   installs it. (Or `make apk` and copy the APK to the phone yourself.)
4. First launch walks you through the permissions: nearby devices / local network,
   microphone, notifications, **Alarms & reminders** (exact alarms for phone-tier timers) and
   battery optimisation exemption (so timers fire with the screen off).

The release APK is signed with the Android debug key. That is fine for your own phone;
updates install over the previous version as long as they are built on the same Mac.

## 2. iPhone (free Apple ID)

1. Open `app/ios/Runner.xcworkspace` in Xcode → select the **Runner** target →
   *Signing & Capabilities* → Team: *your name (Personal Team)*. If Xcode says the bundle id
   `dev.offlinehome.offlineHome` is taken, change it to something unique, e.g.
   `dev.<yourname>.offlinehome`.
2. On the iPhone (iOS 16+): Settings → Privacy & Security → **Developer Mode** → on (restarts
   the phone). Plug it into the Mac and tap *Trust*.
3. `make ios-device` — builds a release build and installs it. (Several phones? Pass the id
   from `flutter devices`: `make ios-device IOS_DEVICE=<id>`.)
4. First launch on the phone may say "Untrusted Developer": Settings → General →
   VPN & Device Management → your Apple ID → Trust.
5. Allow **Local Network** when asked (the app cannot see your devices without it),
   microphone + speech recognition, and notifications.

**Free signing expires after 7 days.** After that the app will not open until you run
`make ios-device` again (your devices, rooms, keys and timers are kept). A free Apple ID can
have at most 3 such apps installed at a time.

## 3. After installing

- Settings → Import Tuya keys (for Wipro / Syska / other Tuya devices), then Add devices →
  scan. See [`docs/HARDWARE_LOG.md`](HARDWARE_LOG.md) → *Pending hardware checks* for what to
  try on each device.
- Settings → Diagnostics shows network state, scan results, voice test and the
  performance numbers (tap→device latency, cold start).

## Troubleshooting

| Symptom | Fix |
|---|---|
| Scan finds nothing (Android) | Phone on the same Wi-Fi as the devices? Mobile data can stay on — the app binds to Wi-Fi. Check Diagnostics → Network. |
| Scan finds nothing (iPhone) | Settings → Offline Home → Local Network must be on. Tuya beacons may not reach iOS; the TCP scan still finds Tuya devices by port. |
| "Key rejected" on a Tuya device | The device was reset / re-paired, so its local key changed: import a fresh `devices.json` or enter the key on the device page. |
| Timer did not fire (Android, phone tier) | Allow *Alarms & reminders* and disable battery optimisation for the app. |
| Timer did not fire (iPhone, phone tier) | An iPhone cannot switch devices in the background. For devices without a built-in timer, keep the app open until the timer ends; a notification at the time asks you to open it. Devices with a plug timer are not affected. |
