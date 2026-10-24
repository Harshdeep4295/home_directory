# LAN scan — after switching the Xiaomi (R3L) to "Network amplifier" (wired AP) mode, 2026-10-24

Both Wi-Fis now share 192.168.1.0/24 (DHCP from router 1). The Xiaomi itself is at 192.168.1.2.
Same method as router1/router2 scans (spike/survey.py, tinytuya beacons 15 s, mDNS).

| IP | What |
|---|---|
| .1 | Main router / ISP box (login page) |
| .2 | Xiaomi R3L, now an access point |
| .4, .9 | Fire TV Sticks (TLS on 55443) |
| .7 | Hikvision/EZVIZ camera |
| .8 | Echo (TLS on 55443) |
| .14 | Tuya 3.3, productKey keyjcr45yfptp7h7 (was 192.168.31.170) |
| .15 | Tuya 3.4, productKey pyttjmy4uwavtftq (was .31.33) |
| .16 | Tuya 3.5, productKey keykmm3rjyqy5r8p (was .31.42) |
| .18 | Tuya 3.3, productKey keyjup78v54myhan (was .31.75) |
| .19 | Tuya 3.3, productKey keyjup78v54myhan (was .31.144) |
| .24 | Tuya 3.3, productKey keytg5kq8gvkv9dh (was .31.197) |
| .20 | WiZ RGB bulb ESP25_SHRGB_01 fw 1.38.0 (was .31.116) |
| .25 | Matter device (mDNS _matter, also 55443 → likely Echo) |

All devices are now discoverable from either Wi-Fi.
