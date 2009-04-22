#!/bin/bash

# wrapper around which
# usage: system_has [REQUIRED_PROGRAMS]
function system_has() {
    which ${@} >/dev/null 2>&1
}

# TODO: make a kde4-compatible (dbus-based) version
if ! system_has kdialog dcop; then
    echo 'kdialog and dcop not found, please use dellbiosupdate.sh' >&2
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
# where CHOICES is a 2-dimensional-like array like SUPPORTED_SYSTEMS
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

if [ "${EUID}" != '0' ]; then
    error 2 'Must run this script as root'
fi
while ! system_has dellBiosUpdate curl; do
    if warn_and_ask 'libsmbios and curl needed!
Should I install it for you?' ; then
        eval "$(menu "Please select your distro" "${SUPPORTED_SYSTEMS[@]}")"
    else
        error 3 'Please install libsmbios and curl'
    fi
done

# we define a function() for "getSystemId"; less code, same results:
function getSystemId_about() {
    getSystemId | awk -F': *' '/'"${1}"'/ { print $NF }'
}

if [ "$(getSystemId_about 'Is Dell')" = '0' ]; then
    error 4 'Error! You *don`t* have a Dell!'
fi

SYSTEM_ID="$(getSystemId_about 'System ID')"
BIOS_VERSION_BASE="$(getSystemId_about 'BIOS Version')"
COMPUTER="$(getSystemId_about 'Product Name')"
DELL_SITE='http://linux.dell.com/repo/firmware/bios-hdrs/'

# TODO: make a kde4-compatible (dbus-based) version
DCOPREF="$(kdialog --progressbar "Your BIOS Version is ${BIOS_VERSION_BASE}
Getting the available BIOS updates for your ${COMPUTER}" 1)"
dcop "${DCOPREF}" setAutoClose 1
BIOS_AVAILABLE=($(curl -s "${DELL_SITE}" | \
        sed -n '/'"${SYSTEM_ID}_"'/s/.*version_\([^\/]\{1,\}\).*$/\1/p'))
dcop "${DCOPREF}" setProgress 1

BIOS_VERSION="$(kdialog --combobox \
        'Please choose the BIOS version you want to install' \
        "${BIOS_AVAILABLE[@]}")"
if [ "${?}" != '0' ]; then # User did *not* pressed 'ok'
    error 5 'This script will not upgrade nothing'
fi
URL="${DELL_SITE}system_bios_ven_0x1028_dev_${SYSTEM_ID}_version_${BIOS_VERSION}/bios.hdr"

# found an old bios file... from where it came from???
if [ -f ~/'bios.hdr' ]; then
    mv ~/'bios.hdr' "bios-$(date +%F).hdr"
fi

BIOS_LOCAL_NAME=~/"bios-${BIOS_VERSION}.hdr"
if [ -f "${BIOS_LOCAL_NAME}" ]; then # I already have it!
    error 6 'You already have this bios installed!'
fi

curl "${URL}" -o "${BIOS_LOCAL_NAME}"
if dellBiosUpdate -t -f "${BIOS_LOCAL_NAME}" >/dev/null; then
    rm "${BIOS_LOCAL_NAME}"
    error 7 "${BIOS_LOCAL_NAME} appeared to be older than current BIOS version.
It has been deleted"
fi
if modprobe dell_rbu >/dev/null 2>&1; then
    error 8 "The necessary 'dell_rbu' module has NOT been loaded correctly.
The script stops here."
fi
dellBiosUpdate -u -f "${BIOS_LOCAL_NAME}"
if warn_and_ask 'In order to update the BIOS you *must* reboot your system.
Do you want to reboot now?'; then
    DCOPREF="$(kdialog --progressbar 'Rebooting in 5 seconds' 5)"
    dcop "${DCOPREF}" showCancelButton 1
    dcop "${DCOPREF}" setAutoClose 5
    for i in `seq 5`; do
        sleep 1
        if [ "$(dcop "${DCOPREF}" wasCancelled)" == 'true' ]; then
            dcop "${DCOPREF}" close
            break
        fi
        dcop "${DCOPREF}" setProgress "${i}" 2>/dev/null
        if [ "${i}" = '5' ]; then
            reboot
        fi
    done
fi
