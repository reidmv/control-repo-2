#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'open3'
require 'json'

class EnableAgent < TaskHelper
  def task(enable_pxp: false, **_kwargs)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip

    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet resource service puppet ensure=running')
    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet resource service pxp-agent ensure=running') if enable_pxp
    raise TaskHelper::Error.new("Failed to restart puppet service on agent with certname #{certname}", 'puppetlabs.certregen/enable-agent-error', output) if !status.exitstatus.zero?
    result = { _output: output }
    result.to_json
  end
end

EnableAgent.run if __FILE__ == $PROGRAM_NAME
