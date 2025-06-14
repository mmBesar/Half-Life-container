# ⚠️ Project Status: Work In Progress ⚠️

> **This containerized Half-Life server is not ready for production use.**
> It is under active development — expect breaking changes, missing features, and dragons. You’ve been warned.

---

![Build](https://github.com/\${REPO_OWNER:-mmbesar}/half-life/actions/workflows/container-build.yml/badge.svg)

# 🎮 Half-Life Dedicated Server in Docker

This project builds a multi-architecture Docker container for running a dedicated Half-Life server using [Xash3D-FWGS](https://github.com/FWGS/xash3d-fwgs), targeting both AMD64 and ARM64 (e.g. Raspberry Pi 4).

---

## ✨ Features

* 📦 Fully containerized Half-Life server
* 🔁 Multi-arch support: `linux/amd64`, `linux/arm64`
* 👤 Runs as any UID\:GID via Docker Compose
* 🔧 Configurable via environment variables
* 🎯 Bots support (via server-side cvars)
* 📡 Map control from environment or runtime

---

## 🚀 Quick Start

```bash
git clone https://github.com/YOURUSER/half-life-server-docker.git
cd half-life-server-docker
docker-compose -f docker-compose.example.yml up -d
```

Ensure that your `valve/` directory contains the necessary game files.

---

## ⚙️ Environment Variables

| Variable              | Default     | Description                 |
| --------------------- | ----------- | --------------------------- |
| `HLSERVER_PORT`       | `27015`     | Server UDP port             |
| `HLSERVER_MAP`        | `stalkyard` | Default map                 |
| `HLSERVER_MAXPLAYERS` | `16`        | Max number of players       |
| `HLSERVER_BOTS`       | `true`      | Enable bots (server-side)   |
| `HLSERVER_BOTS_COUNT` | `10`        | Number of bots (if enabled) |

---

## 📁 Volume Mounts

```yaml
volumes:
  - ./valve:/data/valve
  - ./logs:/data/logs
```

Ensure you provide valid game content under `valve/`.

---

## 🏗 CI/CD

This project uses GitHub Actions to build and publish multi-arch Docker images to GitHub Container Registry:

```text
ghcr.io/<repo-owner>/half-life:latest
```

### Automated Releases

* Pushing a new tag (e.g., `v1.0.0`) will:

  * Build and push multi-arch images
  * Create a GitHub release based on that tag

---

## 🧪 TODO

* [ ] Validate ARM64 performance on Pi4
* [ ] RCON support or map rotation tool
* [ ] Auto-downloading maps/mods
* [ ] Bot plugin modularization

---

## 🤝 Contributions

PRs welcome, especially for:

* Better mod integration
* Entry-point enhancements
* Networking or monitoring support

---

## 📜 License

MIT — See [LICENSE](./LICENSE)
