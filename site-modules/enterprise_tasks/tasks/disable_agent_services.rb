#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class DisableAgentServices < TaskHelper
  def task(disable_pxp: false, **_kwargs)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip

    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet resource service puppet ensure=stopped')
    raise TaskHelper::Error.new("Unable to stop puppet on host with certname #{certname}", 'puppetlabs.certregen/disable-services-failed', output) if !status.exitstatus.zero?
    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet resource service pxp-agent ensure=stopped') if disable_pxp
    raise TaskHelper::Error.new("Unable to stop pxp-agent on host with certname #{certname}", 'puppetlabs.certregen/disable-services-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

DisableAgentServices.run if __FILE__ == $PROGRAM_NAME
