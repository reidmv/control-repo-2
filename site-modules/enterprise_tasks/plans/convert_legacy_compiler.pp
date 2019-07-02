plan enterprise_tasks::convert_legacy_compiler(
  TargetSpec $compiler,
) {
  $constants = constants()

  $master = 'localhost'
  $status_hash = run_plan(enterprise_tasks::get_service_status, target => $compiler, service => 'puppet')
  $result_or_error = catch_errors() || {
    run_plan(enterprise_tasks::verify_nodes, nodes => $master, expected_type => 'master')
    $postgres = enterprise_tasks::get_nodes_with_role('database')

    wait_until_available([$compiler, $postgres], wait_time => 0)
    # This allows the compiler to be added to the postgres whitelist in advance so that
    # when the compiler starts the pe-puppetdb service for the first time, it can connect.
    run_task(enterprise_tasks::add_modify_conf_keys, $master, file => $constants['pe_conf'], hash => { $constants['temp_whitelist_key'] => $compiler })
    run_task(enterprise_tasks::run_puppet, $postgres, max_timeout => 256)
    # Node is verified to be a compiler in agent_cert_regen, which also performs the puppet
    # run that turns it into a new compiler+PDB
    run_task(enterprise_tasks::disable_agent_services, $compiler, disable_pxp => false)
    run_task(enterprise_tasks::stop_puppetserver, $compiler)
    run_plan(enterprise_tasks::agent_cert_regen, agent => $compiler, caserver => $master, node_type => 'compiler', extension_requests => {'pp_role' => 'pe_compiler'})

    run_command("puppet resource pe_node_group \"PE Master\" unpinned=\"${compiler}\"", $master)
    run_task(enterprise_tasks::remove_conf_keys, $master, file => $constants['pe_conf'], keys => $constants['temp_whitelist_key'])
    run_task(enterprise_tasks::run_puppet, $postgres, max_timeout => 256)

    # Run on MoM to update services.conf, and any other compilers to update services.conf and crl.pem
    $all_masters = enterprise_tasks::get_nodes_with_role('master')
    $all_masters.each |$node| {
      # We already ran on the new compiler, as well as the postgres node if postgres == master
      unless $node == $compiler or $node == $postgres {
        run_task(enterprise_tasks::run_puppet, $node, max_timeout => 256)
      }
    }

    run_plan(enterprise_tasks::verify_nodes, nodes => $compiler, expected_type => 'pe_compiler')
  }
  out::message('Applying original agent state...')
  run_command("puppet resource service puppet ensure=${status_hash[status]} enable=${status_hash[status]}", $compiler)
  if $result_or_error =~ Error {
    return fail_plan($result_or_error)
  }
}
