plan enterprise_tasks::ha_puppetdb_sync(
  String $mode
) {
  $constants = constants()
  $primary = run_command('facter fqdn','localhost').first['stdout'].strip
  $replica_pql = "resources[certname] { type = 'Class' and title = 'Puppet_enterprise::Profile::Primary_master_replica' }"
  $replica = puppetdb_query($replica_pql)[0][certname]
  $status_hash = run_plan(enterprise_tasks::get_service_status, target => $primary, service => 'puppet')
  $result_or_error = catch_errors() || {
    run_task(enterprise_tasks::disable_agent_services, $primary, disable_pxp => false)
    run_task(enterprise_tasks::add_modify_conf_keys, $primary, file => $constants['pe_conf'], hash => {'puppet_enterprise::packages::installing' => true})

    if ($mode == 'sync') {
      $primary_results = run_task(enterprise_tasks::fetch_sync_peer_data, $primary, recipient => $primary)
      $primary_peers = [$primary_results.first.value]
      $replica_results = run_task(enterprise_tasks::fetch_sync_peer_data, $primary, recipient => $replica)
      $replica_peers = [$replica_results.first.value]
    }
    elsif ($mode == 'unsync') {
      $primary_peers = []
      $replica_peers = []
    }
    else {
      fail_plan("'Must specify mode option as 'sync' or 'unsync'.")
    }
    $peer_hash = { $primary => $primary_peers, $replica => $replica_peers}
    run_task(enterprise_tasks::update_sync_peers, $primary, mode => $mode)

    $peer_hash.each |$nodes, $peers| {
      apply_prep($nodes)
      get_targets($nodes).each |$node| {
        apply($node) {
          realize(Package['pe-puppetdb'])
          service { 'pe-puppetdb':
            ensure => running,
          }
          class { 'puppet_enterprise::puppetdb::sync_ini':
            peers => $peers,
          }
        }
      }
      run_task(enterprise_tasks::remove_conf_keys, $primary, file => $constants['pe_conf'], keys => ['puppet_enterprise::packages::installing'])
      run_task(service, $nodes, action => 'restart', name => 'pe-puppetdb')
    }
  }
  out::message('Applying original agent state...')
  run_command("puppet resource service puppet ensure=${status_hash[status]} enable=${status_hash[enabled]}", $primary)
  if $result_or_error =~ Error {
    return fail_plan($result_or_error)
  }
}
