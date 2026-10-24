- **wp-robin: the missing queue table is created from the command line.** After
  `wp plugin activate`, Robin's `rio_process_queue` table can be absent because WP-CLI
  activation skipped its table setup, and the skill's only fix was to deactivate and
  reactivate the plugin in wp-admin, which a headless or scripted run cannot do. The
  troubleshooting row now gives `wp eval 'RIO_Process_Queue::try_create_plugin_tables();'`,
  the call Robin's own activator makes, and keeps wp-admin as the fallback without WP-CLI.
