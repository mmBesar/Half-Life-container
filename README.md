# 🎮 Half-Life Dedicated Server — Docker Container

[![Build & Push Image](https://img.shields.io/github/actions/workflow/status/mmBesar/Half-Life-container/image-build.yml?branch=main&label=image%20build&logo=docker&logoColor=white)](https://github.com/mmBesar/Half-Life-container/actions/workflows/image-build.yml)
[![Upstream Check](https://img.shields.io/github/actions/workflow/status/mmBesar/Half-Life-container/upstream-check.yml?label=upstream%20check&logo=github&logoColor=white)](https://github.com/mmBesar/Half-Life-container/actions/workflows/upstream-check.yml)
[![Image on GHCR](https://img.shields.io/badge/ghcr.io-half--life--container-blue?logo=github&logoColor=white)](https://github.com/mmBesar/Half-Life-container/pkgs/container/half-life-container)
[![Platforms](https://img.shields.io/badge/platforms-amd64%20%7C%20arm64-lightgrey?logo=linux&logoColor=white)](https://github.com/mmBesar/Half-Life-container/pkgs/container/half-life-container)
[![License](https://img.shields.io/badge/license-GPL--3.0-green)](https://www.gnu.org/licenses/gpl-3.0.html)
[![Xash3D FWGS](https://img.shields.io/badge/engine-Xash3D%20FWGS-orange?logo=github&logoColor=white)](https://github.com/FWGS/xash3d-fwgs)
[![HPB Bot #10](https://img.shields.io/badge/bots-HPB%20Bot%20%2310-red?logo=github&logoColor=white)](https://github.com/FWGS/hlsdk-portable/tree/bot10)

---

> ⚠️ **PERSONAL USE ONLY**
> This project is intended for personal, private, non-commercial use.
> You must own a legitimate copy of Half-Life (via Steam) to run this server.
> This project does not include, distribute, or circumvent any Valve game files.

---

## ✨ Features

- ✅ Runs a full Half-Life dedicated server using [Xash3D FWGS](https://github.com/FWGS/xash3d-fwgs)
- ✅ Native multi-arch builds: `amd64` and `arm64` (Raspberry Pi 4 ready)
- ✅ Bot support via [botman's HPB Bot #10](https://github.com/FWGS/hlsdk-portable/tree/bot10)
- ✅ Full bot control: count, skill, names, skins — all via environment variables
- ✅ Auto-rebuilds when upstream xash3d-fwgs releases a new build
- ✅ All server config generated at startup from environment variables
- ✅ Host networking for true LAN discovery
- ✅ Supports `valve`, `cstrike`, and other mods

---

## 🏗️ Image Tags

| Tag | Description |
|---|---|
| `ghcr.io/mmbesar/half-life-container:latest` | Multi-arch manifest (auto-selects correct arch) |
| `ghcr.io/mmbesar/half-life-container:latest-amd64` | amd64 only |
| `ghcr.io/mmbesar/half-life-container:latest-arm64` | arm64 only |

---

## 📋 Requirements

- Docker + Docker Compose
- A **legally purchased** copy of Half-Life on [Steam](https://store.steampowered.com/app/70/HalfLife/)
- The `valve/` folder copied from your Half-Life installation

---

## 🚀 Quick Start

**1. Prepare your game files:**
```
your-data-dir/
└── half-life/
    └── valve/        ← copy from your Half-Life installation
```

**2. Create a `.env` file:**
```env
CONTAINER_DIR=/opt/containers
PUID=1000
PGID=1000
TZ=Africa/Cairo
BASIC_PASSWORD=your_rcon_password
```

**3. Copy `docker-compose.yml` from this repo and start:**
```bash
docker compose up -d
docker compose logs -f half-life
```

---

## 🔧 docker-compose.yml

```yaml
services:
  half-life:
    image: ghcr.io/mmbesar/half-life-container:latest
    container_name: half-life
    network_mode: "host"
    restart: unless-stopped
    user: "${PUID}:${PGID}"
    # ports:                         # not needed in host mode
    #   - "27015:27015/udp"
    volumes:
      - ${CONTAINER_DIR}/half-life/valve:/data/valve
      - ${CONTAINER_DIR}/half-life/dll:/data/dll
      - ${CONTAINER_DIR}/half-life/cstrike:/data/cstrike
      - ${CONTAINER_DIR}/half-life/logs:/data/logs
      - ${CONTAINER_DIR}/half-life/configs:/data/configs:ro
      - ${CONTAINER_DIR}/half-life/entrypoint.sh:/usr/local/bin/entrypoint.sh
    environment:
      TZ: ${TZ}
      HLSERVER_GAME: valve
      HLSERVER_NAME: "My Half-Life Server"
      HLSERVER_IP: 0.0.0.0
      HLSERVER_PORT: 27015
      HLSERVER_MAXPLAYERS: 16
      HLSERVER_MAP: stalkyard
      HLSERVER_MAPCYCLE: stalkyard,gasworks,datacore
      HLSERVER_FRAGLIMIT: 20
      HLSERVER_TIMELIMIT: 10
      HLSERVER_TICRATE: 10
      HLSERVER_RCON_PASS: ${BASIC_PASSWORD}
      HLSERVER_BOTS: true
      HLSERVER_BOTS_COUNT: 8
      HLSERVER_BOT_SKILL: 3
      HLSERVER_BOT_NAMES:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

> ❗ In `host` mode you do **not** need to expose ports manually.
> Switch to `bridge` mode by commenting out `network_mode` and uncommenting `ports`.

---

## ⚙️ Environment Variables

### Server

| Variable | Default | Description |
|---|---|---|
| `HLSERVER_GAME` | `valve` | Game mod directory (`valve`, `cstrike`, etc.) |
| `HLSERVER_NAME` | `Half-Life Server` | Server name shown in the browser |
| `HLSERVER_IP` | `0.0.0.0` | Bind IP |
| `HLSERVER_PORT` | `27015` | UDP port |
| `HLSERVER_MAXPLAYERS` | `16` | Max human + bot slots (max 32) |
| `HLSERVER_MAP` | `stalkyard` | Starting map |
| `HLSERVER_MAPCYCLE` | _(empty)_ | Comma-separated map rotation |
| `HLSERVER_FRAGLIMIT` | `0` | Frags to end round (0 = disabled) |
| `HLSERVER_TIMELIMIT` | `0` | Minutes per map (0 = disabled) |
| `HLSERVER_TICRATE` | `10` | Server tick rate |
| `HLSERVER_RCON_PASS` | _(required)_ | Remote console password |

### 🤖 Bots

Bots use **botman's HPB Bot #10**, integrated into the game DLL.
The DLL has **no runtime cvars** — all bot control is via `bot.cfg`,
which the DLL reads and parses itself at startup.

| Variable | Default | Description |
|---|---|---|
| `HLSERVER_BOTS` | `false` | Enable bots (`true` / `false`) |
| `HLSERVER_BOTS_COUNT` | `5` | Number of bots to spawn |
| `HLSERVER_BOT_SKILL` | `3` | `1`=best (hardest) → `5`=worst (easiest) |
| `HLSERVER_BOT_DONTSHOOT` | `0` | `0`=bots shoot, `1`=bots never shoot |
| `HLSERVER_BOT_MIN` | `0` | Kick a bot when humans join (0 = disabled) |
| `HLSERVER_BOT_MAX` | `0` | Auto-fill server up to this count (0 = disabled) |
| `HLSERVER_BOT_NAMES` | _(empty)_ | Comma-separated `skin:name` pairs (see below) |

#### Bot Names & Skins

**Valid skins:** `barney` `gina` `gman` `gordon` `helmet` `hgrunt` `recon` `robo` `scientist` `zombie`

> `gina` is the only female model in standard Half-Life DM.

```yaml
# Specific skin + custom name
HLSERVER_BOT_NAMES: "gordon:Mustafa,hgrunt:Mohamed,scientist:Omar,gina:Mona"

# Specific skins, default names
HLSERVER_BOT_NAMES: "gordon,barney,scientist"

# Random skins, custom names
HLSERVER_BOT_NAMES: ":Mustafa,:Mohamed,:Omar"

# All random (leave blank)
HLSERVER_BOT_NAMES:
```

---

## 🕹️ Connecting to the Server

### 📡 LAN Discovery (in-game browser)

- Requires `network_mode: host`
- Server will appear automatically in the LAN tab

### 🖥️ Manual Connect

Open the game console and run:
```
connect 192.168.1.100:27015
```

To enable the console: Steam → Half-Life → Properties → Launch Options → add `-console`

---

## 🔒 Networking

Default ports used by Half-Life:

| Port | Protocol | Purpose |
|---|---|---|
| `27015` | UDP | Main game port |
| `27005` | UDP | Client port |
| `27025` | UDP | Alternate query port |
| `47584` | UDP/TCP | Voice chat / RCON |

In `host` mode none of these need to be explicitly exposed.

---

## 🔄 Auto-Rebuild on Upstream Updates

A scheduled workflow polls the [xash3d-fwgs `continuous` release](https://github.com/FWGS/xash3d-fwgs/releases/tag/continuous)
every 6 hours. When the upstream SHA changes, it automatically triggers
a fresh multi-arch image build and pushes it to GHCR.

To trigger a manual rebuild: **Actions** → **Check Upstream & Trigger Rebuild** → **Run workflow**

---

## 🛠️ Troubleshooting

| Problem | Fix |
|---|---|
| `Game directory "valve" not found` | Check your volume mount — `valve/` must be at `${CONTAINER_DIR}/half-life/valve/` |
| Can't see server in browser | Use `network_mode: host` or connect by IP |
| Bots not spawning | Check `HLSERVER_BOTS: true` is set and `HLSERVER_GAME: valve` (bots only work in HL DM) |
| Wrong number of bots | Delete `valve/bot.cfg` from your volume and restart — stale file from a previous run |
| Server name not showing | Make sure `HLSERVER_NAME` is set and the entrypoint is the latest version |

---

## 🙏 Credits & Upstream Projects

This container is built entirely on the work of others. Full credit to:

### 🔧 Xash3D FWGS Engine
> https://github.com/FWGS/xash3d-fwgs

The engine that powers this server. A cross-platform reimplementation of
Valve's GoldSrc engine, maintained by the FWGS team (a1batross, mittorn,
and many contributors). Licensed under **GPL-3.0**.

### 🔧 HLSDK Portable — bot10 branch
> https://github.com/FWGS/hlsdk-portable/tree/bot10

The game DLL that runs Half-Life multiplayer rules and the bot AI.
Based on Valve's Half-Life SDK, maintained by the FWGS team.
Bot AI is **botman's HPB Bot #10** by Jeff Broome, with unrestricted
use granted provided credit is given. Original: http://planethalflife.com/botman/

### 🎮 Half-Life
> https://store.steampowered.com/app/70/HalfLife/

The game itself, by Valve Corporation. Not included in this project.
You must own a legitimate copy.

---

## 📄 License

The Dockerfile, `entrypoint.sh`, and workflow files in this repository
are released under the **GNU General Public License v3.0**, in keeping
with the upstream projects this work is based on.

See [LICENSE](LICENSE) or https://www.gnu.org/licenses/gpl-3.0.html

---

## ⚠️ Disclaimer

This project is not affiliated with or endorsed by Valve Corporation,
the FWGS team, or botman. Half-Life is a registered trademark of Valve
Corporation. All game assets and trademarks remain the property of their
respective owners.
