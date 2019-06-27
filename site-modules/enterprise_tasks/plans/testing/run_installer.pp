# Run the puppet-enterprise-installer for the passed version of PE on the given
# nodes.
#
# Assumes that a 'workdir' variable has been set for each node; if not
# will default to /root.
#
# Will lookup a 'workdir' and a 'pe_dir' variable for each node.
#
# If there is no 'pe_dir' set, a pe_version must have been passed, and the
# plan will construct from it the dirname of an unpacked PE tarball it expects
# to find in the 'workdir' of each node.
#
# Also assumes that an appropriate pe.conf file is present in the 'workdir'.
#
# If the installer fails, will lookup the installer log and output it along with
# a summary of errors or warnings.
#
# @param $nodes [TargetSpec] nodes to run the installer on.
# @param $pe_version [Optional[Enterprise_tasks::Pe_version]] full PE version.
#   If the targets do not have 'pe_dir' set, then this, plus the target's
#   platform_tag will be be used to generate a pe_dir value in the target's
#   'workdir'.
# @param $non_interactive [Boolean] if true, run the installer with -y
#   'non-interactive' flag. Mostly useful for upgrades.
# @param $debug_logging [Boolean] if true, run the installer with the -p flag.
#   'prep' sets up repo config and installs the base packages needed for the installer
#   but does not install PE.
# @param $skip_pe_conf [Boolean] if true, do not pass a file to be used with the -c flag.
#   Important for upgrades, when the installer should typically use the
#   existing /etc/puppetlabs/enterprise data..
plan enterprise_tasks::testing::run_installer(
  TargetSpec $nodes,
  Optional[Enterprise_tasks::Pe_version] $pe_version = undef,
  Boolean $non_interactive = false,
  Boolean $debug_logging = false,
  Boolean $prep_install = false,
  Boolean $skip_pe_conf = false,
) {
  # Set workdir if not already set
  enterprise_tasks::set_workdirs($nodes)

  get_targets($nodes).each |$node| {
    $workdir = $node.vars()['workdir']
    $_pe_dir  = $node.vars()['pe_dir']
    $pe_dir = case $_pe_dir {
      Undef: {
        if empty($pe_version) {
          fail_plan("${node} has no 'pe_dir' variable set and no pe_version ('${pe_version}') was passed.")
        }
        run_plan('facts', $node)
        $platform_tag = enterprise_tasks::platform_tag($node.facts()['os'])
        "${workdir}/puppet-enterprise-${pe_version}-${platform_tag}"
      }
      default: { $_pe_dir }
    }

    $installer_args = {
      'pe_dir'          => $pe_dir,
      'non_interactive' => $non_interactive,
      'debug_logging'   => $debug_logging,
      'prep_install'    => $prep_install,
      '_catch_errors'   => true,
    }
    $pe_conf_arg = $skip_pe_conf ? {
      true  => {},
      false => {
        'pe_conf_file'    => "${workdir}/pe.conf",
      },
    }
    $result = run_task('enterprise_tasks::testing_installer', $node,
      $installer_args + $pe_conf_arg
    ).first()

    if !$result.ok() {
      $error = $result.error()
      if $error =~ Error['enterprise_tasks/testing_installer/pe-install-error'] {
        $log_file = $error.details()['last_log_file']
        $cat_result = run_command("cat ${log_file}", $node).first()
        $log = $cat_result.value()['stdout']
        $log_lines = $log.split("\n")
        $errors = $log_lines.filter |$l| { $l =~ /\[Error\]|Error:/ }
        if !empty($errors) {
          $log_details = {
            'errors' => $errors,
          }
        } else {
          $log_details = {
            'warnings' => $log_lines.filter |$l| { $l =~ /Warning/ },
          }
        }
        notice("Failed puppet-enterprise-installer log:\n${log}")
        out::message("Failed puppet-enterprise-installer log:\n${log}")
        fail_plan($error.msg(), $error.kind(), $error.details() + $log_details)
      }
      fail_plan($error)
    }
  }
}
