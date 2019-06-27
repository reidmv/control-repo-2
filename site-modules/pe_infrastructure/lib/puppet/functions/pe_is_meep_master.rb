require 'puppet/functions/meep_function'

# Returns true if the node is the primary meep master.
#
# See pe_meep_master() for a definition.
Puppet::Functions.create_function(:pe_is_meep_master, Puppet::Functions::MeepFunction) do

  # @param certname Defaults to $trusted.certname, but may be
  #   the certname of another node.
  # @return [Boolean] true if the node certname (default or provided) matches
  #   that of the primary meep master node
  dispatch :pe_is_meep_master do
    optional_param 'String', :certname
  end

  def pe_is_meep_master(certname = nil)
    certname ||= closure_scope.lookupvar('trusted')['certname']

    get_primary_meep_master == certname
  end
end
