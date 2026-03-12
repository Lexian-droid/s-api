<?php

/**
 * Authentication helpers.
 *
 * Reads the "Authorization: Bearer <token>" header and validates it against
 * the configured API keys.  Sends a 401 JSON response and exits immediately
 * when authentication fails.
 */

require_once __DIR__ . '/../config/api_keys.php';

/**
 * Extract the bearer token from the Authorization header.
 *
 * @return string|null  The token string, or null when the header is absent /
 *                      malformed.
 */
function getBearerToken(): ?string
{
    $header = '';

    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $header = $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        foreach ($headers as $key => $value) {
            if (strcasecmp($key, 'Authorization') === 0) {
                $header = $value;
                break;
            }
        }
    }

    if (preg_match('/^Bearer\s+(\S+)$/i', trim($header), $matches)) {
        return $matches[1];
    }

    return null;
}

/**
 * Enforce API key authentication.
 *
 * Terminates the request with HTTP 401 if the supplied token is missing or
 * not present in the configured key list.
 *
 * @param array $validKeys  List of accepted API key strings.
 */
function requireAuth(array $validKeys): void
{
    $token = getBearerToken();

    if ($token === null || !in_array($token, $validKeys, true)) {
        http_response_code(401);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'success' => false,
            'error'   => 'Unauthorized. Provide a valid Bearer token.',
        ]);
        exit;
    }
}
