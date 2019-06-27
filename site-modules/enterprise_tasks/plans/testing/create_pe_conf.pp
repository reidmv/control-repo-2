# Used to generate an initial pe.conf file on a node for installing PE on that
# node. Intended to be used on a fresh node that does not yet have puppet-agent/ruby.
# Because of this, the pe.conf file is generated on the localhost that bolt is
# executing on and pushed to the target node.
#
# Bolt apply is not used, since apply_prep would install the most recent agent
# on the node, which is unlikely to be the agent version shipped with the PE
# tarball we are about to install.
#
# @param $nodes [TargetSpec] Target nodes passed into the plan.
# @param $master [String] The puppet_enterprise::puppet_master_host certname.
# @param $puppetdb [String] The puppet_enterprise::puppetdb_host certname, defaults to $master.
# @param $database [String] The puppet_enterprise::database_host certname, defaults to $puppetdb.
# @param $console [String] The puppet_enterprise::console_host certname, defaults to $master.
# @param $console_admin_password [Optional[String]] The console_admin_password
#   parameter for pe.conf if it must be set for initial install. Use of this is
#   discouraged in favor of resetting the console admin password post install.
# @param $other_parameters [Optional[Hash]] Optional hash of additional parameters to be set
#   in pe.conf.
plan enterprise_tasks::testing::create_pe_conf(
  TargetSpec $nodes,
  String $master,
  String $puppetdb = $master,
  String $database = $puppetdb,
  String $console = $master,
  Optional[String] $console_admin_password = undef,
  Optional[Hash] $other_parameters = {},
) {
  # If we don't have a workdir set on our nodes, set it to /root.
  enterprise_tasks::set_workdirs($nodes)

  # Create a local copy of pe.conf so that we can upload it.
  $localhost_result_set = run_task(enterprise_tasks::tempdirs, 'localhost', 'purpose' => 'peconf')
  $local_tempdir = $localhost_result_set.find('localhost').value()['tempdir']

  $pe_conf_json = enterprise_tasks::generate_pe_conf(
    {
      'master'           => $master,
      'puppetdb'         => $puppetdb,
      'database'         => $database,
      'console'          => $console,
    },
    $console_admin_password,
    $other_parameters,
  )

  $local_pe_conf = "${local_tempdir}/pe.conf"
  file::write($local_pe_conf, $pe_conf_json)

  get_targets($nodes).each |$node| {
    $remote_tempdir = $node.vars()['workdir']

    # Upload the file directly to the chosen working dir on the node.
    upload_file($local_pe_conf, "${remote_tempdir}/pe.conf", $node)
  }

  # Delete the local copy.
  run_command("rm ${local_pe_conf} && rmdir ${local_tempdir}", localhost)

  info("Generated pe.conf: ${pe_conf_json}")

  $result = {
    'pe_conf' => $pe_conf_json,
  }

  return $result
}
