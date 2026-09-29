import asyncio
import json
from typing import Any

import pytest


class UdpClient:
    """Minimal UDP request/response client for tests."""

    async def request(self, host: str, port: int, payload: dict[str, Any], timeout: float = 1.0) -> dict[str, Any]:
        loop = asyncio.get_running_loop()
        fut: asyncio.Future[bytes] = loop.create_future()

        class _Proto(asyncio.DatagramProtocol):
            def datagram_received(self, data: bytes, addr: tuple[str, int]) -> None:
                if not fut.done():
                    fut.set_result(data)

        transport, _ = await loop.create_datagram_endpoint(_Proto, remote_addr=(host, port))
        try:
            transport.sendto(json.dumps(payload).encode())
            return json.loads(await asyncio.wait_for(fut, timeout))
        finally:
            transport.close()


@pytest.fixture
def udp() -> UdpClient:
    return UdpClient()
