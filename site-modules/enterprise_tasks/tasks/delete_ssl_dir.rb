#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'

class DeleteSSLDirPE < TaskHelper
  def task(_)
    host, = Open3.capture2e('hostname -f') if !host

    output, status = Open3.capture2e('rm -rf /etc/puppetlabs/puppet/ssl')
    raise TaskHelper::Error.new("Unable to remove Puppet ssl directory on host #{host}", 'puppetlabs.hafailover/delete-ssl-dir-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

DeleteSSLDirPE.run if __FILE__ == $PROGRAM_NAME
