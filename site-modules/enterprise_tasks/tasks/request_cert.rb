#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class RequestCertificate < TaskHelper
  def task(_)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip

    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet ssl submit_request')
    raise TaskHelper::Error.new("Certificate request failed on host with certname #{certname}", 'puppetlabs/request-certificate-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

RequestCertificate.run if __FILE__ == $PROGRAM_NAME
