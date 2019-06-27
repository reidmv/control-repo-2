Puppet::Functions.create_function(:constants) do
  def constants
    {
      'pe_conf'             => '/etc/puppetlabs/enterprise/conf.d/pe.conf',
      'user_data_conf'      => '/etc/puppetlabs/enterprise/conf.d/user_data.conf',
      'ca_pem'              => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
      'temp_whitelist_key'  => 'puppet_enterprise::profile::database::private_temp_puppetdb_host',
      'pe_services'         => ['pe-ace-server', 'pe-bolt-server', 'pe-console-services', 'pe-nginx', 'pe-orchestration-services', 'pe-postgresql', 'pe-puppetdb', 'pe-puppetserver'],
      'agent_services'      => ['puppet', 'pxp-agent'],
    }
  end
end
