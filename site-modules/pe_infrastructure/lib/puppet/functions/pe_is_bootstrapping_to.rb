require 'puppet_x/puppetlabs/meep/config'

# If this catalog is being compiled by an invocation from the
# puppet-enterprise-installer for an initial installation or upgrade on a
# primary node, this function returns a version string.
Puppet::Functions.create_function(:pe_is_bootstrapping_to) do

  # @return [String,Boolean] PE version string we are installing or upgrading to,
  #   or false if this catalog is not being compiled for a bootstrap case. This later
  #   possibility indicates either an agent invoked configuration run, or a manual
  #   invocation of *puppet-infrastructure configure* without the --install flag.
  def pe_is_bootstrapping_to
    PuppetX::Puppetlabs::Meep::Config.get_bootstrap_version || false
  end
end
