#
#gwt is dir home
#


gwt="`dirname $(readlink -f "$0")`"

chmod -R 777 "$gwt/bin"

arch=$(uname -m | cut -c-3)
if [ $arch = x86 ]; then
   bin=$gwt/bin/x86
else
   bin=$gwt/bin/arm
fi

########################################
help(){
	echo " "
	echo "usage : mbk.sh -i <input folder> -o <output folder>"
	echo " "
	echo "-i --input         input folder"
	echo "-o --output        output folder"
	echo "   Example  : ./mbk.sh -i /sdcard/download -o /sdcard/music"
	echo "   Example2 : sh mbk.sh -input /files/boot -output /home/music"
	echo " "
	echo "move file boot.img, initrd.img, kernel, ramdisk.img into input folder"
	echo " "
	echo "Telegram : t.me/wahyu6070"
	echo "Youtube  : www.youtube.com/c/wahyu6070"
	echo " "
}

case $1 in
-i | --input) input="$2" ;;
-h | --help) help ;;
*) input="$gwt/input" ;;
esac

case $3 in
-o | --output) output="$4" ;;
*) output="$gwt/output" ;;
esac


if [ $1 ] && [ -f $2 ]; then
help
elif [ $1 ] && [ -d $2 ] && [ $3 ] && [ ! -d $4 ]; then
help
elif [ $1 ] && [ ! -d $2 ]; then
help
fi


################################
# Load utility functions
.$gwt/bin/util_functions.sh 2>/dev/null
################################


#############################################
#Functions
#############################################
boot(){
if [ -f "$gwt/ramdisk.img" ] && [ -f "$gwt/initrd.img" ] && [ -f "$gwt/kernel" ]; then
rm -rf $input/new_boot.img >/dev/null
echo "- Repack kernel, ramdisk.img, initrd.img"
$bin/mkbootimg --kernel $gwt/kernel --ramdisk $gwt/ramdisk.img --second $gwt/initrd.img --output $input/new_boot.img
elif [ -f "$input/ramdisk.img" ] && [ -f "$input/initrd.img" ] && [ -f "$input/kernel" ]; then
rm -rf $input/new_boot.img >/dev/null
echo "- Repack kernel, ramdisk.img, initrd.img"
$bin/mkbootimg --kernel $input/kernel --ramdisk $input/ramdisk.img --second $input/initrd.img  --output $input/new_boot.img
fi

if [ -f "$input/new_boot.img" ]; then
bootimg=$input/new_boot.img
elif [ -f "$input/boot.img" ]; then
bootimg=$input/boot.img
elif [ -f "$input/magisk_patched.img" ]; then
bootimg=$input/magisk_patched.img
elif [ -f "$input/boot_patched.img" ]; then
bootimg=$input/boot_patched.img
elif [ -f "$gwt/boot.img" ]; then
bootimg=$gwt/boot.img
elif [ -f "$gwt/magisk_patched.img" ]; then
bootimg="$gwt/magisk_patched.img"
else
echo "-Please added boot.img or ramdisk.img,initrd.img,kernel"
exit
fi

}
unpack() {
	# Extract magisk if doesn't exist
[ -e magisk ] || "$bin/magiskinit" -x magisk magisk
CHROMEOS=false
echo "- Unpacking boot image"
$bin/magiskboot unpack "$bootimg" 2>/dev/null

case $? in
  1 )
    abort "! Unsupported/Unknown image format"
    ;;
  2 )
    echo "- ChromeOS boot image detected"
    CHROMEOS=true
    ;;
esac

[ -f recovery_dtbo ] && RECOVERYMODE=true

}
ramdisk_restore(){
# Test patch status and do restore
echo "- Checking ramdisk status"
if [ -e "$gwt/ramdisk.cpio" ]; then
  $bin/magiskboot cpio ramdisk.cpio test
  STATUS=$?
else
  # Stock A only system-as-root
  STATUS=0
fi
case $((STATUS & 3)) in
  0 )  # Stock boot
    echo "- Stock boot image detected"
    SHA1=`$bin/magiskboot sha1 "$input/boot.img" 2>/dev/null`
    #cat $bootimg > $input/stock_boot.img
    cp -af  ramdisk.cpio ramdisk.cpio.orig 2>/dev/null
    ;;
  1 )  # Magisk patched
    echo "- Magisk patched boot image detected"
    # Find SHA1 of stock boot image
    [ -z $SHA1 ] && SHA1=`$bin/magiskboot cpio ramdisk.cpio sha1 2>/dev/null`
    $bin/magiskboot cpio ramdisk.cpio restore
    cp -af ramdisk.cpio ramdisk.cpio.orig
    ;;
  2 )  # Unsupported
    echo "! Boot image patched by unsupported programs"
    abort "! Please restore back to stock boot image"
    ;;
