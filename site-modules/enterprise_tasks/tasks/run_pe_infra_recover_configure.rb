#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'

class RunPEInfrastructureConfigure < TaskHelper
  def task(_)
    version_file = '/opt/puppetlabs/server/pe_version'
    puppet_bin   = '/opt/puppetlabs/bin'
    pe_version   = File.read(version_file).strip.to_s

    if pe_version.empty?
      raise TaskHelper::Error.new('No existing PE version found on host', 'puppetlabs/no-pe-version-file')
    elsif Gem::Version.new('2016.5') > Gem::Version.new(pe_version)
      infra_cmd = "#{puppet_bin}/puppet-enterprise recover_configuration"
    else
      infra_cmd = "#{puppet_bin}/puppet-infrastructure recover_configuration"
    end

    output, status = Open3.capture2e(infra_cmd)
    raise TaskHelper::Error.new('Puppet infrastructure recover_configuration failed', 'puppetlabs/puppet-infra-recover-configuration-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

RunPEInfrastructureConfigure.run if __FILE__ == $PROGRAM_NAME
