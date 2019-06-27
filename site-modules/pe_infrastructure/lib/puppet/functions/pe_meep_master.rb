require 'puppet/functions/meep_function'

# Returns the primary master that is the source of meep configuration for all other 
# PE infrastructure.
#
# Right now, we really only support a single primary master, but the
# configuration allows an array, and you could conceivably construct a
# custom_role which would register as a primary_master role.
#
# For now this function just returns the first primary_master from the list.
# This should be consistent, but will undoubtadedly need to be reworked in the
# future.
Puppet::Functions.create_function(:pe_meep_master, Puppet::Functions::MeepFunction) do

  # @return [String] the first primary_master certname. (Could be nil in
  #   misconfigured pe.conf file)
  def pe_meep_master
    get_primary_meep_master
  end
end
