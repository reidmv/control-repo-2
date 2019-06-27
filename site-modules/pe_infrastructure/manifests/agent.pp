# This class is the new agent profile class for PE.
class pe_infrastructure::agent {

  # Including this class is temporary until the agent and repo classes move
  # from puppet_enterprise into pe_infrastructure (PE-16734)
  include puppet_enterprise::profile::agent
}
