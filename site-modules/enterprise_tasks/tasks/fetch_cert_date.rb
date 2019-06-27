#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class FetchCertDate < TaskHelper
  def task(_)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip

    output, status = Open3.capture2e("test -e /etc/puppetlabs/puppet/ssl/certs/#{certname}.pem")
    output, status_two = Open3.capture2e("/opt/puppetlabs/puppet/bin/openssl x509 -noout -startdate -in /etc/puppetlabs/puppet/ssl/certs/#{certname}.pem") if status.exitstatus.zero?
    raise TaskHelper::Error.new("Unable to find certificate on host with certname #{certname}", 'puppetlabs.certregen/fetch-cert-date-failed', output) if status_two && !status_two.exitstatus.zero?

    result = { startdate: output }
    result.to_json
  end
end

FetchCertDate.run if __FILE__ == $PROGRAM_NAME
