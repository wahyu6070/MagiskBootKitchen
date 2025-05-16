*# Magisk Boot Kitchen
- Magisk boot kitchen repack,unpack,patched magisk boot 
- this is a tool to install magisk to boot.img, kernel, initrd, ramsidk.  the main purpose of this tool is to install magisk on android-x86 (pc). but you can use this on android (mobile)
## Informations
[telegram group](https://t.me/wahyu6070group)

## Usage
- git clone https://github.com/Wahyu6070/MagiskBootKitchen
- cd MagiskBootKitchen
- Moved boot.img/ramdisk.img/initrd.img/kernel to (Folder input)
- chmod 777 mbk.sh
- ./mbk.sh

## Manual mbk
- usage ./mbk.sh -i [Folder input] -o [Folder output]
-
- -i --input     Folder input
- -o --output    Folder output
-
- Example  : ./mbk.sh -i /home/wahyu6070/downloads -o /home/wahyu6070/videos
- Example2 : sh mbk.sh --input /sdcard --output /sdcard/music
-

## Magisk Version
- Magisk base Version : [v20.3](https://github.com/topjohnwu/Magisk/releases/tag/v20.3)
- Magisk Manager Version : [v7.5.1](https://github.com/topjohnwu/Magisk/releases/tag/manager-v7.5.1)

## Credits
- [topjohnwu](https://github.com/topjohnwu/Magisk) magisk
- [osm0sis](https://github.com/osm0sis/mkbootimg) mkbootimg
-

## Tested
- Android x86 desktop (android 9.0)
