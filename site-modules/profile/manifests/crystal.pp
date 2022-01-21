class profile::crystal {

  concat::fragment { 'profiles.txt: profile::crystal':
    target  => '/var/cache/profiles.txt',
    content => 'profile::crystal',
  }

}
