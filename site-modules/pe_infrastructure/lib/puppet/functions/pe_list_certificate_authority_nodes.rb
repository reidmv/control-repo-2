require 'puppet_x/puppetlabs/meep/config'

# Return a list with the certificate authority host.
#
# This is the master of masters, and in current configurations of PE is
# singular, but is being returned as a list for uniformity with other
# pe_list_<role>_nodes() functions.
#
# Not, if the installation is using an external CA, this may return an empty array.
#
# The data is obtained from the MEEP pe.conf configuration.
Puppet::Functions.create_function(:pe_list_certificate_authority_nodes) do
  # @return [Array<String>]
  def pe_list_certificate_authority_nodes
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.list_nodes(:certificate_authority)
  end
end
