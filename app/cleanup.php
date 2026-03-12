<?php

/**
 * TTS file cleanup.
 *
 * Deletes files in the TTS output directory that are older than 24 hours.
 * Safe to call on every request — it is a no-op when there is nothing to
 * delete.
 */

define('TTS_DIR', '/tts');
define('MAX_AGE_SECONDS', 600); // 10 minutes

/**
 * Remove TTS audio files that are older than MAX_AGE_SECONDS.
 *
 * Only regular files whose names end with a recognised audio extension are
 * removed; directory entries and other file types are left untouched.
 */
function cleanupOldFiles(): void
{
    if (!is_dir(TTS_DIR)) {
        return;
    }

    $now   = time();
    $files = glob(TTS_DIR . '/*.{wav,mp3,ogg,flac}', GLOB_BRACE);

    if (empty($files)) {
        return;
    }

    foreach ($files as $file) {
        if (!is_file($file)) {
            continue;
        }

        $age = $now - filemtime($file);
        if ($age > MAX_AGE_SECONDS) {
            // Attempt to remove; log a warning on failure but do not abort the loop.
            if (!@unlink($file)) {
                error_log('[tts-cleanup] Failed to delete: ' . $file);
            }
        }
    }
}
