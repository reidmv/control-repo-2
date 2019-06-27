plan enterprise_tasks::rebuild_ca(
  TargetSpec $caserver,
  Optional[Boolean] $manage_pxp_service = true,
) {
  if $caserver != 'localhost' {
    wait_until_available([$caserver], wait_time => 0)
  }

  run_plan(enterprise_tasks::verify_nodes, node_to_verify => $caserver, expected_type => 'ca')
  run_task(enterprise_tasks::disable_ca_services, $caserver)
  run_task(enterprise_tasks::backup, $caserver)
  run_task(enterprise_tasks::delete_ca_files, $caserver)

  run_task(enterprise_tasks::run_pe_infra_configure, $caserver)
  run_task(enterprise_tasks::run_puppet, $caserver)

  if $manage_pxp_service {
    run_task(service, [$caserver], action => 'restart', name => 'pxp-agent')
  }
}
