require 'puppet/functions/meep_function'

# Provides any data to be made available via Puppet lookup() calls to any other module.
Puppet::Functions.create_function('pe_infrastructure::data', Puppet::Functions::MeepFunction) do

  # Navigate the services list to either safely return the meep master's port
  # or the default puppet server port.
  #
  # @return [Integer] the meep master port or default
  def get_meep_master_port
    get_service_port_or_default(get_primary_meep_master, 'puppetserver', 'puppet_master_port')
  end

  def get_meep_pcp_broker_port
    get_service_port_or_default(get_primary_meep_master, 'pcp-broker', 'pcp_broker_port')
  end

  # Helper function looks up the port associated with a particular service
  # on the given primary host
  def get_service_port_or_default(host_cert, service_name, port_key)
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    services = config.services_list

    primary = services['primary'] || {}
    service_list = primary[service_name] || []
    service_config = service_list.find { |e| e['certname'] == host_cert } || {}
    default = PuppetX::Puppetlabs::Meep::Defaults.parameters[port_key]
    service_config['port'] || default
  end

  def get_stomp_port
    get_meep_parameter_or_default('puppet_enterprise::mcollective_middleware_port')
  end

  def get_stomp_user
    get_meep_parameter_or_default('puppet_enterprise::mcollective_middleware_user')
  end

  def get_meep_parameter_or_default(full_parameter, host_cert = nil)
    host_cert ||= closure_scope.lookupvar('trusted')['certname']
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    value = config.hiera_lookup_for_node(host_cert, full_parameter)
    last_key = full_parameter.split('::').last
    default = PuppetX::Puppetlabs::Meep::Defaults.parameters[last_key]
    value || default
  end

  # @return Hash
  def data(options, context)
    {
      ###############
      # Puppet Enterprise Defaults being made available to other modules under
      # the pe_infrastructure namespace.
      'pe_infrastructure::default_roles' => PuppetX::Puppetlabs::Meep::Defaults.role_definitions,
      'pe_infrastructure::default_parameters' => PuppetX::Puppetlabs::Meep::Defaults.parameters,

      ###############
      # Class parameter defaults for pe_infrastructure classes
      #
      # pe_infrastructure::enterprise::repo
      # 'pe_infrastructure::enterprise::repo::master' => get_primary_meep_master,
      # 'pe_infrastructure::enterprise::repo::port'   => get_meep_master_port,

      # pe_infrastructure::agent
      # 'pe_infrastructure::agent::pcp_broker_host' => get_primary_meep_master,
      # 'pe_infrastructure::agent::pcp_broker_port' => get_meep_pcp_broker_port,

      # pe_infrastructure::agent::mcollective
      # 'pe_infrastructure::agent::mcollective::stomp_port'     => get_stomp_port,
      # 'pe_infrastructure::agent::mcollective::stomp_user'     => get_stomp_user,
    }
  end
end
