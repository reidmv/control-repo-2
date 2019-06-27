#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class RunPEInfrastructureConfigure < TaskHelper
  def task(agent_pid: nil, **_kwargs)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip

    command = '/opt/puppetlabs/bin/puppet infrastructure configure --no-recover'
    command += " --agent-pid=#{agent_pid}" if agent_pid
    output, status = Open3.capture2e(command)
    raise TaskHelper::Error.new("Puppet infrastructure configure failed on host with certname #{certname}", 'puppetlabs/infrastructure-configure-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

RunPEInfrastructureConfigure.run if __FILE__ == $PROGRAM_NAME
