require 'puppet_x/puppetlabs/meep/config'

# Return a list of all compile master hosts.
#
# The data is obtained from the MEEP pe.conf configuration.
Puppet::Functions.create_function(:pe_list_compile_master_nodes) do
  # @return [Array<String>]
  def pe_list_compile_master_nodes
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.list_nodes(:compile_master)
  end
end
