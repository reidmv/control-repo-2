#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'
require 'etc'

class RunPuppetJob < TaskHelper
  def task(_)
    host, = Open3.capture2e('hostname -f') if !host

    output, status = Open3.capture2e("/opt/puppetlabs/bin/puppet-job run --no-enforce-environment --query 'nodes {deactivated is null and expired is null}'")
    raise TaskHelper::Error.new("Unable to run puppet job on host #{host}", 'puppetlabs.hafailover/run-puppet-job-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

# The HOME variable is required to run the provision command but may not exist
# when this task is executed using the orchestrator
ENV['HOME'] ||= Etc.getpwuid.dir

RunPuppetJob.run if __FILE__ == $PROGRAM_NAME
