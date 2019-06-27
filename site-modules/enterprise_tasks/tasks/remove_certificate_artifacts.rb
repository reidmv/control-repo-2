#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'

class RemovePECertificateArtifacts < TaskHelper
  def task(certname:, **_kwargs)
    host, = Open3.capture2e('hostname -f')

    output, status = Open3.capture2e("find /etc/puppetlabs/puppet/ssl/ -type f -name '#{certname}.pem' -delete")
    raise TaskHelper::Error.new("Unable to remove Puppet certificate artifacts on host #{host}", 'puppetlabs.hafailover/remove-certificate-artifacts-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

RemovePECertificateArtifacts.run if __FILE__ == $PROGRAM_NAME
