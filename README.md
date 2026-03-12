# s-api — SAPI5 TTS JSON API

A Dockerized PHP 8 application that exposes a JSON API for generating
Text-to-Speech (TTS) audio files using Windows SAPI5 voices running inside
**Wine**, with a browser-accessible desktop (noVNC) for voice installation.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Project Structure](#project-structure)
3. [Quick Start](#quick-start)
4. [Installing SAPI5 Voices via noVNC](#installing-sapi5-voices-via-novnc)
5. [API Reference](#api-reference)
6. [API Key Authentication](#api-key-authentication)
7. [File Storage & Cleanup](#file-storage--cleanup)
8. [Configuration](#configuration)
9. [Development](#development)

---

## Architecture Overview

```
Browser / Client
       │
       ├─ HTTP :8080  ──►  Apache + PHP 8 API  ──►  Wine (cscript + tts.vbs)
       │                                                     │
       └─ HTTP :6080  ──►  noVNC (websockify)  ──►  x11vnc ──►  Xfce4 / Xvfb
```

- **Port 8080** — JSON REST API for TTS generation.
- **Port 6080** — Browser-based Xfce desktop for installing Windows SAPI5 voices.

---

## Project Structure

```
/app
  index.php       Entry point (loaded by Apache for every request)
  router.php      Route dispatcher
  auth.php        Bearer-token authentication
  tts.php         TTS generation via Wine + cscript + tts.vbs
  cleanup.php     Deletes TTS files older than 24 hours
/bin
  tts.vbs         VBScript executed by Wine's cscript.exe to invoke SAPI5
  README.txt      Notes about the bin directory
/config
  api_keys.php    API key list (overridable via API_KEYS env var)
/docker
  apache-tts.conf Apache VirtualHost configuration
  cleanup_cron.php Standalone cron wrapper for cleanup.php
  entrypoint.sh   Container startup script
/tts              (runtime) Generated audio files
Dockerfile
docker-compose.yml
README.md
```

---

## Quick Start

### Prerequisites

- Docker ≥ 20.x and Docker Compose ≥ 2.x

### 1. Clone and configure

```bash
git clone https://github.com/Lexian-droid/s-api.git
cd s-api
```

Create a `.env` file (optional — sensible defaults are built in):

```bash
# .env
API_KEYS=my-secret-key-1,my-secret-key-2
```

### 2. Build and start

```bash
docker compose up --build -d
```

The first build downloads Wine, Xfce, and noVNC — expect a few minutes.

### 3. Verify

```bash
curl http://localhost:8080/health
# {"status":"ok"}
```

---

## Installing SAPI5 Voices via noVNC

1. Open **http://localhost:6080** in your browser.
2. Click **Connect** (no password required by default).
3. You now have a full Xfce desktop running inside Wine's environment.
4. Download a SAPI5 voice installer (e.g., from Nuance, Ivona, CereVoice, or
   any free SAPI5 provider) to the desktop.
5. Double-click the installer — Wine will execute it.
6. Follow the voice installer's setup wizard.
7. After installation, the voice is registered in the Wine registry and
   available to the API immediately.

> **Tip:** You can also copy a pre-installed `%APPDATA%\...` voice directory
> and its registry export into the container volume (`wine_prefix`) to skip
> the GUI installer step.

---

## API Reference

### `GET /health`

Health check — no authentication required.

**Response `200`**

```json
{ "status": "ok" }
```

---

### `POST /tts`

Generate a TTS audio file.

**Request headers**

```
Content-Type: application/json
Authorization: Bearer <API_KEY>
```

**Request body**

| Field    | Type   | Required | Description                                 |
| -------- | ------ | -------- | ------------------------------------------- |
| `text`   | string | ✓        | The text to synthesise.                     |
| `voice`  | string | ✓        | SAPI5 voice name (partial match supported). |
| `format` | string |          | Output format: `wav` (default) or `mp3`.    |

**Example request**

```bash
curl -X POST http://localhost:8080/tts \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer changeme-api-key-1" \
     -d '{"text":"Hello world","voice":"Microsoft David","format":"wav"}'
```

**Response `200`**

```json
{
  "success": true,
  "file": "/tts/550e8400-e29b-41d4-a716-446655440000.wav"
}
```

**Error responses**

| Code | Meaning                                  |
| ---- | ---------------------------------------- |
| 400  | Missing / invalid request fields         |
| 401  | Missing or invalid `Authorization` token |
| 500  | TTS generation failed (Wine error)       |

---

## API Key Authentication

All requests to `/tts` must carry a valid bearer token:

```
Authorization: Bearer <API_KEY>
```

### Configuring keys

**Option A — environment variable (recommended)**

Set `API_KEYS` to a comma-separated list of keys in `.env` or
`docker-compose.yml`:

```env
API_KEYS=key-one,key-two,key-three
```

**Option B — config file**

Edit `config/api_keys.php` and add keys to the `$API_KEYS` array.  
Environment variables take precedence over the config file.

---

## File Storage & Cleanup

- Generated files are stored in `/tts/` with UUID filenames
  (e.g., `550e8400-e29b-41d4-a716-446655440000.wav`).
- Files older than **24 hours** are deleted automatically by a cron job that
  runs every hour inside the container (`/etc/cron.d/tts-cleanup`).
- Cleanup also runs on every API request (lightweight, skips when nothing to
  delete).
- The `/tts` directory is backed by the `tts_files` Docker volume so files
  persist between container restarts until they age out.

---

## Configuration

| Environment Variable | Default                  | Description                            |
| -------------------- | ------------------------ | -------------------------------------- |
| `API_KEYS`           | `changeme-api-key-1,...` | Comma-separated list of valid API keys |
| `SCREEN_WIDTH`       | `1280`                   | noVNC desktop width                    |
| `SCREEN_HEIGHT`      | `800`                    | noVNC desktop height                   |
| `SCREEN_DEPTH`       | `24`                     | noVNC colour depth                     |
| `NOVNC_PORT`         | `6080`                   | Port noVNC listens on inside container |
| `WINEPREFIX`         | `/root/.wine`            | Wine prefix directory                  |
| `WINEARCH`           | `win32`                  | Wine architecture                      |

---

## Development

Run a shell inside the running container:

```bash
docker compose exec sapi-tts bash
```

Check Wine is working:

```bash
DISPLAY=:1 wine --version
```

Test the VBScript directly:

```bash
DISPLAY=:1 wine cscript.exe //NoLogo 'C:\tts\tts.vbs' \
    /voice:"Microsoft David" /text:"Hello" /output:"Z:\tts\test.wav"
```

View Apache logs:

```bash
docker compose logs -f sapi-tts
```
