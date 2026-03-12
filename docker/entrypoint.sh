#!/usr/bin/env bash
set -e

export DISPLAY=:1
export WINEPREFIX="${WINEPREFIX:-/var/www/.wine}"
export WINEARCH="${WINEARCH:-win32}"

# ── 1. Clean up stale X lock files (left over from a previous container run) ──
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# ── 2. Ensure www-data owns the Wine prefix directory ─────────────────────────
mkdir -p "$WINEPREFIX"
chown -R www-data:www-data "$WINEPREFIX"

# Allow www-data to write fontconfig cache
mkdir -p /var/www/.cache/fontconfig
chown -R www-data:www-data /var/www/.cache

echo "[entrypoint] Starting Xvfb on $DISPLAY …"
Xvfb "$DISPLAY" -screen 0 "${SCREEN_WIDTH:-1280}x${SCREEN_HEIGHT:-800}x${SCREEN_DEPTH:-24}" &
XVFB_PID=$!

# Wait until Xvfb is actually ready rather than a fixed sleep
for i in $(seq 1 20); do
    xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && break
    sleep 0.5
done

echo "[entrypoint] Starting Xfce4 desktop …"
if [ "${ENABLE_VNC:-true}" = "true" ]; then
    XAUTHORITY=/dev/null startxfce4 &
    sleep 3
else
    echo "[entrypoint] VNC disabled (ENABLE_VNC=false), skipping Xfce4."
fi

echo "[entrypoint] Starting wineserver as www-data …"
gosu www-data env HOME=/var/www XDG_CACHE_HOME=/var/www/.cache \
    DISPLAY=:1 WINEPREFIX=/var/www/.wine \
    wineserver -f &
WINESERVER_PID=$!
sleep 1

echo "[entrypoint] Initialising Wine prefix as www-data …"
gosu www-data env HOME=/var/www XDG_CACHE_HOME=/var/www/.cache \
    wineboot --init 2>&1 | tail -5 || true

# Install MS Speech SDK (SAPI5) on first run — Wine's built-in sapi.dll is a stub.
SAPI_MARKER="${WINEPREFIX}/.speechsdk_installed"
if [ ! -f "$SAPI_MARKER" ]; then
    echo "[entrypoint] Installing MS Speech SDK (first run only) …"
    gosu www-data env DISPLAY=:1 HOME=/var/www XDG_CACHE_HOME=/var/www/.cache \
        WINEPREFIX=/var/www/.wine WINEARCH=win32 \
        winetricks -q speechsdk 2>&1 | tail -10 || true
    # Set DLL override so Wine uses the native sapi.dll
    gosu www-data env WINEPREFIX=/var/www/.wine \
        wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" \
        /v sapi /t REG_SZ /d native /f 2>&1 || true
    touch "$SAPI_MARKER"
    chown www-data:www-data "$SAPI_MARKER"
    echo "[entrypoint] Speech SDK installed."
else
    echo "[entrypoint] Speech SDK already installed, skipping."
fi

# Copy the TTS VBScript into the Wine C: drive.
WINE_C="${WINEPREFIX}/drive_c"
mkdir -p "${WINE_C}/tts"
cp /tmp/tts.vbs "${WINE_C}/tts/tts.vbs"
chown -R www-data:www-data "${WINE_C}/tts"
echo "[entrypoint] tts.vbs installed at ${WINE_C}/tts/tts.vbs"

# ── 3. Start VNC stack (only when ENABLE_VNC=true) ────────────────────────────
if [ "${ENABLE_VNC:-true}" = "true" ]; then
    echo "[entrypoint] Starting x11vnc …"
    x11vnc -display "$DISPLAY" -nopw -forever -shared -bg -rfbport 5900 -quiet || \
        echo "[entrypoint] WARNING: x11vnc failed to start (VNC will be unavailable)"

    NOVNC_PORT="${NOVNC_PORT:-6080}"
    echo "[entrypoint] Starting noVNC on port $NOVNC_PORT …"
    websockify --web /usr/share/novnc/ "$NOVNC_PORT" localhost:5900 &
else
    echo "[entrypoint] VNC disabled (ENABLE_VNC=false), skipping x11vnc and noVNC."
fi

# ── 5. Start cron ─────────────────────────────────────────────────────────────
echo "[entrypoint] Starting cron …"
service cron start || cron

# ── 6. Start Apache in the foreground ────────────────────────────────────────
echo "[entrypoint] Starting Apache …"
exec apache2ctl -D FOREGROUND
