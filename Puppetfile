def default_branch(default)
  match = /(.+)_(cdpe|cdpe_ia)_\d+$/.match(@librarian.environment.name)
  match ? match[1]:default
rescue
  default
end

forge 'https://forge.puppet.com'

# Modules from the Puppet Forge
# Versions should be updated to be the latest at the time you start
#mod 'puppetlabs/inifile',     '2.2.1'
#mod 'puppetlabs/stdlib',      '4.25.1'
#mod 'puppetlabs/concat',      '4.2.1'

# Modules from Git
# Examples: https://github.com/puppetlabs/r10k/blob/master/doc/puppetfile.mkd#examples
#mod 'apache',
#  :git    => 'https://github.com/puppetlabs/puppetlabs-apache',
#  :commit => 'de290646f97e04b4b8e42c70f6e01e860c394ce7'

#mod 'apache',
#  :git    => 'https://github.com/puppetlabs/puppetlabs-apache',
#  :branch => 'docs_experiment'
mod 'puppetlabs-ruby_task_helper', '0.3.0'
mod 'puppetlabs-bolt_shim', '0.3.0'
mod 'puppetlabs-apply_helpers', '0.1.0'
mod 'puppetlabs-stdlib', '6.1.0'
mod 'WhatsARanjit-node_manager', '0.7.2'
mod 'puppet-cassandra', '2.7.3'
mod 'puppetlabs-firewall', '2.1.0'
mod 'puppetlabs-inifile', '4.0.0'


mod 'reidmv-fail_fast',
  :git => 'file:///Users/reidmv/src/reidmv-fail_fast/.git',
  :branch => :control_branch, :default_branch => 'master'

mod 'reidmv-pe_ha_failover',
  :git => 'https://github.com/reidmv/reidmv-pe_ha_failover.git',
  :branch => :control_branch, :default_branch => 'master'

