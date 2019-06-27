# Generates a temp directory on each node using enterprise_tasks::tempdirs, and
# records the path in the vars for each node Target so that the calling plan
# and any plans it calls can continue to reference the directory via
# Target.vars()['workdir'].
#
# If a given node already has a 'workdir' variable set, nothing is done for
# that node, so this plan is idempotent and may be called multiple times.
#
# @param purpose [Optional[String]] Optional descriptive string to include in
#   the tempdir name.
plan enterprise_tasks::create_tempdirs(
  TargetSpec $nodes,
  Optional[String] $purpose = undef,
) {
  get_targets($nodes).each |$node| {
    if $node.vars()['workdir'] == undef {
      $tempdirs_result_set = run_task(enterprise_tasks::tempdirs, $node, 'purpose' => $purpose)
      $tempdir = $tempdirs_result_set.find($node.name()).value()['tempdir']
      set_var($node, 'workdir', $tempdir)
    }
  }
}
