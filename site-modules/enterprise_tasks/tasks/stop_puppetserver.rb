#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class StopPuppetServer < TaskHelper
  def task(_)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip

    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet resource service pe-puppetserver ensure=stopped')
    raise TaskHelper::Error.new("Failed to stop puppetserver successfully on host with certname #{certname}", 'puppetlabs.certregen/rebuild-certs-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

StopPuppetServer.run if __FILE__ == $PROGRAM_NAME
