#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class DisableCAServices < TaskHelper
  def task(_)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip

    services = ['puppet', 'pxp-agent', 'pe-puppetserver', 'pe-bolt-server', 'pe-orchestration-services', 'pe-console-services', 'pe-puppetdb', 'pe-postgresql']
    output = ''
    if Gem::Version.new(Puppet.version) >= Gem::Version.new('6.0')
      services.each do |service|
        output, status = Open3.capture2e("/opt/puppetlabs/bin/puppet resource service #{service} ensure=stopped")
        raise TaskHelper::Error.new("Unable to stop service #{service} on host with certname #{certname}", 'puppetlabs.certregen/disable-services-failed', output) if !status.exitstatus.zero?
      end
    end
    result = { _output: output }
    result.to_json
  end
end

DisableCAServices.run if __FILE__ == $PROGRAM_NAME
