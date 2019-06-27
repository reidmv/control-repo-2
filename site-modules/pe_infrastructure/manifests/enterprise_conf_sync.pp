class pe_infrastructure::enterprise_conf_sync() {
  $enterprise_conf_path = '/etc/puppetlabs/enterprise'

  $enterprise_conf_owner = (pe_is_node_a('compile_master') or pe_is_node_a('primary_master')) ? {
    true  => undef,
    false => 'root',
  }

  # Skip having the Primary Master attempt to sync itself
  if (!pe_is_meep_master()) {
    file { "${enterprise_conf_path}":
      ensure  => directory,
      owner   => $enterprise_conf_owner,
      mode    => '0600',
      recurse => true,
      purge   => true,
      source  => "puppet://${pe_meep_master()}/enterprise_conf/",
    }
  }
}
