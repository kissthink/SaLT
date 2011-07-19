#!/bin/bash
qemu --version >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo ""
  echo "WARNING: qemu not installed!"
  echo ""
fi
cd $(dirname $0)
startdir=$PWD
ISODIR=$startdir/iso
grubdir=$startdir
rm -rf $ISODIR
mkdir -p $ISODIR
BOOTFILE=boot/eltorito.img
CATALOGFILE=boot/grub.cat
cp bg.png "$grubdir/build/boot/grub/bg.png"
# generate grub config
(
  cd "$grubdir/genlocale"
  # compile mo files, create locale dir containg translations
  make install VOLUMENAME="GRUB2 Test"
  ./genlocale "$grubdir/build/boot/grub/locale" "$grubdir/build/boot/grub" "$grubdir/build/boot/grub/keymaps" "GRUB2 Test"
)
# add grub2 menu
(
  cd $ISODIR
  # prepare the grub2 initial tree
  eval $(grep '^libdir=' $(which grub-mkrescue))
  eval $(grep '^PACKAGE_TARNAME=' $(which grub-mkrescue))
  GRUB_DIR=$libdir/$PACKAGE_TARNAME/i386-pc
  mkdir -p boot/grub
  cp -ar "$grubdir"/build/* .
  sed -i "s:\(set debug=\).*:\1=debug:" boot/grub/grub.cfg
  sed -i "s:@@IDENT_FILE@@:qemu:" boot/grub/embed.cfg
  touch qemu
  mkdir -p boot/grub/locale/
  for i in /usr/share/locale/*; do
    if [ -f "$i/LC_MESSAGES/grub.mo" ]; then
      cp -f "$i/LC_MESSAGES/grub.mo" "boot/grub/locale/${i##*/}.mo"
    fi
  done
  mkdir -p boot/grub/i386-pc/
  for i in $GRUB_DIR/*.mod $GRUB_DIR/*.lst $GRUB_DIR/*.img $GRUB_DIR/efiemu??.o; do
    if [ -f $i ]; then
      cp -f $i boot/grub/i386-pc/
    fi
  done
  grub-mkimage -p /boot/grub/i386-pc -o /tmp/core.img -O i386-pc \
    biosdisk iso9660
  cat $GRUB_DIR/cdboot.img /tmp/core.img > $BOOTFILE
  rm /tmp/core.img
  grub-editenv boot/grub/salt.env create
)
# remove uneeded/unwanted files
rm -rf boot/dos boot/isolinux boot/pxelinux.cfg boot/syslinux boot/bootinst.* boot/*.c32 boot/liloinst.sh
# create the iso
echo "Creating ISO..."
cd $startdir
mkisofs -r -J -V "grub2_menu" -b $BOOTFILE -c $CATALOGFILE -no-emul-boot -boot-load-size 4 -boot-info-table -o "grub2menu.iso" $ISODIR
rm -rf $ISODIR
qemu -cdrom grub2menu.iso
read R
rm grub2menu.iso
