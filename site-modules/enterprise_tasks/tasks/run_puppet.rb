#!/opt/puppetlabs/puppet/bin/ruby

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'

class RunPuppet < TaskHelper
  def task(alternate_host: nil, exit_codes: [0, 2], max_timeout: 0, env_vars: nil, **_kwargs)
    certname = Open3.capture2e('puppet config print certname')[0].strip

    run_string = env_vars ? env_vars.map { |k, v| "#{k}=#{v}" }.join(' ') + ' ' : ''
    run_string += '/opt/puppetlabs/bin/puppet agent -t'
    run_string += " --server_list #{alternate_host}:8140" if alternate_host

    if max_timeout.zero?
      output, status = Open3.capture2e(run_string)
    else
      timeout = 1
      while timeout < max_timeout
        output, status = Open3.capture2e(run_string)
        break if exit_codes.include?(status.exitstatus)
        sleep(timeout)
        timeout *= 2
      end
    end

    if !exit_codes.include? status.exitstatus
      raise TaskHelper::Error.new("Running puppet failed on host with certname #{certname}", 'puppetlabs.installpe/run-puppet-failed', output)
    end

    result = { _output: output }
    result.to_json
  end
end

RunPuppet.run if __FILE__ == $PROGRAM_NAME
