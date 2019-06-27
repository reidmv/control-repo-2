#Gist for this plan: https://gist.github.com/npwalker/8ad2ab7d6e7901ba9fbf1910a310c21f

plan enterprise_tasks::migrate_split_to_mono {
  $constants = constants()

  # This plan should be running from the master, so find the fqdn and consider it $master
  $master = run_command('facter fqdn','localhost').first['stdout'].strip
  run_plan(enterprise_tasks::verify_nodes, node_to_verify => 'localhost', expected_type => 'master')

  # Find which node is master, console, and puppetdb
  # Each infra node passed should have this info in pe.conf, so
  # it doesn't really matter which one we get this from.
  $host_keys = ['puppet_enterprise::puppet_master_host','puppet_enterprise::console_host','puppet_enterprise::puppetdb_host','puppet_enterprise::database_host']
  $split_hosts = run_task(enterprise_tasks::get_conf_values, $master, file => $constants['pe_conf'], keys => $host_keys).first.value

  # Query nodes before migration and puppetdb fqdn changes
  $all_masters = enterprise_tasks::get_nodes_with_role('master')

  $console = $split_hosts['puppet_enterprise::console_host']
  $puppetdb = $split_hosts['puppet_enterprise::puppetdb_host']
  $postgres = $split_hosts['puppet_enterprise::database_host']
  $external_postgres_exists = $postgres != undef
  $dbnode = $external_postgres_exists ? {
    true  => $postgres,
    false => $puppetdb
  }

  notice('*** Pre-Migration ***')
  notice("Master = ${master}")
  notice("Console = ${console}")
  notice("PuppetDB = ${puppetdb}")
  if $external_postgres_exists {
    notice("PE-PostgreSQL = ${postgres}")
  }
  notice('*********************')

  if ($master == $console or $master == $puppetdb) {
    fail_plan('The nodes specified do not appear to be in a split configuration.', 'puppetlabs.splitmigration/invalid_config', {'Master' => $master, 'Console' => $console, 'PuppetDB' => $puppetdb})
  }

  # ensure that all hosts are reachable by Bolt
  if $external_postgres_exists {
    wait_until_available([$master, $console, $puppetdb, $postgres], wait_time => 0)
  } else {
    wait_until_available([$master, $console, $puppetdb], wait_time => 0)
  }

  # Disable the recover_configuration cron job on master
  $disable_cron_key = 'puppet_enterprise::master::recover_configuration::recover_configuration_interval'
  $recover_configuration_interval = run_task(enterprise_tasks::get_conf_values, $master, file => $constants['pe_conf'], keys => $disable_cron_key).first.value[$disable_cron_key]
  run_task(enterprise_tasks::add_modify_conf_keys, $master, file => $constants['pe_conf'], hash => {$disable_cron_key => 0})
  run_task(enterprise_tasks::run_puppet, $master)

  # Edit user_data.conf and pe.conf on master
  run_task(enterprise_tasks::remove_conf_keys, $master, file => $constants['user_data_conf'], keys => ['puppet_enterprise::console_host','puppet_enterprise::puppetdb_host'])
  run_task(enterprise_tasks::remove_conf_keys, $master, file => $constants['pe_conf'], keys => ['puppet_enterprise::console_host','puppet_enterprise::puppetdb_host'])
  unless $external_postgres_exists {
    run_task(enterprise_tasks::add_modify_conf_keys, $master, file => $constants['pe_conf'], hash => {'puppet_enterprise::database_host' => $puppetdb})
  }

  # Move pe.conf from master to postgres host
  upload_file($constants['pe_conf'], $constants['pe_conf'], $dbnode)

  # Run puppet infra configure on postgres and master
  run_task(enterprise_tasks::run_pe_infra_configure, $dbnode)
  run_task(enterprise_tasks::run_pe_infra_configure, $master)

  # Unpin old nodes from PE Console and PE PuppetDB node groups
  run_command("puppet resource pe_node_group \"PE Console\" unpinned=\"${console}\"", $master)
  run_command("puppet resource pe_node_group \"PE PuppetDB\" unpinned=\"${puppetdb}\"", $master)

  # Puppet agent runs
  run_task(enterprise_tasks::run_puppet, $console)
  run_task(enterprise_tasks::run_puppet, $puppetdb)
  run_task(enterprise_tasks::run_puppet, $master)
  # Second run on the master happens at the end

  # Remove pe-puppetdb on old PuppetDB node
  run_task(service, $puppetdb, name => 'pe-puppetdb', action => 'stop')
  run_command('puppet resource package pe-puppetdb ensure=absent', $puppetdb)

  # Remove pe-console-services on old Console node
  run_task(service, $console, name => 'pe-console-services', action => 'stop')
  run_command('puppet resource package pe-console-services ensure=absent', $console)

  $discard_string = $external_postgres_exists ? {
    true => "${console} and ${puppetdb} may now be discarded.",
    false => "${console} may now be discarded."
  }

  # Re-enable the recover_configuration cron job on master, if it was enabled before
  # It doesn't really matter if it is in pe.conf on the postgres node, but this keeps
  # pe.conf consistent with the master.
  if $recover_configuration_interval {
    run_task(enterprise_tasks::add_modify_conf_keys, [$master,$dbnode], file => $constants['pe_conf'], hash => {$disable_cron_key => $recover_configuration_interval})
  } else {
    run_task(enterprise_tasks::remove_conf_keys, [$master,$dbnode], file => $constants['pe_conf'], keys => $disable_cron_key)
  }

  #PE-26274 One last puppet run on compile master(s)
  $all_masters.each |$node| {
    run_task(enterprise_tasks::run_puppet, $node)
  }

  notice("${master} is now set up as a monolithic master, with a separate PE-PostgreSQL database node at ${dbnode}. ${discard_string}")
}
