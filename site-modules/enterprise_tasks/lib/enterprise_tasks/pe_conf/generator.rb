require 'json'

# EnterpriseTasks isn't defined elsewhere.
# rubocop:disable Style/ClassAndModuleChildren
module EnterpriseTasks
  module PeConf

    # Build a basic pe.conf file suitable for an initial PE installation.
    #
    # Accepts the basic master, database, puppetdb and console host values,
    # an optional password, and a hash for other parameters to be added directly
    # to the final JSON.
    #
    # Outputs a JSON hash.
    class Generator
      attr_accessor :parameters, :roles, :password, :other_parameters

      def initialize(roles:, password: nil, other_parameters: {})
        @parameters = {}
        raise(ArgumentError, "Expected a roles hash, got '#{roles}'") if !roles.is_a?(Hash)
        @roles = roles
        raise(ArgumentError, "No master role given in #{roles}") if !role?('master')
        @password = password
        @other_parameters = other_parameters
      end

      # @return [Boolean] true if role is not nil.
      def role?(r)
        !get_role(r).nil?
      end

      # Looks up a role from the roles hash as either a string or symbol.
      #
      # @param r [String,Symbol] role to lookup from the @roles hash.
      # @return [String] Return nil or the role value as a string.
      def get_role(r)
        value = roles[r.to_s] || roles[r.to_sym]
        value.nil? ? nil : value.to_s
      end

      # @return [Boolean] true if role is not nil and does not match any of the other roles.
      def unique_role?(role, *other_roles)
        role?(role) && other_roles.none? { |o| get_role(o) == get_role(role) }
      end

      # Generate a hash of pe.conf parameters.
      def pe_conf_hash
        parameters['puppet_enterprise::puppet_master_host'] = get_role('master')
        parameters['puppet_enterprise::database_host'] = get_role('database') if unique_role?('database', 'puppetdb', 'master')
        parameters['puppet_enterprise::puppetdb_host'] = get_role('puppetdb') if unique_role?('puppetdb', 'master')
        parameters['puppet_enterprise::console_host'] = get_role('console') if unique_role?('console', 'master')
        parameters['console_admin_password'] = password if !password.nil?
        parameters.merge!(other_parameters)
      end

      def to_json
        JSON.pretty_generate(pe_conf_hash) + "\n"
      end
    end
  end
end
