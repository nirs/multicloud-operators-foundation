#!/bin/bash

# licensed Materials - Property of IBM
# 5737-E67
# (C) Copyright IBM Corporation 2016, 2019 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit

# Note: this was copied from hack/lib/version.sh and then adapted
# Changes from original:
#   variables renamed:
#     KUBE_*          -> MCM_*
#     kube            -> mcm
#     KUBE_ROOT       -> ROOT
#     KUBE_GO_PACKAGE -> SC_GO_PACKAGE
#  added get_ldflags for use in Makefile

# -----------------------------------------------------------------------------
# Version management helpers.  These functions help to set, save and load the
# following variables:
#
#    MCM_GIT_COMMIT - The git commit id corresponding to this
#          source code.
#    MCM_GIT_TREE_STATE - "clean" indicates no changes since the git commit id
#        "dirty" indicates source code changes after the git commit id
#    MCM_GIT_VERSION - "vX.Y" used to indicate the last release version.
#    MCM_GIT_MAJOR - The major part of the version
#    MCM_GIT_MINOR - The minor component of the version

# Grovels through git to set a set of env variables.
#
# If MCM_GIT_VERSION_FILE, this function will load from that file instead of
# querying git.
mcm_version_get_version_vars() {
  if [[ -n ${MCM_GIT_VERSION_FILE-} ]]; then
    mcm_version_load_version_vars "${MCM_GIT_VERSION_FILE}"
    return
  fi

  local git=(git --work-tree "${ROOT}")

  if [[ -n ${MCM_GIT_COMMIT-} ]] || MCM_GIT_COMMIT=$("${git[@]}" rev-parse "HEAD^{commit}" 2>/dev/null); then
    if [[ -z ${MCM_GIT_TREE_STATE-} ]]; then
        MCM_GIT_TREE_STATE="clean"
    fi

    # Use git describe to find the version based on annotated tags.
    if [[ -n ${MCM_GIT_VERSION-} ]] || MCM_GIT_VERSION=$("${git[@]}" describe --tags --abbrev=14 "${MCM_GIT_COMMIT}^{commit}" 2>/dev/null); then
      # This translates the "git describe" to an actual semver.org
      # compatible semantic version that looks something like this:
      #   v1.1.0-alpha.0.6+84c76d1142ea4d
      #
      # TODO: We continue calling this "git version" because so many
      # downstream consumers are expecting it there.
      DASHES_IN_VERSION=$(echo "${MCM_GIT_VERSION}" | sed "s/[^-]//g")
      if [[ "${DASHES_IN_VERSION}" == "---" ]] ; then
        # We have distance to subversion (v1.1.0-subversion-1-gCommitHash)
        MCM_GIT_VERSION=$(echo "${MCM_GIT_VERSION}" | sed "s/-\([0-9]\{1,\}\)-g\([0-9a-f]\{14\}\)$/.\1\+\2/")
      elif [[ "${DASHES_IN_VERSION}" == "--" ]] ; then
        # We have distance to base tag (v1.1.0-1-gCommitHash)
        MCM_GIT_VERSION=$(echo "${MCM_GIT_VERSION}" | sed "s/-g\([0-9a-f]\{14\}\)$/+\1/")
      fi
      if [[ "${MCM_GIT_TREE_STATE}" == "dirty" ]]; then
        # git describe --dirty only considers changes to existing files, but
        # that is problematic since new untracked .go files affect the build,
        # so use our idea of "dirty" from git status instead.
        MCM_GIT_VERSION+="-dirty"
      fi


      # Try to match the "git describe" output to a regex to try to extract
      # the "major" and "minor" versions and whether this is the exact tagged
      # version or whether the tree is between two tagged versions.
      if [[ "${MCM_GIT_VERSION}" =~ ^v([0-9]+)\.([0-9]+)(\.[0-9]+)?([-].*)?$ ]]; then
        MCM_GIT_MAJOR=${BASH_REMATCH[1]}
        MCM_GIT_MINOR=${BASH_REMATCH[2]}
        if [[ -n "${BASH_REMATCH[4]}" ]]; then
          MCM_GIT_MINOR+="+"
        fi
      fi
    fi
  fi
}

# Saves the environment flags to $1
mcm_version_save_version_vars() {
  local version_file=${1-}
  [[ -n ${version_file} ]] || {
    echo "!!! Internal error.  No file specified in mcm_version_save_version_vars"
    return 1
  }

  cat <<EOF >"${version_file}"
MCM_GIT_COMMIT='${MCM_GIT_COMMIT-}'
MCM_GIT_TREE_STATE='${MCM_GIT_TREE_STATE-}'
MCM_GIT_VERSION='${MCM_GIT_VERSION-}'
MCM_GIT_MAJOR='${MCM_GIT_MAJOR-}'
MCM_GIT_MINOR='${MCM_GIT_MINOR-}'
EOF
}

# Loads up the version variables from file $1
mcm_version_load_version_vars() {
  local version_file=${1-}
  [[ -n ${version_file} ]] || {
    echo "!!! Internal error.  No file specified in mcm_version_load_version_vars"
    return 1
  }

  # shellcheck source=/dev/null
  source "${version_file}"
}

mcm_version_ldflag() {
  local key=${1}
  local val=${2}

  # If you update these, also update the list pkg/version/def.bzl.
  echo "-X ${SC_GO_PACKAGE}/pkg/version.${key}=${val}"
}

# Prints the value that needs to be passed to the -ldflags parameter of go build
# in order to set the Kubernetes based on the git tree status.
# IMPORTANT: if you update any of these, also update the lists in
# pkg/version/def.bzl and hack/print-workspace-status.sh.
mcm_version_ldflags() {
  mcm_version_get_version_vars

  local buildDate=
  [[ -z ${SOURCE_DATE_EPOCH-} ]] || buildDate="--date=@${SOURCE_DATE_EPOCH}"
  
  if [ -z "$buildDate" ]; then
    local -a ldflags=( "$(mcm_version_ldflag "buildDate" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')")" )
  else
    local -a ldflags=( "$(mcm_version_ldflag "buildDate" "$(date "${buildDate}" -u +'%Y-%m-%dT%H:%M:%SZ')")" )
  fi
  if [[ -n ${MCM_GIT_COMMIT-} ]]; then
    ldflags+=( "$(mcm_version_ldflag "gitCommit" "${MCM_GIT_COMMIT}")" )
    ldflags+=( "$(mcm_version_ldflag "gitTreeState" "${MCM_GIT_TREE_STATE}")" )
  fi

  if [[ -n ${MCM_GIT_VERSION-} ]]; then
    ldflags+=( "$(mcm_version_ldflag "gitVersion" "${MCM_GIT_VERSION}")" )
  fi

  if [[ -n ${MCM_GIT_MAJOR-} && -n ${MCM_GIT_MINOR-} ]]; then
    ldflags+=(
      "$(mcm_version_ldflag "gitMajor" "${MCM_GIT_MAJOR}")"
      "$(mcm_version_ldflag "gitMinor" "${MCM_GIT_MINOR}")"
    )
  fi

  # The -ldflags parameter takes a single string, so join the output.
  echo "${ldflags[*]-}"
}

# called from Makefile
mcm_version_get_ldflags() {
  export ROOT=$1
  export SC_GO_PACKAGE=$2
  mcm_version_ldflags
}

mcm_version_get_ldflags "$1" "$2"
