# ── Base image ────────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    SCREEN_WIDTH=1280 \
    SCREEN_HEIGHT=800 \
    SCREEN_DEPTH=24 \
    WINEPREFIX=/root/.wine \
    WINEARCH=win64 \
    NOVNC_PORT=6080

# ── System packages ───────────────────────────────────────────────────────────
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Apache + PHP 8
        apache2 \
        libapache2-mod-php \
        php \
        php-cli \
        php-json \
        # Wine
        wine \
        wine32 \
        wine64 \
        winetricks \
        # Xfce desktop (lightweight)
        xfce4 \
        xfce4-terminal \
        # Virtual framebuffer + VNC
        xvfb \
        x11vnc \
        # noVNC + websockify
        novnc \
        websockify \
        # Misc utilities
        wget \
        curl \
        ca-certificates \
        cron \
        gosu \
    && rm -rf /var/lib/apt/lists/*

# ── Apache configuration ───────────────────────────────────────────────────────
# Enable mod_rewrite and configure the VirtualHost.
RUN a2enmod rewrite php8.2 headers

COPY docker/apache-tts.conf /etc/apache2/sites-available/tts.conf
RUN a2dissite 000-default && a2ensite tts

# ── Application files ─────────────────────────────────────────────────────────
COPY app/    /app/
COPY config/ /config/
COPY bin/    /app/bin/

RUN mkdir -p /tts && chmod 777 /tts

# ── TTS VBScript in the Wine prefix ──────────────────────────────────────────
# The Wine C: drive is created the first time wineboot runs (handled in
# entrypoint.sh).  We copy the script to a helper location that the
# entrypoint will move into the Wine prefix.
COPY bin/tts.vbs /tmp/tts.vbs

# ── noVNC ─────────────────────────────────────────────────────────────────────
# Symlink the noVNC web root so it is served on NOVNC_PORT.
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html || true

# ── Cron job: clean up TTS files older than 24 h ─────────────────────────────
RUN echo "0 * * * * php /app/cleanup_cron.php >> /var/log/tts_cleanup.log 2>&1" \
        > /etc/cron.d/tts-cleanup && \
    chmod 0644 /etc/cron.d/tts-cleanup

COPY docker/cleanup_cron.php /app/cleanup_cron.php

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 6080

ENTRYPOINT ["/entrypoint.sh"]
