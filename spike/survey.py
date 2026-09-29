#!/usr/bin/env python3
"""Offline Home — home network device survey (T0.6).

Run on the MacBook while connected to the home Wi-Fi:

    python3 -m venv .venv && . .venv/bin/activate
    pip install tinytuya zeroconf           # both optional, but you want them
    python spike/survey.py                  # scans your /24
    python spike/survey.py --devices-json path/to/devices.json   # + Tuya DP dump

It answers: which devices are on the LAN, what protocol each one speaks, and — for Tuya
devices when a tinytuya `devices.json` is given — the protocol version and the data points
(DPs) with their names. Nothing leaves the LAN. Local keys are never printed or saved.

Writes spike/survey-<timestamp>.json (gitignored) and prints a summary to paste into
docs/HARDWARE_LOG.md.

Protocol constants (ports, payloads) are the same ones listed in docs/PLAN.md §5–6; sources:
WiZ 38899 getPilot (pywizlight), Kasa 9999 XOR key 171 (python-kasa), Yeelight 55443 get_prop
(python-yeelight), Shelly GET /shelly, Tasmota GET /cm?cmnd=Status 0, Tuya 6668 + UDP beacons
6666/6667 (tinytuya).
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import datetime as dt
import ipaddress
import json
import socket
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any

TCP_PORTS = {
    6668: "tuya",
    6053: "esphome-native",
    80: "http",
    8081: "sonoff-diy",
    9999: "kasa-tcp",
    55443: "yeelight",
}
MDNS_TYPES = [
    "_hue._tcp.local.",
    "_shelly._tcp.local.",
    "_http._tcp.local.",
    "_ewelink._tcp.local.",
    "_esphomelib._tcp.local.",
    "_matter._tcp.local.",
    "_hap._tcp.local.",
]


# ---------------------------------------------------------------------------- helpers


def local_ipv4() -> str:
    """Address of the interface that routes to the LAN (no packet is sent)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def kasa_xor_encrypt(data: bytes) -> bytes:
    # python-kasa xortransport: autokey XOR starting at 171.
    key = 171
    out = bytearray()
    for b in data:
        key ^= b
        out.append(key)
    return bytes(out)


def kasa_xor_decrypt(data: bytes) -> bytes:
    key = 171
    out = bytearray()
    for b in data:
        out.append(key ^ b)
        key = b
    return bytes(out)


def udp_query(host: str, port: int, payload: bytes, timeout: float) -> bytes | None:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    try:
        s.sendto(payload, (host, port))
        data, _ = s.recvfrom(8192)
        return data
    except OSError:
        return None
    finally:
        s.close()


def tcp_open(host: str, port: int, timeout: float) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def http_get(url: str, timeout: float) -> tuple[int, dict[str, str], str] | None:
    # Explicitly no proxy: this must only ever talk to the LAN.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(url, timeout=timeout) as r:
            return r.status, dict(r.headers), r.read(4096).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers or {}), ""
    except (OSError, ValueError):
        return None


def parse_json(text: str | bytes | None) -> Any:
    if not text:
        return None
    try:
        return json.loads(text)
    except ValueError:
        return None


# ---------------------------------------------------------------------------- probes


def probe_wiz(host: str, port: int, timeout: float) -> dict[str, Any] | None:
    r = parse_json(udp_query(host, port, b'{"method":"getPilot","params":{}}', timeout))
    if not isinstance(r, dict) or r.get("method") != "getPilot":
        return None
    out: dict[str, Any] = {"pilot": r.get("result")}
    cfg = parse_json(udp_query(host, port, b'{"method":"getSystemConfig","params":{}}', timeout))
    if isinstance(cfg, dict):
        out["systemConfig"] = cfg.get("result")
    return out


def probe_kasa_udp(host: str, port: int, timeout: float) -> dict[str, Any] | None:
    payload = kasa_xor_encrypt(b'{"system":{"get_sysinfo":{}}}')
    r = parse_json(kasa_xor_decrypt(udp_query(host, port, payload, timeout) or b""))
    if not isinstance(r, dict) or "system" not in r:
        return None
    info = r["system"].get("get_sysinfo", {})
    keep = ("model", "alias", "mac", "hw_ver", "sw_ver", "type", "mic_type", "relay_state", "deviceId")
    return {k: info[k] for k in keep if k in info}


