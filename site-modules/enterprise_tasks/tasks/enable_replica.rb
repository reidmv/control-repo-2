#!/opt/puppetlabs/puppet/bin/ruby

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'
require 'etc'

class EnableReplica < TaskHelper
  def task(host:, topology:, skip_agent_config: nil, agent_server_urls: nil, pcp_brokers: nil, **_kwargs)
    Puppet.initialize_settings
    cmd = ['/opt/puppetlabs/bin/puppet-infra', 'enable', 'replica', host, '--topology', topology, '-y']

    if topology == 'mono'
      # none of the agent configuration parameters are required
    elsif skip_agent_config
      cmd << '--skip-agent-config' # this is the only parameter required
    else
      if agent_server_urls
        cmd << '--agent-server-urls' << agent_server_urls
      end
      if pcp_brokers
        cmd << '--pcp-brokers' << pcp_brokers
      end
    end

    output, status = Open3.capture2e(*cmd)
    if !status.exitstatus.zero?
      raise TaskHelper::Error.new("Failed to enable replica with certname #{host}",
                                  'puppetlabs.hafailover/enable-replica-failed',
                                  output)
    end

    result = { _output: output }
    result.to_json
  end
end

# The HOME variable is required to run the provision command but may not exist
# when this task is executed using the orchestrator
ENV['HOME'] ||= Etc.getpwuid.dir

EnableReplica.run if __FILE__ == $PROGRAM_NAME
