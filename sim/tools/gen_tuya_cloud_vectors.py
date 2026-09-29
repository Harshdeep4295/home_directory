#!/usr/bin/env python3
"""Generate Tuya OpenAPI request-signing vectors with tinytuya (the reference, CLAUDE.md
rule 2). Output: app/test/onboarding/cloud_import/signing_vectors.json, consumed by the
Dart TuyaCloudClient tests.

    pip install tinytuya==1.20.0 && python sim/tools/gen_tuya_cloud_vectors.py

Requests are produced by tinytuya's own Cloud._tuyaplatform (tinytuya/Cloud.py) with
time.time() pinned and requests.get/request mocked, so the captured URL + headers are
exactly what tinytuya would send. Credentials are dummies.
"""

from __future__ import annotations

import json
from pathlib import Path
from unittest import mock

import tinytuya

API_KEY = "testaccessid0000000a"
API_SECRET = "testaccesssecret00000000000000bb"
TOKEN = "testtoken0000000000000000000000cc"
NOW_MS = 1790000000123


class _Resp:
    status_code = 200
    text = '{"success": true, "result": {}}'
    content = text.encode()


def capture(cloud: tinytuya.Cloud, **kw) -> dict:
    seen = {}

    def fake_get(url, headers=None, **_):
        seen.update(method="GET", url=url, headers=dict(headers))
        return _Resp()

    def fake_request(method, url, headers=None, data=None, **_):
        seen.update(method=method, url=url, headers=dict(headers), body=data)
        return _Resp()

    with mock.patch("tinytuya.Cloud.requests.get", fake_get), mock.patch(
        "tinytuya.Cloud.requests.request", fake_request
    ), mock.patch("tinytuya.Cloud.time.time", lambda: NOW_MS / 1000.0):
        cloud._tuyaplatform(**kw)
    h = seen["headers"]
    return {
        "method": seen["method"],
        "url": seen["url"],
        "token": cloud.token,
        "t": h["t"],
        "sign": h["sign"],
        "body": seen.get("body"),
    }


def main() -> None:
    with mock.patch.object(tinytuya.Cloud, "_gettoken", lambda self: None):
        cloud = tinytuya.Cloud(apiRegion="in", apiKey=API_KEY, apiSecret=API_SECRET)
    cloud.token = None
    vectors = [
        dict(name="token", **capture(cloud, uri="token?grant_type=1")),
    ]
    cloud.token = TOKEN
    vectors += [
        dict(
            name="associated-users",
            **capture(
                cloud,
                uri="/v1.0/iot-01/associated-users/devices",
                ver=None,
                query={"size": "50"},
            ),
        ),
        dict(
            name="by-uid",
            **capture(
                cloud,
                uri="/v1.3/iot-03/devices",
                ver=None,
                query={
                    "page_size": "75",
                    "source_type": "tuyaUser",
                    "source_id": "ay0000000000000uid",
                    "last_row_key": "row1",
                },
            ),
        ),
        dict(name="specifications", **capture(cloud, uri="devices/bfdev/specifications", ver="v1.1")),
        dict(
            name="post",
            **capture(cloud, uri="devices/bfdev/commands", action="POST", post={"commands": []}, ver="v1.0"),
        ),
    ]
    out = Path(__file__).resolve().parents[2] / "app/test/onboarding/cloud_import/signing_vectors.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps(
            {"host": cloud.urlhost, "access_id": API_KEY, "access_secret": API_SECRET, "t": NOW_MS, "vectors": vectors},
            indent=2,
        )
        + "\n"
    )
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
