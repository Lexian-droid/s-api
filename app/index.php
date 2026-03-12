<?php

/**
 * Application entry point.
 *
 * This file is the only file referenced by the Apache VirtualHost / .htaccess
 * rewrite rule.  It loads configuration and hands off to the router.
 */

declare(strict_types=1);

require_once __DIR__ . '/../config/api_keys.php';
require_once __DIR__ . '/router.php';

dispatch($API_KEYS);
