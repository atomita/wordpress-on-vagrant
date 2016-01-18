define wordpress::instance::app (
  $install_dir          = '/opt/wordpress',
  $install_url          = 'http://wordpress.org',
  $version              = '3.8',
  $db_name              = 'wordpress',
  $db_host              = 'localhost',
  $db_user              = 'wordpress',
  $db_password          = 'password',
  $wp_owner             = 'root',
  $wp_group             = '0',
  $wp_lang              = '',
  $wp_config_content    = undef,
  $wp_plugin_dir        = 'DEFAULT',
  $wp_additional_config = 'DEFAULT',
  $wp_table_prefix      = 'wp_',
  $wp_proxy_host        = '',
  $wp_proxy_port        = '',
  $wp_multisite         = false,
  $wp_site_domain       = '',
  $wp_debug             = false,
  $wp_debug_log         = false,
  $wp_debug_display     = false,
  $wp_siteurl_uri       = 'DEFAULT',
  $wp_home_uri          = 'DEFAULT',
  $wp_content_uri       = 'DEFAULT',
  $wp_content_dir       = 'DEFAULT',
  $wp_config_is_outside = false,
) {
  validate_string($install_dir,$install_url,$version,$db_name,$db_host,$db_user,$db_password,$wp_owner,$wp_group, $wp_lang, $wp_plugin_dir,$wp_additional_config,$wp_table_prefix,$wp_proxy_host,$wp_proxy_port,$wp_site_domain, $wp_siteurl_uri, $wp_home_uri, $wp_content_uri, $wp_content_dir)
  validate_bool($wp_multisite, $wp_debug, $wp_debug_log, $wp_debug_display, $wp_config_is_outside)
  validate_absolute_path($install_dir)

  if $wp_config_content and ($wp_lang or $wp_debug or $wp_debug_log or $wp_debug_display or $wp_proxy_host or $wp_proxy_port or $wp_multisite or $wp_site_domain or $wp_siteurl_uri or $wp_home_uri or $wp_content_uri or $wp_content_dir) {
    warning('When $wp_config_content is set, the following parameters are ignored: $wp_table_prefix, $wp_lang, $wp_debug, $wp_debug_log, $wp_debug_display, $wp_plugin_dir, $wp_proxy_host, $wp_proxy_port, $wp_multisite, $wp_site_domain, $wp_additional_config, $wp_siteurl_uri, $wp_home_uri, $wp_content_uri, $wp_content_uri, $wp_content_dir')
  }

  if $wp_multisite and ! $wp_site_domain {
    fail('wordpress class requires `wp_site_domain` parameter when `wp_multisite` is true')
  }

  if $wp_debug_log and ! $wp_debug {
    fail('wordpress class requires `wp_debug` parameter to be true, when `wp_debug_log` is true')
  }

  if $wp_debug_display and ! $wp_debug {
    fail('wordpress class requires `wp_debug` parameter to be true, when `wp_debug_display` is true')
  }

  if ! $wp_site_domain and ($wp_siteurl_uri != 'DEFAULT' or $wp_home_uri != 'DEFAULT' or $wp_content_uri != 'DEFAULT') {
    fail('wordpress class requires `wp_site_domain` parameter when `$wp_siteurl_uri` or `$wp_home_uri` or `$wp_content_uri` is true')
  }


  ## Resource defaults
  File {
    owner  => $wp_owner,
    group  => $wp_group,
    mode   => '0644',
  }
  Exec {
    path      => ['/bin','/sbin','/usr/bin','/usr/sbin'],
    cwd       => $install_dir,
    logoutput => 'on_failure',
  }

  ## Installation directory
  if ! defined(File[$install_dir]) {
    file { $install_dir:
      ensure  => directory,
      recurse => true,
    }
  } else {
    notice("Warning: cannot manage the permissions of ${install_dir}, as another resource (perhaps apache::vhost?) is managing it.")
  }

  ## tar.gz. file name lang-aware
  if $wp_lang {
    $install_file_name = "wordpress-${version}-${wp_lang}.tar.gz"
  } else {
    $install_file_name = "wordpress-${version}.tar.gz"
  }

  ## wp_config directory
  if $wp_config_is_outside {
    $wp_config_dir = "${install_dir}/.."
  } else {
    $wp_config_dir = "${install_dir}"
  }

  ## Download and extract
  exec { "Download wordpress ${install_url}/wordpress-${version}.tar.gz to ${install_dir}":
    command => "wget ${install_url}/${install_file_name}",
    creates => "${install_dir}/${install_file_name}",
    require => File[$install_dir],
    user    => $wp_owner,
    group   => $wp_group,
  }
  -> exec { "Extract wordpress ${install_dir}":
    command => "tar zxvf ./${install_file_name} --strip-components=1",
    creates => "${install_dir}/index.php",
    user    => $wp_owner,
    group   => $wp_group,
  }
  ~> exec { "Change ownership ${install_dir}":
    command     => "chown -R ${wp_owner}:${wp_group} ${install_dir}",
    refreshonly => true,
    user        => $wp_owner,
    group       => $wp_group,
  }

  ## Configure wordpress
  #
  concat { "${wp_config_dir}/wp-config.php":
    owner   => $wp_owner,
    group   => $wp_group,
    mode    => '0640',
    require => Exec["Extract wordpress ${install_dir}"],
  }
  if $wp_config_content {
    concat::fragment { "${wp_config_dir}/wp-config.php body":
      target  => "${wp_config_dir}/wp-config.php",
      content => $wp_config_content,
      order   => '20',
    }
  } else {
    # Template uses no variables
    file { "${wp_config_dir}/wp-keysalts.php":
      ensure  => present,
      content => template('wordpress/wp-keysalts.php.erb'),
      replace => false,
      require => Exec["Extract wordpress ${install_dir}"],
    }
    concat::fragment { "${wp_config_dir}/wp-config.php keysalts":
      target  => "${wp_config_dir}/wp-config.php",
      source  => "${wp_config_dir}/wp-keysalts.php",
      order   => '10',
      require => File["${wp_config_dir}/wp-keysalts.php"],
    }
    # Template uses:
    # - $db_name
    # - $db_user
    # - $db_password
    # - $db_host
    # - $wp_table_prefix
    # - $wp_lang
    # - $wp_plugin_dir
    # - $wp_proxy_host
    # - $wp_proxy_port
    # - $wp_multisite
    # - $wp_site_domain
    # - $wp_additional_config
    # - $wp_debug
    # - $wp_debug_log
    # - $wp_debug_display
    # - $wp_siteurl_uri
    # - $wp_home_uri
    # - $wp_content_uri
    # - $wp_content_dir
    # - $wp_config_is_outside
    concat::fragment { "${wp_config_dir}/wp-config.php body":
      target  => "${wp_config_dir}/wp-config.php",
      content => template('wordpress/wp-config.php.erb'),
      order   => '20',
    }
  }
}
