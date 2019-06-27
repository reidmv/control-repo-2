# Returns the role assigned to the current node in MEEP's pe.conf file.
#
# It is invalid for a node to be assigned to more than one role in pe.conf,
# and the role returned is not guaranteed in this case.
#
# @example
#   Assuming the following split configuration in pe.conf:
#
#   "node_roles": {
#     "pe_role::split::primary_master": ["a.master.node"]
#     "pe_role::split::puppetdb": ["a.puppetdb.node"]
#     "pe_role::split::console": ["a.console.node"]
#   }
#
#   and a catalog being compiled by MEEP on 'a.puppetdb.node' then
#
#   pe_role() # => "pe_role::split::puppetdb"
#   pe_role("a.master.node") # => "pe_role::split::primary_master"
#
Puppet::Functions.create_function(:pe_role) do
  # @return [Optional[String]] role from pe.conf or nil if there is no match.
  dispatch :pe_role_current_node do
  end

  # @param certname certname of a node to look up (defaults
  #   to the current node (trusted.certname)
  # @return [Optional[String]] role from pe.conf or nil if there is no match.
  dispatch :pe_role do
    param 'String', :certname
  end

  def pe_role_current_node
    certname = closure_scope.lookupvar('trusted')['certname']
    pe_role(certname)
  end

  def pe_role(certname)
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.get_role_for(certname) 
  end
end
