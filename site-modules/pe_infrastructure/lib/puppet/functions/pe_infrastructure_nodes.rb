require 'puppet_x/puppetlabs/meep/config'

# Returns the set of all infrastructure nodes being managed by Puppet
# Enterprise through MEEP.
#
# This is every node listed in the node_roles hash in the pe.conf file.
#
# It does not include any of the customer's agent fleet outside of those
# specifically provisioned as parts of Puppet Enterprise itself.
Puppet::Functions.create_function(:pe_infrastructure_nodes) do
  # @return [Array<String>]
  def pe_infrastructure_nodes
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.list_all_infrastructure
  end
end
