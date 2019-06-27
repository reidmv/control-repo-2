require 'puppet_x/puppetlabs/meep/config'

# Provides common code for MEEP functions.
class Puppet::Functions::MeepFunction < Puppet::Functions::Function
  # Ensure that the Component type is defined.
  def self.init_dispatch
    local_types do
      type "Component = Enum[#{PuppetX::Puppetlabs::Meep::Config.pe_components.join(',')}]"
    end
  end

  # Lookup the first element of the primary_master node role list.
  # @return [String] certname of primary meep master
  def get_primary_meep_master
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.list_nodes(:primary_master).first
  end
end
