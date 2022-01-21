class profile::example {

  concat::fragment { 'profiles.txt: profile::example':
    target  => '/var/cache/profiles.txt',
    content => "profile::example\n",
  }

}
