plan enterprise_tasks::enable_ha_failover(
  TargetSpec $host,
  TargetSpec $caserver,
  Enum['mono', 'mono-with-compile'] $topology,
  Optional[Integer] $replication_timeout_secs = 1800,
  Optional[Boolean] $skip_agent_config = undef,
  Optional[String] $agent_server_urls = undef,
  Optional[String] $pcp_brokers = undef,
) {
  $prev_master = get_targets($host)[0]
  $curr_master = get_targets($caserver)[0]

  # Fail when either agent_server_urls or pcp_brokers is not supplied, when they need to be
  if ($topology == 'mono-with-compile' and !$skip_agent_config and (!$agent_server_urls or !$pcp_brokers)) {
    fail_plan(@(EOT/L))
      agent_server_urls and pcp_brokers are required parameters for the \
      'mono-with-compile' topology, unless skip_agent_config is set to true
      | EOT
  }

  # The indexing removes the trailing newline. chomp() is not a core function
  $prev_master_certname = run_command(@(EOS/L), $prev_master).first[stdout][0,-2]
    /opt/puppetlabs/bin/puppet config print certname
    |-EOS

  wait_until_available([$prev_master, $curr_master], wait_time => 0)

  run_plan('enterprise_tasks::verify_nodes',
    node_to_verify => $curr_master.host,
    expected_type  => 'ca',
  )

  run_task('enterprise_tasks::disable_all_puppet_services', $prev_master)
  apply($prev_master) {
    cron { 'puppet infra recover_configuration':
      ensure => absent,
    }
  }
  run_task('enterprise_tasks::remove_enterprise_conf_files', $prev_master)
  run_task('enterprise_tasks::remove_certificate_artifacts', $curr_master,
    certname => $prev_master_certname,
  )
  run_task('enterprise_tasks::drop_pglogical_databases', $prev_master)
  run_task('enterprise_tasks::delete_ssl_dir', $prev_master)
  run_task('enterprise_tasks::run_puppet', $prev_master,
    alternate_host => $curr_master.host,
    exit_codes     => [1],
  )
  run_task('enterprise_tasks::sign', $curr_master,
    host => $prev_master_certname,
  )
  run_task('enterprise_tasks::run_puppet', $prev_master,
    alternate_host => $curr_master.host,
  )
  upload_file('/etc/puppetlabs/enterprise/hiera.yaml', '/etc/puppetlabs/enterprise/hiera.yaml', $prev_master)
  run_task('enterprise_tasks::provision_replica', $curr_master,
    host                => $prev_master.host,
    replication_timeout => $replication_timeout_secs,
  )
  run_task('enterprise_tasks::enable_replica', $curr_master,
    host              => $prev_master_certname,
    topology          => $topology,
    skip_agent_config => $skip_agent_config,
    agent_server_urls => $agent_server_urls,
    pcp_brokers       => $pcp_brokers,
  )

  # If skipping agent config, there is no need to run Puppet everywhere
  unless ($skip_agent_config) {
    run_task('enterprise_tasks::run_puppet_job', $curr_master)
  }
}
