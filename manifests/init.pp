#
class gitlab_ci_runner (
  $gitlab_ci    = $gitlab_ci_runner::params::gitlab_ci,
  $gitlab       = $gitlab_ci_runner::params::gitlab,
  $token        = $gitlab_ci_runner::params::token
) inherits gitlab_ci_runner::params {

  $packages = [
    'wget',
    # 'curl',
    'gcc',
    'checkinstall',
    # 'libxml2-dev',
    # 'libxslt-dev',
    'libcurl4-openssl-dev',
    # 'libreadline6-dev',
    # 'libc6-dev',
    # 'libssl-dev',
    'libmysql++-dev',
    'make',
    # 'build-essential', # already included with rvm
    # 'zlib1g-dev',
    'openssh-client',
    # 'git-core',
    # 'libyaml-dev',
    'postfix',
    'libpq-dev',
    'libicu-dev',
  ]

  $user = 'gitlab_ci_runner'
  $group = $user
  $home_path = "/home/${user}"
  $install_path = "${home_path}/gitlab-ci-runner"

  package { $packages: ensure => installed }
  ->
  user { $user:
    ensure      => present,
    managehome  => true,
  }
  ->
  file { "${home_path}/.ssh":
    ensure  => directory,
    mode    => 700,
    owner   => $user,
    group   => $user,
  }
  ->
  exec { 'remove old host fingerprint from known_hosts':
    command => "ssh-keygen -R ${gitlab}",
    onlyif => "ssh-keygen -F ${gitlab}",
    user => $user,
    provider => shell,
  }
  ->
  exec { 'add host fingerprint to known_hosts':
    command => "ssh-keyscan -t rsa ${gitlab} >> ${home_path}/.ssh/known_hosts",
    user => $user,
    provider => shell,
  }
  ->
  class { 'rvm': }
  ->
  rvm_system_ruby {
    'ruby-1.9.3-p392':
      ensure => present,
  }
  ->
  rvm::system_user {
    $user:
  }
  ->
  rvm_gemset {
    "ruby-1.9.3-p392@${user}":
      ensure => present,
      require => Rvm_system_ruby["ruby-1.9.3-p392"],
  }
  ->
  rvm_gem {
    "ruby-1.9.3-p392@${user}/bundler":
      ensure => present,
      require => Rvm_gemset["ruby-1.9.3-p392@${user}"],
  }
  ->
  vcsrepo { $install_path:
    ensure    => latest,
    owner     => $user,
    group     => $group,
    provider  => git,
    require   => [ Package['git-core'] ],
    source    => 'https://github.com/gitlabhq/gitlab-ci-runner.git'
  }
  ->
  exec { 'bundle install gems':
    command => "rvm 1.9.3-p392@${user} do bundle install",
    cwd => $install_path,
    path => [ '/usr/local/sbin', '/usr/local/bin' , '/usr/sbin/', '/usr/bin/', '/sbin', '/bin', '/usr/local/rvm/bin' ],
    user => $user,
    provider => shell,
  }
  ->
  file { '/etc/init.d/gitlab-ci-runner':
    ensure  => present,
    source  => "${install_path}/lib/support/init.d/gitlab_ci_runner",
    mode    => "0744",
  }
  file { "${home_path}/.ssh/id_rsa":
    ensure  => absent,
    force => true,
  }
  ->
  file { "${home_path}/.ssh/id_rsa.pub":
    ensure  => absent,
    force => true,
  }
  ->
  exec { 'generate ssh key':
    command => "ssh-keygen -t rsa -f '${home_path}/.ssh/id_rsa' -N ''",
    user => $user,
    provider => shell,
  }
  ->
  exec { 'register token and public key':
    command => "(echo -n '{\"token\":\"${token}\",\"public_key\":\"'; ssh-keygen -y -f '${home_path}/.ssh/id_rsa'; echo -n '\"}') | curl -H 'Content-Type: application/json' -d @- '${gitlab_ci}api/v1/runners/register.json'",
    user => $user,
    provider => shell,
    # | curl -H 'Content-Type: application/json' -d @- '${gitlab_ci}api/v1/runners/register.json'"
  }
  # exec { 'bundle install runner':
  #   # 1) Please enter the gitlab-ci coordinator URL (e.g. http://gitlab-ci.org:3000/ )  <= $gitlab_ci
  #   # 2) Enter file in which to save the key (/home/gitlab_ci_runner/.ssh/id_rsa):      <= [nothing]
  #   # 3) Enter passphrase (empty for no passphrase):                                    <= [nothing]
  #   # 4) Enter same passphrase again:                                                   <= [nothing]
  #   # 5) Please enter the gitlab-ci token for this runner:                              <= $token
  #   command => "echo -e '${gitlab_ci}\n\n\n\n${token}\n' | rvm 1.9.3-p392@${user} exec bundle exec ./bin/install",
  #   # command => "rvm 1.9.3-p392@${user} exec bundle exec ./bin/install << \$'${gitlab_ci}\\n\\n\\n\\n${token}\\n'",
  #   cwd => $install_path,
  #   path => [ '/usr/local/sbin', '/usr/local/bin' , '/usr/sbin/', '/usr/bin/', '/sbin', '/bin', '/usr/local/rvm/bin' ],
  #   # path => [  ],
  #   # $install_path,
  #   user => $user,
  #   provider => shell,
  #   logoutput => true,
  # }
  # ->
  # service { "gitlab-ci-runner service":
  #   ensure    => running,
  #   provider  => init,
  # }
  # ->
  # exec { 'register service to run on start':
  #   command   => 'update-rc.d gitlab-ci-runner defaults 21',
  #   path => $install_path,
  # }

}
