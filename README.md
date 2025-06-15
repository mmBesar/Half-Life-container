# 🚧 Half-Life Server (Xash3D FWGS) Container

**⚠️ This project is under active development and not production-ready yet.**  
Use it for testing, experimentation, and learning purposes.

---

## 🎮 Features

- ✅ Supports Xash3D-FWGS dedicated server
- ✅ Multi-arch support: `amd64`, `arm64`, `i386`, `armhf`
- ✅ Mount external `valve/`, `cstrike/`, `configs/`, `logs/`
- ✅ Enable or disable bots using `liblist.gam`
- ✅ Set map, port, IP, player count via environment variables
- ✅ Optional host networking for true LAN discovery
- ✅ RCON support with manual config

---

## 🏗️ Image Tags

| Arch   | Docker Tag                                   |
|--------|----------------------------------------------|
| amd64  | `ghcr.io/youruser/half-life:latest-amd64`    |
| arm64  | `ghcr.io/youruser/half-life:latest-arm64`    |
| i386   | `ghcr.io/youruser/half-life:latest-i386`     |
| armhf  | `ghcr.io/youruser/half-life:latest-armhf`    |

Replace `youruser` with your GHCR username or organization.

---

## 🧠 Bot Support

Mount two files inside `/data/configs/`:

- `liblist.clean.gam` → no bots
- `liblist.bots.gam`  → bots enabled

Enable bots using:

```yaml
environment:
  HLSERVER_BOTS: true
````

---

## 🔧 Example `docker-compose.yml` (host mode)

```yaml
services:
  half-life:
    image: ghcr.io/youruser/half-life:latest-amd64
    container_name: half-life
    network_mode: host  # Enables LAN discovery
    restart: unless-stopped
    user: "${PUID}:${PGID}"
    volumes:
      - ${CONTAINER_DIR}/half-life/valve:/data/valve
      - ${CONTAINER_DIR}/half-life/cstrike:/data/cstrike
      - ${CONTAINER_DIR}/half-life/logs:/data/logs
      - ${CONTAINER_DIR}/half-life/configs:/data/configs:ro
    environment:
      HLSERVER_IP: 0.0.0.0
      HLSERVER_GAME: valve
      HLSERVER_PORT: 27015
      HLSERVER_MAP: stalkyard
      HLSERVER_MAXPLAYERS: 16
      HLSERVER_BOTS: false
```

> ❗ Ports section is not needed in `host` mode.
> If using `bridge` mode, manually expose all relevant UDP ports.

---

## 🧱 Architecture Requirements

### ✅ For `amd64`:

* Use `valve/dlls/hl.so` compiled for 64-bit Linux (x86\_64)

### ✅ For `arm64` (e.g. Raspberry Pi 4):

* Build `hl.so` and `client.so` using [FWGS/hlsdk-portable](https://github.com/FWGS/hlsdk-portable)
* Place them in `valve/dlls/` and `valve/cl_dlls/`

### ✅ For `i386` and `armhf`:

* Requires matching 32-bit `.so` game DLLs

---

## 🕹️ Connecting to the Server

### A. 📡 LAN Discovery (in-game browser)

* Requires `network_mode: host`
* `sv_lan 1` must be set in `server.cfg`

### B. 🖥️ Manual Connect

Open game console and run:

```
connect 192.168.100.51:27015
```

To enable console:

* Steam → Properties → Launch Options: `-console`
* Or bind a key in-game (Keyboard → Advanced)

---

## 🔒 Networking Notes

Ports used by default:

* `27015/udp` — main game server port
* `27005/udp`, `27025/udp`, `47584/udp|tcp` — optional/extras

In `host` mode, you do **not** need to expose ports manually.

---

## 🛠️ Troubleshooting

* ❌ `game directory "valve" not exist` → Ensure working dir is `/data` and mounted correctly
* ❌ `couldn't get physics API` → Use a compatible architecture-specific `hl.so`
* ❌ Can't see server in game browser → Use `network_mode: host` or `connect` by IP

---

## 📦 Optional Extras

* `liblist.gam` bot control via ENV
* RCON via `rcon_password` in `server.cfg`
* Future enhancement: `socat`-based UDP rebroadcast for bridge mode LAN discovery
