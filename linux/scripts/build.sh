#!/bin/bash

# Build KMFL in the required order: kmflcomp libkmfl ibus-kmfl

# It must be run from the keyman/linux directory

set -e

BASEDIR=`pwd`

INSTALLDIR=${INSTALLDIR:-"/usr/local"}

CONFIGUREONLY=${CONFIGUREONLY:="no"}
BUILDONLY=${BUILDONLY:="no"}

if [[ "${CONFIGUREONLY}" != "no" && "${BUILDONLY}" != "no" ]]; then
	echo "Only use one of CONFIGUREONLY and BUILDONLY"
	exit 1
fi

for proj in kmflcomp libkmfl ibus-kmfl; do
	if [ ! -f $proj/configure ]; then
		echo "$proj is not set up with autoreconf. First run 'make reconf' or 'make devreconf'"
		exit 1
	fi
	if [[ "${BUILDONLY}" == "no" ]]; then
		rm -rf build-$proj
	fi
	mkdir -p build-$proj
	cd build-$proj
	if [[ "${BUILDONLY}" == "no" ]]; then
		if [[ "${INSTALLDIR}" == "/tmp/kmfl" ]]; then # don't install ibus-kmfl into ibus
			../$proj/configure CPPFLAGS="-I../kmflcomp/include -I../libkmfl/include" LDFLAGS="-L`pwd`/../build-kmflcomp/src -L`pwd`/../build-libkmfl/src" --prefix=${INSTALLDIR} --libexecdir=${INSTALLDIR}/lib/ibus
		else	# install ibus-kmfl into ibus
			../$proj/configure CPPFLAGS="-I../kmflcomp/include -I../libkmfl/include" LDFLAGS="-L`pwd`/../build-kmflcomp/src -L`pwd`/../build-libkmfl/src" --prefix=${INSTALLDIR} --libexecdir=${INSTALLDIR}/lib/ibus --datadir=/usr/share
		fi
	fi
	if [[ "${CONFIGUREONLY}" == "no" ]]; then
		if [ ! -f config.h ]; then
			echo "$proj has not been configured before building. First run 'make configure'"
			exit 1
		fi
		make
	fi
	cd $BASEDIR
done

if [[ "${CONFIGUREONLY}" == "no" ]]; then
	cd keyman-config
	make clean
	make
	cd $BASEDIR
fi
