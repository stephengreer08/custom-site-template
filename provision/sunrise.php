<?php
if ( !empty( $_SERVER['HTTP_HOST'] ) ) {
    $site = get_site_by_path( strtolower( $_SERVER['HTTP_HOST'] ), '/');
    define( 'COOKIE_DOMAIN', '.' . $site->domain );
}
