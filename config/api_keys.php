<?php

/**
 * API key configuration.
 *
 * Keys can be supplied here as a hard-coded list OR via the environment
 * variable API_KEYS (comma-separated). Environment values take precedence
 * when present, making the container easy to configure without rebuilding.
 *
 * Example (env):
 *   API_KEYS=key-one,key-two,key-three
 */

$envKeys = getenv('API_KEYS');

if ($envKeys !== false && $envKeys !== '') {
    $API_KEYS = array_filter(array_map('trim', explode(',', $envKeys)));
} else {
    // Fallback hard-coded keys — replace or remove before production use.
    $API_KEYS = [
        'changeme-api-key-1',
        'changeme-api-key-2',
    ];
}
