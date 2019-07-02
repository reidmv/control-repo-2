plan enterprise_tasks::master_cert_regen(
  TargetSpec $master = 'localhost',
  Optional[Boolean] $manage_pxp_service = true,
) {
  $status_hash = run_plan(enterprise_tasks::get_service_status, target => $master, service => 'puppet')

  $result_or_error = catch_errors() || {
    if $master != 'localhost' {
      wait_until_available([$master], wait_time => 0)
    }

    run_plan(enterprise_tasks::verify_nodes, nodes => $master, expected_type => 'master')

    $original_start_date = run_task(enterprise_tasks::fetch_cert_date, $master)
    run_task(enterprise_tasks::disable_agent_services, $master, disable_pxp => $manage_pxp_service)
    run_task(enterprise_tasks::backup, $master)

    $lock_result = lock_agent() |$lock_pid| {
      run_task(enterprise_tasks::remove_cache, $master)
      run_task(enterprise_tasks::clean, $master, host => $master)
      run_task(enterprise_tasks::delete_cert, $master, certname => $master)
      run_task(enterprise_tasks::stop_puppetserver, $master)
      run_task(enterprise_tasks::run_pe_infra_configure, $master, agent_pid => $lock_pid)
    }
    unless $lock_result{
      fail_plan('Could not acquire agent lock. Please try rerunning this plan once the current agent run is finished.')
    }

    run_task(enterprise_tasks::run_puppet, $master)
    $new_start_date = run_task(enterprise_tasks::fetch_cert_date, $master)
    if $original_start_date.first().value()['startdate'] == $new_start_date.first().value()['startdate'] {
      fail_plan("Certificate for ${master} was not correctly regenerated")
    }
    if $manage_pxp_service {
      $targets = get_targets($master)
      $targets.each |$target| {
        set_feature($target, 'puppet-agent', true)
      }
      run_task(service, [$master], action => 'restart', name => 'pxp-agent')
    }
  }
  out::message('Applying original agent state...')
  run_command("puppet resource service puppet ensure=${status_hash[status]} enable=${status_hash[enabled]}", $master)
  if $result_or_error =~ Error {
    return fail_plan($result_or_error)
  }
}
