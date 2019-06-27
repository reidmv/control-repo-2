require 'puppet/util/pidlock'

# This function implements running a block of Bolt code inside an agent lock.
# Because Bolt runs from its own Puppet context, we can't simply use
# Puppet::Agent::Locker, as it will look for the lockfile in the wrong place
# (Puppet[:statedir] points to a tmp directory with Bolt's Puppet context).
# So instead, this mostly copies what Puppet::Agent::Locker does, but specifies
# the location of the agent_catalog_run.lock file used on the system.
#
# The Bolt plan should check the result of this function to determine if the lock
# could be acquired.
Puppet::Functions.create_function(:lock_agent) do
  dispatch :lock do
    block_param 'Callable', :_block
  end

  def lock(&_block)
    lockfile = Puppet::Util::Pidlock.new('/opt/puppetlabs/puppet/cache/state/agent_catalog_run.lock')
    if lockfile.lock
      begin
        yield(lockfile.lock_pid)
      ensure
        lockfile.unlock
      end
    else
      return false
    end

    true
  end
end
