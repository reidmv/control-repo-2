# If the targets have not already had a +workdir+ variable set (by a plan
# like enterprise_tasks::create_tempdirs, for example, which will generate
# randomized /tmp directories on each node), then a simple default of /root
# will be used.
#
# This is intended for manual testing workflows where various plans are
# called individually and need a static workdir for locating tarballs and
# configuration files for installation.
function enterprise_tasks::set_workdirs(
  TargetSpec $nodes,
  String $default_workdir = '/root',
) {
  get_targets($nodes).each |$node| {
    if $node.vars()['workdir'] == undef {
      set_var($node, 'workdir', $default_workdir)
    }
  }
}
