#!/bin/bash
#set -x
trap "{ kill -s SIGTERM $$ ; exit 1; }" SIGINT SIGTERM

# ver. 20240918

function _color-off {
        echo -n -e "\033[0m"
}
function _color-red {
        echo -n -e "\033[91m"
}
function _color-grn {
        echo -n -e "\033[32m"
}
function _color-wht {
        echo -n -e "\033[37m"
}

function _disable_distcc {
        sed -i '/distcc/s/^FEATURES/#FEATURES/' /etc/portage/make.conf
        printf "(distcc disabled)\n"
}

function _enable_distcc {
        if [ `grep -c distcc /etc/portage/make.conf` -gt 0 ]; then
            sed -i '/distcc/s/^#FEATURES/FEATURES/' /etc/portage/make.conf
            printf "(distcc)\n"
        else
            printf "(distcc not available in make.conf, will not use it.)\n"
        fi
}

function _emerge_world {
        emerge --ask=y --verbose --verbose-conflicts --update --deep --newuse --backtrack=10000 --autounmask=y --autounmask-write=y --autounmask-keep-masks=y --autounmask-use=y --autounmask-backtrack=y --autounmask-keep-keywords=y --keep-going @world
        emerge_rc=$?
        return ${emerge_rc}
}

function _resume_emerge {
	loop=0
        while [ ${emerge_rc} -ne 0 ] && [ ${loop} -le 10 ]; do
                _color-wht; printf "Resuming emerge (${loop}/10)... "; _color-off
                sleep 10
                emerge --ask=n --resume --skipfirst
                emerge_rc=$?
                loop=$((loop+1))
        done
        return ${emerge_rc}
}

function _update_packages {
        update=false
        for package in $(echo ${1}); do
        pkg_status=`eix "${package}" | grep "${package}$" | awk -F'[' '{print $2}' | awk -F']' '{print $1}'`
        case "${pkg_status}" in
                'U'|'U?'|'?' )
                _color-wht; printf "Package ${package} can be updated.\n"; _color-off
                update=true
                ;;
                'I' )
                        _color-grn; printf "Package ${package} is up-to-date [${pkg_status}]\n"; _color-off
                ;;
                * )
                        eix "${1}"
                        _color-red; printf "DEBUG: ${package} - Unsupported package status. [${pkg_status}]\nFIXME!\n"; _color-off
                        exit 1
                ;;
                esac
        done
        if [ "${update}" == "true" ]; then
                printf "Updating ${package}: "
                _enable_distcc
                emerge --ask=n --update --with-bdeps=y --oneshot "${1}"
                if [[ "$?" -ne "0" ]]; then
                        _color-red; printf "Updating package(s) ${1} FAILED!\n"; _color-off
                        _color-wht; printf "Updating package(s) ${1}: "; _color-off
                        _disable_distcc
                        emerge --ask=n --update --with-bdeps=y --oneshot "${1}"
                        if [[ "$?" -ne "0" ]]; then _color-red; printf "Updating package(s) ${1} FAILED!\n"; exit 1; else updated=yes; fi
                else
                        updated=yes
                fi
        fi
}

function _update_eix {
# Update eix database if it s older than 24 hours or portage was updated in step above
if [[ $(( (`date +%s` - `stat -L --format %Y /var/cache/eix/portage.eix`) > (60*60*24) )) -eq 1 ]] || [[ "${portage_synchronized}" == "true" ]]; then
        if [ ! -f /usr/bin/eix ]; then
            printf "eix was not found. Installing it.\n"
            emerge --ask=n app-portage/eix
        fi
        _color-wht; printf "eix-update:\n"; _color-off
        eix-update
fi
}

function _sync-portage {
                _color-wht; printf "emain --auto sync\n"; _color-off
                RC=1
                ATTEMPT=0
                while [ "$RC" -ne "0" ] || [ "$ATTEMPT" -le "3" ]; do
                        emaint --auto sync
                        RC=$?
                        ATTEMPT=$((ATTEMPT+1))
                done
                if [ $RC -ne 0 ]; then
                        _color-red; printf "Portage sync failed.\n"; _color-off; exit 1
                fi
                 printf "Completed.\n" && portage_synchronized=true
 }
# START

_color-wht; printf "Removing emerge resume history:\n"; _color-off
emaint --fix cleanresume

portage_synchronizedd=false
_color-wht; printf "Sync Portage now? (y/N): "; _color-off
read answer

case ${answer} in
        y|Y )
		_sync-portage
        ;;
        * )
                true
        ;;
esac

_update_eix

# Check if portage should be updated
_update_packages sys-apps/portage

# Check if gcc should be updated
_update_packages sys-devel/gcc
if [[ "${updated}" -eq "yes" ]]; then
        if  [ `gcc-config -l | wc -l` -ne 1 ]; then
	_color-wht; printf "GCC version select: \n"; _color-off
        gcc-config -l
        _color-wht; printf "Select gcc version: "; _color-off
        read answer
        case ${answer} in
                [1-9] )
                        gcc-config ${answer}
                        source /etc/profile
                        _update_packages sys-devel/binutils sys-libs/binutils-libs sys-libs/glibc sys-devel/libtool
                ;;
                * )
                        true
                ;;
        esac
        fi
fi

# Emerge with distcc
_color-wht; printf "Updating @world: "; _color-off
_enable_distcc
_emerge_world || \
_resume_emerge

if [[ ${emerge_rc} -ne 0 ]]; then
        _color-red; printf "Updating @world (distcc) FAILED!\n"; _color-off
        _color-wht; printf "Updating @world: "; _color-off
        _disable_distcc
        _emerge_world || \
        _resume_emerge

        if [[ ${emerge_rc} -ne 0 ]]; then _color-red; printf "Updating @world (no distcc)  FAILED!\n"; _color-off; exit 1; fi
fi

#emerge --depclean | egrep --line-buffered -v "^ .* pulled in by:$|^ .* requires " | uniq -u
emerge --ask=y --depclean || exit 1
emerge -v1 --keep-going @preserved-rebuild || exit 1

if [ ! -f /usr/sbin/perl-cleaner ]; then
    printf "perl-cleaner not found. Installing it.\n"
    emerge --ask=n app-admin/perl-cleaner
fi
perl-cleaner --all

emerge --ask=y --depclean || exit 1

if [ ! -f /usr/bin/revdep-rebuild ]; then
    printf "Gentoolkit not found. Installing it.\n"
    emerge --ask=n app-portage/gentoolkit
fi
revdep-rebuild || exit 1

emerge -v1 --keep-going @preserved-rebuild || exit 1
eix-sync -0
dispatch-conf
