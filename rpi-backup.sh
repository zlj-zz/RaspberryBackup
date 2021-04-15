#!/usr/bin/env bash

if [  $# != 2 ]; then
  echo "argument error: Usage: $0 boot_device_name root_device_name"
  echo "example: $0 /dev/mmcblk0p1 /dev/mmcblk0p2"
  exit 0
fi

echo "=====================   part 1, preparation    ==============================="
dev_boot=$1
dev_root=$2
mounted_boot=`df -h | grep $dev_boot | awk '{print $6}'`
mounted_root=`df -h | grep $dev_root | awk '{print $6}'`
img=rpi-`date +%Y%m%d-%H%M`.img

echo "==> check tools..."
NEED_TOOLS="dosfstools dump parted kpartx gzip"
not_installed=""
for nt in ${NEED_TOOLS[@]}; do
  if ! type ${nt}>/dev/null 2>&1;then
    not_installed="${not_installed} ${nt}"
  fi
done

if [ ! -n "${not_installed}" ]; then
  echo "...all need tools was installed."
else
  echo "not installed: ${not_installed}"
  echo -e "\n==> try install..."
  if type apt-get>/dev/null 2>&1; then
    sudo apt install ${not_installed}
  elif type pacman>/dev/null 2>&1; then
    echo 222
    sudo pacman -S ${not_installed}
  else
    echo "Automatic installation does not support this system, please try to install manually."
    exit
  fi
fi

echo -e "\n==>prepare workspace ...\n"
mkdir ~/backupimg
cd ~/backupimg

# New img file
bootsz=`df -P | grep $dev_boot | awk '{print $2}'`
rootsz=`df -P | grep $dev_root | awk '{print $3}'`
totalsz=`echo $bootsz $rootsz | awk '{print int(($1+$2)*1.3/1024)}'`
echo -e "\n==> created a blank img, size ${totalsz}M ...\n"
sudo dd if=/dev/zero of=$img bs=1M count=$totalsz status=progress
#sync

# format virtual disk
bootstart=`sudo fdisk -l | grep $dev_boot | awk '{print $2}'`
bootend=`sudo fdisk -l | grep $dev_boot | awk '{print $3}'`
if [ $bootstart == '*' ]; then
  bootstart=`sudo fdisk -l | grep $dev_boot | awk '{print $3}'`
  bootend=`sudo fdisk -l | grep $dev_boot | awk '{print $4}'`
fi
rootstart=`sudo fdisk -l | grep $dev_root | awk '{print $2}'`
#有些系统 sudo fdisk -l 时boot分区的boot标记会标记为*,此时bootstart和bootend最后应改为 $3 和 $4
#rootend=`sudo fdisk -l /dev/mmcblk0 | grep mmcblk0p2 | awk '{print $3}'`
echo -e "\n==> boot: $bootstart - $bootend, root: $rootstart - end; initialize backup img ...\n"

# initialize backup img.
sudo parted $img --script -- mklabel msdos
sudo parted $img --script -- mkpart primary fat32 ${bootstart}s ${bootend}s
sudo parted $img --script -- mkpart primary ext4 ${rootstart}s -1

echo "=====================  part 2, mount img to system  ==============================="
loopdevice=`sudo losetup -f --show $img`
echo "losetup result: ${loopdevice}"
device=/dev/mapper/`sudo kpartx -va $loopdevice | sed -E 's/.*(loop[0-9]+)p.*/\1/g' | head -1`
echo "kpartx result: ${device}"
sleep 5
sudo mkfs.vfat ${device}p1 -n boot
sudo mkfs.ext4 ${device}p2 -L rootfs
#在backupimg文件夹下新建两个文件夹，将两个分区挂载在下面
mkdir tgt_boot tgt_Root
#这里没有使用id命令来查看uid和gid，而是假设uid和gid都和当前用户名相同
uid=`whoami`
gid=$uid
sudo mount -t vfat -o uid=${uid},gid=${gid},umask=0000 ${device}p1 ./tgt_boot/
sudo mount -t ext4 ${device}p2 ./tgt_Root/


echo "===================== part 3, backup /boot ========================="
sudo cp -rfp ${mounted_boot}/* ./tgt_boot/
sync
echo "...Boot partition done"

echo "===================== part 4, backup / ========================="
sudo chmod 777 ./tgt_Root
sudo chown ${uid}.${gid} tgt_Root
sudo rm -rf ./tgt_Root/*
cd tgt_Root/
# start backup
sudo dump -0uaf - ${mounted_root}/ | sudo restore -rf -
sync 
echo "...Root partition done"
cd ..

echo "===================== part 5, replace PARTUUID ========================="

# replace PARTUUID
opartuuidb=`sudo blkid -o export $dev_boot | grep PARTUUID`
opartuuidr=`sudo blkid -o export $dev_root | grep PARTUUID`
npartuuidb=`sudo blkid -o export ${device}p1 | grep PARTUUID`
npartuuidr=`sudo blkid -o export ${device}p2 | grep PARTUUID`
sudo sed -i "s/$opartuuidr/$npartuuidr/g" ./tgt_boot/cmdline.txt
sudo sed -i "s/$opartuuidb/$npartuuidb/g" ./tgt_Root/etc/fstab
sudo sed -i "s/$opartuuidr/$npartuuidr/g" ./tgt_Root/etc/fstab
echo "...replace PARTUUID done"

echo -e "\n==> remove auto generated files"
#下面内容是删除树莓派中系统自动产生的文件、临时文件等
cd ~/backupimg/tgt_Root
sudo rm -rf ./.gvfs ./dev/* ./media/* ./mnt/* ./proc/* ./run/* ./sys/* ./tmp/* ./lost+found/ ./restoresymtable
cd ..

echo "===================== part 6, unmount ========================="
sudo umount tgt_boot tgt_Root
sudo kpartx -d ${loopdevice}
sudo losetup -d ${loopdevice}
rmdir tgt_boot tgt_Root
echo "...unmount done"

echo "===================== part 7, compress ========================="
echo "Do you want to use gzip for compression?[Y/n]:"
read isCompress
if [[ ${isCompress} = 'Y' || ${isCompress} = 'y' ]]; then
  echo -e "\n==> compressing..."
  sudo gzip ${img}
  sync
  echo "...Compress done"
else
  echo "No compression"
fi

echo -e "\n\nWhere the img?"
echo "    img file is under ~/backupimg/"
