require 'puppet_x/puppetlabs/meep/config'

# True if the MEEP tool is the one compiling this catalog for its own apply.
# The opposite case would be puppetserver compiling a normal agent catalog.
Puppet::Functions.create_function(:pe_meep_is_executing) do

  # @return [Boolean] true if MEEP is driving the compiler.
  def pe_meep_is_executing
    PuppetX::Puppetlabs::Meep::Config.is_local_meep_run_in_progress?
  end
end