esac

if [ $((STATUS & 8)) -ne 0 ]; then
  # Possibly using 2SI, export env var
  export TWOSTAGEINIT=true
fi
}

ramdisk_patch(){
echo "- Patching ramdisk"

echo "KEEPVERITY=$KEEPVERITY" > config
echo "KEEPFORCEENCRYPT=$KEEPFORCEENCRYPT" >> config
echo "RECOVERYMODE=$RECOVERYMODE" >> config
[ ! -z $SHA1 ] && echo "SHA1=$SHA1" >> config

"$bin/magiskboot" cpio ramdisk.cpio \
"add 750 init $bin/magiskinit" \
"patch" \
"backup ramdisk.cpio.orig" \
"mkdir 000 .backup" \
"add 000 .backup/.magisk config"

if [ $((STATUS & 4)) -ne 0 ]; then
  echo "- Compressing ramdisk"
  $bin/magiskboot cpio ramdisk.cpio compress 2>/dev/null
fi

rm -f ramdisk.cpio.orig config
}


binary(){
for dt in dtb kernel_dtb extra recovery_dtbo; do
  [ -f $dt ] && $bin/magiskboot dtb $dt patch && echo "- Patch fstab in $dt"
done

if [ -f kernel ]; then
  # Remove Samsung RKP
  $bin/magiskboot hexpatch kernel \
  49010054011440B93FA00F71E9000054010840B93FA00F7189000054001840B91FA00F7188010054 \
  A1020054011440B93FA00F7140020054010840B93FA00F71E0010054001840B91FA00F7181010054

  # Remove Samsung defex
  # Before: [mov w2, #-221]   (-__NR_execve)
  # After:  [mov w2, #-32768]
  $bin/magiskboot hexpatch kernel 821B8012 E2FF8F12

  # Force kernel to load rootfs
  # skip_initramfs -> want_initramfs
  $bin/magiskboot hexpatch kernel \
  736B69705F696E697472616D667300 \
  77616E745F696E697472616D667300
fi
}
#repack
repack(){
echo "- Repacking boot image"
$bin/magiskboot repack "$bootimg" || abort "! Unable to repack boot image!"
# Sign chromeos boot
$CHROMEOS && sign_chromeos
cp -f "$gwt/kernel" "$output" 2>/dev/null
cp -f "$gwt/ramdisk.cpio" "$output/ramdisk.img" 2>/dev/null
cp -f "$gwt/second" "$output/initrd.img" 2>/dev/null
cp -f "$gwt/kernel_dtb" "$output" 2>/dev/null
cp -f "$gwt/new-boot.img" "$output/boot_patched.img" 2>/dev/null
rm -rf "$gwt/second" "$gwt/kernel_dtb" "$gwt/ramdisk.cpio" "$gwt/kernel" "$gwt/magisk" "$gwt/new-boot.img" "$gwt/config" 2>/dev/null
# Reset any error code
true
}


###############################################
#end functions
###############################################


###############################################
#Run
###############################################
if [ ! $1 ]; then
echo " "
echo "    MAGISK BOOT KITCHEN by wahyu6070"
echo " "
boot
unpack
ramdisk_restore
ramdisk_patch
binary
repack
echo " "
echo " output : $output"
echo " "
fi

if [ $1 ] && [ -d $2 ] && [ $3 ] && [ -d $4 ]; then
echo " "
echo "    MAGISK BOOT KITCHEN by wahyu6070"
echo " "
boot
unpack
ramdisk_restore
ramdisk_patch
binary
repack
echo " "
echo " output : $output"
echo " "
fi

###############################################
#End
###############################################

