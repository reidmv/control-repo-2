class MeepScope < Hash

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

  def compiler
    @parent_scope.compiler
  end
end
