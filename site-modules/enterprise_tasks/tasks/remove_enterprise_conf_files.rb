#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'

class RemoveEnterpriseConfFiles < TaskHelper
  def task(_)
    host, _status = Open3.capture2e('hostname -f')

    output, status = Open3.capture2e('rm -rf /etc/puppetlabs/enterprise/*')
    raise TaskHelper::Error.new("Unable to remove PE configuration directory on host #{host}", 'puppetlabs.hafailover/delete-conf-dir-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

RemoveEnterpriseConfFiles.run if __FILE__ == $PROGRAM_NAME
