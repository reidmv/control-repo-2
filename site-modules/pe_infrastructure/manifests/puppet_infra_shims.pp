# Class: pe_infrastructure::puppet_infra_shims
# ===========================
#
# Ensures that the node is configured to be able to run the puppet
# infrastructure face. In practice, this means laying down a link to a
# puppet-infrastructure external subcommand in /opt/puppetlabs/bin (which
# puppet-agent places in the shell PATH).
#
# This shim execs the puppet infrastructure face with --environmentpath set to
# the /opt/puppetlabs/server/data/environments and the --environment set to
# 'enterprise' so that the face can be found without manually specifying the
# --modulepath on the commandline.
#
# Parameters
# ----------
#
# None.
class pe_infrastructure::puppet_infra_shims {
  $bindir         = '/opt/puppetlabs/bin'
  $appsdir        = '/opt/puppetlabs/server/apps'
  $appdir         = "${appsdir}/enterprise"
  $appbindir      = "${appdir}/bin"

  file { [$appdir, $appbindir]:
    ensure => directory,
    mode   => '0755',
  }

  ['puppet-infra', 'puppet-infrastructure'].each |String $shim| {
    $appbindir_shim = "${appbindir}/${shim}"
    $bindir_link    = "${bindir}/${shim}"

    file { $appbindir_shim:
      ensure => file,
      mode   => '0700',
      source => 'puppet:///modules/pe_infrastructure/puppet-infrastructure',
    } ->
    file { $bindir_link:
      ensure => link,
      target => $appbindir_shim,
    }
  }
}
