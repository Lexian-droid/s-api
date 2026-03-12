<?php

/**
 * TTS generation via Wine + SAPI5.
 *
 * Wraps the Wine-based Windows TTS executable and writes the resulting audio
 * file to the /tts output directory.
 */

require_once __DIR__ . '/cleanup.php';

define('TTS_VBS', 'C:\\tts\\tts.vbs');

/**
 * Generate a TTS audio file.
 *
 * @param string $text   The text to synthesise.
 * @param string $voice  The SAPI5 voice name (e.g. "Microsoft David").
 * @param string $format Output audio format: "wav" (default), "mp3".
 *
 * @return array{success: bool, file?: string, error?: string}
 */
function generateTTS(string $text, string $voice, string $format = 'wav'): array
{
    // Validate format — only known safe extensions are accepted.
    $allowedFormats = ['wav', 'mp3'];
    $format = strtolower($format);
    if (!in_array($format, $allowedFormats, true)) {
        return ['success' => false, 'error' => 'Unsupported format. Use wav or mp3.'];
    }

    if (trim($text) === '') {
        return ['success' => false, 'error' => 'Text must not be empty.'];
    }

    if (trim($voice) === '') {
        return ['success' => false, 'error' => 'Voice must not be empty.'];
    }

    // Build a unique output path.
    $filename   = generateUUID() . '.' . $format;
    $outputPath = TTS_DIR . '/' . $filename;

    // Ensure the output directory exists.
    if (!is_dir(TTS_DIR) && !mkdir(TTS_DIR, 0755, true)) {
        return ['success' => false, 'error' => 'Failed to create TTS output directory.'];
    }

    // Build the Wine command using cscript + tts.vbs.
    // The output path is converted from Linux to a Wine (Windows) path.
    // All arguments are escaped to prevent shell injection.
    $winOutputPath = linuxPathToWine($outputPath);
    $cmd = sprintf(
        'DISPLAY=:1 WINEPREFIX=/var/www/.wine HOME=/var/www XDG_CACHE_HOME=/var/www/.cache wine cscript.exe //NoLogo %s /voice:%s /text:%s /output:%s 2>&1',
        escapeshellarg(TTS_VBS),
        escapeshellarg($voice),
        escapeshellarg($text),
        escapeshellarg($winOutputPath)
    );

    exec($cmd, $outputLines, $exitCode);

    if ($exitCode !== 0) {
        $detail = implode("\n", $outputLines);
        return [
            'success' => false,
            'error'   => 'TTS generation failed: ' . $detail,
        ];
    }

    if (!file_exists($outputPath)) {
        return ['success' => false, 'error' => 'TTS executable did not produce an output file.'];
    }

    return ['success' => true, 'file' => '/audio/' . $filename];
}

/**
 * Convert a Linux filesystem path to a Wine (Windows) path via winepath.
 *
 * Falls back to a simple Z:-drive substitution when winepath is not available.
 *
 * @param string $linuxPath  Absolute Linux path, e.g. /tts/abc123.wav
 * @return string            Windows path, e.g. Z:\tts\abc123.wav
 */
function linuxPathToWine(string $linuxPath): string
{
    $win = shell_exec('DISPLAY=:1 winepath -w ' . escapeshellarg($linuxPath) . ' 2>/dev/null');
    if ($win !== null && trim($win) !== '') {
        return trim($win);
    }
    // Fallback: Wine maps the root filesystem to the Z: drive.
    return 'Z:' . str_replace('/', '\\', $linuxPath);
}

/**
 * Generate a version-4 UUID.
 *
 * Fills 16 random bytes, then sets the version (bits 12-15 of byte 6 → 0x4)
 * and the variant (bits 6-7 of byte 8 → 0b10) per RFC 4122 §4.4.
 *
 * @return string  e.g. "550e8400-e29b-41d4-a716-446655440000"
 */
function generateUUID(): string
{
    $data    = random_bytes(16);
    $data[6] = chr((ord($data[6]) & 0x0f) | 0x40);
    $data[8] = chr((ord($data[8]) & 0x3f) | 0x80);

    // Split the 32 hex chars into eight 4-char groups and format as UUID.
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}

function handleVoicesRequest(): void
{
    $vbs = <<<'VBS'
On Error Resume Next
Dim sapi
Set sapi = CreateObject("SAPI.SpVoice")
Dim voices
Set voices = sapi.GetVoices()
Dim v
For Each v In voices
    WScript.Echo v.GetDescription()
Next
VBS;
    $tmpFile = tempnam(sys_get_temp_dir(), 'voices_') . '.vbs';
    file_put_contents($tmpFile, $vbs);

    $winPath = linuxPathToWine($tmpFile);
    $cmd = sprintf(
        'DISPLAY=:1 WINEPREFIX=/var/www/.wine HOME=/var/www XDG_CACHE_HOME=/var/www/.cache wine cscript.exe //NoLogo %s 2>/dev/null',
        escapeshellarg($winPath)
    );

    exec($cmd, $lines, $exitCode);
    @unlink($tmpFile);

    $voices = array_values(array_filter(array_map('trim', $lines)));
    echo json_encode(['success' => true, 'voices' => $voices]);
}
