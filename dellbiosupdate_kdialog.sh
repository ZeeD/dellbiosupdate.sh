#!/bin/bash

# wrapper around which
# usage: system_has[REQUIRED_PROGRAMS]
function system_has() {
    which ${@} >/dev/null 2>&1
}

if ! system_has kdialog ; then
    echo 'kdialog not found, please use dellbiosupdate.sh' >&2
    exit 1
fi

# wrapper around kdialog
# usage: error EXITVALUE "STRING"
function error() {
    EXITVALUE="${1}"
    shift
    kdialog --error "${@}"
    exit "${EXITVALUE}"
}

# wrapper around kdialog
# usage: warn_and_ask "STRING"
function warn_and_ask() {
    kdialog --warningcontinuecancel "${@}"
}

# unfortunately bash only support 1-dimensional arrays...
# think it about an array of couples where '|' is the separator
# use "${e%|*}" to get the first element and "${e#*|}" to the last
SUPPORTED_SYSTEMS=(\
    'Debian, ubuntu|apt-get install libsmbios-bin curl'
    'Red hat, fedora, centos|yum install firmware-addon-dell libsmbios curl'
    'Suse, opensuse|zypper install libsmbios-bin curl'
    'Mandriva|urpmi libsmbios2 curl'
    'Arch, chakra|pacman -S libsmbios curl'
    'Gentoo|emerge -av libsmbios curl'
    'Sabayon|equo install libsmbios curl')

# wrapper around kdialog
# usage: menu "STRING" CHOICES
# where CHOICES is a 2-dimensiona array like SUPPORTED_SYSTEMS
function menu() {
    I=0
    ARRAY=()
    MESSAGE="${1}"
    shift
    for element in "${@}"; do
        ARRAY[${I}]="${element#*|}"
        I="$(($I+1))"
        ARRAY[${I}]="${element%|*}"
        I="$(($I+1))"
    done
    kdialog --menu "${MESSAGE}" "${ARRAY[@]}"
}

if [[ "${EUID}" != 0 ]]; then
    error 2 'Must run this script as root'
else
    while ! system_has dellBiosUpdate curl ; do
        if warn_and_ask 'libsmbios and curl needed!
Should I install it for you?' ; then
            eval "$(menu "Please select your distro" "${SUPPORTED_SYSTEMS[@]}")"
        else
            error 3 'Please install libsmbios and curl'
        fi
    done
fi

