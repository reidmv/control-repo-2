# Responsible for bootstrapping the execution of meep on an agent node which
# has been classified as infrastructure.
#
# IMPORTANT: This class should never be included, directly or indirectly, among
# the classes which meep itself determines a node needs (via
# {Config#get_node_profiles}). Otherwise meep will kick off a meep run
# recursively, with predictably poor results...
#
# It should only be present in the Classifier's PE Agent node group to ensure
# that meep is kicked off on infrastructure nodes at the tail end of the puppet
# agent run.
#
# See pe_infrastructure/stages.pp for a discussion of why stages are being
# used.
#
# @param timeout [Integer] amount of time that `puppet-infrastructure configure`
#   should be allowed to complete configuration on a PE infrastructure node, in
#   seconds. Defaults to 600.
class pe_infrastructure::agent::meep(
  Integer $timeout = 600,
) {
  if (pe_is_infrastructure()) {

    # Including this class is temporary until the agent and repo classes move
    # from puppet_enterprise into pe_infrastructure (PE-16734)
    include puppet_enterprise::repo

    # This is the boostrap case, from an agent node to an infrastructure node
    # need to sync data, pe-modules, prepare to run puppet-infrastructure
    include pe_infrastructure::infrastructure

    include pe_infrastructure::stages

    class { pe_infrastructure::agent::meep::run:
      stage   => 'pe_meep',
      timeout => $timeout,
    }
  }
}
