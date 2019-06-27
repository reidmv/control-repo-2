require 'puppet_x/puppetlabs/meep/config'

module PuppetX
  module Puppetlabs
    module Meep
      class MeepLookupAdapter < Puppet::Pops::Lookup::LookupAdapter
        def initialize(compiler)
          super
        end
      end

      # Data implementation accesses MEEP hieradata through Hiera.
      #
      # Hiera can only consider the MEEP hieradata in the context of a
      # particular node because of how the hierarchy is constructed.  The
      # presence of nodes/%{::trusted.certname}.conf files in the hierarchy
      # requires that any lookup have ::trusted.certname in its scope.
      #
      # This also means that %{::trusted.certname} cannot be used as a
      # convience in pe.conf in any configuration other than an isolated
      # monolithic master with no other pe infrastructure nodes. Otherwise
      # the master role would be applied to every node in turn.
      class HieraAdapter
        attr_accessor :config_path

        def initialize(config_path)
          @config_path = File.absolute_path(config_path)
          unless File.exist?(@config_path)
            msg = "Puppet Enterprise was not able to find its configuration data at '#{@config_path}'"
            raise RuntimeError, msg if PuppetX::Puppetlabs::Meep::Config.is_local_meep_run_in_progress?
            Puppet.warning(msg)
          end
        end

        # A lookup call requires both the parameter key and a Puppet::Parser::Scope.
        #
        # @param key [String] is the parameter to lookup.
        # @param scope [Puppet::Parser::Scope] A valid scope from a properly constructed
        #   Puppet::Compiler
        def lookup(key, scope)
          compiler = scope.compiler
          _override_loaders(compiler) do
            MeepLookupAdapter.adapt(compiler) do |adapter|
              adapter.set_global_hiera_config_path(config_path)
            end

            invocation = Puppet::Pops::Lookup::Invocation.new(
                scope, Puppet::Pops::EMPTY_HASH, Puppet::Pops::EMPTY_HASH, true, MeepLookupAdapter)
            Puppet::Pops::Lookup.lookup(key, nil, nil, true, nil, invocation)
          end
        end

        ###### Class methods ##################################################
        ### Helpers for generating a node scope for lookups
        #######################################################################

        # Make a new Puppet::Node object based on the passed node_name and environment
        #
        # @param [String] A certname for a node to create (defaults to Puppet[:certname])
        # @param [String] An environment to use for the node (defaults to Puppet.lookup(:current_environment))
        # @param [String] The node terminus currently configured for the master run mode
        # @param [Puppet::Node::Facts] A valid facts object to pre-populate the node
        # @return [Puppet::Node] A node instance corresponding to the node_name and environment
        #     passed in to be used for hiera lookups
        def self.get_node(node_name = Puppet[:certname], environment = Puppet.lookup(:current_environment), node_terminus = nil, facts = nil)
          # If they are using the classifier, we need to turn it on here
          # so that data bindings will work correctly
          if node_terminus
            old_terminus = Puppet.settings[:node_terminus]
            Puppet::Node.indirection.reset_terminus_class
            Puppet.settings[:node_terminus] = node_terminus
          end

          node = Puppet::Node.indirection.find(node_name, :environment => environment, :facts => facts)
          # This node may later be used in get_scope() to compile a catalog and yield the compiler scope.
          # We don't actually want that throw away catalog to waste time
          # evaluating resources, generate log messages, etc.
          node.classes = []
          return node
        ensure
          if !old_terminus.nil?
            Puppet.settings[:node_terminus] = old_terminus
            Puppet::Node.indirection.reset_terminus_class
          end
        end

        # Create a Puppet::Parser::Scope object for use in lookups
        # given a Puppet::Node object
        #
        # @param node [Puppet::Node] An explicit node instance to
        #   use when creating the compiler and scope
        # @return scope [Puppet::Parser::Scope] A scope to be used during lookups
        def self.generate_scope(node)
          compiler = nil
          # Because of how trusted facts are implemented, we have to override
          # the trusted_information lookup in Puppet to return a local
          # TrustedInformation instance.
          Puppet.override({:trusted_information => Puppet::Context::TrustedInformation.local(node)}) do
            compiler = Puppet::Parser::Compiler.new(node)
          end

          # We compile the empty catalog to give the node a real scope
          if block_given?
            original_code = Puppet[:code]
            begin
              Puppet[:code] = 'undef'
              compiler.compile { |catalog| yield(compiler.topscope); catalog }
            ensure
              Puppet[:code] = original_code
            end
          else
            # Normally this would be called during the compile, but since we are
            # just using a compiler to provide a scope, we have to call it here.
            # https://github.com/puppetlabs/puppet/blob/5.3.0/lib/puppet/parser/compiler.rb#L157
            compiler.send(:set_node_parameters)
            compiler.topscope
          end
        end

        private

        def _override_loaders(compiler, &block)
          context_loaders = Puppet.lookup(:loaders) { nil }
          if !context_loaders.equal?(compiler.loaders)
            Puppet.override({:loaders => compiler.loaders}, "MEEP HieraAdapter setting local loader context for #{compiler.node.name}") do
              yield
            end
          else
            yield
          end
        end
      end
    end
  end
end

