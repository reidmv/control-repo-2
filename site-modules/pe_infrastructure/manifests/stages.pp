# The only use for this stage is to isolate the run of meep on an
# infrastructure node so that it occurs after everything else in the main stage
# has completed.
#
# Stages have a number of limitations (see
# https://docs.puppet.com/puppet/latest/reference/lang_run_stages.html#limitations-and-known-issues)
# and should not be used generally.
class pe_infrastructure::stages {
  stage { 'pe_meep':
    require => Stage['main'],
  }
}
