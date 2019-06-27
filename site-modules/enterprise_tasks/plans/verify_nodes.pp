plan enterprise_tasks::verify_nodes(
  TargetSpec $node_to_verify,
  String $expected_type,
) {

  # First, verify that this command is running on the master
  $localhost_is_primary = run_task(enterprise_tasks::verify_node, localhost, hostname => 'localhost', expected_type => 'master', allow_failure => true).first().value()['node_verified']
  if !localhost_is_primary {
    fail_plan('Please run this command from your master host')
  }

  run_task(enterprise_tasks::check_user_data_conf, localhost)

  # Query puppetdb to get a list of all compilers (and the primary master)
  # This means that the case of checking to see whether a node is a compiler or not will require an RBAC token
  if $expected_type == 'compiler' {
    $compilers_and_primary = enterprise_tasks::get_nodes_with_role('master')

    # Make sure the supposed compiler isn't actually a primary or a replica
    # This check should be allowed to run without throwing errors if this node isn't a master/replica, since that would break things

    $is_replica = run_task(enterprise_tasks::verify_node, localhost, hostname => $node_to_verify, expected_type => 'replica', allow_failure => true).first().value()['node_verified']
    $is_primary = run_task(enterprise_tasks::verify_node, localhost, hostname => $node_to_verify, expected_type => 'master', allow_failure => true).first().value()['node_verified']

    if !($node_to_verify in $compilers_and_primary) or $is_replica or $is_primary {
      fail_plan("${node_to_verify} does not appear to be a compiler, this plan requires ${node_to_verify} to be a compiler")
    }
  } elsif $expected_type == 'pe_compiler' {
    $compilers_with_puppetdb = enterprise_tasks::get_nodes_with_role('pe_compiler')
    if !($node_to_verify in $compilers_with_puppetdb){
      fail_plan("${node_to_verify} does not appear to be a compiler with puppetdb")
    }
  } elsif $expected_type == 'agent' {
    # Run on the agent node because this case doesn't use Hiera
    run_task(enterprise_tasks::verify_node, $node_to_verify, hostname => $node_to_verify, expected_type => $expected_type)
  } else {
    # Run on the master node because non-agent cases require Hiera
    # If $node_to_verify is localhost and we want to check it is a master, we've already done that
    unless $node_to_verify == 'localhost' and $expected_type == 'master' {
      run_task(enterprise_tasks::verify_node, localhost, hostname => $node_to_verify, expected_type => $expected_type)
    }
  }
}
