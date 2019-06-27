# The pe_infrastructure module manages aspects of PE which are common to all nodes in the
# user's fleet that are not being specifically managed by MEEP.  This should be limited
# to management of agents, mcollective, pxp and, for PE infrastructure (as
# opposed to agents) specifically, the minimal synchronization and kickoff of
# MEEP itself.
#
# @param use_meep_for_classification Boolean a temporary feature flag toggling
#   whether to base classification and configuration of off pe.conf
class pe_infrastructure(
  Boolean $use_meep_for_classification = false,
){
}
