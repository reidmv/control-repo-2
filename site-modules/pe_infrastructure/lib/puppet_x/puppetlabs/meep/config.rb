require 'hocon'
require 'hocon/config_factory'
require 'hocon/parser/config_document_factory'
require 'hocon/config_value_factory'

# Extension namespace for Puppet
module PuppetX
  # Under the Puppet organization namespace
  module Puppetlabs

    # Querying MEEP Configuration
    # ---------------------------
    #
    # This extension provides a couple of simple classes for loading and
    # inspecting MEEP configuration data from Puppet functions or applications.
    # This is based off of the Hiera hierarchy specified here:
    # https://github.com/puppetlabs/pe-installer-shim/blob/2016.2.0/conf.d/hiera.yaml
    #
    # The Config class configures a lookup instance to look up MEEP data based
    # on this hiera.yaml.  An instance of Config should be intialized with a
    # scope providing any necessary facts (see {Config}).
    #
    # A few inspection methods are provided:
    #
    # In aggregate:
    #
    # * {Config#list_nodes Config#list_nodes(component)} list of all nodes
    #   configured for a particular PE role.
    # * {Config#is_node_a Config#is_node_a(component, certname)} true if the
    #   given certname is found to have the given component managed on it.  This
    #   function is implemented in terms of {Config#list_nodes}.
    # * {Config#list_all_infrastructure} list all PE infrastructure nodes (any
    #   node listed in node_roles).
    # * {Config#is_infrastructure Config#is_infrastructure(certname)} true if the
    #   given certname ia a PE infrastructure node.
    #
    # The components loosely correspond to terminal roles defined in pe.conf
    # (sans architecture), but also include some core profiles which are not
    # themselves full roles at this time (such as certificate_authority).  This
    # is because we often need to customize configuration on a given node based
    # on whether specific PE services are installed on that or another node.
    #
    # The current definition of components is returned by {Config.pe_components}.
    #
    # * {Config#services_list} lists the certname and port of all the PE
    #   components.
    #
    # * {Config#get_node_profiles} is the list of profiles which should be included
    #   on a node managed by meep.  It takes into account external services such as
    #   postgres or certificate_authority.
    #
    # Per parameter:
    #
    # * {Config#hiera_lookup}(parameter) a very general method for looking up a
    #   parameter in the context of the scope Config was initialized with.
    #
    # * {Config#hiera_lookup_for_node}(certname, parameter) allows changing
    #   context to ::trusted.certname => certname in case there are overrides
    #   or other hiera data in that node file.
    #
    # Modifying MEEP Configuration
    # ----------------------------
    #
    # The {Modify} module provides some additional methods for setting data
    # in the pe.conf file.
    #
    # Known Issues
    # ------------
    #
    # 1) Interpolation in parameters is only as complete as the scope passed to
    # Config.  This shouldn't come up much for pe.conf and family, except that
    # by default a mono install uses '"puppet_enterprise::puppet_master_host" :
    # "%{::trusted.certname}"'
    #
    module Meep

      require 'puppet_x/puppetlabs/meep/config/modify'
      require 'puppet_x/puppetlabs/meep/config/services'
      require 'puppet_x/puppetlabs/meep/defaults'
      require 'puppet_x/puppetlabs/meep/scope'
      require 'puppet_x/puppetlabs/meep/hiera_adapter'

      # Location of MEEP hieradata
      MEEP_CONFIGURATION_PATH = "/etc/puppetlabs/enterprise".freeze

      # Provides a consistent means of accessing and modifying the Hocon Hiera
      # configuration data used by MEEP.  Should be initialized with a scope,
      # which may either be a Puppet::Parser::Scope, or a simple Hash of fact
      # data.  This provides the initial context for Hiera lookups. The
      # critical fact for MEEP is $::trusted.certname.
      #
      # See {Modify} for the API for setting values in pe.conf.
      class Config

        attr_accessor :scope, :hiera

        # Accessor for the current configured path to MEEP hieradata.
        def self.meep_config_path
          @meep_config_path ||= MEEP_CONFIGURATION_PATH.dup
        end

        # This is used during testing to provide local configuration data.
        #
        # @api private
        def self.meep_config_path=(new_path)
          @meep_config_path = new_path
        end

        # This is a flag that `puppet infrastructure configure` can set to
        # indicate that meep is in the process of running. It is state cached
        # in a Config class instance variable so that meep functions can
        # determine whether they are operating in a normal master catalog
        # compilation, or during a local meep apply. Most importantly, this
        # lets us safe guard including the meep kick off class from within the
        # catalog meep is composing, and so avoid getting stuck in meep
        # Inception.
        # @return [True]
        def self.local_meep_run_in_progress!
          @meep_run_in_progress = true
        end

        # True if {Config.local_meep_run_in_progress!} has been called.
        # @return [Boolean]
        def self.is_local_meep_run_in_progress?
          !!@meep_run_in_progress
        end

        # This is a flag that `puppet infrastructure configure` can set to
        # indicate that meep was called by the puppet-enterprise-installer shim.
        # In this case, we are performing a fresh install or upgrade from a PE
        # tarball, which has an impact on repo configurations, and upgrade
        # actions in the compiled catalog.
        #
        # @param pe_version [String] PE version we are installing or upgrading to.
        # @return [True]
        def self.bootstrap_run_in_progress!(pe_version)
          @bootstrap_version = pe_version
          return true
        end

        # @return [String] the PE version set in the
        #   {Config.bootstrap_run_in_progress!} call
        def self.get_bootstrap_version
          @bootstrap_version
        end

        # Provides a Config instance in the context of the local node.
        #
        # Typically the MEEP Config is accessed via Puppet functions during
        # Catalog compilation, in which case fact information is supplied
        # automatically in the scope by the associated compiler.
        #
        # However there are bootstrap cases where we need to access MEEP data
        # within faces, most importantly to provide the list of profile classes
        # via PuppetX::Puppetlabs::Meep::Enterprise node indirection that underlies
        # `puppet infrastructure configure`. But also anywhere else in the
        # infrastructure faces where we may need to query the local Meep data
        # outside of a manifest.
        #
        # If no arguements are given a node/compiler/scope will be derived
        # based on the locally configured Puppet[:certname].
        #
        # Alternately, a pre-constructed node can be passed in.
        #
        # @note This method should never be used within a puppet function. It
        # is only meant to provide a context to faces or other code needing
        # access to MEEP's data outside of the normal compilation process.
        #
        # @param node [Puppet::Node] (Optional) An explicit node instance to
        #   use when creating the compiler and scope for this Config.
        # @return [Config] A Config object initialized with a Puppet::Compiler
        #   constructed from a locally created or passed Puppet::Node.
        # @raise [Puppet::Error] If unable to obtain facts
        def self.local(node = HieraAdapter.get_node)
          new(HieraAdapter.generate_scope(node))
        end

        # List of defined roles in PE (as opposed to custom_roles). These are
        # the defined architectures.
        #
        # @return [Array<String>] All the roles strings that ship in PE.
        def self.default_roles
          Defaults.role_definitions.keys
        end

        # Convenience accessor for the class method
        def default_roles
          self.class.default_roles
        end

        # The types of PE components (primary master, puppetdb, etc.) which
        # can be queried in a {list_nodes} or {is_node_a} calls.
        #
        # Currently these are the keys of {Defaults::COMPONENTS_TO_PROFILES}.
        #
        # @return [Array<String>]
        def self.pe_components
          Defaults::COMPONENTS_TO_PROFILES.keys
        end

        # Convenience accessor for the class method
        def pe_components
          self.class.pe_components
        end

        # @param scope [Puppet::Parser::Scope] used by Hiera during lookups.
        def initialize(scope)
          self.hiera = HieraAdapter.new("#{self.class.meep_config_path}/hiera.yaml")
          self.compilers = {}

          _certname = scope.lookupvar('trusted')['certname']
          self.scope = _scope_for_node(_certname, scope)
        end

        ###################
        # Querying pe.conf

        include PuppetX::Puppetlabs::Meep::Services

        # A list of all nodes configured with a particular component of PE
        # based on the MEEP hieradata.
        #
        # NOTE: There is a stub in place for potentially scraping
        # certificate extention pp_auth_role info from puppetdb.
        #
        # @param component [String] can be any component string returned by {pe_components}
        # @return [Array<String>] Array of nodes providing the component
        # @raise ArgumentError if component is not one of the {pe_components}
        def list_nodes(component)
          component = component.to_s
          raise(ArgumentError, "Undefined component role '#{component}'") if !pe_components.include?(component)

          nodes = list_nodes_set_by_role(component)
          nodes += list_nodes_set_by_certificate(component)

          nodes.uniq
        end

        # True if the given certname provides the services of the given component.
        #
        # @param certname [String]
        def is_node_a(component, certname)
          list_nodes(component).include?(certname)
        end

        # List of all the PE infrastructure being managed by MEEP.
        #
        # @return [Array] The set of all certnames listed in all node_role arrays.
        def list_all_infrastructure
          node_roles.values.flatten.uniq
        end

        # True if the certname is a PE infrastructure node being managed by MEEP.
        #
        # @return [Boolean] true if certname is a member of {list_all_infrastructure}
        def is_infrastructure(certname)
          list_all_infrastructure.include?(certname)
        end

        # PE may be configured to use an external unmanaged Postgres database
        # if the puppet_enterprise::database_host parameter is set to its fqdn.
        #
        # This method checks for that parameter and verifies that it does not
        # match any exiting nodes that might have the database role (monolithic
        # primary_master or split puppetdb, for example).
        #
        # @param certname [String] Optional certname for determining the hiera
        #   context; defaults to using the current scope that Config was
        #   intialized with
        # @return Boolean true if heuristics indicate an unmanaged database
        #   node is configured.
        def has_external_db?(certname = nil)
          parameter = 'puppet_enterprise::database_host'
          roles = [
            'pe_role::monolithic::primary_master',
            'pe_role::split::puppetdb',
          ]

          _has_external?(parameter, roles, certname)
        end

        # PE may be configured to use an external certificate authority if
        # the puppet_enterprise::certificate_authority is set to its fqdn.
        #
        # Checks if the parameter exists, and if it does that it it does not
        # matching an existing node with the certificate_authority profile.
        #
        # @param certname [String] Optional certname for determining the hiera
        #   context; defaults to using the current scope that Config was
        #   intialized with
        # @return Boolean true if heuristics indicate an unmanaged certificate
        #   authority is configured.
        def has_external_ca?(certname = nil)
          parameter = 'puppet_enterprise::certificate_authority_host'
          roles = [
            'pe_role::monolithic::primary_master',
            'pe_role::split::primary_master'
          ]

          _has_external?(parameter, roles, certname)
        end

        # Return the first role found in pe.conf's node_roles hash which includes
        # the passed certname.
        #
        # Having a node assigned to more than one role is an error, and is likely
        # to be non-determinisitic since Hash ordering isn't guaranteed.
        #
        # @param certname [String] of the node to lookup
        # @return [String] the role it has assigned, or nil
        def get_role_for(certname)
          role = node_roles.find { |k,v| v.include?(certname) }
          role[0] if role
        end

        # Returns the list of profiles associated with the passed role.
        # A role may be either default or custom.
        #
        # Default roles are defined in
        # {PuppetX::Puppetlabs::Meep::Defaults::ROLE_DEFINITIONS}
        #
        # Custom roles are defined from the {Config#custom_roles} hash.
        #
        # Custom roles may themselves be composed of default roles, in which case
        # all profiles will be merged and de-duplicated.
        #
        # @param role [String] default or custom role to lookup
        # @return [Array<String>] of profile classes associated with that role
        #   or an empty array if the role is not found
        def get_role_profiles(role)
          role = role.to_s
          profiles = Defaults.role_definitions[role]
          unless profiles
            profiles = (custom_roles[role] || []).map do |entry|
              Defaults.role_definitions[entry] || entry
            end.flatten.uniq
          end
          profiles.dup
        end

        # Returns the list of pe_repo classes to be applied to the master based
        # on what is specified in pe.conf.
        def get_agent_profiles()
          platforms = hiera_lookup('agent_platforms')
          if platforms && ! platforms.empty?
            platforms.map do |platform_tag|
              "pe_repo::platform::#{platform_tag}".gsub(/-/, '_').gsub(/\./, '')
            end
          else
            []
          end
        end

        # Returns the list of profiles which should be included on a node based
        # on the role associated with the passed certname and any other
        # configuration factors which may impact profiles for that node.
        #
        # External database and external ca configurations can cause database
        # and certificate_authority profiles to be dropped from monolithic
        # primary master and split puppetdb nodes for example.
        #
        # This method is essentially a simple ENC based on meep data and
        # configuration.
        #
        # @param certname [String] certname of the node to lookup profiles for
        # @return [Array<String>] of profile classes that should be included on
        #   that node, or an empty array if no role is found for the node.
        def get_node_profiles(certname)
          role = get_role_for(certname)
          profiles = get_role_profiles(role)

          if (default_roles).include?(role)
            profiles.reject! do |r|
              case r
              when "puppet_enterprise::profile::database" then has_external_db?(certname)
              when "puppet_enterprise::profile::certificate_authority" then has_external_ca?(certname)
              else false
              end
            end
          end

          if profiles.include?('puppet_enterprise::profile::primary_master')
            profiles.concat(get_agent_profiles)
          end

          profiles
        end

        # Use Hiera to find the value of the given parameter in the context
        # of the scope that the Config instance was initialized with.
        def hiera_lookup(key)
          hiera.lookup(key, self.scope)
        end

        # Use Hiera to find the value of the given parameter in the context of
        # the given node's certname.
        #
        # @param certname [String] this will be added to the scope of the Hiera
        #   lookup as '::trusted.certname', thereby establishing which node's
        #   file will apply.
        # @param key [String] is the parameter to look for.
        def hiera_lookup_for_node(certname, key)
          hiera.lookup(key,
            _scope_for_node(
              certname
            )
          )
        end

        # Returns the node_roles hash from pe.conf or an empty hash
        # if the entry doesn't exist.
        #
        # @return [Hash<String,Array<String>>] A hash keyed by role string to
        #   an array of node certs
        def node_roles
          hiera_lookup("node_roles") || {}
        end

        # Returns the custom roles hash from pe.conf or an empty hash
        # if the entry doesn't exist.
        #
        # @return [Hash<String,Array<String>>] A hash keyed by a custom role
        #   string to an array of PE module profile classes to be included with
        #   that role
        def custom_roles
          hiera_lookup("custom_roles") || {}
        end

        # Return all default and custom roles defined in this class and pe.conf.
        # @return [Array<String>]
        def all_roles
          default_roles + custom_roles.keys
        end

        private

        attr_accessor :compilers

        # Returns a scope in the context of
        #
        # 1) a new compiler
        # 2) with a trusted.certname injected into the scope.
        # 3) with a trusted.extensions.pp_auth_role injected into the scope.
        #
        # #1 is necessary to ensure that any compiler caches from the scope
        # that a Config was initialized with do not interfere with the new
        # lookup path in nodes/%{::trusted.certname}. Notably so that
        # @scope_interpolations have been cleared:
        # https://github.com/puppetlabs/puppet/blob/4.10.x/lib/puppet/pops/lookup/hiera_config.rb#L17
        #
        # #2 is necessary so that a trusted.certname value is overridden in
        # the new scope and is available for interpolation. Because we don't
        # have a good means (short of hitting puppetdb) to get the actual facts
        # for the node.
        #
        # #3 is necessary so that a trusted.extensions.pp_auth_role value is
        # overridden in the new scope and is available for interpolation.
        # Again, we don't have the facts for the node, and not every node will
        # have pp_auth_role set in its certificate extensions anyway, but we 
        # need this value in order to traverse the roles hierarchy layer.
        #
        # TODO if we reverse our lookup interaction such that lookup relies on
        # a backend in this library to perform the hierarchy traversal, rather
        # than our having to overload a scope with info needed by hiera to traverse
        # the hierarchy when we request a lookup from it, then we would not
        # need to generate these scopes or track compiler instances.
        #
        # @param certname [String] the node to add to the trusted hash.
        # @return [PuppetX::Puppetlabs::Meep::Scope]
        def _scope_for_node(_certname, _scope = nil)
          if _scope.nil?
            compiler = _fetch_compiler(_certname)
            _scope = compiler.topscope
          end

          _node_roles = self.hiera.lookup('node_roles', _scope) || {}
          _role_entry = _node_roles.find { |k,v| v.include?(_certname) }
          _role = _role_entry.nil? ? '' : _role_entry[0]

          PuppetX::Puppetlabs::Meep::Scope.new(_scope).merge({
            "trusted" => {
              "certname" => _certname,
              "extensions" => {
                "pp_auth_role" => _role,
              },
            }
          })
        end

        # Fetches from and maintains an instance cache of compilers
        # keyed by certname. There is no need to recreate a new compiler if you
        # are just looking up parameters for the same node.
        #
        # @param certname [String] the node's cert.
        # @return [Puppet::Parser::Compiler] built around that node.
        def _fetch_compiler(certname)
          unless compilers.include?(certname)
            current_compiler = scope.compiler
            env = current_compiler.environment
            node = Puppet::Node.new(certname, :environment => env)
            compilers[certname] = Puppet::Parser::Compiler.new(node)
          end
          compilers[certname]
        end

        def _has_external?(parameter, roles, certname = nil)
          host = certname.nil? ?
            hiera_lookup(parameter) :
            hiera_lookup_for_node(certname, parameter)

          nodes = roles.map { |r| node_roles[r] }.flatten.uniq.compact

          # parameter for an external service host has been set, and not to a
          # node that is in one of the roles which would include a profile for
          # managing that service. (So, not internally managed by PE)
          if !host.nil? && !host.empty? && !nodes.include?(host)
            true
          else
            false
          end
        end

        # Return a list of nodes providing the passed component based on the
        # roles set in pe.conf's node_roles hash, and the profiles these roles
        # provide.
        #
        # Since this method is the heart of all list_nodes() and is_node_a() call,
        # and since pe.conf is
        def list_nodes_set_by_role(component)
          node_list = []
          profile = Defaults::COMPONENTS_TO_PROFILES[component]

          node_roles.each do |role,nodes|
            # The primary master replica has a number of profiles which are not
            # active as components, it needs to be thought of as simply a
            # replica
            next if role == 'pe_role::monolithic::primary_master_replica' && !['primary_master_replica', 'enabled_primary_master_replica'].include?(component)

            # If the default role is relevant
            if get_role_profiles(role).include?(profile)
              nodes.each do |node|
                # Add the node if the profiles for that node include the component profile
                # (this takes into account has_external_db/ca)
                node_list << node if get_node_profiles(node).include?(profile)
              end
            end
          end

          if component == 'enabled_primary_master_replica'
            # Filter just for enabled replicas
            enabled = hiera_lookup("puppet_enterprise::ha_enabled_replicas") || []
            node_list = node_list & enabled
          end

          node_list
        end

        # Return a list of nodes providing the passed component based on a
        # lookup of nodes with certificate extensions providing pp_auth_role
        # matching role::<arch>::<component> classes.
        def list_nodes_set_by_certificate(component)
          []
        end
      end
    end
  end
end
