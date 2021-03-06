# Class: rally::config
#
# This class configures rally tool and creates existing deployment

class rally::config inherits rally {

  $rally_config = '/etc/rally/rally.conf'
  $rally_deployment = 'existing'
  $rally_deployment_config = '/etc/rally/deployment/existing.json'

  $rally_hostname = hiera('rally::public_hostname')
  $rally_vip = hiera('rally::public_vip')

  $fuel_version = hiera('fuel_version')

  host { "${rally_hostname}":
    ensure => present,
    ip     => $rally_vip,
  }

  define rally_deployment_configuration($rally_config, $key, $value) {
    augeas { "${rally_config}_${key}":
      lens    => "Puppet.lns",
      incl    => "${rally_config}",
      context => "/files/${rally_config}/DEFAULT/",
      onlyif  => "get $key != '$value'",
      changes => [
        "ins $key after #comment[. =~ regexp('$key = .*')]",
        "set $key $value",
      ],
    }
  }

  $rally_deployment_config_values = {

    verbose => {
      key   => 'verbose',
      value => 'true',
    },
    log_dir => {
      key   => 'log_dir',
      value => '/var/log/rally/' },
  }

  $defaults = {
    rally_config => $rally_config,
    before       => Exec['register_deployment'],
  }

  create_resources(rally_deployment_configuration, $rally_deployment_config_values, $defaults)

  file { "$rally_deployment_config_values['log_dir']['key']":
    ensure => directory,
    path   => $rally_deployment_config_values['log_dir']['value'],
  }

  file {'deployment':
    ensure  => directory,
    path    => '/etc/rally/deployment'
  } ->
  file { "${rally_deployment_config}":
    ensure  => file,
    content => template('rally/existing.json.erb'),
    owner   => $rally::rally_user,
    group   => $rally::rally_group,
    mode    => '0644',
  }

  $cmd = "/usr/local/bin/rally deployment create \
    --file=${rally_deployment_config} \
    --name ${rally_deployment}"

  exec { 'dependencies_upgrade':
    command => 'pip install --upgrade "python-keystoneclient>=2.0.0"',
    path    => ['/usr/bin', '/usr/sbin'],
    timeout => 100,
    before  => Exec['register_deployment'],
    onlyif  => 'test "$fuel_version" = "8.0"',
  }

  exec { 'register_deployment':
    command => $cmd,
    path    => [
      '/bin',
      '/sbin',
      '/usr/bin',
      '/usr/sbin',
      '/usr/local/bin',
    ],
    user    => $rally::rally_user,
    cwd     => $rally::rally_home,
    require => File[$rally_deployment_config],
    unless  => "/usr/local/bin/rally deployment show \
      --deployment ${rally_deployment}",
  }
}
