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
      |-EOT
  }
  $status_hash = run_plan(enterprise_tasks::get_service_status, target => $host, service => 'puppet')
  $result_or_error = catch_errors() || {

    $certname_cmd = '/opt/puppetlabs/bin/puppet config print certname'
    $certnames = run_command($certname_cmd, [$prev_master, $curr_master]).reduce({}) |$memo,$res| {
      # The indexing removes the trailing newline. chomp() is not a core function
      $memo + { $res.target => $res[stdout][0,-2] }
    }

    wait_until_available([$prev_master, $curr_master], wait_time => 0)

    run_plan('enterprise_tasks::verify_nodes', nodes => $curr_master,
      certname      => $certnames[$curr_master],
      expected_type => 'ca',
    )

    run_task('enterprise_tasks::disable_all_puppet_services', $prev_master)
    apply($prev_master) {
      cron { 'puppet infra recover_configuration':
        ensure => absent,
      }
    }
    run_task('enterprise_tasks::remove_enterprise_conf_files', $prev_master)
    run_task('enterprise_tasks::remove_certificate_artifacts', $curr_master,
      certname => $certnames[$prev_master],
    )
    run_task('enterprise_tasks::drop_pglogical_databases', $prev_master)
    run_task('enterprise_tasks::delete_ssl_dir', $prev_master)
    run_task('enterprise_tasks::run_puppet', $prev_master,
      alternate_host => $curr_master.host,
      exit_codes     => [1],
    )
    run_task('enterprise_tasks::sign', $curr_master,
      host => $certnames[$prev_master],
    )
    run_task('enterprise_tasks::run_puppet', $prev_master,
      alternate_host => $curr_master.host,
    )
    upload_file('/etc/puppetlabs/enterprise/hiera.yaml', '/etc/puppetlabs/enterprise/hiera.yaml', $prev_master)
    run_task('enterprise_tasks::provision_replica', $curr_master,
      host                => $certnames[$prev_master],
      replication_timeout => $replication_timeout_secs,
    )
    run_task('enterprise_tasks::enable_replica', $curr_master,
      host              => $certnames[$prev_master],
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
  out::message('Applying original agent state...')
  run_command("puppet resource service puppet ensure=${status_hash[status]} enable=${status_hash[enabled]}", $host)
  if $result_or_error =~ Error {
    return fail_plan($result_or_error)
  }
}
