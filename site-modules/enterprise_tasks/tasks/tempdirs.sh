#! /usr/bin/env bash

set -e

# shellcheck disable=SC2154
purpose=$PT_purpose

timestamp=$(date +%Y%m%d%H%M%S)
template_elements=('pe' $purpose $timestamp 'XXXXXXXXXX')
template="${template_elements[*]}"
template="${template// /.}"

tempdir=$(mktemp -t -d "${template}")
chmod 700 "${tempdir}"

result=$(cat <<-END
{
  "tempdir": "${tempdir}"
}
END
)

echo "${result}"
