#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'

class GetAgentVersion < TaskHelper
  def task(_)
    certname = Open3.capture2e('puppet config print certname')[0].strip

    output, status = Open3.capture2e('puppet --version')
    raise TaskHelper::Error.new("Could not determine Puppet version on host with certname #{certname}", 'puppetlabs/get-puppet-version-failed', output) if !status.exitstatus.zero?

    agent_version = output.strip
    result = { agent_version: agent_version }
    result.to_json
  end
end

GetAgentVersion.run if __FILE__ == $PROGRAM_NAME