def probe_yeelight(host: str, port: int, timeout: float) -> dict[str, Any] | None:
    try:
        with socket.create_connection((host, port), timeout=timeout) as s:
            s.settimeout(timeout)
            s.sendall(b'{"id":1,"method":"get_prop","params":["power","bright","ct","model"]}\r\n')
            return parse_json(s.recv(4096).split(b"\r\n")[0])
    except OSError:
        return None


def probe_http(host: str, port: int, timeout: float) -> dict[str, Any]:
    base = f"http://{host}:{port}"
    out: dict[str, Any] = {}
    root = http_get(base + "/", timeout)
    if root:
        status, headers, body = root
        lower = {k.lower(): v for k, v in headers.items()}
        out["root"] = {"status": status, "server": lower.get("server"), "title": _title(body)}
    shelly = http_get(base + "/shelly", timeout)
    if shelly and shelly[0] == 200 and isinstance(parse_json(shelly[2]), dict):
        out["shelly"] = parse_json(shelly[2])
    tas = http_get(base + "/cm?cmnd=Status%200", timeout)
    if tas and tas[0] == 200:
        j = parse_json(tas[2])
        if isinstance(j, dict) and "Status" in j:
            out["tasmota"] = {"Status": j.get("Status"), "StatusFWR": j.get("StatusFWR")}
    hue = http_get(base + "/api/config", timeout)
    if hue and hue[0] == 200:
        j = parse_json(hue[2])
        if isinstance(j, dict) and "bridgeid" in j:
            out["hue"] = {k: j.get(k) for k in ("name", "bridgeid", "modelid", "swversion")}
    return out


def _title(body: str) -> str | None:
    lo = body.lower()
    i, j = lo.find("<title>"), lo.find("</title>")
    return body[i + 7 : j].strip()[:80] if 0 <= i < j else None


def mdns_browse(seconds: float) -> dict[str, list[dict[str, Any]]]:
    """ip → [{type, name, port, txt}]. Empty if the optional zeroconf package is missing."""
    try:
        from zeroconf import ServiceBrowser, ServiceListener, Zeroconf
    except ImportError:
        print("  (zeroconf not installed: skipping mDNS; `pip install zeroconf`)", file=sys.stderr)
        return {}
    found: dict[str, list[dict[str, Any]]] = {}

    class L(ServiceListener):
        def add_service(self, zc: Zeroconf, type_: str, name: str) -> None:
            info = zc.get_service_info(type_, name, timeout=1500)
            if not info:
                return
            txt = {k.decode(errors="replace"): (v or b"").decode(errors="replace") for k, v in info.properties.items()}
            for ip in info.parsed_addresses():
                found.setdefault(ip, []).append({"type": type_, "name": name, "port": info.port, "txt": txt})

        def update_service(self, zc: Zeroconf, type_: str, name: str) -> None: ...
        def remove_service(self, zc: Zeroconf, type_: str, name: str) -> None: ...

    zc = Zeroconf()
    try:
        ServiceBrowser(zc, MDNS_TYPES, L())
        time.sleep(seconds)
    finally:
        zc.close()
    return found


def tuya_beacons(seconds: int) -> dict[str, dict[str, Any]]:
    """ip → beacon via tinytuya's scanner (listens on UDP 6666/6667/7000)."""
    try:
        import tinytuya
    except ImportError:
        print("  (tinytuya not installed: skipping Tuya beacons; `pip install tinytuya`)", file=sys.stderr)
        return {}
    try:
        found = tinytuya.deviceScan(verbose=False, maxretry=seconds, color=False, poll=False)
    except Exception as e:  # tinytuya scan failures must not abort the survey
        print(f"  (tinytuya scan failed: {e})", file=sys.stderr)
        return {}
    keep = ("gwId", "ip", "version", "productKey", "active", "ablilty", "encrypt", "name")
    return {ip: {k: v for k, v in b.items() if k in keep} for ip, b in (found or {}).items()}


def tuya_dps(dev: dict[str, Any], ip: str, version: str | None) -> dict[str, Any]:
    """Query DPs for one devices.json entry. Tries the known version, else 3.3 → 3.4 → 3.5 → 3.1."""
    import tinytuya

    versions = [version] if version else ["3.3", "3.4", "3.5", "3.1"]
    attempts = []
    for v in versions:
        d = tinytuya.OutletDevice(dev["id"], ip, dev["key"], version=float(v), connection_timeout=3)
        d.set_socketRetryLimit(1)
        try:
            st = d.status()
        except Exception as e:
            st = {"Error": str(e)}
        finally:
            d.close()
        if isinstance(st, dict) and "dps" in st:
            return {"version": v, "dps": st["dps"], "device22": getattr(d, "dev_type", "") == "device22"}
        attempts.append({"version": v, "error": (st or {}).get("Error") if isinstance(st, dict) else str(st)})
    return {"attempts": attempts}


