require 'puppet/functions/meep_function'

# Given a component string, return true if the current node has this component
# configured on it according to MEEP.
Puppet::Functions.create_function(:pe_is_node_a, Puppet::Functions::MeepFunction) do
  # define the Component type
  init_dispatch

  # @param component the type of PE component. Must be a member of
  #   {PuppetX::Puppetlabs::Meep::Config.pe_components}.
  # @param certname Defaults to $trusted.certname, but may be
  #   the certname of another node.
  # @return [Boolean]
  dispatch :pe_is_node_a  do
    param 'Component', :component
    optional_param 'String', :certname
  end

  def pe_is_node_a(component, certname = nil)
    certname ||= closure_scope.lookupvar('trusted')['certname']

    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.is_node_a(component, certname)
  end
end
