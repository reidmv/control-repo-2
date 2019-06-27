#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class BackupSSLFilesPE < TaskHelper
  def task(_)
    Puppet.initialize_settings
    certname = Open3.capture2e('puppet config print certname')[0].strip
    backup_dirs = [
      '/etc/puppetlabs/puppet/ssl',
      '/etc/puppetlabs/puppetdb/ssl',
      '/opt/puppetlabs/server/data/console-services/certs',
      '/opt/puppetlabs/server/data/postgresql/9.6/data/certs',
      '/etc/puppetlabs/orchestration-services/ssl',
    ]

    output = ''
    backup_dirs.each do |dir|
      output, status = Open3.capture2e("test -e #{dir}")
      if status.exitstatus.zero?
        output, status = Open3.capture2e("cp -r #{dir} #{dir}_bak") if status.exitstatus.zero?
        raise TaskHelper::Error.new("Backing up Puppet directory: #{dir} failed on host with certname #{certname}", 'puppetlabs.certregen/backup-failed', output) if !status.exitstatus.zero?
      end
    end

    result = { _output: output }
    result.to_json
  end
end

BackupSSLFilesPE.run if __FILE__ == $PROGRAM_NAME
