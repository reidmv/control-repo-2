#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'hocon'
require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class VerifyNode < TaskHelper
  def enterprise_hiera_yaml
    '/etc/puppetlabs/enterprise/hiera.yaml'
  end

  def enterprise_lookup_handle
    PuppetX::Puppetlabs::Meep::HieraAdapter.new(enterprise_hiera_yaml)
  end

  def hiera_lookup(hiera_param, certname)
    node = PuppetX::Puppetlabs::Meep::HieraAdapter.get_node
    scope = PuppetX::Puppetlabs::Meep::HieraAdapter.generate_scope(node)
    result = enterprise_lookup_handle.lookup("puppet_enterprise::#{hiera_param}", scope)

    if result.nil?
      false
    else
      result.is_a?(Array) ? result.include?(certname) : result == certname
    end
  end

  def task(certname:, expected_type:, allow_failure: false, **kwargs)
    # Add the Bolt _installdir to Ruby's load_path to pick up pe_infrastructure helper methods
    # This looks a bit awkward since normally requires are at the top, but to load all the correct files,
    #   we need to use the _installdir param that isn't available before the task() method is caled
    $LOAD_PATH << "#{kwargs[:_installdir]}/pe_infrastructure/lib"
    require_relative '../../pe_infrastructure/lib/puppet_x/puppetlabs/meep/hiera_adapter.rb'
    Puppet.initialize_settings
    Puppet.initialize_facts

    hiera_param = {
      'master'   => 'puppet_master_host',
      'ca'       => 'certificate_authority_host',
      'puppetdb' => 'puppetdb_host',
      'console'  => 'console_host',
      'database' => 'database_host',
      'replica'  => 'ha_enabled_replicas',
    }

    if expected_type == 'agent'
      # Ensure puppet is actually installed on the specified node
      _, status_one = Open3.capture2e('puppet --version')

      # Agent platforms should have no pe-* packages, so if no PE packages exist, it's assumed to be a puppet agent
      # Check to ensure exitstatus from the previous command is 1, because we expect the grep to find nothing (exitstatus = 1)
      _, status_two = Open3.capture2e("puppet resource package | grep \"package { 'pe-\"")

      verified = status_one.exitstatus.zero? && status_two.exitstatus == 1
    else
      verified = hiera_lookup(hiera_param[expected_type], certname)
    end
    n = (expected_type == 'agent') ? 'n' : ''
    raise TaskHelper::Error.new("#{certname} does not appear to be a#{n} #{expected_type} host.", 'pe.verify-node/node-verification-failed', '') if !allow_failure && !verified

    result = { node_verified: verified }
    result.to_json
  end
end

VerifyNode.run if __FILE__ == $PROGRAM_NAME
