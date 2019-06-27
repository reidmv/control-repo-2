module PuppetX::Puppetlabs::Meep
  # A hash that handles stripping the root '::' namespace from scope lookup
  # requests (for facts) for hiera so that it can find both 'somekey' and
  # '::somekey'.
  #
  # For the purposes of a hiera lookup, this class is functionally equivalent
  # to a Puppet::Parser::Scope, since hiera just treats the scope as a Hash.
  #
  # A Puppet::Parser::Scope strips this internally during it's own lookup process:
  # https://github.com/puppetlabs/puppet/blob/4.8.1/lib/puppet/parser/scope.rb#L290
  class Scope < Hash
    def initialize(parent_scope)
      @parent_scope = parent_scope
    end

    def merge!(o)
      o.each_pair { |k, v| self[k] = v }
      self
    end

    def [](k)
      mk = munch_key(k)
      key?(mk) ? super(mk) : @parent_scope[k]
    end

    def exist?(k)
      mk = munch_key(k)
      key?(mk) || @parent_scope.exist?(k)
    end

    def include?(k)
      mk = munch_key(k)
      !self[mk].nil? || @parent_scope.include?(k)
    end

    def lookupvar(k, options = {})
      mk = munch_key(k)
      key?(mk) ? self[mk] : @parent_scope.lookupvar(k, options)
    end

    def munch_key(k)
      k = k[2..-1] if k.start_with?('::') && !key?(k)
      k
    end

    def to_hash
      @parent_scope.to_hash.merge(super)
    end

    def compiler
      @parent_scope.compiler
    end
  end
end
