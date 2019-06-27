#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'hocon'
require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class UpdateSyncPeers < TaskHelper
  def task(mode:, **kwargs)
    $LOAD_PATH << "#{kwargs[:_installdir]}/pe_manager/lib"
    require_relative '../../pe_manager/lib/puppet_x/util/classification.rb'
    require_relative '../../pe_manager/lib/puppet_x/util/service_status.rb'
    require_relative '../../pe_install/lib/puppet/util/pe_node_groups.rb'
    Puppet.initialize_settings

    nc_service = PuppetX::Util::ServiceStatus.get_service_on_primary('classifier')
    nc = Puppet::Util::Pe_node_groups.new(nc_service[:server], nc_service[:port].to_i, "/#{nc_service[:prefix]}")
    all_groups = nc.get_groups
    pe_master_group = PuppetX::Util::Classifier.find_group(all_groups, 'PE Master')
    master_certname = Open3.capture2e('facter fqdn')[0].strip
    if mode == 'sync'
      puppetdb_servers = pe_master_group['classes']['puppet_enterprise::profile::master']['puppetdb_host']
      puppetdb_ports = pe_master_group['classes']['puppet_enterprise::profile::master']['puppetdb_port']
    elsif mode == 'unsync'
      puppetdb_ports = []
      puppetdb_servers = []
    end
    PuppetX::Util::Classification.update_ha_master_sync_peers(nc, all_groups, master_certname, puppetdb_servers, puppetdb_ports)
  end
end

UpdateSyncPeers.run if __FILE__ == $PROGRAM_NAME
