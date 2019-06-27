#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'puppet'
require 'open3'

class FindCert < TaskHelper
  def task(_)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip
    found = false

    _output, status = Open3.capture2e("test -e /etc/puppetlabs/puppet/ssl/certs/#{certname}.pem")
    found = true if status.exitstatus.zero?
    result = { found: found }
    result.to_json
  end
end

FindCert.run if __FILE__ == $PROGRAM_NAME
