class profile::base {

  #the base profile should include component modules that will be on all nodes

  # This file lists the profiles applied
  concat { '/var/cache/profiles.txt':
    ensure => present,
  }

  concat::fragment { 'profiles.txt: profile::base':
    target  => '/var/cache/profiles.txt',
    content => 'profile::base',
  }

}
