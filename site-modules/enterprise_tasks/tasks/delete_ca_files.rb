#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'
require 'puppet'

class DeleteCAFiles < TaskHelper
  def task(_)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip
    output, status = Open3.capture2e('rm -rf /etc/puppetlabs/puppet/ssl/*')
    raise TaskHelper::Error.new("Unable to remove CA files on host with certname #{certname}", 'puppetlabs.certregen/delete-ca-files-failed', output) if !status.exitstatus.zero?

    output, status = Open3.capture2e("rm -f /opt/puppetlabs/puppet/cache/client_data/catalog/#{certname}.json") if Gem::Version.new(Puppet.version) >= Gem::Version.new('6.0')
    raise TaskHelper::Error.new("Unable to remove cached catalog on host with certname #{certname}", 'puppetlabs.certregen/delete-ca-files-failed', output) if status.exitstatus != 0

    result = { _output: output }
    result.to_json
  end
end

DeleteCAFiles.run if __FILE__ == $PROGRAM_NAME
