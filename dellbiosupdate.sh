#!/bin/bash

#############################################################################################################
##                                                                                                         ##
##      This script is Free Software, it's licensed under the GPLv3 and has ABSOLUTELY NO WARRANTY         ##
##      you can find and read the complete version of the GPLv3 @ http://www.gnu.org/licenses/gpl.html     ##
##                                                                                                         ##
#############################################################################################################
##                                                                                                         ##
##      Please see the README file for any informations such as FAQs, Version History and TODO             ##
##                                                                                                         ##
#############################################################################################################
##                                                                                                         ##
##      Name:           dellbiosupdate.sh                                                                  ##
##      Version:        0.1.3.7                                                                            ##
##      Date:           Wed, Apr 08 2009                                                                   ##
##      Author:         Callea Gaetano Andrea (aka cga)                                                    ##
##      Contributors:   Riccardo Iaconelli (aka ruphy); Vito De Tullio (aka ZeD)                           ##
##                      Matteo Cappadonna (aka mauser)                                                     ##
##      Language:       BASH                                                                               ##
##      Location:       http://github.com/cga/dellbiosupdate.sh/tree/master                                ##
##                                                                                                         ##
#############################################################################################################

## let's roll!!!

## the script has to be run as root, let's make sure of that:
if (( ${EUID} != 0 )) ; then
	## if you not are root the scripts exits and prompt you this message:
	echo
	echo "You must run this script as root!! See FAQs in README for informations"
	echo
	exit 1
fi

## if you are root the scripts goes on and checks if the needed tools are installed:
if ! which dellBiosUpdate curl >/dev/null 2>&1 ; then
	## if the script doesn't find the needed tools..........
	echo
	echo "Either libsmbios or curl was NOT found! should I install it for you?"
	echo

	## .........you get prompted to install libsmbios for your specific DISTRO: (see FAQs in README for your distro support)
	select DISTRO in "Debian, Ubuntu and derivatives" "Red Hat, Fedora, CentOS and derivatives" "SuSE, OpenSuSE and derivatives" "Mandriva and derivatives" "Arch, Chakra and derivatives" "Gentoo and derivatives" "Sabayon and derivatives" "Quit, I will install it myself" "Ok, I'm done installing. Let's move on!" ; do
	case $DISTRO in
		"Debian, Ubuntu and derivatives") apt-get install libsmbios-bin curl ;;
		"Red Hat, Fedora, CentOS and derivatives") yum install firmware-addon-dell libsmbios curl ;;
		"SuSE, OpenSuSE and derivatives") zypper install libsmbios-bin curl ;;
		"Mandriva and derivatives") urpmi libsmbios2 curl ;;
		"Arch, Chakra and derivatives") pacman -S libsmbios curl ;;
		"Gentoo and derivatives") emerge -av libsmbios curl ;;
		"Sabayon and derivatives") equo install libsmbios curl ;;
		"Quit, I will install it myself") echo ; echo "Please install libsmbios and curl"; echo ; exit 2 ;;
		"Ok, I'm done installing. Let's move on!") break ;;
	esac
	done
fi

## now the script shows helpful informations about your DELL such as libsmbios version, SystemId (we need this) and BIOS version (wee need this):
echo
echo "These are some useful informations about your DELL, some of them are needed to update the BIOS:"
echo
getSystemId
echo

## we define a function() for "getSystemId"; less code, same results:
function getSystemId_about() {
    getSystemId | awk -F': *' '/'"${1}"'/ { print $NF }'
}

if [ "$(getSystemId_about 'Is Dell')" = '0' ]; then
    echo "Error! You *doesn't* have a Dell!"
    exit 5
fi

## now let's get the data we need in order to get the right BIOS: "Syste ID" and "BIOS Version":
SYSTEM_ID=$(getSystemId_about "System ID")
BIOS_VERSION_BASE=$(getSystemId_about "BIOS Version")
## and the model of you computer:
COMPUTER=$(getSystemId_about "Product Name")
DELL_SITE='http://linux.dell.com/repo/firmware/bios-hdrs/'

## now we 1) notify the current installed BIOS and 2) fetch all the available BIOS for your system.........
echo "Your currently installed BIOS Version is ${BIOS_VERSION_BASE}, getting the available BIOS updates for your ${COMPUTER}....."
echo
BIOS_AVAILABLE=($(curl -s "${DELL_SITE}" | grep "${SYSTEM_ID}" | sed 's/.*version_\([^\/]\{1,\}\).*$/\1/'))

