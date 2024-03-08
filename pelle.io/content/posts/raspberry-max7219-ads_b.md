---
title: "raspberry-max7219-ads_b"
date: 2020-10-13T19:00:00
draft: true
---


git clone https://github.com/junzis/pyModeS
cd pyModeS
make ext
make install


sudo apt-get install librtlsdr0
pip3 install pyModeS 


Bus 001 Device 034: ID 0bda:2832 Realtek Semiconductor Corp. RTL2832U DVB-T
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", GROUP="adm", MODE="0666", SYMLINK+="rtl_sdr"
udevadm control --reload-rules && udevadm trigger


verify it works
modeslive --source rtlsdr
