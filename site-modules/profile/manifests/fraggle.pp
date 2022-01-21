class profile::fraggle {

  concat::fragment { 'profiles.txt: profile::fraggle':
    target  => '/var/cache/profiles.txt',
    content => "profile::fraggle\n",
  }

}