## ......we list them..........
echo "These are the available BIOS updates available for your ${COMPUTER}:"
echo

## just to make sure PS3 doesn't get changed forever:
OLDPS3=$PS3
COLUMNS=10
PS3=$'\nNote that you actually *can* install the latest BIOS update without updating the immediately subsequent version.\n\nChoose the BIOS Version you want to install by typing the corresponding number: '
	## ......and we make them selectable:
	select BIOS_VERSION in "${BIOS_AVAILABLE[@]}" "I already have BIOS Version ${BIOS_VERSION_BASE} installed" ; do
	## we offer option to quit script on user will if BIOS Version is already installed
	if [[ "$BIOS_VERSION" == "I already have BIOS Version ${BIOS_VERSION_BASE} installed" ]] ; then
		echo
		echo "Thanks for using this script; now you know you have a tool to check if new BIOS versions are available ;)"
		echo
		exit 3

	elif [[ $BIOS_VERSION ]] ; then
		break
	fi
done
echo
COLUMNS=
PS3=$OLDPS3

## now that we have all the data, we need to set the URL to download the right BIOS:
URL="${DELL_SITE}system_bios_ven_0x1028_dev_${SYSTEM_ID}_version_${BIOS_VERSION}/bios.hdr"

## if an unknown bios.hdr version exist then mv it and append $DATE; finally download the bios.hdr file with the version saved in the file name:
if [[ -f ~/"bios.hdr" ]] ; then
	echo "I found an existing BIOS file (~/bios.hdr) of which I don't know the version and I'm going to back it up as ~/bios-$(date +%Y-%m-%d).hdr"
	echo
	sleep 1
	mv ~/bios.hdr ~/bios-$(date +%Y-%m-%d).hdr
	sleep 1
	echo "Downloading selected BIOS Version ${BIOS_VERSION} for your ${COMPUTER} and saving it as ~/bios-${BIOS_VERSION}.hdr"
	echo
	sleep 1
	curl ${URL} -o ~/bios-${BIOS_VERSION}.hdr
	echo
else
	echo "Downloading selected BIOS Version ${BIOS_VERSION} for your ${COMPUTER} and saving it as ~/bios-${BIOS_VERSION}.hdr"
	echo
	sleep 1
	curl ${URL} -o ~/bios-${BIOS_VERSION}.hdr
	echo
fi

## now we check that the BIOS Version you chose is appropriate for the computer:
echo "Checking if BIOS Version ${BIOS_VERSION} for your ${COMPUTER} is valid............."
sleep 3
echo
dellBiosUpdate -t -f ~/bios-${BIOS_VERSION}.hdr >/dev/null 2>&1
	## if not the script will exit and remove the downloaded BIOS:
	if (( $? != 0 )) ; then
		echo "WARNING: BIOS HDR file BIOS version appears to be less than or equal to current BIOS version."
		echo "This may result in bad things happening!!!! Therefore the script stops here."
		echo
		rm -f ~/bios-${BIOS_VERSION}.hdr
		echo "The downloaded ~/bios-${BIOS_VERSION}.hdr has been deleted."
		echo
		exit 4

	## if BIOS is valid we load the needed DELL module and proceed with the update:
	else
		echo "This is a valid BIOS Version for your ${COMPUTER}, telling the operating system I want to update the BIOS:"
		echo
		modprobe dell_rbu >/dev/null 2&>1
		if (( $? != 0 )) ; then
			echo "The necessary 'dell_rbu' module has NOT been loaded correctly, therefore the script stops here."
			exit 5
		else
			echo "The necessary 'dell_rbu' module has been loaded"
			echo
		fi
		## the actual update:
		dellBiosUpdate -u -f ~/bios-${BIOS_VERSION}.hdr
		echo
	fi

## to complete the update we must *soft* reboot:
echo
read -p "In order to update the BIOS you *must* reboot your system, do you want to reboot now? [Y/n]"
if [[ $REPLY = "Y" || $REPLY = "" ]] ; then
	echo
	echo "Rebooting in 5 seconds. Press CTRL+c to NOT reboot."
	sleep 5
	reboot
else
	echo
	echo "Don't forget to reboot your system or the BIOS will NOT update!!"
fi
exit 0
