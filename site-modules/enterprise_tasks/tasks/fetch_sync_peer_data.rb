#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'hocon'
require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class FetchSyncPeerData < TaskHelper
  def task(recipient:, **kwargs)
    $LOAD_PATH << "#{kwargs[:_installdir]}/pe_manager/lib"
    require_relative '../../pe_manager/lib/puppet_x/util/classification.rb'
    require_relative '../../pe_manager/lib/puppet_x/util/service_status.rb'
    require_relative '../../pe_install/lib/puppet/util/pe_node_groups.rb'
    Puppet.initialize_settings

    nc_service = PuppetX::Util::ServiceStatus.get_service_on_primary('classifier')
    nc = Puppet::Util::Pe_node_groups.new(nc_service[:server], nc_service[:port].to_i, "/#{nc_service[:prefix]}")
    all_groups = nc.get_groups
    pe_master_group = PuppetX::Util::Classifier.find_group(all_groups, 'PE Master')
    pe_infra_group = PuppetX::Util::Classifier.find_group(all_groups, 'PE Infrastructure')
    puppetdb_servers = pe_master_group['classes']['puppet_enterprise::profile::master']['puppetdb_host']
    puppetdb_ports = pe_master_group['classes']['puppet_enterprise::profile::master']['puppetdb_port']
    puppetdb_sync_interval_minutes = pe_infra_group['classes']['puppet_enterprise']['puppetdb_sync_interval_minutes'] || 2
    sync_peer = puppetdb_servers
                .zip(puppetdb_ports)
                .reject { |server, _| server == recipient }
                .map do |replica, port|
                  { 'host' => replica,
                    'port' => port,
                    'sync_interval_minutes' => puppetdb_sync_interval_minutes }
                end
    sync_peer.first
  end
end
FetchSyncPeerData.run if __FILE__ == $PROGRAM_NAME
