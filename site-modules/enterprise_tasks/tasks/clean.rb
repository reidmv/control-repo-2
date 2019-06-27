#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'puppet'
require 'open3'

class CleanSSLCertificate < TaskHelper
  def task(host: nil, **_kwargs)
    Puppet.initialize_settings
    certname, = Open3.capture2e('puppet config print certname')[0].strip
    host = Open3.capture2e('facter fqdn')[0].strip if host == 'localhost'

    output, status = Open3.capture2e("test -e /etc/puppetlabs/puppet/ssl/ca/signed/#{host}.pem")
    output, status_two = Open3.capture2e("puppetserver ca clean --certname=#{host}") if status.exitstatus.zero?
    raise TaskHelper::Error.new("Unable to clean host certificate on #{host} from CA #{certname}", 'puppetlabs.certregen/clean-failed', output) if status_two && !status_two.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

CleanSSLCertificate.run if __FILE__ == $PROGRAM_NAME
