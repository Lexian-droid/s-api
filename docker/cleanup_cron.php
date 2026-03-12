<?php

/**
 * Standalone cleanup script invoked by cron.
 *
 * This wrapper simply includes cleanup.php and runs the cleanup function.
 * Cron entry (see Dockerfile):
 *   0 * * * * php /app/cleanup_cron.php
 */

require_once __DIR__ . '/cleanup.php';

cleanupOldFiles();

echo date('Y-m-d H:i:s') . " Cleanup complete.\n";
