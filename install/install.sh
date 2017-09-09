#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [[ $1 == "remove" ]] ; then 
	remove="all"
else 
	remove=""
fi

if [[ $remove ]] ; then 
	INSTALL="remove"
	CP="rm -f"
	systemctl stop mpradio
else
	INSTALL="install"
	CP="cp -f"
fi

#Installing software dependencies...
apt-get -y $INSTALL bluez pulseaudio-module-bluetooth python-gobject python-gobject-2 bluez-tools sox crudini libsox-fmt-mp3 python-dbus

#Installing software needed to compile PiFmRDS..
apt-get -y $INSTALL git libsndfile1-dev

#Setting rules...
BLACKLIST="/etc/modprobe.d/blacklist.conf"
blacklistline=$(grep "blacklist snd_bcm2835" $BLACKLIST -n|cut -d: -f1)
if [[ $blacklistline == "" ]]; then
	echo "blacklist snd_bcm2835" >> $BLACKLIST
	echo "blacklist ipv6" >> $BLACKLIST
else
	if [[ $remove ]]; then
		sed -i.bak -e "${blacklistline}d" $BLACKLIST
	fi
fi

INPUT="/etc/udev/rules.d/99-input.rules"
inputline=$(grep "bluetooth" $INPUT -n|cut -d: -f1)
if [[ $inputline == "" ]]; then
	echo "KERNEL==\"input[0-9]*\", RUN+=\"/usr/lib/udev/bluetooth\"" >> $INPUT
else
	if [[ $remove ]]; then
		sed -i.bak -e "${inputline}d" $INPUT
	fi
fi

#Installing needed files and configurations
${CP} bluezutils.py /bin/bluezutils.py
${CP} simple-agent /bin/simple-agent

CRONTAB="/etc/crontab"
crontabline=$(grep "simple-agent" $CRONTAB -n|cut -d: -f1)
if [[ $crontabline == "" ]]; then
	echo "@reboot root /bin/simple-agent&" >> $CRONTAB
else
	if [[ $remove ]]; then
		sed -i.bak -e "${crontabline}d" $CRONTAB
	fi
fi

cp -f daemon.conf /etc/pulse/daemon.conf
mkdir /usr/lib/udev
${CP} bluetooth /usr/lib/udev/bluetooth
${CP} audio.conf /etc/bluetooth/audio.conf
${CP} main.conf /etc/bluetooth/main.conf

#compile and $INSTALL mpradio_cc
if [[ $remove ]]; then
	echo "not compiling before uninstall"
else
	cd ../src/
	make clean
	make
fi

${CP} mpradio /home/pi/mpradio

#Installing service units...
#cp -f ../install/mpradio.service /etc/systemd/system/mpradio.service
#if [[ $remove ]]; then
#	systemctl disable mpradio.service
#else
#	systemctl enable mpradio.service
#fi

#Installing fm_transmitter...

if [[ $remove ]]; then
	echo "not compiling before uninstall"
else
	cd /home/pi/
	git clone https://github.com/markondej/fm_transmitter.git
	cd fm_transmitter
	make clean
	make
fi

#Final configuration and perms...
mkdir /pirateradio

usermod -a -G lp pi

echo "Installation completed! Rebooting in 10 seconds..."
sleep 10 && reboot
