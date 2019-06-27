require 'puppet_x/puppetlabs/meep/config'

# Return the list of database hosts.
#
# The data is obtained from the MEEP pe.conf configuration.
Puppet::Functions.create_function(:pe_list_database_nodes) do
  # @return [Array<String>]
  def pe_list_database_nodes
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.list_nodes(:database)
  end
end
