# Synchronizes enterprise configuration data and pe-modules.
#
# This class is only included when the agent is preparing to run meep on an
# infrastructure node.
#
# Although it is probably safe to run it generally, since even during
# a meep run, the catalog will have already been compiled.
#
# Same for syncing pe-modules. Although it might be possible to have conflicts
# if the Classifier pe_node_groups provider changed?
#
# Although as current written, the declaration of Package[pe-modules]
# duplicates the pe-modules package resource declared in
# puppet_enterprise::packages.
#
# In the case of a split install/upgrade, including it in the meep run would
# introduce a possible failure case if the master couldn't be reached.
class pe_infrastructure::infrastructure::sync {
  contain pe_infrastructure::enterprise_conf_sync

  $package_options = $::operatingsystem ? {
    # Becuase the default for OracleLinux is up2date...
    'OracleLinux' => {
      provider => 'yum',
    },
    'SLES'        => {
      provider => 'zypper',
    },
    default       => {}
  }

  package { 'pe-modules':
    ensure => latest,
    *      => $package_options,
  }
  Package['pe-modules'] -> Class['Pe_infrastructure::Puppet_infra_shims']
}
