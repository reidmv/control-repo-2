require 'hocon'
require 'hocon/config_factory'
require 'hocon/parser/config_document_factory'
require 'hocon/config_value_factory'

module PuppetX::Puppetlabs::Meep
  # Provides a separate class for modifying the pe.conf file. Modify
  # does not use Puppet Lookup; or rely on a Config instance. It operates
  # directly on the configuration file via the Hocon library.
  # (See Cacheing below)
  #
  # * {Modify#set_in_pe_conf Modify#set_in_pe_conf(key,value)} sets specified
  #   entry in the pe.conf Object. May nest object keys via 'dot' pathing to
  #   address inner elements of hashes (objects). See the method documentation
  #   for details.
  # * {Modify#set_role Modify#set_role(role, node_array)} conveniently set the
  #   given role to the given array of certs. Adds the role if it does not
  #   exist.
  # * {Modify#add_to_role Modify#add_to_role(role, nodes)} conveniently add
  #   nodes to a role without worrying about duplication. Adds the role if it
  #   does not exist.
  # * {Modify#remove_from_role Modify#remove_from_role(role, nodes)}
  #   conveniently remove nodes from a role without worrying about whether the
  #   role is currently present.
  #
  # Concurrency
  # -----------
  #
  # This library uses File.flock in order to allow two different processes to
  # make atomic changes to pe.conf through our setters without stepping on each
  # other.
  #
  # This makes absolutely no guarantees about any other process arbitrarily
  # writing the file, it is only intended to allow the infrastructure face to
  # coexist with other scripts that use the face, or the Config library
  # directly.
  #
  # Cacheing
  # --------
  #
  # It is important to note that while Modify does not perform any
  # cacheing, the Config class relies on the given scope's Puppet compiler
  # instance to perform Puppet Lookups, and the Lookup implementation does
  # cache the hiera data. Consequently a Config instance only reads the files
  # once, and will not see changes made by a Modify instance after having
  # performed its first lookup.
  class Modify

    # The path to the enterprise hieradata
    attr_reader :enterprise_dir

    # This is a convenience method for obtaining a Modify instance that
    # will operate on the pe.conf that the given Config instance points to.
    #
    # The returned Modify instance retains no references to the passed
    # Config instance. In particular, the Config instance, if it has already
    # performed any lookups, will not see any of the modifications made due
    # to cacheing in the scope.compiler that the Config was initialized with.
    #
    # @param config [PuppetX::Puppetlabs::Meep::Config] the config instance to use
    #   for pathing information to pe.conf.
    # @return [PuppetX::Puppetlabs::Meep::Modify] for the pe.conf pointed to by
    #   the +config+
    def self.create_modifier_for_pe_conf(config)
      new(config.class.meep_config_path)
    end

    # @param path [String] The path to the meep data file to be modified.
    def initialize(enterprise_dir)
      @enterprise_dir = File.expand_path(enterprise_dir)
    end

    def get_in_pe_conf(key)
      pe_conf_mutator._get_in_pe_conf(key)
    end

    # Directly add or update a key, value pair in the local pe.conf
    # file.  This should only be used by other infrastructure faces to
    # adjust pe.conf on the meep master.
    #
    # This method can be used to set root keys, or to set elements within a hash
    # if a compound key is provided:
    #
    #   set_in_pe_conf(
    #     "node_roles",
    #     { "pe_role::monolithic::primary_master" => ["master.net"] }
    #   )
    #
    # for example will replace the node_roles hash entirely. While:
    #
    #   set_in_pe_conf(
    #     '"node_roles"."pe_role::monolithic::primary_master"',
    #     ["master.net"]
    #   )
    #
    # will instead just change the primary_master role's array. (Take note
    # of the quoting in the key...colons are not permitted otherwise...)
    #
    # @param key [String] the name of the pe.conf key.
    # @param value [String,Array,Hash,Numeric,Boolean] the value to assign
    #   to the given key. Must be something that will convert to a valid
    #   JSON type.
    # @return [Boolean] true if successful.
    # @raise [Hocon::ConfigError::ConfigParseError] if pe.conf format is
    #   invalid Hocon.
    # @raise [Puppet::Error] if there is no pe.conf file to work with.
    def set_in_pe_conf(key, value)
      pe_conf_mutator._set_in_pe_conf(key,value)
    end

    # Convenience method to set just one role in the node_roles hash to a
    # given array of node certificates. If the passed role exists it will
    # be reset. If it does not exist, it will be added to the node_roles
    # hash.
    #
    # @param role [String] must match one of the existing default or custom
    #   roles.
    # @param node_array [Array<String>] of node certificates that the role
    #   is to be set to.
    # @return [Boolean] true if successful.
    # @raise [Puppet::Error] if role does not match a default role or cannot
    #   be found in the {Config#custom_roles}, or if node_array is not an array.
    #   (also see {Config#set_in_pe_conf})
    def set_role(role, node_array)
      pe_conf_mutator._set_role(role, node_array)
    end

    # Convenience method to add node certificate or array of certificates to
    # the given role in node_roles. If the role does not exist yet, it will
    # be created and set.
    #
    # New nodes are appended to the end of the existing array.
    # Duplicate nodes are pruned from the array that is to be added,
    # preserving original ordering.
    #
    # @param role [String] must match one of the existing default or custom
    #   roles.
    # @param nodes [String, Array<String>] a node certificate or an array
    #   of node certificates to be added to the role.
    # @return [Boolean] true if successful.
    # @raise [Puppet::Error] if role does not match a default role or cannot
    #   be found in the {Config#custom_roles}.
    #   (also see {Config#set_in_pe_conf})
    def add_to_role(role, nodes)
      pe_conf_mutator._add_to_role(role, nodes)
    end

    # Convenience method to remove node certificate or an array of certificates
    # from the given role in node_roles.
    #
    # There are two potential error conditions related to the role.
    #
    # 1. The role is not one of the default or custom_roles defined.
    #
    # This will raise an error, since you were trying to modify something that
    # shouldn't exist at all.
    #
    # 2. The role is a defined role, but is not declared in node_roles.
    #
    # This will not raise an error, since you were asking to ensure that the node
    # isn't present in that role...and it isn't since the role isn't even present.
    # This could be quibbled, if you were into verbing nouns.
    #
    # @param role [String] must match one of the existing default or custom
    #   roles.
    # @param nodes [String, Array<String>] a node certificate or an array
    #   of node certificates to be removed from the role.
    # @return [Boolean] true if successful
    # @raise [Puppet::Error] if the role does not match a default role or cannot
    #   be found in the {Config#custom_roles}.
    #   (also see {Config#set_in_pe_conf})
    def remove_from_role(role, nodes)
      pe_conf_mutator._remove_from_role(role, nodes)
    end

    private

    def pe_conf_mutator
      SafeMutator.new("#{self.enterprise_dir}/conf.d/pe.conf")
    end

    # This class has the core operations that modify pe.conf, with no
    # concern for locking or concurrency.
    class PeConfMutator
      attr_accessor :conf_file_path

      def initialize(conf_file_path)
        self.conf_file_path = conf_file_path
      end

      def all_roles
        roles = PuppetX::Puppetlabs::Meep::Config.default_roles
        custom_roles = _get_in_pe_conf("custom_roles") || {}
        roles += custom_roles.keys
        roles
      end

      # If the key is unquoted and does not contain pathing ('.'),
      # quote to ensure that puppet namespaces are protected
      #
      # @example
      #   _quoted_hocon_key("puppet_enterprise::database_host")
      #   # => '"puppet_enterprise::database_host"'
      #
      def _quoted_hocon_key(key)
        case key
        when /^[^"][^.]+/
          # if the key is unquoted and does not contain pathing ('.')
          # quote to ensure that puppet namespaces are protected
          # ("puppet_enterprise::database_host" for example...)
          then %Q{"#{key}"}
        else key
        end
      end

      def _get_in_pe_conf(key, default = nil)
        doc = Hocon::ConfigFactory.parse_file(conf_file_path)
        hocon_key = _quoted_hocon_key(key)
        doc.has_path?(hocon_key) ?
          doc.get_value(hocon_key).unwrapped :
          default
      end

      def _set_in_pe_conf(key, value)
        pe_conf = Hocon::Parser::ConfigDocumentFactory.parse_file(conf_file_path)

        hocon_key = _quoted_hocon_key(key)

        hocon_value = case value
        when String
          # ensure unquoted string values are quoted for uniformity
          then value.match(/^[^"]/) ? %Q{"#{value}"} : value
        else Hocon::ConfigValueFactory.from_any_ref(value, nil)
        end

        pe_conf = value.kind_of?(String) ?
          pe_conf.set_value(hocon_key, hocon_value) :
          pe_conf.set_config_value(hocon_key, hocon_value)

        File.open(conf_file_path, 'w') do |fh|
          config_string = pe_conf.render
          fh.puts(config_string)
        end

        return true
      end

      def _set_role(role, node_array)
        raise(Puppet::Error, "Role '#{role}' is not a default role and is not defined in the custom_roles object.") if !(all_roles).include?(role)
        raise(Puppet::Error, "Expected an array of certificate names, but was given '#{node_array}'") if !node_array.kind_of?(Array)

        compound_key = %Q{"node_roles"."#{role}"}
        _set_in_pe_conf(compound_key, node_array)
      end

      def _add_to_role(role, nodes)
        current_array = _get_in_pe_conf("node_roles", {})[role] || []
        new_array = (current_array + Array(nodes)).flatten.compact.uniq

        _set_role(role, new_array)
      end

      def _remove_from_role(role, nodes)
        raise(Puppet::Error, "Role '#{role}' is not a default role and is not defined in the custom_roles object.") if !(all_roles).include?(role)

        current_array = _get_in_pe_conf("node_roles", {})[role]
        role_is_absent = current_array.nil?
        current_array ||= []

        new_array = (current_array - Array(nodes))

        if role_is_absent
          # nothing to do
          result = true
        else
          result = _set_role(role, new_array)
        end

        return result
      end
    end

    # A subclass of Mutator that makes use of flock to ensure that the
    # functions are atomic and can be run concurrently in separate processes.
    #
    # This should allow scripts in PE (autosigning, for example) to run without
    # fear of mangling pe.conf due to simultaneous changes from a command line
    # invocation of `puppet infrastructure provision`.
    #
    # It relies on Puppet::FileSystem.exclusive_open under the hood for locking
    # and timeout behavior.
    #
    # The default timeout implemented in this class is {SafeMutator::TIMEOUT}.
    class SafeMutator < PeConfMutator

      # Default timeout in seconds
      TIMEOUT = 30

      def self.timeout
        @timeout || TIMEOUT
      end

      # This is a convenience for testing.
      def self.timeout=(timeout)
        @timeout = timeout
      end

      def timeout
        self.class.timeout
      end

      def _set_in_pe_conf(key, value)
        _lock_and_set(conf_file_path) do
          super
        end
      end

      def _set_role(role, node_array)
        _lock_and_set(conf_file_path) do
          super
        end
      end

      def _add_to_role(role, nodes)
        _lock_and_set(conf_file_path) do
          super
        end
      end

      def _remove_from_role(role, nodes)
        _lock_and_set(conf_file_path) do
          super
        end
      end

      def locked?
        @locked
      end

      def lock!
        @locked = true
      end

      def unlock!
        @locked = false
      end

      def _lock_and_set(file)
        if locked?
          result = yield
        else
          lock!
          result = nil
          begin
            raise(Puppet::Error, "No pe.conf file found at #{conf_file_path}") unless File.exist?(conf_file_path)

            Puppet::FileSystem.exclusive_open(file, 0600, 'r', timeout) do
              result = yield
              unlock!
            end
          rescue Timeout::Error
            raise(Puppet::Error, "Unable to get a lock on #{file} within #{timeout}s.")
          end
        end

        return result
      end
    end
  end
end
