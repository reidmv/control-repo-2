# This is an internal class of the pe_infrastructure module. It exists solely
# so that the pe_infrastructure::agent::meep class can declare it in the
# pe_meep stage. This allows the pe_infrastructure::agent::meep class to be
# included idempotently in the Classifier while still ensuring that meep is
# executed in the correct stage.
#
# It should never be included by any other class.
#
# @param timeout [Integer] amount of time the `puppet-infrastructure configure`
#   should be allowed to complete configuration on a PE infrastructure node, in
#   seconds.
class pe_infrastructure::agent::meep::run (
  Integer $timeout,
) {
  if !pe_meep_is_executing() {
    exec { 'execute meep':
      command   => '/opt/puppetlabs/bin/puppet-infrastructure configure --no-recover --agent-pid=$PPID --detailed-exitcodes',
      returns   => [0,2],
      timeout   => $timeout,
      logoutput => true,
      loglevel  => notice,
    }
  }
}
