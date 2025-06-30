# 🚧 Half-Life Server (Xash3D FWGS) Container

**⚠️ This project is under active development and not production-ready yet.**  
Use it for testing, experimentation, and learning purposes.

---

## 🎮 Features

- ✅ Supports Xash3D-FWGS dedicated server
- ✅ Multi-arch support: `amd64`, `arm64`
- ✅ Mount external `valve/`, `cstrike/`, `configs/`
- ✅ Set map, port, IP, player count via environment variables
- ✅ Optional host networking for true LAN discovery

---

## 🏗️ Image Tags

| Arch   | Container Tag                                   |
|--------|----------------------------------------------|
| amd64  | `ghcr.io/youruser/half-life:latest-amd64`    |
| arm64  | `ghcr.io/youruser/half-life:latest-arm64`    |

Replace `youruser` with your GHCR username or organization.

---

## 🧠 Bot Support

```yml
    environment:
      HLSERVER_BOTS: true
```

---

## 🔧 Example `docker-compose.yml` (host mode)

```yaml
services:
  half-life:
    image: ghcr.io/mmbesar/half-life-container:latest
    container_name: half-life
    network_mode: "host"
    restart: unless-stopped
    user: "1000:1000"
    # ports:
    #   - "27015:27015/udp"  # main game port
    volumes:
      - ./half-life/valve:/data/valve
      - ./half-life/dll:/data/dll
      - ./half-life/cstrike:/data/cstrike
      - ./half-life/logs:/data/logs
      - ./half-life/configs:/data/configs:ro
      - ./half-life/entrypoint.sh:/usr/local/bin/entrypoint.sh
    environment:
      # XASH3D_BASE: /opt/xash
      # HLSDK_LIBS_PATH: /opt/hlsdk-libs
      HLSERVER_IP: 0.0.0.0
      HLSERVER_GAME: valve
      HLSERVER_PORT: 27015
      HLSERVER_MAXPLAYERS: 16
      HLSERVER_FRAGLIMIT: 20
      HLSERVER_TIMELIMIT: 10
      HLSERVER_MAP: stalkyard
      HLSERVER_MAPCYCLE: stalkyard,gasworks,datacore
      HLSERVER_BOTS: true
      HLSERVER_BOTS_COUNT: 8
      HLSERVER_RCON_PASS: ${BASIC_PASSWORD}
    # Resource limits for Pi4
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 64M
```

> ❗ Ports section is not needed in `host` mode.
> If using `bridge` mode, manually expose all relevant UDP ports.

---

## 🕹️ Connecting to the Server

### A. 📡 LAN Discovery (in-game browser)

* Requires `network_mode: host`
* `sv_lan 1` must be set in `server.cfg`

### B. 🖥️ Manual Connect

Open game console and run:

```
connect 192.168.100.100:27015
```

To enable console:

* Steam → Properties → Launch Options: `-console`
* Or bind a key in-game (Keyboard → Advanced)

---

## 🔒 Networking Notes

Ports used by default:

* `27015/udp` — main game server port

In `host` mode, you do **not** need to expose ports manually.

---

## 🛠️ Troubleshooting

* ❌ `game directory "valve" not exist` → Ensure working dir is `/data` and mounted correctly
* ❌ Can't see server in game browser → Use `network_mode: host` or `connect` by IP
