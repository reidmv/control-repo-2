plan enterprise_tasks::provision_compiler(
  TargetSpec $compiler,
) {
  $constants = constants()

  # We need the fqdn for the pe_boostrap task
  $master = 'localhost'
  run_plan(enterprise_tasks::verify_nodes, nodes => $master, expected_type => 'master')
  $dbnodes = enterprise_tasks::get_nodes_with_role('database')
  # Ignore replicas
  $postgres = $dbnodes.filter |$node| {
    !run_task(enterprise_tasks::verify_node, localhost, hostname => $node, expected_type => 'replica', allow_failure => true).first().value()['node_verified']
  }
  $status_hash = run_plan(enterprise_tasks::get_service_status, target => $master, service => 'puppet')
  $result_or_error = catch_errors() || {

    wait_until_available([$compiler, $postgres], wait_time => 0)

    # This allows the compiler to be added to the postgres whitelist in advance so that
    # when the compiler starts the pe-puppetdb service for the first time, it can connect.
    run_task(enterprise_tasks::add_modify_conf_keys, $master, file => $constants['pe_conf'], hash => { $constants['temp_whitelist_key'] => $compiler })
    run_task(enterprise_tasks::run_puppet, $postgres)

    run_plan(enterprise_tasks::configure_agent, agent => $compiler, extension_requests => {'pp_role' => 'pe_compiler'})

    run_task(enterprise_tasks::remove_conf_keys, $master, file => $constants['pe_conf'], keys => $constants['temp_whitelist_key'])
    run_task(enterprise_tasks::run_puppet, $postgres)

    # Run on MoM to update services.conf, and any other compilers to update services.conf and crl.pem
    $all_masters = enterprise_tasks::get_nodes_with_role('master')
    $all_masters.each |$node| {
      # We already ran on the new compiler, as well as the postgres node if postgres == master
      unless $node == $compiler or $node == $postgres {
        run_task(enterprise_tasks::run_puppet, $node)
      }
    }

    run_plan(enterprise_tasks::verify_nodes, nodes => $compiler, expected_type => 'pe_compiler')
  }
  out::message('Applying original agent state...')
  run_command("puppet resource service puppet ensure=${status_hash[status]} enable=${status_hash[enabled]}", $master)
  if $result_or_error =~ Error {
    return fail_plan($result_or_error)
  }
}
