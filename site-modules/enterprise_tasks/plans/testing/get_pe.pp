# Downloads and unpacks a PE tarball for the appropriate platform onto each of the nodes.
# Requires internal puppet CD resources.
#
# Sets the 'pe_dir' variable on each target in the $nodes array so that subsequent
# plans know what to install. The pe_dir value is the absolute path to the unpacked
# PE tarball that was uploaded to the node.
#
# @param nodes [TargetSpec] list of nodes to download PE to.
# @param version [Optional[Variant[Enterprise_tasks::Pe_family,Enterprise_tasks::Pe_version]]]
#   a version string indicating either the family line (2019.1, 2019.2, etc.)
#   or an exact version of PE to download. If just the family is given, the
#   latest development build from that line will be downloaded.
# @param tarball [Optional[Enterprise_tasks::Absolute_path]] Optionally an
#   absolute path to the a PE tarball to upload from the localhost. If this is
#   set, then version is ignored.
# @return Array[Result] of the results returned by the get_pe task for each node.
plan enterprise_tasks::testing::get_pe(
  TargetSpec $nodes,
  Optional[Variant[Enterprise_tasks::Pe_family,Enterprise_tasks::Pe_version]] $version = undef,
  Optional[Enterprise_tasks::Absolute_path] $tarball = undef,
) {

  # If we don't have a workdir set on our nodes, set it to /root.
  enterprise_tasks::set_workdirs($nodes)

  if $tarball {
    if $version != undef {
      warning("The tarball parameter is set to '${tarball}'; ignoring version '${version}'.")
    }

    return get_targets($nodes).map |$node| {
      $workdir = $node.vars()['workdir']
      $tarball_name = $tarball.split('/')[-1]
      $dirname = regsubst($tarball_name, /(?:.tar|.tar.gz|.tgz)$/, '')
      $pe_dir  = "${workdir}/${dirname}"

      upload_file($tarball, "${workdir}/${tarball_name}", $node)
      run_command("tar -C ${workdir} -xf ${workdir}/${tarball_name}", $node)

      set_var($node, 'pe_dir', $pe_dir)

      $_result = {
        'workdir'    => $workdir,
        'pe_dir'     => "${workdir}/${dirname}",
        'pe_tarball' => "${workdir}/${tarball_name}",
      }
    }
  } else {
    if $version == undef {
      fail_plan("If you do not supply 'tarball', then you must supply the 'version'.")
    }

    run_plan(facts, nodes => $nodes)

    case $version {
      Enterprise_tasks::Pe_family: {
        $ci_ready_url = "http://enterprise.delivery.puppetlabs.net/${version}/ci-ready"
        $curl_of_latest_result = run_command("curl ${ci_ready_url}/LATEST", 'localhost').first()
        $_pe_version = $curl_of_latest_result.value()['stdout'][0,-2]
      }
      default: {
        $_pe_version = $version
      }
    }
    enterprise_tasks::message('get_pe', "Uploading tarball for PE version: '${_pe_version}'.")

    # Return an Array of the Results returned by run_task for the get_pe task.
    return get_targets($nodes).map |$node| {
      debug("node: ${node} ${node.facts}")

      $platform_tag = enterprise_tasks::platform_tag($node.facts['os'])
      debug("platform_tag ${platform_tag}")

      $result = run_task(enterprise_tasks::get_pe, $node,
        'platform_tag' => $platform_tag,
        'version' => $_pe_version,
        'workdir' => $node.vars()['workdir'],
      ).first()

      set_var($node, 'pe_dir', $result.value()['pe_dir'])

      $result
    }
  }
}
