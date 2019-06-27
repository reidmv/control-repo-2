require 'puppet_x/puppetlabs/meep/config'

# Return the list of enabled replica hosts.
#
# This lists all nodes which have been configured as replicas and also
# enabled to take part in PE failover activities.
#
# The data is obtained from the MEEP pe.conf configuration.
Puppet::Functions.create_function(:pe_list_enabled_replica_nodes) do
  # @return [Array<String>]
  def pe_list_enabled_replica_nodes
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.list_nodes(:enabled_primary_master_replica)
  end
end
