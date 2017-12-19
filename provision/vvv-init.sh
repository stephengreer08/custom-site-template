#!/usr/bin/env bash
# Provision WordPress Stable

DOMAIN=`get_primary_host "${VVV_SITE_NAME}".test`
DOMAINS=`get_hosts "${DOMAIN}"`
SITE_TITLE=`get_config_value 'site_title' "${DOMAIN}"`
WP_VERSION=`get_config_value 'wp_version' 'latest'`
WP_TYPE="subdomain"
DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/error.log
touch ${VVV_PATH_TO_SITE}/log/access.log

# Install and configure the latest stable version of WordPress
if [[ ! -f "${VVV_PATH_TO_SITE}/htdocs/wp-load.php" ]]; then
    echo "Downloading WordPress..."
  noroot wp core download --version="${WP_VERSION}"
fi

cp -f "${VVV_PATH_TO_SITE}/provision/sunrise.php" "${VVV_PATH_TO_SITE}/htdocs/wp-content/sunrise.php"

if [[ ! -f "${VVV_PATH_TO_SITE}/htdocs/wp-config.php" ]]; then
  echo "Configuring WordPress Stable..."
  noroot wp config create --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_DISPLAY', false );
define( 'WP_DEBUG_LOG', true );
define( 'SCRIPT_DEBUG', true );
define( 'JETPACK_DEV_DEBUG', true );
if ( isset( \$_SERVER['HTTP_HOST'] ) && preg_match('/^(${DOMAIN}.)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(.xip.io)\z/', \$_SERVER['HTTP_HOST'] ) ) {
  define( 'WP_HOME', 'http://' . \$_SERVER['HTTP_HOST'] );
  define( 'WP_SITEURL', 'http://' . \$_SERVER['HTTP_HOST'] );
}

define( 'WP_ALLOW_MULTISITE', true );
define( 'MULTISITE', true );
define( 'SUBDOMAIN_INSTALL', true );
define( 'DOMAIN_CURRENT_SITE', '${DOMAIN}' );
define( 'PATH_CURRENT_SITE', '/' );
define( 'SITE_ID_CURRENT_SITE', 1 );
define( 'BLOG_ID_CURRENT_SITE', 1 );

define( 'FSAPI_SECRET_KEY', 'fslocaldevsecretkey' );
define( 'SUNRISE',true );
define( 'FS_DEVELOPER_KEY', 'localdev' );
/*Getty API Credentials*/
// define( 'GETTY_API_KEY', '' );
// define( 'GETTY_CLIENT_SECRET', '' );
/*WP RestRest cache constants*/
// Use the content types to specify what types of content the rest cache will actually store/save
//define( 'WRC_CONTENT_TYPES', array( 'application/json', 'text/xml' ) );
// secret key for FanSided WP API plugin server to server authentication
define( 'FSAPI_SECRET_KEY', 'fslocaldevsecretkey' );
PHP
fi

if ! $(noroot wp core is-installed); then
  echo "Installing WordPress Stable..."

  if [ "${WP_TYPE}" = "subdomain" ]; then
    INSTALL_COMMAND="multisite-install --subdomains"
  elif [ "${WP_TYPE}" = "subdirectory" ]; then
    INSTALL_COMMAND="multisite-install"
  else
    INSTALL_COMMAND="install"
  fi

  noroot wp core ${INSTALL_COMMAND} --url="${DOMAIN}" --quiet --title="${SITE_TITLE}" --admin_name=admin --admin_email="admin@local.test" --admin_password="password"
else
  echo "Updating WordPress Stable..."
  cd ${VVV_PATH_TO_SITE}/htdocs
  noroot wp core update --version="${WP_VERSION}"
fi

if $(noroot wp core is-installed); then
  echo "Importing Database..."
  unzip "${VVV_PATH_TO_SITE}/provision/fansidedblogs-test.sql.zip" -d "${VVV_PATH_TO_SITE}/provision"
  noroot wp db import "${VVV_PATH_TO_SITE}/provision/fansidedblogs-test.sql"
fi

cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
