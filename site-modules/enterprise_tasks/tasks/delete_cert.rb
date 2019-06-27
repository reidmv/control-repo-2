#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class DeleteCertificate < TaskHelper
  def task(certname: nil, **_kwargs)
    Puppet.initialize_settings
    if !certname || certname == 'localhost'
      certname = Open3.capture2e('facter fqdn')[0].strip
    end
    output, status = Open3.capture2e("find /etc/puppetlabs/puppet/ssl -name #{certname}.pem -delete")
    raise TaskHelper::Error.new("Failed to delete master certificates on host using certname #{certname}", 'puppetlabs.certregen/delete-master-cert-failed', output) if !status.exitstatus.zero?
    result = { _output: output }
    result.to_json
  end
end

DeleteCertificate.run if __FILE__ == $PROGRAM_NAME
