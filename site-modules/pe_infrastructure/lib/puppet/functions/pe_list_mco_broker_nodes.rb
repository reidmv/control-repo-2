require 'puppet_x/puppetlabs/meep/config'

# Return a list of all mco broker hosts.
#
# The data is obtained from the MEEP pe.conf configuration.
Puppet::Functions.create_function(:pe_list_mco_broker_nodes) do
  # @return [Array<String>]
  def pe_list_mco_broker_nodes
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.list_nodes(:mco_broker)
  end
end
