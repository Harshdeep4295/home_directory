"""Base classes for simulated devices."""

from __future__ import annotations

import abc
import asyncio
import logging
from typing import Any, ClassVar

log = logging.getLogger("ohsim")


class SimDevice(abc.ABC):
    """A fake device listening on host:port. Tests may read and mutate ``state`` directly."""

    kind: ClassVar[str]  # name used on the run.py command line, e.g. "wiz"
    protocol: ClassVar[str]  # protocol id as the app names it, e.g. "wiz", "tuya-3.3"

    def __init__(
        self,
        name: str | None = None,
        host: str = "127.0.0.1",
        port: int = 0,
        device_id: str | None = None,
        **options: str,
    ) -> None:
        self.name = name or self.kind
        self.host = host
        self.requested_port = port
        self.options = options
        self.device_id = device_id or self.default_device_id()
        self.state: dict[str, Any] = self.initial_state()
        self._port: int | None = None

    def default_device_id(self) -> str:
        return f"sim-{self.kind}"

    def initial_state(self) -> dict[str, Any]:
        return {"on": False}

    @property
    def port(self) -> int:
        if self._port is None:
            raise RuntimeError(f"{self.name} not started")
        return self._port

    @property
    def running(self) -> bool:
        return self._port is not None

    @abc.abstractmethod
    async def start(self) -> None: ...

    @abc.abstractmethod
    async def stop(self) -> None: ...

    def info(self) -> dict[str, Any]:
        """Entry printed by run.py and consumed by Flutter integration tests."""
        return {
            "kind": self.kind,
            "protocol": self.protocol,
            "host": self.host,
            "port": self.port,
            "id": self.device_id,
        }

    async def __aenter__(self) -> "SimDevice":
        await self.start()
        return self

    async def __aexit__(self, *exc: object) -> None:
        await self.stop()


class UdpSimDevice(SimDevice):
    """Request/response over UDP. Subclasses implement ``handle_datagram``."""

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self._transport: asyncio.DatagramTransport | None = None

    @abc.abstractmethod
    def handle_datagram(self, data: bytes, addr: tuple[str, int]) -> bytes | None:
        """Return the reply bytes, or None to stay silent."""

    async def start(self) -> None:
        loop = asyncio.get_running_loop()
        device = self

        class _Proto(asyncio.DatagramProtocol):
            def connection_made(self, transport: asyncio.BaseTransport) -> None:
                self.transport = transport  # type: ignore[assignment]

            def datagram_received(self, data: bytes, addr: tuple[str, int]) -> None:
                try:
                    reply = device.handle_datagram(data, addr)
                except Exception:  # a broken request must never kill the simulator
                    log.exception("%s: error handling datagram", device.name)
                    return
                if reply is not None:
                    self.transport.sendto(reply, addr)  # type: ignore[attr-defined]

        transport, _ = await loop.create_datagram_endpoint(
            _Proto, local_addr=(self.host, self.requested_port)
        )
        self._transport = transport
        self._port = transport.get_extra_info("sockname")[1]

    async def stop(self) -> None:
        if self._transport is not None:
            self._transport.close()
            self._transport = None
        self._port = None


class TcpSimDevice(SimDevice):
    """Stream server. Subclasses implement ``handle_connection``."""

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self._server: asyncio.Server | None = None
        self._clients: set[asyncio.StreamWriter] = set()

    @abc.abstractmethod
    async def handle_connection(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None: ...

    async def _serve(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        self._clients.add(writer)
        try:
            await self.handle_connection(reader, writer)
        except (ConnectionError, asyncio.IncompleteReadError):
            pass
        except Exception:
            log.exception("%s: error in connection handler", self.name)
        finally:
            self._clients.discard(writer)
            writer.close()

    async def start(self) -> None:
        self._server = await asyncio.start_server(
            self._serve, self.host, self.requested_port, reuse_address=True
        )
        self._port = self._server.sockets[0].getsockname()[1]

    async def stop(self) -> None:
        # Drop live connections too, so adapters see a real disconnect (reconnect tests).
        for w in list(self._clients):
            w.close()
        if self._server is not None:
            self._server.close()
            await self._server.wait_closed()
            self._server = None
        self._port = None
