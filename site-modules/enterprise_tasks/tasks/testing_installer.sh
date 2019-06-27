#! /usr/bin/env bash

set -e

# shellcheck disable=SC2154
pe_dir=$PT_pe_dir

# shellcheck disable=SC2154
pe_conf_file=$PT_pe_conf_file

# shellcheck disable=SC2154
non_interactive=$PT_non_interactive

# shellcheck disable=SC2154
debug_logging=$PT_debug_logging

# shellcheck disable=SC2154
prep_install=$PT_prep_install

args=()

if [ "$non_interactive" == 'true' ]; then
  args+=("-y")
fi

if [ "$debug_logging" == 'true' ]; then
  args+=("-D")
fi

if [ "$prep_install" == 'true' ]; then
  args+=("-p")
fi

if [ -n "$pe_conf_file" ]; then
  args+=("-c" "$pe_conf_file")
fi

validate() {
  if [ ! -d "$pe_dir" ]; then
      RESULT=$(cat <<-END
{
  "_error": {
    "msg": "Unable to find the unpacked PE tarball at '${pe_dir}'.",
    "kind": "enterprise_tasks/testing_installer/no-tarball-dir-error",
    "details": {
      "pe_dir": "${pe_dir}}",
    }
  }
}
END
      )
      SUCCESS=1
  fi
  return ${SUCCESS:=0}
}

install() {
  cd "${pe_dir:?}"

  set +e # Non zero exit from subshells will otherwise cause the task to fail early
  log=$("${pe_dir:?}/puppet-enterprise-installer" "${args[@]}")
  SUCCESS=$?
  puppet_infra_configure=$(echo "${log}" | grep -E '\*.*puppet infrastructure configure')
  last_log_file=$(find /var/log/puppetlabs/installer -name '*.install.log' | sort | tail -n1)
  set -e

  details=$(cat <<-END
{
  "success": "${SUCCESS}",
  "installer_command": "${pe_dir}/puppet-enterprise-installer ${args[@]}",
  "puppet_infra_configure": "${puppet_infra_configure}",
  "last_log_file": "${last_log_file}"
}
END
  )
  if [ "$SUCCESS" == '0' ]; then
    RESULT="${details}"
  else
    RESULT=$(cat <<-END
{
  "_error": {
    "msg": "PE installation failed",
    "kind": "enterprise_tasks/testing_installer/pe-install-error",
    "details": ${details}
  }
}
END
    )
  fi

  return 0
}

if validate; then
  install
fi
echo "${RESULT}"
exit $SUCCESS
