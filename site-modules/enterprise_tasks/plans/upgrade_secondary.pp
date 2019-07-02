plan enterprise_tasks::upgrade_secondary(
  TargetSpec $node
) {
  $constants = constants()
  $status_hash = run_plan(enterprise_tasks::get_service_status, target => $node, service => 'puppet')
  $result_or_error = catch_errors() || {
    wait_until_available([$node], wait_time => 0)
    $master = run_command('facter fqdn','localhost').first['stdout'].strip
    run_plan(enterprise_tasks::verify_nodes, nodes => $master, expected_type => 'master')
    run_plan(enterprise_tasks::verify_nodes, nodes => $node, expected_type => 'replica')

    $master_build = run_command('cat /opt/puppetlabs/server/pe_build', $master).first['stdout'].strip

    apply($node){
      service { $constants['pe_services'] + $constants['agent_services']:
        ensure => stopped
      }
    }

    run_command("/opt/puppetlabs/puppet/bin/curl --cacert ${constants['ca_pem']} https://${master}:8140/packages/current/install.bash | bash", $node, _run_as => 'root')
    run_task(enterprise_tasks::run_puppet, $node, env_vars => {'FACTER_pe_build' => $master_build})
  }
  out::message('Applying original agent state...')
  run_command("puppet resource service puppet ensure=${status_hash[status]} enable=${status_hash[enabled]}", $node)
  if $result_or_error =~ Error {
    return fail_plan($result_or_error)
  }
}
