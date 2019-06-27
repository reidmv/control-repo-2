# Generates a platform_tag string (such as `facter -p platform_tag` would
# return, were facter present on the node) for a PE master platform without
# requiring facter and pe-modules facts.
#
# @param osfacts [Hash] Hash of facts returned by the facts plan.
# @return [String] a platform_tag string.
function enterprise_tasks::platform_tag(Hash $osfacts) {
  $os_family = $osfacts['family']
  $os_major  = $osfacts['release']['major']
  case $os_family {
    'RedHat': {
      "el-${os_major}-x86_64"
    }
    'Debian': {
      "ubuntu-${osfacts['release']['full']}-amd64"
    }
    'SLES','Suse': {
      "sles-${os_major}-x86_64"
    }
    default: {
      fail("Unknown os family: ${os_family}")
    }
  }
}
