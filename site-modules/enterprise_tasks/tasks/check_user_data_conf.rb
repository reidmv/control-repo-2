#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'

class CheckUserDataConf < TaskHelper
  def task(_)
    output, status = Open3.capture2e('test -e /etc/puppetlabs/enterprise/conf.d/user_data.conf')
    output, status_two = Open3.capture2e('/opt/puppetlabs/bin/puppet-infra recover_configuration') if !status.exitstatus.zero?
    raise TaskHelper::Error.new('Failed to run `puppet infrastructure recover_configuration` on the puppet master host', 'pe.verify-node/recover-configuration-failed', output) if status_two && !status_two.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

CheckUserDataConf.run if __FILE__ == $PROGRAM_NAME
