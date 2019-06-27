# Orchestrate installation of PE's primary infrastructure.
#
# Installs in any layout (monolithic, legacy split, master/database, legacy
# split/database) based on the given (or absence of) master, database, puppetdb
# and console parameters. It is intended for internal use in CI and manual
# testing, since PE tarballs are pulled from enterprise.delivery.puppetlabs.net.
#
# There are a number of plans and tasks that break down installation into a few steps.
#
#  * coordinating tempdirs for uploading and unpacking PE tarballs
#    ([create_tempdirs](plans/create_tempdirs.pp))
#  * generating a pe.conf file for installation and placing it in the workdir
#    of each node ([create_pe_conf](plans/testing/create_pe_conf.pp))
#  * getting the tarballs onto the workdir of each node and unpacking them
#    ([get_pe](plans/testing/get_pe.pp))
#  * installing in the correct sequence ([run_installer](plans/testing/run_installer.pp))
#  * running puppet nodes to complete installation until we are at a verified
#    steady state on all nodes ([run_puppet](tasks/run_puppet.rb))
#
# The plan and its supporting plans and tasks try to return useful errors where possible.
# In particular, if the PE installer fails, full log output will be retrieved
# and returned for review.
#
# Puppet will have had to return a 0 exit code (no changes) from every target
# node before the plan will succeed.
#
# # Additional pe.conf parameters
#
# The plan adds parameters supressing the agent daemon for the purpose of testing (so
# that background agent runs do not interfere with testing).
#
# A puppet_enterprise::puppetdb_start_timeout is set to 300 if the database is split out
# to avoid the potentially four hour wait on the master node for puppetdb to give up
# before proceeding to the database node.
#
# You must specify either +version+ or +tarball+, but not both.
#
# @param master [TargetSpec] the master PE node.
# @param puppetdb [TargetSpec] the puppetdb node if different from master (legacy split)
# @param database [TargetSpec] the database node if different from the master or puppetdb node.
# @param console [TargetSpec] the console node if different from master (legacy split)
# @param version [Optional[Variant[Enterprise_tasks::Pe_family,Enterprise_tasks::Pe_version]]]
#   a version string indicating either the family line (2019.1, 2019.2, etc.)
#   or an exact version of PE to download and install. If just the family is
#   given, the latest development build from that line will be installed.
# @param tarball [Optional[Enterprise_tasks::Absolute_path] alternately you may
#   supply an absolute path to a PE tarball on the localhost which you wish
#   installed.
# @param console_admin_password [Optional[String]] the console_admin_password
#   for pe.conf. Only bother with this if required (installing < 2019.0).
# @param other_pe_conf_parameters [Optional[Hash]] a hash of additional PE module parameters to
#   be added to pe.conf prior to installation.
# @param use_tempdirs [Boolean] if true, generate proper tempdirs as workdirs
#   for uploading PE and pe.conf files. Otherwise use /root. Defaults to true.
#   Set to false for manual testing where you want the simplicity of using /root
#   as the workdir.
plan enterprise_tasks::testing::install_pe(
  TargetSpec $master,
  TargetSpec $puppetdb = $master,
  TargetSpec $database = $puppetdb,
  TargetSpec $console = $master,
  Optional[Variant[Enterprise_tasks::Pe_family,Enterprise_tasks::Pe_version]] $version = undef,
  Optional[Enterprise_tasks::Absolute_path] $tarball = undef,
  Optional[String] $console_admin_password = undef,
  Optional[Hash] $other_pe_conf_parameters = {},
  Boolean $use_tempdirs = true,
) {

  if ($version == undef and $tarball == undef) or ($version != undef and $tarball != undef) {
    fail_plan("You must specify either version or tarball, but not both. Received version: '${version}' and tarball: '${tarball}'")
  }

  $master_target = get_targets($master)[0]
  debug("Master target is: ${master_target}")
  $database_target = get_targets($database)[0]
  debug("Database target is: ${database_target}")
  $puppetdb_target = get_targets($puppetdb)[0]
  debug("Puppetdb target is: ${puppetdb_target}")
  $console_target = get_targets($console)[0]
  debug("Console target is: ${console_target}")
  $targets = [$master_target, $database_target, $puppetdb_target, $console_target].unique
  debug("Targets are: ${targets}")

  enterprise_tasks::message('install_pe', 'Checking connectivity to infrastructure nodes.')
  wait_until_available($targets, wait_time => 0)

  $db_split = ($master != $database and $puppetdb != $database)
  if $db_split {
    # Then we don't want to wait for the default 4 hours...
    $extra_db_parameters = {
      'puppet_enterprise::puppetdb::start_timeout' => 300
    }
    debug('Detected a separate database node')
  } else {
    $extra_db_parameters = {}
  }

  run_plan('facts', nodes => $targets)

  $platform_tag = enterprise_tasks::platform_tag($master_target.facts['os'])

  enterprise_tasks::message('install_pe', 'Preparing work directories.')
  if $use_tempdirs {
    run_plan('enterprise_tasks::create_tempdirs', nodes => $targets, 'purpose' => 'install')
  } else {
    enterprise_tasks::set_workdirs($targets)
  }

  enterprise_tasks::message('install_pe', 'Creating pe.conf on all nodes.')
  $pe_conf_results = run_plan('enterprise_tasks::testing::create_pe_conf',
    'nodes'                  => $targets,
    'master'                 => $master,
    'database'               => $database,
    'puppetdb'               => $puppetdb,
    'console'                => $console,
    'console_admin_password' => $console_admin_password,
    'other_parameters'       => {
      'pe_infrastructure::agent::puppet_service_managed' => true,
      'pe_infrastructure::agent::puppet_service_ensure'  => 'stopped',
      'pe_infrastructure::agent::puppet_service_enabled' => false,
    } + $extra_db_parameters + $other_pe_conf_parameters,
  )
  $pe_conf = $pe_conf_results['pe_conf']
  enterprise_tasks::message('install_pe', "Generated pe.conf: ${pe_conf}")

  enterprise_tasks::message('install_pe', "Distributing PE tarball based on ${enterprise_tasks::first_defined($tarball, $version)}.")
  run_plan('enterprise_tasks::testing::get_pe',
    'nodes'   => $targets,
    'version' => $version,
    'tarball' => $tarball,
  )

  if $db_split {
    # Set up CA, expect it to fail because puppetdb dies 5min in (because we set
    # puppet_enterprise::puppetdb::start_timeout to 300 above). This should
    # be torn out in favor of a plan that sets up just the ca rather than running
    # the whole installer...
    enterprise_tasks::message('install_pe', "Setting up CA on master. This will hang for ${pe_conf['puppet_enterprise::puppetdb::start_timeout']} seconds.")

    $master_workdir = $master_target.vars()['workdir']
    $master_pe_dir = $master_target.vars()['pe_dir']
    run_task('enterprise_tasks::testing_installer', $master,
      'pe_dir'        => $master_pe_dir,
      'pe_conf_file'  => "${master_workdir}/pe.conf",
      '_catch_errors' => true, # ignoring the error on the master node...
    )

    enterprise_tasks::message('install_pe', 'Installing the database')
    run_plan('enterprise_tasks::testing::run_installer',
      'nodes'      => $database,
    )

    $remaining =  [$master_target, $puppetdb_target, $console_target].unique.filter |$i| { $i =~ NotUndef }
    enterprise_tasks::message('install_pe', 'Completing configuration of master (and any remaining infrastructure nodes if this was a legacy split layout).')
    $remaining.each |$node| {
      run_plan('enterprise_tasks::testing::run_installer',
        'nodes'      => $node,
      )
    }
  } else {
    enterprise_tasks::message('install_pe', 'Installing on all infrastructure nodes.')
    $targets.each |$node| {
      run_plan('enterprise_tasks::testing::run_installer',
        'nodes'      => $node,
      )
    }
  }

  enterprise_tasks::message('install_pe', 'Runnning puppet on all nodes to populate puppetdb.')
  run_task(enterprise_tasks::run_puppet, $targets)
  enterprise_tasks::message('install_pe', 'Running puppet a second time on master (and possibly console node) to modify configuration based on puppetdb_query.')
  $second_run = [$master_target, $console_target].unique.filter |$i| { $i =~ NotUndef }
  run_task(enterprise_tasks::run_puppet, $second_run)

  enterprise_tasks::message('install_pe', 'Validating that all infrastructure nodes are steady state.')
  run_task(enterprise_tasks::run_puppet, $targets, 'exit_codes' => [0])
}