# ---------------------------------------------------------------------------- survey


def classify(e: dict[str, Any]) -> str:
    """Same precedence as the app's Fingerprinter (PSEUDOCODE §7.2)."""
    types = {m["type"] for m in e.get("mdns", [])}
    http = e.get("http", {})
    if "tuyaBeacon" in e:
        return f"tuya {e['tuyaBeacon'].get('version', '?')}"
    if "wiz" in e:
        return "wiz"
    if "_hue._tcp.local." in types or "hue" in http:
        return "hue bridge"
    if "_shelly._tcp.local." in types or "shelly" in http:
        return f"shelly gen{(http.get('shelly') or {}).get('gen', 1)}"
    if "_ewelink._tcp.local." in types:
        return "sonoff (eWeLink LAN)"
    if "_esphomelib._tcp.local." in types:
        return "esphome"
    if "kasa" in e:
        return "kasa (legacy)"
    if "yeelight" in e:
        return "yeelight"
    if "tasmota" in http:
        return "tasmota"
    if 6668 in e.get("openPorts", []):
        return "tuya (version unknown)"
    if "_matter._tcp.local." in types:
        return "matter"
    if e.get("openPorts") or types:
        return "unknown"
    return "no reply"


def survey(args: argparse.Namespace) -> dict[str, Any]:
    if args.hosts:
        hosts = args.hosts.split(",")
    else:
        net = ipaddress.ip_network(args.subnet or f"{local_ipv4()}/24", strict=False)
        hosts = [str(h) for h in net.hosts()]
    print(f"Scanning {len(hosts)} hosts ({hosts[0]} … {hosts[-1]})", file=sys.stderr)
    ev: dict[str, dict[str, Any]] = {}

    def at(ip: str) -> dict[str, Any]:
        return ev.setdefault(ip, {"ip": ip})

    with cf.ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        # Tuya beacons and mDNS run in the background while the unicast probes go out.
        bg_tuya = pool.submit(tuya_beacons, args.listen) if not args.no_tuya else None
        bg_mdns = pool.submit(mdns_browse, min(args.listen, 5)) if not args.no_mdns else None

        tcp_ports = {p: TCP_PORTS[p] for p in TCP_PORTS}
        port_of = {**{p: p for p in TCP_PORTS}, **args.port_override_tcp}
        jobs = {
            pool.submit(tcp_open, h, port_of[p], args.timeout): (h, p) for h in hosts for p in tcp_ports
        }
        for f in cf.as_completed(jobs):
            h, p = jobs[f]
            if f.result():
                at(h).setdefault("openPorts", []).append(p)

        udp_jobs = {pool.submit(probe_wiz, h, args.wiz_port, args.timeout): (h, "wiz") for h in hosts}
        udp_jobs |= {pool.submit(probe_kasa_udp, h, args.kasa_port, args.timeout): (h, "kasa") for h in hosts}
        for f in cf.as_completed(udp_jobs):
            h, kind = udp_jobs[f]
            if r := f.result():
                at(h)[kind] = r

        for h, e in list(ev.items()):
            ports = e.get("openPorts", [])
            if 80 in ports:
                e["http"] = probe_http(h, port_of[80], args.timeout * 3)
            if 55443 in ports and (y := probe_yeelight(h, port_of[55443], args.timeout * 3)):
                e["yeelight"] = y

        for ip, b in (bg_tuya.result() if bg_tuya else {}).items():
            at(ip)["tuyaBeacon"] = b
        for ip, recs in (bg_mdns.result() if bg_mdns else {}).items():
            at(ip)["mdns"] = recs

    if args.devices_json:
        tuya_keys = json.loads(Path(args.devices_json).read_text())
        by_id = {e["tuyaBeacon"]["gwId"]: ip for ip, e in ev.items() if "tuyaBeacon" in e}
        for dev in tuya_keys:
            ip = by_id.get(dev.get("id")) or dev.get("ip")
            rec = {
                "name": dev.get("name"),
                "id": dev.get("id"),
                "category": dev.get("category"),
                "product_name": dev.get("product_name"),
                "mapping": {k: v.get("code") for k, v in (dev.get("mapping") or {}).items()},
                "ip": ip,
            }
            if ip and dev.get("key"):
                version = (ev.get(ip, {}).get("tuyaBeacon") or {}).get("version") or dev.get("version") or None
                rec |= tuya_dps(dev, ip, str(version) if version else None)
            else:
                rec["skipped"] = "no ip found" if not ip else "no key"
            if ip:
                at(ip)["tuyaDevice"] = rec
            else:
                ev.setdefault("_unlocated", {"ip": None, "tuyaDevices": []})["tuyaDevices"].append(rec)

    for e in ev.values():
        if e.get("ip"):
            e["guess"] = classify(e)
            e.get("openPorts", []).sort()
    return {
        "when": dt.datetime.now().isoformat(timespec="seconds"),
        "scanner": {"localIp": local_ipv4(), "hosts": len(hosts)},
        "devices": {ip: e for ip, e in sorted(ev.items(), key=lambda kv: _ipkey(kv[0]))},
    }


