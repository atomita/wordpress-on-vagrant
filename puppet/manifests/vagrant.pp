# Basics
Exec {
  path => ['/usr/bin', '/bin', '/usr/sbin', '/sbin', '/usr/local/bin', '/usr/local/sbin']
}
exec {
    'apt-get update':
        command => '/usr/bin/apt-get update';
}
package {
	'make':
		ensure  => present,
		require => Exec['apt-get update'];
	'build-essential':
		ensure  => present,
		require => Exec['apt-get update'];
}
include bootstrap

# Apache
class {
	'apache':
		mpm_module => 'prefork',
		servername => 'localhost',
		require => Exec['apt-get update'];
	'apache::mod::php':
		require => Exec['apt-get update'];
}
apache::vhost {
	'localhost':
		port    => '80',
		docroot => '/home/vagrant/www',
}

# PHP
class {
	'php':
		service => 'httpd',
		require => Exec['apt-get update'];
}

# Mysql
class {
	'mysql':
		require => Exec['apt-get update'];
	'mysql::php':
		require => Exec['apt-get update'];
	'mysql::server':
		config_hash => { 'root_password' => 'DosbonApEz6' },
		require => Exec['apt-get update'];
}
mysql::db {
	'wpdb':
		user     => 'wpuser',
		password => 'varomofIc8',
		host     => 'localhost',
		grant    => ['all'],
}

## Git
#include git

## Node
#include nodejs


# apache2/envvars
$apache2_define_flugs = { "dev" => "yes" }
file {
	'/etc/apache2/envvars':
		content => template('apache-envvers/default.erb'),
		require => Package['httpd'],
		notify  => Service['httpd'];
}

# php modules
php::module {
	'gd':;
	'curl':;
	'cli':;
	'dev':;
	'xdebug':;
}

# apache modules
apache::mod { 'rewrite': }

# thias-postfix
#include postfix
class { 'postfix::server':
  myhostname              => 'mx1.example.com',
  mydomain                => 'example.com',
  myorigin                => '$mydomain',
  mydestination           => "\$myhostname, localhost.\$mydomain, localhost, $fqdn",
  inet_interfaces         => 'all',
  message_size_limit      => '15360000', # 15MB
  mail_name               => 'example mail daemon',
#  virtual_mailbox_domains => [
#    'proxy:mysql:/etc/postfix/dynamicmaps.cf',
#  ],
#  virtual_alias_maps      => [
##    'proxy:mysql:/etc/postfix/dynamicmaps.cf',
#    'proxy:mysql:/etc/postfix/mysql_virtual_alias_maps.cf',
#    'proxy:mysql:/etc/postfix/mysql_virtual_alias_domain_maps.cf',
#    'proxy:mysql:/etc/postfix/mysql_virtual_alias_domain_catchall_maps.cf',
#  ],
#  virtual_transport         => 'dovecot',
  # if you want dovecot to deliver user+foo@example.org to user@example.org,
  # uncomment this: (c.f. http://wiki2.dovecot.org/LDA/Postfix#Virtual_users)
  # dovecot_destination     => '${user}@${nexthop}',
  smtpd_sender_restrictions => [
    'permit_mynetworks',
    'reject_unknown_sender_domain',
  ],
  smtpd_recipient_restrictions => [
    'permit_sasl_authenticated',
    'permit_mynetworks',
    'reject_unauth_destination',
  ],
  smtpd_sasl_auth       => true,
#  sender_canonical_maps => 'regexp:/etc/postfix/sender_canonical',
  ssl                   => 'wildcard.example.com',
  submission            => true,
  header_checks         => [
    '# Remove LAN (Webmail) headers',
    '/^Received: from .*\.example\.ici/ IGNORE',
    '# Sh*tlist',
    '/^From: .*@(example\.com|example\.net)/ REJECT Spam, go away',
    '/^From: .*@(lcfnl\.com|.*\.cson4\.com|.*\.idep4\.com|.*\.gagc4\.com)/ REJECT user unknown',
  ],
  postgrey              => true,
  spamassassin          => true,
  sa_skip_rbl_checks    => '0',
  spampd_children       => '4',
  # Send all emails to spampd on 10026
  smtp_content_filter   => 'smtp:127.0.0.1:10026',
  # This is where we get emails back from spampd
  master_services       => [ '127.0.0.1:10027 inet n  -       n       -      20       smtpd'],
  require => Exec['apt-get update'];
}


# wordpress
class { 'wordpress::app':
  version     => '4.4.1',
  install_dir => '/home/vagrant/www/wordpress',
  install_url => 'https://ja.wordpress.org',
  wp_owner    => 'vagrant',
  wp_group    => 'vagrant',
  db_user     => 'wpuser',
  db_password => 'varomofIc8',
  db_name     => 'wpdb',
  db_host     => 'localhost',
  wp_site_domain => 'localhost',
  wp_lang     => 'ja',
  wp_siteurl_uri => '/wordpress',
  wp_home_uri    => '',
  wp_content_uri => '/content',
  wp_content_dir => '/home/vagrant/www/content',
  wp_config_is_outside => true,
}
