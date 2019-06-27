# Recover configuration on the master and then synchronize the master's enterprise data
# to all other primary infrastructure nodes.
#
# Synchronizing is only relevent if +infrastructure+ contains more than +master+.
#
# @param $master [TargetSpec] the master node.
# @param $infrastructure [TargetSpec] all infrastructure nodes (master will be
#   filtered from it).
plan enterprise_tasks::sync_enterprise_data(
  TargetSpec $master,
  TargetSpec $infrastructure,
) {
  $master_target = get_targets($master)[0]
  $remaining_infrastructure_targets = get_targets($infrastructure) - $master_target

  enterprise_tasks::message('sync_enterprise_data', 'Running puppet infra recover_configuration on master node.')
  run_task(enterprise_tasks::run_pe_infra_recover_configure, $master)

  if !empty($remaining_infrastructure_targets) {
    enterprise_tasks::message('sync_enterprise_data', 'Retrieving enterprise data from master node.')
    $results = run_task('enterprise_tasks::get_enterprise_data',  $master)
    $enterprise_data = $results.first()['enterprise_data']
    $user_data_conf = $enterprise_data
    $etc_puppetlabs_dir = '/etc/puppetlabs'

    enterprise_tasks::message('sync_enterprise_data', 'Pushing enterprise data onto remaining infrastructure nodes.')
    get_targets($remaining_infrastructure_targets).each |$node| {
      apply($node) {
        $common = {
          owner => 'root',
          group => 'root',
          mode  => '0600',
        }

        file { $etc_puppetlabs_dir:
          ensure => 'directory',
          *      => $common + {
            mode   => '0755',
          }
        }

        file { [
          "${etc_puppetlabs_dir}/enterprise",
          "${etc_puppetlabs_dir}/enterprise/conf.d",
          "${etc_puppetlabs_dir}/enterprise/conf.d/nodes",
        ]:
          ensure => 'directory',
          *      => $common,
        }

        $user_data_conf.each |$name,$contents| {
          file { $name:
            ensure  => 'present',
            content => Sensitive($contents),
            *       => $common,
          }
        }
      }
    }
  }
}
