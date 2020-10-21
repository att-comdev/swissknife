#!/bin/bash
set -eu
set -Eo pipefail

# This script installs apt packages by using a file with newline delimited list of packages as input
# bash-style comments (begin with #) are allowed in the input file
#
# Environment Variables:
#   - APT_DEPENDENCIES_INPUT -path to the location of input file [optional] [defaults to ./apt-dependencies.txt]
#
#
#

input_file=${APT_DEPENDENCIES_INPUT:-"./apt-dependencies.txt"}
err=()

if [ ! -f "${input_file}" ]; then
    echo "File ${input_file} not found!"
    exit 1
fi

# Checking for  Newline at the end of the apt-dependencies.txt
if [ -z "$(tail -c 1 "${input_file}")" ]; then
    echo "Found Newline at end of ${input_file} file, you are ready to go forward!"
else
    echo "No newline at end of ${input_file} file!"
    exit 1
fi

# remove comments and spaces and normalize for apt cli
IFS=" " read -r -a packages <<< "$(sed '/^[[:blank:]]*#/d;s/#.*//;s/ //g' "$input_file" | tr '\r\n' ' ')"

export DEBIAN_FRONTEND=noninteractive
APT_UPDATE_RUN=false
for REQUIRED_PKG in "${packages[@]}"
do
  # Check if package is already installed and if not, install the required package
  if [ "$(dpkg-query -W -f='${Status}' "$REQUIRED_PKG" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then

    echo "$REQUIRED_PKG not installed. Setting up $REQUIRED_PKG."
    # Check if user is root to install the dependencies else exit with error message
    if [[ $(id -u) -ne 0 ]]; then
        echo "This script must be run as root to install ${REQUIRED_PKG}. Script ending" >&2
        exit 1
    fi
    # Check if apt update has already been run
    if [ "$APT_UPDATE_RUN" = false ] ; then
      apt update
      APT_UPDATE_RUN=true
    fi
    if ! apt -y install --no-install-recommends "$REQUIRED_PKG" ; then
      err+=("$REQUIRED_PKG")
    fi
  else
    echo "$REQUIRED_PKG is installed, No installation is required."
  fi
done
apt autoremove -yqq --purge

apt clean

rm -rf \
    /var/lib/apt/lists/* \
    /var/cache/apt/archives \
    /tmp/* \
    /var/tmp/* \
    /usr/share/man \
    /usr/share/doc \
    /usr/share/doc-base

# Verify if any errors were encountered while installing and exit with error message if any error was found
if [ ${#err[@]} -ne 0 ]; then
    echo "Unable to install packages: [${err[*]}]"
    exit 1
fi
