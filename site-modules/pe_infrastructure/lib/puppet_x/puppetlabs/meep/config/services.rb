module PuppetX::Puppetlabs::Meep
  module Services
    # Composes node lists for all pe components with the api ports they've
    # been configured to listen on.
    #
    # Looks for port overrides in per node files, then in pe.conf, and finally
    # relies on {Defaults::PE_INFRASTRUCTURE}.
    #
    # @return Hash with services broken out by primary services (the
    #   primary master, puppetdb, console nodes), secondary services such as
    #   compile masters, and replica services.
    #
    # @example
    #   services_list() =>
    #
    #   {
    #     "primary" => {
    #       "puppetserver" => [{
    #         "display_name"  => "Puppet Server",
    #         "node_certname" => "master.node",
    #         "port"          => 8140,
    #         "prefix"        => "",
    #         "server"        => "master.node",
    #         "status_key"    => "pe-master",
    #         "status_prefix" => "status",
    #         "status_url"    => "https://master.node:8140/status",
    #         "type"          => "master",
    #         "url"           => "https://master.node:8140/"
    #       }],
    #       "code-manager" => [{
    #         "display_name"  => "Code Manager",
    #         "node_certname" => "master.node",
    #         "port"          => 8170,
    #         "prefix"        => "",
    #         "server"        => "master.node",
    #         "status_key"    => "code-manager-service",
    #         "status_prefix" => "status",
    #         "status_url"    => "https://master.node:8140/status",
    #         "type"          => "master",
    #         "url"           => "https://master.node:8170/"
    #       }],
    #       etc.
    #     },
    #     "secondary" => {
    #       "puppetserver" => [],
    #       etc.
    #     },
    #     "replica" => {
    #       "puppetserver" => [],
    #       etc.
    #     }
    #   }
    def services_list
      service_hash = Hash.new { |h,k| h[k] = [] }
      services_list = {
        "primary" => service_hash.clone,
        "secondary" => service_hash.clone,
        "replica" => service_hash.clone,
      }

      node_roles.each do |role, nodes|
        nodes.each do |certname|

          node_profiles = get_node_profiles(certname)
          services = services_list_by_node(node_profiles)
          tier = infrastructure_class(role, node_profiles)

          services.each do |service_type|
            next unless _service_enabled?(service_type, certname)
            service = Defaults.component_services[service_type]
            service['node_certname'] = certname
            service['server'] = certname
            overrides = _param_overrides_for_service(certname, service_type)
            service.merge!(overrides)

            # now that we've looked up any potential param overrides, such as port,
            # generate and add the various service url's.
            service['status_url'] = _service_status_url(service)
            service['url'] = _service_url(service)

            services_list[tier][service_type] << service
          end
        end
      end

      services_list
    end

    private

    # The list of services the passed node provides based on the profiles
    # associated with its role in the pe.conf's node_roles hash.
    #
    # @param node_profiles [Array] The list of profiles applied to the node.
    #
    # @return [Array] A list of services running on the node
    def services_list_by_node(node_profiles)
      services = Defaults::SERVICES_TO_PROFILES.select do |service, service_profiles|
        !(service_profiles & node_profiles).empty?
      end

      services.keys.uniq
    end

    # Somewhat artificial separation into primary, secondary, replica
    # classes of infrastructure based on the assigned role and profiles.
    def infrastructure_class(role, node_profiles)
      tier = nil
      if default_roles.include?(role)
        tier = case role
        when
          "pe_role::monolithic::primary_master",
          "pe_role::split::primary_master",
          "pe_role::split::puppetdb",
          "pe_role::split::console"
          then 'primary'
        when "pe_role::monolithic::primary_master_replica"
          then 'replica'
        else 'secondary'
        end
      else
        tier = case
        when node_profiles.include?("puppet_enterprise::profile::primary_master")
          then 'primary'
        when node_profiles.include?("puppet_enterprise::profile::primary_master_replica")
          then 'replica'
        when !(node_profiles & [
            "puppet_enterprise::profile::compile_master",
            "puppet_enterprise::profile::amq::broker",
            "puppet_enterprise::profile::amq::hub",
          ]).empty?
          then 'secondary'
        # otherwise it's difficult to say, could be a primary split variant
        # or some new secondary (extra puppetdb?), consider primary for now
        else 'primary'
        end
      end

      tier
    end

    # Returns a hash of parameters a user may have overriden on a component via pe.conf.
    #
    # @param certname [String] The node's certname to lookup node based overrides.
    # @param service [String] The service name to look for overrides on.
    #
    # @return [Hash] A hash keyed by parameter name to value
    def _param_overrides_for_service(certname, service)
      overrides = {}
      Defaults::OVERRIDEABLE_COMPONENT_SERVICES_PARAMS[service].each do |parameter_key, module_parameters|
        param_override = nil
        module_parameters.each do |param|
          # node override nodes/ directory
          param_override = hiera_lookup_for_node(certname, param)
          # global override in pe.conf
          param_override ||= hiera_lookup(param)
          break if param_override
        end

        overrides[parameter_key] = param_override if param_override
      end

      overrides
    end

    def _service_url(service)
      "#{service['protocol']}://#{service['node_certname']}:#{service['port']}/#{service['prefix']}"
    end

    def _service_status_url(service)
      "https://#{service['node_certname']}:#{service['status_port']}/#{service['status_prefix']}"
    end

    # Determines whether or not a service is enabled by doing hiera lookups on
    # the parameter that controls it.
    #
    # @param service_type [String] The service type to lookup
    # @param certname [String] The node whose context should be used for hiera lookups
    #
    # @return [Boolean] whether or not the service is enabled
    def _service_enabled?(service_type, certname)
      case service_type
      when 'file-sync-client','file-sync-storage'
        file_sync_enabled = hiera_lookup_for_node(certname, 'puppet_enterprise::profile::master::file_sync_enabled') || 'automatic'

        # File sync is forced on if code manager is enabled, so lookup if code manager is enabled
        code_manager_enabled = hiera_lookup_for_node(certname, 'puppet_enterprise::profile::master::code_manager_auto_configure') || false
        if code_manager_enabled || file_sync_enabled == true
          true
        else
          false
        end
      when 'code-manager'
        hiera_lookup_for_node(certname, 'puppet_enterprise::profile::master::code_manager_auto_configure') || false
      when 'orchestrator'
        enabled = hiera_lookup_for_node(certname, 'puppet_enterprise::profile::orchestrator::run_service')
        enabled.nil? ? true : enabled
      else
        true
      end
    end
  end
end
