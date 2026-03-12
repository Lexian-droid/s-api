#!/usr/bin/env bash
set -e

# ── 1. Initialise Wine prefix ─────────────────────────────────────────────────
# wineboot sets up the prefix on first run. We run it with a virtual display
# so it does not error out looking for a real screen.

export DISPLAY=:1
export WINEPREFIX="${WINEPREFIX:-/root/.wine}"
export WINEARCH="${WINEARCH:-win64}"

echo "[entrypoint] Starting Xvfb on $DISPLAY …"
Xvfb "$DISPLAY" -screen 0 "${SCREEN_WIDTH:-1280}x${SCREEN_HEIGHT:-800}x${SCREEN_DEPTH:-24}" &
XVFB_PID=$!
sleep 2

echo "[entrypoint] Starting Xfce4 desktop …"
startxfce4 &
sleep 2

echo "[entrypoint] Initialising Wine prefix …"
wineboot --init 2>&1 | tail -5 || true

# Copy the TTS VBScript into the Wine C: drive.
WINE_C="${WINEPREFIX}/drive_c"
mkdir -p "${WINE_C}/tts"
cp /tmp/tts.vbs "${WINE_C}/tts/tts.vbs"
echo "[entrypoint] tts.vbs installed at ${WINE_C}/tts/tts.vbs"

# ── 2. Start x11vnc (VNC server on port 5900) ─────────────────────────────────
# Port 5900 is intentionally NOT published in docker-compose; it is only
# reachable through the websockify/noVNC proxy on NOVNC_PORT.  If you
# publish port 5900 directly, add -passwd or -rfbauth for security.
echo "[entrypoint] Starting x11vnc …"
x11vnc -display "$DISPLAY" -nopw -forever -shared -bg -rfbport 5900 -quiet
sleep 1

# ── 3. Start noVNC (websocket proxy on NOVNC_PORT) ───────────────────────────
NOVNC_PORT="${NOVNC_PORT:-6080}"
echo "[entrypoint] Starting noVNC on port $NOVNC_PORT …"
websockify --web /usr/share/novnc/ "$NOVNC_PORT" localhost:5900 &

# ── 4. Start cron ─────────────────────────────────────────────────────────────
echo "[entrypoint] Starting cron …"
service cron start || cron

# ── 5. Start Apache in the foreground ────────────────────────────────────────
echo "[entrypoint] Starting Apache …"
exec apache2ctl -D FOREGROUND
