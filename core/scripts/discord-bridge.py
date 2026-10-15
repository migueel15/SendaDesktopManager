#!/usr/bin/env python3
"""Local Discord voice bridge for Senda (Python standard library only)."""
from __future__ import annotations

import argparse
import asyncio
import ctypes
import fcntl
import json
import math
import os
import signal
import socket
import struct
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

CLIENT_ID = "207646673902501888"
SCOPES = ["rpc", "rpc.voice.read", "rpc.voice.write"]
EXCHANGE = "https://streamkit.discord.com/overlay/token"
OP_HANDSHAKE, OP_FRAME, OP_CLOSE, OP_PING, OP_PONG = range(5)
IN_CREATE, IN_MOVED_TO, IN_DELETE, IN_MOVED_FROM, IN_ISDIR = 0x100, 0x80, 0x200, 0x40, 0x40000000
IN_IGNORED = 0x8000
INOTIFY_MASK = IN_CREATE | IN_MOVED_TO | IN_DELETE | IN_MOVED_FROM
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
SOCKET = RUNTIME / "senda-discord.sock"
LOCK = RUNTIME / "senda-discord.lock"
DATA = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "senda/discord"
TOKEN = DATA / "token.json"


def get_token():
    try:
        return json.loads(TOKEN.read_text()).get("access_token")
    except (OSError, ValueError):
        return None


def save_token(value):
    DATA.mkdir(mode=0o700, parents=True, exist_ok=True)
    DATA.chmod(0o700)
    fd = os.open(TOKEN, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"access_token": value}, f)


