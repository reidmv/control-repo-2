require 'puppet_x/puppetlabs/meep/config'

# Returns true if the certname is a node that is part of Puppet Enterprise's own
# infrastructure as managed by MEEP.
Puppet::Functions.create_function(:pe_is_infrastructure) do
  # @param certname Defaults to $trusted.certname, but may be
  #   the certname of another node.
  # @return [Boolean]
  dispatch :pe_is_infrastructure do
    optional_param 'String', :certname
  end

  def pe_is_infrastructure(certname = nil)
    certname ||= closure_scope.lookupvar('trusted')['certname']

    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.is_infrastructure(certname)
  end
end
