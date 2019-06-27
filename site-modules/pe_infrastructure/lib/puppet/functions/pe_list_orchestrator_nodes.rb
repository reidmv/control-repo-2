require 'puppet_x/puppetlabs/meep/config'

# Return a list with the orchestrator host.
#
# Currently singular, and on the master.
#
# The data is obtained from the MEEP pe.conf configuration.
Puppet::Functions.create_function(:pe_list_orchestrator_nodes) do
  # @return [Array<String>]
  def pe_list_orchestrator_nodes
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.list_nodes(:orchestrator)
  end
end
