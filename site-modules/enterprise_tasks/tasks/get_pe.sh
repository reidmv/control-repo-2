#! /usr/bin/env bash

set -e

# shellcheck disable=SC2154
platform_tag=$PT_platform_tag
# shellcheck disable=SC2154
pe_version=$PT_version
# shellcheck disable=SC2154
pe_family=$PT_family
# shellcheck disable=SC2154
workdir=${PT_workdir:-/root}

if [ -z "$pe_version" ] && [ -z "$pe_family" ]; then
  echo "Must set either version or family" >&2
  exit 1
fi

cd "$workdir"

if [ -n "$pe_version" ]; then
  pe_family=$(echo "$pe_version" | grep -oE '^[0-9]+\.[0-9]+')
fi

if [[ "$pe_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  release_version='true'
  base_url="http://enterprise.delivery.puppetlabs.net/archives/releases/${pe_version}"
else
  base_url="http://enterprise.delivery.puppetlabs.net/${pe_family}/ci-ready"
fi

if [ -z "$pe_version" ]; then
  pe_version=$(curl "${base_url}/LATEST")
fi

pe_dir="puppet-enterprise-${pe_version}-${platform_tag}"

if [ "$release_version" == 'true' ]; then
  pe_tarball="${pe_dir}.tar.gz"
else
  pe_tarball="${pe_dir}.tar"
fi

pe_tarball_url="${base_url}/${pe_tarball}"

set +e
[ ! -f "${pe_tarball}" ] && wget -nv "${pe_tarball_url}"
wget_code=$?
[ ! -d "${pe_dir}" ] && tar -xf "${pe_tarball}"
tar_code=$?
set -e

if [ "$wget_code" != 0 ] || [ "$tar_code" != 0 ]; then
  echo "{
  \"_error\": {
    \"msg\": \"Failed either to wget or untar the PE tarball from ${pe_tarball_url}\",
    \"kind\": \"enterprise_tasks/get_pe\",
    \"details\": {
      \"wget_exit_code\": \"${wget_code}\",
      \"tar_exit_code\": \"${tar_code}\",
      \"pe_tarball_url\": \"${pe_tarball_url}\",
      \"pe_tarball\": \"${pe_tarball}\",
      \"pe_dir\": \"${pe_dir}\"
    }
  }
}"
  exit 1
fi

echo "{
  \"workdir\":\"${workdir}\",
  \"pe_dir\":\"${workdir}/${pe_dir}\",
  \"pe_tarball\":\"${pe_tarball}\",
  \"pe_tarball_url\":\"${pe_tarball_url}\",
  \"pe_family\":\"${pe_family}\",
  \"pe_version\":\"${pe_version}\"
}"
