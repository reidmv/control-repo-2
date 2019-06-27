# This plan will check if an agent is already installed on a non-infra node. If it
# isn't, it will use pe_bootstrap to securely install the agent with the given 
# extension_requests and/or custom_attributes. If an agent is already installed,
# it will upgrade the agent to match the master's version, if necessary, and then
# it will regenerate the cert if extension_requests or custom_attributes is defined. 
#
# Note that if extension_requests is defined in order to put a trusted fact in the
# cert that will classify the node as a new infra node, the node will turn into
# the desired infra node since either this plan or the agent_cert_regen plan does
# a puppet run at the end.
plan enterprise_tasks::configure_agent(
  TargetSpec $agent,
  Optional[Hash] $extension_requests = undef,
  Optional[Hash] $custom_attributes = undef,
) {
  $constants = constants()
  $master = run_command('facter fqdn','localhost').first['stdout'].strip
  run_plan(enterprise_tasks::verify_nodes, node_to_verify => 'localhost', expected_type => 'master')
  wait_until_available([$agent], wait_time => 0)

  $agent_version = run_task(puppet_agent::version, $agent).first().value()['version']
  $master_agent_version = run_task(puppet_agent::version, $master).first().value()['version']
  $cacert_contents = run_command("cat ${constants['ca_pem']}", $master).first['stdout']

  if $agent_version {
    if $agent_version != $master_agent_version {
      # pe_bootstrap appears not to add the extension requests if you are upgrading the agent, so we'll need
      # to do agent cert regen after this in that case. We should first verify this is not an infra node already.
      run_plan(enterprise_tasks::verify_nodes, node_to_verify => $agent, expected_type => 'agent')
      run_task(pe_bootstrap, $agent, cacert_content => $cacert_contents, master => $master)
    }
    if $extension_requests or $custom_attributes {
      run_plan(enterprise_tasks::agent_cert_regen, agent => $agent, caserver => $master, extension_requests => $extension_requests, custom_attributes => $custom_attributes)
    }
  }
  else {
    if $extension_requests {
      $extension = $extension_requests.map |$key, $value| { "${key}=${value}" }
    } else {
      $extension = []
    }
    if $custom_attributes {
      $custom = $custom_attributes.map |$key, $value| { "${key}=${value}" }
    } else {
      $custom = []
    }
    run_task(pe_bootstrap, $agent, cacert_content => $cacert_contents, master => $master, extension_request => $extension, custom_attribute => $custom)
    run_task(enterprise_tasks::sign, $master, host => $agent)
    # Since this is a brand new node, it should be safe to stop/start the service without checking 
    # the existing service status beforehand
    run_task(enterprise_tasks::disable_agent_services, $agent, disable_pxp => true)
    run_task(enterprise_tasks::run_puppet, $agent, max_timeout => 256)
    run_task(enterprise_tasks::enable_agent, $agent,  enable_pxp => true)
  }
}