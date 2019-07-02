plan enterprise_tasks::rebuild_ca(
  TargetSpec $caserver,
  Optional[Boolean] $manage_pxp_service = true,
) {
  $status_hash = run_plan(enterprise_tasks::get_service_status, target => $caserver, service => 'puppet')
  $result_or_error = catch_errors() || {
    if $caserver != 'localhost' {
      wait_until_available([$caserver], wait_time => 0)
    }

    run_plan(enterprise_tasks::verify_nodes, nodes => $caserver, expected_type => 'ca')
    run_task(enterprise_tasks::disable_ca_services, $caserver)
    run_task(enterprise_tasks::backup, $caserver)
    run_task(enterprise_tasks::delete_ca_files, $caserver)

    run_task(enterprise_tasks::run_pe_infra_configure, $caserver)
    run_task(enterprise_tasks::run_puppet, $caserver)

    if $manage_pxp_service {
      run_task(service, [$caserver], action => 'restart', name => 'pxp-agent')
    }
  }
  out::message('Applying original agent state...')
  run_command("puppet resource service puppet ensure=${status_hash[status]} enable=${status_hash[enabled]}", $caserver)
  if $result_or_error =~ Error {
    return fail_plan($result_or_error)
  }
}
