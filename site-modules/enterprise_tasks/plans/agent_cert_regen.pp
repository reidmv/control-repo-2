# Be careful when using a node_type other than agent, as other considerations may need to be made
# when regenerating a certificate on an infrastructure node, such as restarting services.
plan enterprise_tasks::agent_cert_regen(
  TargetSpec $agent,
  TargetSpec $caserver,
  Optional[Hash] $extension_requests = undef,
  Optional[Hash] $custom_attributes = undef,
  Optional[String] $node_type = 'agent',
  Optional[Boolean] $manage_pxp_service = true,
) {
  wait_until_available([$agent, $caserver], wait_time => 0)
  $status_hash = run_plan(enterprise_tasks::get_service_status, target => $agent, service => 'puppet')
  $result_or_error = catch_errors() || {
    run_plan(enterprise_tasks::verify_nodes, nodes => $caserver, expected_type => 'ca')
    run_plan(enterprise_tasks::verify_nodes, nodes => $agent, expected_type => $node_type)

    $original_start_date = run_task(enterprise_tasks::fetch_cert_date, $agent)
    run_task(enterprise_tasks::clean, $caserver, host => $agent)
    run_task(enterprise_tasks::backup, $agent)
    run_task(enterprise_tasks::disable_agent_services, $agent, disable_pxp => true)
    if $extension_requests or $custom_attributes{
      run_task(enterprise_tasks::set_csr_attributes, $agent, extension_requests => $extension_requests, custom_attributes => $custom_attributes)
    }
    run_task(enterprise_tasks::delete_ca_files, $agent)

    $agent_version_string = run_task(enterprise_tasks::get_agent_version, $agent).first().value()['agent_version']
    $agent_version = SemVer($agent_version_string)
    $puppet_ssl_range = SemVerRange('>=6.0.0')

    # Use `puppet ssl` to make the certificate request if possible, else use `enable_agent`
    if $agent_version =~ $puppet_ssl_range {
      run_task(enterprise_tasks::request_cert, $agent)
    } else {
      run_task(enterprise_tasks::enable_agent, $agent, enable_pxp => true)
    }
    run_task(enterprise_tasks::sign, $caserver, host => $agent)

    # Wait and retry to account for potential SSL lockfile conflicts
    run_task(enterprise_tasks::run_puppet, $agent, max_timeout => 256)

    if $manage_pxp_service {
      $targets = get_targets($agent)
      $targets.each |$target| {
        set_feature($target, 'puppet-agent', true)
      }
      run_task(service, $targets, action => 'restart', name => 'pxp-agent')
    }

    $new_start_date = run_task(enterprise_tasks::fetch_cert_date, $agent)

    if $original_start_date.first().value()['startdate'] == $new_start_date.first().value()['startdate'] {
      fail_plan("Certificate for ${agent} was not correctly regenerated")
    }
  }
  out::message('Applying original agent state...')
  run_command("puppet resource service puppet ensure=${status_hash[status]} enable=${status_hash[enabled]}", $agent)

  if $result_or_error =~ Error {
    return fail_plan($result_or_error)
  }
}