class Bridge:
    def __init__(self):
        self.reader = self.writer = None
        self.nonce = 0
        self.pending = {}
        self.state = {"connected": False, "authenticated": False, "auth_required": False,
                      "channel": None, "mute": False, "deaf": False, "speaking": [], "participants": [],
                      "self_speaking": False, "error": ""}
        self.user_id = None
        self.clients = set()
        self.connection_lock = asyncio.Lock()

    @staticmethod
    def participant(data):
        user = data.get("user") or {}
        user_id = str(user.get("id") or data.get("user_id") or "")
        if not user_id:
            return None
        avatar_hash = user.get("avatar")
        if avatar_hash:
            extension = "gif" if str(avatar_hash).startswith("a_") else "png"
            avatar = f"https://cdn.discordapp.com/avatars/{user_id}/{avatar_hash}.{extension}?size=64"
        else:
            avatar = f"https://cdn.discordapp.com/embed/avatars/{(int(user_id) >> 22) % 6}.png"
        return {"id": user_id, "name": data.get("nick") or user.get("global_name") or user.get("username") or "Usuario",
                "avatar": avatar}

    def update_participant(self, data):
        participant = self.participant(data)
        if not participant:
            return
        participants = {item["id"]: item for item in self.state["participants"]}
        previous = participants.get(participant["id"], {})
        voice_state = data.get("voice_state") or {}
        participant["volume"] = data.get("volume", previous.get("volume", 100))
        participant["mute"] = bool(data.get("mute", previous.get("mute", False)))
        participant["pan"] = data.get("pan", previous.get("pan", {"left": 1.0, "right": 1.0}))
        participant["server_mute"] = bool(voice_state.get("mute", previous.get("server_mute", False)))
        participant["server_deaf"] = bool(voice_state.get("deaf", previous.get("server_deaf", False)))
        participant["self_mute"] = bool(voice_state.get("self_mute", previous.get("self_mute", False)))
        participant["self_deaf"] = bool(voice_state.get("self_deaf", previous.get("self_deaf", False)))
        participants[participant["id"]] = participant
        self.state["participants"] = list(participants.values())

    def update_participant_settings(self, data):
        user_id = str(data.get("user_id") or "")
        if not user_id:
            return
        participants = []
        for participant in self.state["participants"]:
            if participant["id"] == user_id:
                participant = dict(participant)
                if "volume" in data:
                    participant["volume"] = data["volume"]
                if "mute" in data:
                    participant["mute"] = bool(data["mute"])
                if "pan" in data:
                    participant["pan"] = data["pan"]
            participants.append(participant)
        self.state["participants"] = participants

    def remove_participant(self, data):
        user = data.get("user") or {}
        user_id = str(user.get("id") or data.get("user_id") or "")
        self.state["participants"] = [item for item in self.state["participants"] if item["id"] != user_id]
        self.state["speaking"] = [item for item in self.state["speaking"] if item != user_id]

    async def send_discord(self, opcode, data):
        raw = json.dumps(data).encode()
        self.writer.write(struct.pack("<II", opcode, len(raw)) + raw)
        await self.writer.drain()

    async def recv_discord(self):
        op, size = struct.unpack("<II", await self.reader.readexactly(8))
        return op, json.loads((await self.reader.readexactly(size)).decode())

    async def command(self, name, args=None):
        self.nonce += 1
        nonce = str(self.nonce)
        self.pending[nonce] = name
        payload = {"cmd": name, "nonce": nonce}
        if args is not None:
            payload["args"] = args
        await self.send_discord(OP_FRAME, payload)

    async def connect_discord(self, authorize=False):
        async with self.connection_lock:
            await self._connect_discord(authorize)

    async def _connect_discord(self, authorize=False):
        if self.writer:
            if authorize:
                await self.authorize()
            return
        candidates = []
        bases = [RUNTIME, Path(os.environ.get("TMPDIR", "/tmp")), Path("/tmp")]
        flatpak = RUNTIME / "app/com.discordapp.Discord"
        if flatpak.is_dir():
            bases.insert(1, flatpak)
        for base in bases:
            candidates.extend(base / f"discord-ipc-{i}" for i in range(10))
        for path in candidates:
            try:
                self.reader, self.writer = await asyncio.open_unix_connection(str(path))
                break
            except OSError:
                pass
        if not self.writer:
            raise RuntimeError("No encuentro el socket IPC; abre Discord primero")
        await self.send_discord(OP_HANDSHAKE, {"v": 1, "client_id": CLIENT_ID})
        _, ready = await asyncio.wait_for(self.recv_discord(), 5)
        if ready.get("evt") != "READY":
            raise RuntimeError("Discord no aceptó el handshake local")
        self.state["connected"] = True
        asyncio.create_task(self.reader_loop())
        if authorize:
            await self.authorize()
        elif (token := get_token()):
            await self.command("AUTHENTICATE", {"access_token": token})
        else:
            self.state["auth_required"] = True

    async def try_connect(self):
        try:
            await self.connect_discord()
        except Exception:
            if self.writer:
                self.writer.close()
                try:
                    await self.writer.wait_closed()
                except OSError:
                    pass
                self.reader = self.writer = None
            self.state.update(connected=False, authenticated=False, channel=None,
                              self_speaking=False, speaking=[], participants=[])
            await self.broadcast()

    async def watch_discord_sockets(self):
        libc = ctypes.CDLL(None, use_errno=True)
        libc.inotify_init1.argtypes = (ctypes.c_int,)
        libc.inotify_init1.restype = ctypes.c_int
        libc.inotify_add_watch.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32)
        libc.inotify_add_watch.restype = ctypes.c_int
        fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
        if fd < 0:
            raise OSError(ctypes.get_errno(), "inotify_init1 failed")

        loop = asyncio.get_running_loop()
        watched = set()
        watch_paths = {}

        def add_watch(path):
            path = Path(path)
            key = str(path)
            if key in watched or not path.is_dir():
                return
            wd = libc.inotify_add_watch(fd, os.fsencode(path), INOTIFY_MASK)
            if wd >= 0:
                watched.add(key)
                watch_paths[wd] = path

        bases = {RUNTIME, Path(os.environ.get("TMPDIR", "/tmp")), Path("/tmp")}
        for base in bases:
            add_watch(base)
        add_watch(RUNTIME / "app")
        add_watch(RUNTIME / "app" / "com.discordapp.Discord")

        # Connect immediately if Discord was already open before the watcher started.
        await self.try_connect()

        try:
            while True:
                ready = loop.create_future()
                loop.add_reader(fd, lambda: None if ready.done() else ready.set_result(None))
                try:
                    await ready
                finally:
                    loop.remove_reader(fd)

                while True:
                    try:
                        events = os.read(fd, 65536)
                    except BlockingIOError:
                        break
                    offset = 0
                    should_connect = False
                    while offset + 16 <= len(events):
                        wd, mask, _cookie, name_length = struct.unpack_from("iIII", events, offset)
                        name = events[offset + 16:offset + 16 + name_length].split(b"\0", 1)[0].decode(errors="ignore")
                        offset += 16 + name_length
                        parent = watch_paths.get(wd)
                        if mask & IN_IGNORED:
                            watch_paths.pop(wd, None)
                            if parent:
                                watched.discard(str(parent))
                            continue
                        if parent and name and mask & IN_ISDIR:
                            child = parent / name
                            add_watch(child)
                            if mask & (IN_CREATE | IN_MOVED_TO):
                                should_connect = True
                        if name.startswith("discord-ipc-") and mask & (IN_CREATE | IN_MOVED_TO):
                            should_connect = True
                    if should_connect:
                        asyncio.create_task(self.try_connect())
        finally:
            loop.remove_reader(fd)
            os.close(fd)

    async def authorize(self):
        self.nonce += 1
        nonce = str(self.nonce)
        self.pending[nonce] = "AUTHORIZE"
        await self.send_discord(OP_FRAME, {"cmd": "AUTHORIZE", "args": {
            "client_id": CLIENT_ID, "scopes": SCOPES, "prompt": "none"}, "nonce": nonce})

    async def reader_loop(self):
        try:
            while self.writer:
                op, msg = await self.recv_discord()
                if op == OP_PING:
                    await self.send_discord(OP_PONG, msg)
                    continue
                nonce, evt = msg.get("nonce"), msg.get("evt")
                name = self.pending.pop(nonce, None)
                data = msg.get("data") or {}
                if evt == "ERROR":
                    if name == "AUTHENTICATE":
                        TOKEN.unlink(missing_ok=True)
                        self.state.update(authenticated=False, auth_required=True, error=data.get("message", "Auth failed"))
                    else:
                        self.state["error"] = data.get("message", "Discord RPC error")
                elif name == "AUTHORIZE":
                    code = data.get("code")
                    if code:
                        req = urllib.request.Request(EXCHANGE, data=json.dumps({"code": code}).encode(),
                            headers={"Content-Type": "application/json", "User-Agent": "Senda/1.0"}, method="POST")
                        with urllib.request.urlopen(req, timeout=10) as response:
                            token = json.loads(response.read()).get("access_token")
                        if token:
                            save_token(token)
                            await self.command("AUTHENTICATE", {"access_token": token})
                elif name == "AUTHENTICATE":
                    self.user_id = str((data.get("user") or {}).get("id") or "") or None
                    self.state.update(authenticated=True, auth_required=False, error="")
                    for ev in ("VOICE_CHANNEL_SELECT", "VOICE_SETTINGS_UPDATE"):
                        await self.subscribe(ev)
                    await self.command("GET_SELECTED_VOICE_CHANNEL")
                    await self.command("GET_VOICE_SETTINGS")
                elif name == "GET_SELECTED_VOICE_CHANNEL":
                    previous_channel_id = (self.state["channel"] or {}).get("id")
                    self.state["channel"] = ({"id": data.get("id"), "name": data.get("name"),
                        "guild": data.get("guild_name", ""), "guild_id": data.get("guild_id")}
                        if data.get("id") else None)
                    if not data.get("id") or data.get("id") != previous_channel_id:
                        self.state["self_speaking"] = False
                        self.state["speaking"] = []
                        self.state["participants"] = []
                    if data.get("id"):
                        for voice_state in data.get("voice_states", []):
                            self.update_participant(voice_state)
                        for event in ("SPEAKING_START", "SPEAKING_STOP"):
                            await self.subscribe(event, {"channel_id": data["id"]})
                        for event in ("VOICE_STATE_CREATE", "VOICE_STATE_UPDATE", "VOICE_STATE_DELETE"):
                            await self.subscribe(event, {"channel_id": data["id"]})
                elif name == "SELECT_VOICE_CHANNEL":
                    await self.command("GET_SELECTED_VOICE_CHANNEL")
                elif name in ("GET_VOICE_SETTINGS", "SET_VOICE_SETTINGS"):
                    for setting in ("mute", "deaf"):
                        if setting in data:
                            self.state[setting] = bool(data[setting])
                elif name == "SET_USER_VOICE_SETTINGS":
                    self.update_participant_settings(data)
                elif msg.get("cmd") == "DISPATCH":
                    if evt == "VOICE_CHANNEL_SELECT":
                        await self.command("GET_SELECTED_VOICE_CHANNEL")
                    elif evt == "VOICE_SETTINGS_UPDATE":
                        for setting in ("mute", "deaf"):
                            if setting in data:
                                self.state[setting] = bool(data[setting])
                    elif evt == "SPEAKING_START":
                        user_id = str(data.get("user_id") or "")
                        self.state["speaking"] = list(set(self.state["speaking"] + [user_id]))
                        if user_id and user_id == self.user_id:
                            self.state["self_speaking"] = True
                    elif evt == "SPEAKING_STOP":
                        user_id = str(data.get("user_id") or "")
                        self.state["speaking"] = [x for x in self.state["speaking"] if x != user_id]
                        if user_id and user_id == self.user_id:
                            self.state["self_speaking"] = False
                    elif evt in ("VOICE_STATE_CREATE", "VOICE_STATE_UPDATE"):
                        self.update_participant(data)
                    elif evt == "VOICE_STATE_DELETE":
                        self.remove_participant(data)
                await self.broadcast()
        except (OSError, asyncio.IncompleteReadError, asyncio.CancelledError):
            self.state.update(connected=False, authenticated=False, channel=None, self_speaking=False,
                              speaking=[], participants=[])
            self.user_id = None
            self.writer = self.reader = None
            await self.broadcast()

    async def subscribe(self, event, args=None):
        self.nonce += 1
        message = {"cmd": "SUBSCRIBE", "evt": event, "nonce": str(self.nonce)}
        if args:
            message["args"] = args
        await self.send_discord(OP_FRAME, message)

    async def broadcast(self):
        for writer in tuple(self.clients):
            try:
                writer.write((json.dumps(self.state) + "\n").encode())
                await writer.drain()
            except OSError:
                self.clients.discard(writer)

    async def handle(self, reader, writer):
        try:
            line = await asyncio.wait_for(reader.readline(), 3)
            req = json.loads(line or b"{}")
            action = req.get("action", "status")
            if action == "watch":
                self.clients.add(writer)
                writer.write((json.dumps(self.state) + "\n").encode())
                await writer.drain()
                await reader.read()
                return
            if action == "connect":
                await self.connect_discord()
            elif action == "authorize":
                await self.connect_discord(authorize=True)
            elif action == "leave":
                if not self.state["authenticated"]:
                    raise RuntimeError("Discord no está autorizado; ejecuta senda discord authorize")
                if not self.state["channel"]:
                    raise RuntimeError("No estás en un canal de voz")
                self.state["error"] = ""
                await self.command("SELECT_VOICE_CHANNEL", {"channel_id": None})
                deadline = asyncio.get_running_loop().time() + 3
                while self.state["channel"] and asyncio.get_running_loop().time() < deadline:
                    await asyncio.sleep(.05)
                if self.state["channel"]:
                    raise RuntimeError(self.state["error"] or "Discord no confirmó la salida del canal")
            elif action in ("set-user-volume", "set-user-mute"):
                if not self.state["authenticated"]:
                    raise RuntimeError("Discord no está autorizado; ejecuta senda discord authorize")
                if not self.state["channel"]:
                    raise RuntimeError("No estás en un canal de voz")
                user_id = str(req.get("args", {}).get("user_id") or "")
                participant = next((item for item in self.state["participants"] if item["id"] == user_id), None)
                if not participant:
                    raise RuntimeError("Ese usuario ya no está en el canal de voz")
                self.state["error"] = ""
                await self.broadcast()
                if action == "set-user-volume":
                    volume = float(req["args"]["volume"])
                    if not math.isfinite(volume) or not 0 <= volume <= 200:
                        raise RuntimeError("El volumen debe ser un número entre 0 y 200")
                    await self.command("SET_USER_VOICE_SETTINGS", {"user_id": user_id, "volume": volume})
                else:
                    await self.command("SET_USER_VOICE_SETTINGS", {
                        "user_id": user_id, "mute": bool(req["args"]["mute"])})
            elif action in ("mute", "unmute", "toggle-mute", "deafen", "undeafen", "toggle-deafen"):
                if not self.state["authenticated"]:
                    raise RuntimeError("Discord no está autorizado; ejecuta senda discord authorize")
                if action in ("mute", "unmute", "toggle-mute"):
                    field = "mute"
                    desired = not self.state["mute"] if action == "toggle-mute" else action == "mute"
                    if action == "unmute" and self.state["deaf"]:
                        await self.command("SET_VOICE_SETTINGS", {"mute": False})
                        await asyncio.sleep(.15)
                        await self.command("SET_VOICE_SETTINGS", {"deaf": False})
                    else:
                        await self.command("SET_VOICE_SETTINGS", {field: desired})
                else:
                    field = "deaf"
                    desired = not self.state["deaf"] if action == "toggle-deafen" else action == "deafen"
                    await self.command("SET_VOICE_SETTINGS", {field: desired})
                await asyncio.sleep(.15)
            elif action == "shutdown":
                writer.write(b'{"ok":true}\n'); await writer.drain()
                os.kill(os.getpid(), signal.SIGTERM)
            writer.write((json.dumps({"ok": True, "state": self.state}) + "\n").encode())
            await writer.drain()
        except Exception as e:
            writer.write((json.dumps({"ok": False, "error": str(e), "state": self.state}) + "\n").encode())
            await writer.drain()
        finally:
            self.clients.discard(writer)
            writer.close()

    async def run(self):
        SOCKET.parent.mkdir(parents=True, exist_ok=True)
        lock_fd = os.open(LOCK, os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            os.close(lock_fd)
            return

        self.lock_fd = lock_fd
        SOCKET.unlink(missing_ok=True)
        server = await asyncio.start_unix_server(self.handle, path=str(SOCKET))
        os.chmod(SOCKET, 0o600)
        asyncio.create_task(self.watch_discord_sockets())
        async with server:
            await server.serve_forever()


def rpc(action, parameters=None):
    try:
        with socket.socket(socket.AF_UNIX) as sock:
            sock.settimeout(3)
            sock.connect(str(SOCKET))
            request = {"action": action}
            if parameters is not None:
                request["args"] = parameters
            sock.sendall((json.dumps(request) + "\n").encode())
            chunks = b""
            while not chunks.endswith(b"\n"):
                chunks += sock.recv(65536)
        result = json.loads(chunks)
    except (OSError, ValueError) as exc:
        return {"ok": False, "error": f"Bridge not running: {exc}", "state": {
            "connected": False, "authenticated": False, "auth_required": False, "channel": None,
            "mute": False, "deaf": False, "speaking": [], "participants": [], "error": "bridge not running"}}
    return result


def start_daemon():
    if bridge_available():
        return True
    script = Path(__file__).resolve()
    subprocess.Popen([sys.executable, str(script), "daemon"], stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True, close_fds=True)
    for _ in range(40):
        if bridge_available():
            return True
        time.sleep(.05)
    return False


def bridge_available():
    try:
        with socket.socket(socket.AF_UNIX) as sock:
            sock.settimeout(.1)
            sock.connect(str(SOCKET))
        return True
    except OSError:
        return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["daemon", "status", "connect", "authorize", "mute", "unmute", "toggle-mute", "deafen", "undeafen", "toggle-deafen", "leave", "set-user-volume", "set-user-mute", "reset-user", "shutdown"])
    parser.add_argument("parameters", nargs="*")
    args = parser.parse_args()
    if args.action == "daemon":
        asyncio.run(Bridge().run()); return
    parameters = None
    if args.action in ("set-user-volume", "set-user-mute"):
        if len(args.parameters) != 2:
            parser.error(f"{args.action} requiere el ID del usuario y un valor")
        user_id, value = args.parameters
        if args.action == "set-user-volume":
            try:
                parameters = {"user_id": user_id, "volume": float(value)}
            except ValueError:
                parser.error("el volumen debe ser un número entre 0 y 200")
            if not math.isfinite(parameters["volume"]) or not 0 <= parameters["volume"] <= 200:
                parser.error("el volumen debe ser un número entre 0 y 200")
        else:
            if value.lower() not in ("true", "false"):
                parser.error("el mute debe ser true o false")
            parameters = {"user_id": user_id, "mute": value.lower() == "true"}
    elif args.action == "reset-user":
        if len(args.parameters) != 1:
            parser.error("reset-user requiere el ID del usuario")
        parameters = {"user_id": args.parameters[0]}
    if args.action in ("connect", "authorize") and not bridge_available():
        if not start_daemon():
            result = {"ok": False, "error": "No se pudo iniciar el puente"}
        else:
            result = rpc(args.action, parameters)
    elif args.action == "reset-user":
        user_id = parameters["user_id"]
        result = rpc("set-user-volume", {"user_id": user_id, "volume": 100})
        if result.get("ok"):
            time.sleep(.2)
            result = rpc("set-user-mute", {"user_id": user_id, "mute": False})
    else:
        result = rpc(args.action, parameters)
    if args.action == "status":
        print(json.dumps(result.get("state", result), ensure_ascii=False))
    elif not result.get("ok"):
        print(result.get("error", "Error"), file=sys.stderr); sys.exit(1)


if __name__ == "__main__":
    main()
