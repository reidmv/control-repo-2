# Minimal requirements for agent configuration on an infrastructure node.
#
# Basically, just the plain agent profile, and setting up puppet-infrastructure shims.
#
# Allows this configuration to be separated from the act of synchronizing meep in
# pe_infrastructure::infrastructure::sync.
class pe_infrastructure::infrastructure::agent {
  # Needed during fresh meep installs/upgrades when the classifier is not involved
  include pe_infrastructure::agent

  # Ensure that puppet-infrastructure shim is laid down
  include pe_infrastructure::puppet_infra_shims
}
