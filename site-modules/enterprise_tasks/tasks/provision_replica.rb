#!/opt/puppetlabs/puppet/bin/ruby

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'
require 'etc'

class ProvisionReplica < TaskHelper
  def task(host:, replication_timeout:, **_kwargs)
    Puppet.initialize_settings

    output, status = Open3.capture2e("/opt/puppetlabs/bin/puppet-infra provision replica #{host}")
    raise TaskHelper::Error.new("Failed to provision replica with certname #{host}", 'puppetlabs.hafailover/provision-replica-failed', output) if !status.exitstatus.zero?

    start_time = Time.now
    services_ok = false

    while (Time.now - start_time) < replication_timeout && !services_ok
      output, = Open3.capture2e("/opt/puppetlabs/bin/puppet-infra status --host #{host}")
      service_status = output.scan(%r{[0-9]+ of [0-9]+ services are fully operational})[0]
      services = service_status.scan(%r{[0-9]+})
      services_up = services[0]
      services_total = services[1]

      if services_up == services_total && services_up != 0
        services_ok = true
      else
        sleep(15)
      end
    end

    raise TaskHelper::Error.new("Replica status check timed out on host with certname #{host}", 'puppetlabs.hafailover/provision-replica-failed', output) if !services_ok

    result = { _output: output }
    result.to_json
  end
end

# The HOME variable is required to run the provision command but may not exist
# when this task is executed using the orchestrator
ENV['HOME'] ||= Etc.getpwuid.dir

ProvisionReplica.run if __FILE__ == $PROGRAM_NAME