def _ipkey(ip: str) -> tuple[int, ...]:
    try:
        return tuple(int(x) for x in ip.split("."))
    except ValueError:
        return (999,)


def summary(result: dict[str, Any]) -> str:
    lines = [f"Survey {result['when']} from {result['scanner']['localIp']}", ""]
    for ip, e in result["devices"].items():
        if ip == "_unlocated":
            for t in e["tuyaDevices"]:
                lines.append(f"  (no ip)          tuya  {t['name']!r} id={t['id']} — not seen on LAN")
            continue
        if e.get("guess") == "no reply":
            continue
        extra = []
        if w := e.get("wiz"):
            cfg = w.get("systemConfig") or {}
            extra.append(f"module={cfg.get('moduleName')} fw={cfg.get('fwVersion')}")
        if k := e.get("kasa"):
            extra.append(f"model={k.get('model')} alias={k.get('alias')!r}")
        if b := e.get("tuyaBeacon"):
            extra.append(f"gwId={b.get('gwId')} productKey={b.get('productKey')}")
        if t := e.get("tuyaDevice"):
            extra.append(f"name={t['name']!r} category={t.get('category')}")
            if "dps" in t:
                extra.append(f"WORKS v{t['version']}{' device22' if t.get('device22') else ''}")
                named = {dp: f"{t['mapping'].get(dp, '?')}={val}" for dp, val in t["dps"].items()}
                extra.append("dps " + ", ".join(f"{dp}:{v}" for dp, v in named.items()))
            elif "attempts" in t:
                extra.append("FAILED " + "; ".join(f"v{a['version']}: {a['error']}" for a in t["attempts"]))
        if m := e.get("mdns"):
            extra.append("mdns " + ",".join(sorted({r["type"].split(".")[0] for r in m})))
        if h := e.get("http", {}).get("root"):
            extra.append(f"http server={h.get('server')} title={h.get('title')!r}")
        ports = ",".join(map(str, e.get("openPorts", [])))
        lines.append(f"  {ip:<16} {e['guess']:<24} ports[{ports}]  " + "  ".join(extra))
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--subnet", help="CIDR to scan (default: your IP /24)")
    ap.add_argument("--hosts", help="comma-separated host list instead of a subnet")
    ap.add_argument("--devices-json", help="tinytuya wizard devices.json (keys are never printed)")
    ap.add_argument("--listen", type=int, default=8, help="seconds to listen for Tuya beacons / mDNS")
    ap.add_argument("--timeout", type=float, default=0.4, help="per-probe timeout, seconds")
    ap.add_argument("--concurrency", type=int, default=128)
    ap.add_argument("--no-tuya", action="store_true", help="skip Tuya beacon listening")
    ap.add_argument("--no-mdns", action="store_true")
    ap.add_argument("--out", help="output JSON path (default spike/survey-<time>.json)")
    # Test hooks: point probes at simulators on non-standard ports.
    ap.add_argument("--wiz-port", type=int, default=38899, help=argparse.SUPPRESS)
    ap.add_argument("--kasa-port", type=int, default=9999, help=argparse.SUPPRESS)
    ap.add_argument("--tcp-port", action="append", default=[], help=argparse.SUPPRESS)  # std=actual
    args = ap.parse_args(argv)
    args.port_override_tcp = {int(a): int(b) for a, b in (x.split("=") for x in args.tcp_port)}

    result = survey(args)
    out = Path(args.out or Path(__file__).parent / f"survey-{dt.datetime.now():%Y%m%d-%H%M%S}.json")
    out.write_text(json.dumps(result, indent=2, default=str))
    print(summary(result))
    print(f"\nFull results: {out}  (gitignored; contains no keys)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
