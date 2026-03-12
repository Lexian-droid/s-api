<?php

/**
 * Request router.
 *
 * Maps incoming HTTP method + path combinations to their handler functions and
 * returns a 404 for any unrecognised route.
 */

require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/tts.php';
require_once __DIR__ . '/cleanup.php';

/**
 * Dispatch the current request.
 *
 * @param array $validKeys  API key list forwarded from index.php.
 */
function dispatch(array $validKeys): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $path   = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
    $path   = '/' . trim($path, '/');

    // Run cleanup on every request (lightweight — skips when nothing to do).
    cleanupOldFiles();

    header('Content-Type: application/json; charset=utf-8');

    // ------------------------------------------------------------------ POST /tts
    if ($method === 'POST' && $path === '/tts') {
        requireAuth($validKeys);
        handleTTSRequest();
        return;
    }

    // ------------------------------------------------------------------ GET /health
    if ($method === 'GET' && $path === '/health') {
        echo json_encode(['status' => 'ok']);
        return;
    }

    // ------------------------------------------------------------------ 404
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Not found.']);
}

/**
 * Handle POST /tts.
 *
 * Reads a JSON body, validates the required fields, delegates to
 * generateTTS(), and writes the JSON response.
 */
function handleTTSRequest(): void
{
    $body = file_get_contents('php://input');
    $data = json_decode($body, true);

    if (!is_array($data)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Invalid JSON body.']);
        return;
    }

    $text   = isset($data['text'])   ? trim((string) $data['text'])   : '';
    $voice  = isset($data['voice'])  ? trim((string) $data['voice'])  : '';
    $format = isset($data['format']) ? trim((string) $data['format']) : 'wav';

    if ($text === '') {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => '"text" field is required.']);
        return;
    }

    if ($voice === '') {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => '"voice" field is required.']);
        return;
    }

    $result = generateTTS($text, $voice, $format);

    if (!$result['success']) {
        http_response_code(500);
    }

    echo json_encode($result);
}
