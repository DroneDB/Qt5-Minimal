#!/bin/bash
__dirname=$(cd $(dirname "$0"); pwd -P)
cd ${__dirname}
set -e -o pipefail

QT_MAJOR=5.9
QT_VERSION=5.9.5

ISSUE=$(cat /etc/issue | xargs echo -n)
PKG_SUFFIX=""
if [[ "$ISSUE" == *"Ubuntu"* ]]; then
  UBUNTU_VERSION=$(echo $ISSUE | cut -c7-12 | xargs echo -n)
  echo "Ubuntu: $UBUNTU_VERSION"
  PKG_SUFFIX="ubuntu-$UBUNTU_VERSION-"
fi

apt update || sudo apt update

check_command(){
	check_msg_prefix="Checking for $1... "
	check_msg_result="\033[92m\033[1m OK\033[0m\033[39m"

	hash $1 2>/dev/null || not_found=true 
	if [[ $not_found ]]; then
		
		# Can we attempt to install it?
		if [[ ! -z "$3" ]]; then
			echo -e "$check_msg_prefix \033[93mnot found, we'll attempt to install\033[39m"
			eval "$3 || sudo $3"

			# Recurse, but don't pass the install command
			check_command "$1" "$2"	
		else
			check_msg_result="\033[91m can't find $1! Check that the program is installed and that you have added the proper path to the program to your PATH environment variable before launching WebODM. If you change your PATH environment variable, remember to close and reopen your terminal. $2\033[39m"
		fi
	fi

	echo -e "$check_msg_prefix $check_msg_result"
	if [[ $not_found ]]; then
		return 1
	fi
}

check_command "curl" "apt install curl" "apt install curl -y"
check_command "g++" "apt install build-essential" "apt install build-essential -y"
check_command "xz" "apt install xz-utils" "apt install xz-utils -y"

if [ ! -e qt-everywhere-opensource-src-$QT_VERSION.tar.xz ]; then
    echo Downloading QT5...
    curl -L https://download.qt.io/archive/qt/$QT_MAJOR/$QT_VERSION/single/qt-everywhere-opensource-src-$QT_VERSION.tar.xz --output qt-everywhere-opensource-src-$QT_VERSION.tar.xz
fi

if [ ! -e qt-everywhere-opensource-src-$QT_VERSION ]; then
    tar -xf qt-everywhere-opensource-src-$QT_VERSION.tar.xz
fi

if [ -e qt-build ]; then
    echo "Removing previous build"
    rm -fr qt-build
fi

if [ -e qt-install ]; then
    echo "Removing previous install"
    rm -fr qt-install
fi

mkdir -p qt-build
cd qt-build

../qt-everywhere-opensource-src-$QT_VERSION/configure -static -skip connectivity -skip sensors -skip datavis3d -skip serialbus -skip declarative -skip serialport -skip doc -skip speech -skip gamepad -skip svg -skip graphicaleffects -skip tools -skip imageformats -skip translations -skip location -skip virtualkeyboard -skip macextras -skip wayland -skip multimedia -skip webchannel -skip networkauth -skip webengine -skip websockets -skip 3d -skip purchasing -skip webview -skip activeqt -skip quickcontrols -skip winextras -skip androidextras -skip quickcontrols2 -skip x11extras -skip remoteobjects -skip xmlpatterns -skip canvas3d -skip script -skip charts -skip scxml -opensource -nomake tools -nomake tests -nomake examples -confirm-license -qt-libpng -no-harfbuzz -qt-pcre -qt-freetype -nomake tests -no-feature-testlib -no-feature-widgets -no-feature-xml -no-feature-sql -no-feature-network -no-feature-dbus -no-feature-linuxfb -no-feature-accessibility -no-feature-evdev -no-feature-vnc -no-feature-xlib -no-feature-xcb -no-feature-iconv -qt-zlib -platform linux-g++ -no-feature-eglfs -no-feature-opengl --prefix=$__dirname/qt-install
make -j$(nproc) && make install
cd $__dirname

# Strip some stuff
rm -fr qt-install/{description-pak,doc,doc-pak,mkspecs}

mkdir -p qt-install/DEBIAN

# Build dev package
echo "Package: qt5-minimal-dev
Version: $QT_VERSION
Architecture: amd64
Maintainer: Piero Toffanin <pt@masseranolabs.com>
Description: Minimal QT5 installation development files" > qt-install/DEBIAN/control

dpkg-deb --build qt-install
mv -v qt-install.deb qt5-$QT_VERSION-minimal-${PKG_SUFFIX}amd64-dev.deb

# Strip some more stuff
rm -fr $__dirname/qt-install/lib/*.{a,prl,la}
rm -fr $__dirname/qt-install/lib/{cmake,pkgconfig}
rm -fr $__dirname/qt-install/bin
rm -fr $__dirname/qt-install/plugins

# Build binary
echo "Package: qt5-minimal-bin
Version: $QT_VERSION
Architecture: amd64
Maintainer: Piero Toffanin <pt@masseranolabs.com>
Description: Minimal QT5 installation binary files" > qt-install/DEBIAN/control

dpkg-deb --build qt-install
mv -v qt-install.deb qt5-$QT_VERSION-minimal-${PKG_SUFFIX}amd64-bin.deb

echo "Done!"