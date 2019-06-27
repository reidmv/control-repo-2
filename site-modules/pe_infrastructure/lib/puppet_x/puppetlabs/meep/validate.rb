require 'hocon'

module PuppetX::Puppetlabs::Meep
  class ValidationResult
    attr_accessor :status, :warnings, :errors, :version

    def initialize(status=:unknown, warnings=[], errors=[])
      @status = status
      @warnings = warnings
      @errors = errors
      @version = nil
    end

    def valid?
      @errors.empty?
    end

    # Display all warnings and errors that were found during validation using
    # Puppet.warning to display.
    #
    # @return nil
    def output_warnings
      if @warnings.size > 0
        Puppet.warning "We found that your Puppet Enterprise configuration had the following warnings:"
        @warnings.each do |warning|
          Puppet.warning warning
        end
      end

      if @errors.size > 0
        Puppet.warning "We found that your Puppet Enterprise configuration had the following errors:"
        @errors.each do |error|
          Puppet.warning error
        end
      end
    end
  end

  # Module that provides some helper methods for use in validating a generated
  # or found configuration.
  module Validate
    # Validate a pe.conf.
    #
    # @param [String] conf_path A path to a pe.conf on the local filesystem
    # @param [Hash] opts Options hash, typically provided by the Puppet face.
    # @option [Bool] opts[:is_install] Default: nil
    #   If true, validate that the conf would be suitable for an installation.
    # @option [String] opts[:expected_version] Default: '2.0'
    #   Which MEEP schema version to expect when validating.
    #   Will fail validation if the provided conf does not match this version.
    #   Provide :none if the validator should not enforce a version.
    # @return [ValidationResult] The result of the validation attempt.
    def self.pe_conf(conf_path, opts={})
      is_install = (opts[:is_install] == true)
      expected_version = opts[:expected_version] || '2.0'
      validation_result = ValidationResult.new

      begin
        conf = Hocon.parse(File.open(conf_path).read)
      rescue Errno::ENOENT => not_exist
        validation_result.errors << "Unable to read HOCON config: #{not_exist}"
        return validation_result
      rescue Hocon::ConfigError::ConfigParseError => cpe
        validation_result.errors << "Unable to parse HOCON config: #{cpe}"
        return validation_result
      end

      if conf.has_key?("meep_schema_version")
        # Read schema version so we can determine if it is supported.
        validation_result.version = conf["meep_schema_version"]
      else
        # We assume that if the meep_schema_version is unspecified we are dealing
        # with a MEEP 1.0 config
        validation_result.version = "1.0"
      end
      Puppet.debug("Validating against MEEP #{validation_result.version} schema")

      if expected_version != :none && validation_result.version != expected_version
        validation_result.errors << "#{conf_path} schema version #{validation_result.version} does not match the expected #{expected_version}."
      end

      if validation_result.version == "2.0"
        # 2.0 config shipped with PE Glisan-???
        required_params = [
          "node_roles",
          "agent_platforms",
        ]
        if is_install == true
          required_params << "console_admin_password"
        end
        hosts_to_roles = {}

        if conf.has_key?("node_roles")
          architectures = []

          if conf["node_roles"].is_a?(Hash)
            conf["node_roles"].each_pair do |role, value|
              arch_match = /pe_role\:\:(\w*)\:\:.*/.match(role)
              if arch_match
                architectures << arch_match[1]
                unless ['monolithic', 'split'].include?(arch_match[1])
                  validation_result.errors << "Unknown architecture #{arch_match[1]} was used in role #{role}"
                end
              end

              if value.is_a?(Array)
                value.each do |host|
                  if host.is_a?(String)
                    if host.include?("%{::trusted.certname}")
                      validation_result.errors << "node_roles::#{role} contains %{::trusted.certname}. You must specify a host for this role."
                    else
                      hosts_to_roles[host] ||= []
                      hosts_to_roles[host] << role
                    end
                  else
                    validation_result.errors << "node_roles::#{role} contains #{host}. All hosts must be provided as strings."
                  end
                end
              else
                validation_result.errors << "node_roles::#{role} is not an array. All roles must be arrays."
              end
            end

            architectures = architectures.uniq

            if architectures.length == 1
              architecture = architectures.first
            elsif architectures.length > 1
              validation_result.errors << "Multiple architectures detected in node_roles: #{architectures.join(', ')} Only one architecture is allowed."
            else
              validation_result.errors << "No architecture detected in node_roles. Please add some valid roles to node_roles."
            end

            if architecture
              required_params << {"node_roles" => ["pe_role::#{architecture}::primary_master"]}
              if architecture == 'split'
                required_params << {"node_roles" => ["pe_role::#{architecture}::puppetdb"]}
                required_params << {"node_roles" => ["pe_role::#{architecture}::primary_master"]}
              end
            end
          else
            validation_result.errors << "node_roles is not a hash. node_roles must be a hash."
          end
        end

        if conf.has_key?("agent_platforms")
          if conf["agent_platforms"].is_a?(Array)
            conf["agent_platforms"].each do |platform|
              if !platform.is_a?(String)
                validation_result.errors << "agent_platforms contains #{platform}. All platforms must be provided as strings."
              end
            end
          else
            validation_result.errors << "agent_platforms is not an array. agent_platforms must be an array."
          end
        end

        if conf.has_key?("custom_roles")
          if conf["custom_roles"].is_a?(Hash)
            conf["custom_roles"].each_pair do |role, classes|
              if !role.is_a?(String)
                validation_result.errors << "custom_roles contains #{role}. All roles must be provided as strings."
              end

              if classes.is_a?(Array)
                classes.each do |cls|
                  if !cls.is_a?(String)
                    validation_result.errors << "custom_roles::#{role} contains #{cls}. All classes must be provided as strings."
                  end
                end
              else
                validation_result.errors << "custom_roles contains #{role} that is not an array. All role keys must be an array of strings."
              end
            end
          else
            validation_result.errors << "custom_roles is not a hash. custom_roles must be a hash."
          end
        end

        hosts_with_multiple_roles = hosts_to_roles.select { |host, roles| roles.size > 1 }
        if hosts_with_multiple_roles.size > 0
          validation_result.errors << "Each host can only have one role. We found hosts with multiple roles: #{hosts_with_multiple_roles}"
        end
      elsif validation_result.version == "1.0"
        # 1.0 config shipped with PE ???
        required_params = [
          "puppet_enterprise::puppet_master_host"
        ]

        if is_install == true
          required_params << "console_admin_password"
        end
      else
        required_params = []
        validation_result.errors << "Unknown MEEP version: #{validation_result.version}"
      end

      missing_params, empty_params = missing_or_empty_params_in_conf(required_params, conf)
      validation_result.errors << "Missing required parameters: #{missing_params.join(', ')}" if missing_params.length > 0
      validation_result.errors << "Required parameters are empty: #{empty_params.join(', ')}" if empty_params.length > 0

      return validation_result
    end

    # @private
    # Recursive search of conf hash for missing or empty required parameters
    #
    # @param [Array[String]] params Required parameters to check for in provided conf
    # @param [Hash] conf A config
    # @param [String] namespace Default: nil Namespace to search, used in resursive step.
    # @return [Array, Array] List of missing parameters, list of empty parameters
    def self.missing_or_empty_params_in_conf(params, conf, namespace=nil)
      missing = []
      empty = []

      params.each do |param|
        if param.is_a? Hash
          param.each_pair do |key, value|
            key_ns = "#{key}"
            key_ns = "#{namespace}.#{key_ns}" if namespace
            if conf.has_key?(key)
              found_missing, found_empty = self.missing_or_empty_params_in_conf(value, conf[key], key_ns)
              missing.push(*found_missing)
              empty.push(*found_empty)
            else
              missing.push(key_ns)
            end
          end
        else
          param_ns = "#{param}"
          param_ns = "#{namespace}.#{param_ns}" if namespace
          if !conf.has_key?(param)
            missing.push(param_ns)
          else
            if conf[param].length == 0
              empty.push(param_ns)
            end
          end
        end
      end

      return missing, empty
    end
  end
end
