plan enterprise_tasks::verify_nodes(
  TargetSpec       $nodes,
  String           $expected_type,
  Optional[String] $certname = undef,
) {
  $target = get_targets($nodes)[0]
  $_certname = $certname ? {
    undef   => $target.host,
    default => $certname,
  }

  # First, verify that this command is running on the master
  $local_certname = run_command(@(EOS/L), localhost).first[stdout][0,-2]
    puppet config print certname --section agent
    |-EOS
  $localhost_is_primary = run_task(enterprise_tasks::verify_node, localhost,
                            certname      => $local_certname,
                            expected_type => 'master',
                            allow_failure => true,
                          ).first().value()['node_verified']

  if !localhost_is_primary {
    fail_plan('Please run this command from your master host')
  }

  # If $target.host is localhost and we were asked to check it is a master,
  # then yay, we're done! We just did that.
  # TODO: we should be able to check for local transport type, not just
  # string-match "localhost". That would be slightly more robust.
  if $target.host == 'localhost' and $expected_type == 'master' {
    return()
  }

  run_task(enterprise_tasks::check_user_data_conf, localhost)

  # Query puppetdb to get a list of all compilers (and the primary master)
  # This means that the case of checking to see whether a node is a compiler or not will require an RBAC token
  if $expected_type == 'compiler' {
    $compilers_and_primary = enterprise_tasks::get_nodes_with_role('master')

    # Make sure the supposed compiler isn't actually a primary or a replica
    # This check should be allowed to run without throwing errors if this node isn't a master/replica, since that would break things

    $is_replica = run_task(enterprise_tasks::verify_node, localhost,
                    certname      => $_certname,
                    expected_type => 'replica',
                    allow_failure => true,
                  ).first().value()['node_verified']
    $is_primary = run_task(enterprise_tasks::verify_node, localhost,
                    certname      => $_certname,
                    expected_type => 'master',
                    allow_failure => true,
                  ).first().value()['node_verified']

    if !($_certname in $compilers_and_primary) or $is_replica or $is_primary {
      fail_plan("${_certname} does not appear to be a compiler, this plan requires ${_certname} to be a compiler")
    }
  } elsif $expected_type == 'pe_compiler' {
    $compilers_with_puppetdb = enterprise_tasks::get_nodes_with_role('pe_compiler')
    if !($_certname in $compilers_with_puppetdb){
      fail_plan("${_certname} does not appear to be a compiler with puppetdb")
    }
  } elsif $expected_type == 'agent' {
    # Run on the agent node because this case doesn't use Hiera
    run_task(enterprise_tasks::verify_node, $target,
      certname      => $_certname,
      expected_type => $expected_type,
    )
  } else {
    run_task(enterprise_tasks::verify_node, localhost,
      certname      => $_certname,
      expected_type => $expected_type,
    )
  }
}
