# Orchestrate upgrade of PE's primary infrastructure.
#
# Upgrades any layout (monolithic, legacy split, master/database, legacy
# split/database) based on the configuration read from pe.conf. It is
# intended for internal use in CI and manual testing, since PE tarballs are
# pulled from enterprise.delivery.puppetlabs.net.
#
# Puppet will have had to return a 0 exit code (no changes) from every target
# node before the plan will succeed.
#
# You must specify either $version or $tarball, but not both.
#
# @param $master [TargetSpec] the master PE node. All other primary infrastructure nodes
#   are looked up from enterprise data configuration on the master.
# @param $version [Optional[Variant[Enterprise_tasks::Pe_family,Enterprise_tasks::Pe_version]]]
#   a version string indicating either the family line (2019.1, 2019.2, etc.)
#   or an exact version of PE to download and upgrade to. If just the family is
#   given, the latest development build from that line will be installed.
# @param $tarball [Optional[Enterprise_tasks::Absolute_path] alternately you may
#   supply an absolute path to a PE tarball on the localhost which you wish
#   installed.
# @param $pe_conf [Optional[Enterprise_tasks::Absolute_path] the pe.conf to read on the
#   master for configuration information.
# @param $use_tempdirs [Boolean] if true, generate proper tempdirs as workdirs
#   for uploading PE and pe.conf files. Otherwise use /root. Defaults to true.
#   Set to false for manual testing where you want the simplicity of using /root
#   as the workdir.
plan enterprise_tasks::testing::upgrade_pe(
  TargetSpec $master,
  Optional[Variant[Enterprise_tasks::Pe_family,Enterprise_tasks::Pe_version]] $version = undef,
  Optional[Enterprise_tasks::Absolute_path] $tarball = undef,
  Optional[Enterprise_tasks::Absolute_path] $pe_conf = '/etc/puppetlabs/enterprise/conf.d/pe.conf',
  Boolean $use_tempdirs = true,
) {

  if ($version == undef and $tarball == undef) or ($version != undef and $tarball != undef) {
    fail_plan("You must specify either version or tarball, but not both. Received version: '${version}' and tarball: '${tarball}'")
  }

  $host_keys = ['puppet_enterprise::puppet_master_host','puppet_enterprise::console_host','puppet_enterprise::puppetdb_host','puppet_enterprise::database_host']
  $host_hash = run_task(enterprise_tasks::get_conf_values, $master, file=>$pe_conf, keys=>$host_keys).first.value
  if $host_hash['puppet_enterprise::puppet_master_host'] != $master {
    fail_plan("The master parameter (${master}) given to this plan does not match the puppet_enterprise::puppet_master_host (${host_hash['puppet_enterprise::puppet_master_host']}) parameter from ${pe_conf} on ${master}.")
  }

  $master_target = get_targets($master)[0]
  debug("Master target is: ${master_target}")
  $database_target = get_targets(enterprise_tasks::first_defined(
    $host_hash['puppet_enterprise::database_host'],
    $host_hash['puppet_enterprise::puppetdb_host'],
    $master
  ))[0]
  debug("Database target is: ${database_target}")
  $puppetdb_target = get_targets(enterprise_tasks::first_defined($host_hash['puppet_enterprise::puppetdb_host'], $master))[0]
  debug("Puppetdb target is: ${puppetdb_target}")
  $console_target  = get_targets(enterprise_tasks::first_defined($host_hash['puppet_enterprise::console_host'], $master))[0]
  debug("Console target is: ${console_target}")

  $db_split = ($master_target != $database_target and $puppetdb_target != $database_target)
  $dbnode = $db_split ? {
    true  => $database_target,
    false => $puppetdb_target,
  }
  $targets = [$dbnode, $master_target, $puppetdb_target, $console_target].unique - undef
  debug("Targets are: ${targets}")

  enterprise_tasks::message('upgrade_pe', 'Checking connectivity to infrastructure nodes.')
  wait_until_available($targets, wait_time => 0)

  enterprise_tasks::message('upgrade_pe', 'Preparing work directories')
  if $use_tempdirs {
    run_plan('enterprise_tasks::create_tempdirs', nodes => $targets, 'purpose' => 'upgrade')
  } else {
    enterprise_tasks::set_workdirs($targets)
  }

  enterprise_tasks::message('upgrade_pe', "Distributing PE tarball based on ${enterprise_tasks::first_defined($tarball, $version)}.")
  run_plan('enterprise_tasks::testing::get_pe',
    'nodes'   => $targets,
    'version' => $version,
    'tarball' => $tarball,
  )

  enterprise_tasks::message('upgrade_pe', 'Syncing enterprise data.')
  run_plan(enterprise_tasks::sync_enterprise_data,
    'master'         => $master_target,
    'infrastructure' => $targets,
  )

  enterprise_tasks::message('upgrade_pe', 'Upgrading Infrastructure nodes.')
  $targets.each |$node| {
    run_plan(enterprise_tasks::testing::run_installer,
      'nodes'           => $node,
      'non_interactive' => true,
      'skip_pe_conf'    => true,
    )
  }

  enterprise_tasks::message('upgrade_pe', 'Runnning puppet on all nodes to populate puppetdb.')
  run_task(enterprise_tasks::run_puppet, $targets)
  enterprise_tasks::message('upgrade_pe', 'Running puppet a second time on master (and possibly console node) to modify configuration based on puppetdb_query.')
  $second_run = [$master_target, $console_target].unique - undef
  run_task(enterprise_tasks::run_puppet, $second_run)

  enterprise_tasks::message('upgrade_pe', 'Validating that all infrastructure nodes are steady state.')
  run_task(enterprise_tasks::run_puppet, $targets, 'exit_codes' => [0])
}
