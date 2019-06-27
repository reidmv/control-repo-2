# For infrastructure nodes (primary masters, compile masters, replicas, etc.)
# this class manages those aspects of configuration that are still being
# managed by the routine agent runs (as opposed to the puppet-infrastructure
# command itself).
#
# This boils down to:
#
# * synchronizing the /etc/puppetlabs/enterprise data
# * ensuring that the pe-modules package is installed
# * ensuring that there is a puppet-infrastructure shim link so we can execute
#   `puppet-infrastructure configure`
class pe_infrastructure::infrastructure {
  include pe_infrastructure::infrastructure::agent
  include pe_infrastructure::infrastructure::sync
}
