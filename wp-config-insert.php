
/////////////////////////////////////////////////////
//// Start Buddyboss Hosted wp-config defaults ////

/* set site direct url */ 
//define( 'WP_SITEURL', 'https://mydomain.com' );
//define( 'WP_HOME', 'https://mydomain.com' );

/* Define unique redis object store location */
define( 'WP_REDIS_SCHEME', 'unix' );
define( 'WP_REDIS_PATH', '/var/run/redis/redis.sock' );

/* Define redis prefix if multiple sites are on same server  */
// define('WP_REDIS_PREFIX','unique_site_prefix_');

/* Define redis selective flush if multiple sites are on same server  */
// define('WP_REDIS_SELECTIVE_FLUSH', true);

/* Define redis database if multiple sites are on same server  */
//define( 'WP_REDIS_DATABASE', 0 );

/* Define redis ignore groups - these should be updated over time */
define( 'WP_REDIS_IGNORED_GROUPS', 
[
'comment',
'counts',
'plugins',
'themes',
'wc_session_id',
'learndash_reports',
'learndash_admin_profile',
'bp_messages',
'bp_messages_threads',
] 
);

/* define php memory limits */
define( 'WP_MEMORY_LIMIT', '384M' );
define( 'WP_MAX_MEMORY_LIMIT', '512M' );

/* Disable all site auto updates  */
define( 'AUTOMATIC_UPDATER_DISABLED', true );

/* Disable all wp-cron - page level handling */
//define('DISABLE_WP_CRON', true);

/* define hard drive access method and default permissions */
define('FS_METHOD','direct');
define('FS_CHMOD_DIR', (0775 & ~ umask()));
define('FS_CHMOD_FILE', (0664 & ~ umask()));

//// End Buddyboss Hosted wp-config defaults ////
////////////////////////////////////////////////////
