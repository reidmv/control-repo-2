class profile::muppet {

  concat::fragment { 'profiles.txt: profile::muppet':
    target  => '/var/cache/profiles.txt',
    content => "profile::muppet\n",
  }

}
