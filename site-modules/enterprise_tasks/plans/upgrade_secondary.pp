plan enterprise_tasks::upgrade_secondary(
  TargetSpec $node
) {
  $constants = constants()
  wait_until_available([$node], wait_time => 0)
  $master = run_command('facter fqdn','localhost').first['stdout'].strip
  run_plan(enterprise_tasks::verify_nodes, node_to_verify => $master, expected_type => 'master')
  run_plan(enterprise_tasks::verify_nodes, node_to_verify => $node, expected_type => 'replica')

  $pe_build = run_command('cat /opt/puppetlabs/server/pe_build', $master).first['stdout'].strip

  apply($node){
    service { $constants['pe_services'] + $constants['agent_services']:
      ensure => stopped
    }
  }

  run_command("/opt/puppetlabs/puppet/bin/curl --cacert ${constants['ca_pem']} https://${master}:8140/packages/current/install.bash | sudo bash", $node)
  run_task(enterprise_tasks::run_puppet, $node, env_vars => {'FACTER_pe_build' => $pe_build})
  apply($node){
    service { 'puppet':
      ensure => running
    }
  }
}