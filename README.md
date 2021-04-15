# RaspberryBackup

在 Linux 系统中一键备份树莓派系统 SD 卡的脚本

脚本文件来源：https://blog.csdn.net/qingtian11112/article/details/99825257

使用方法：
step1：下载脚本文件`rpi-backup.sh`到 Linux 系统中

step2：把需要备份的 SD 卡插入 Linux 系统中，用 `df -h` 命令查询下 SD 卡对应的设备名。

step3：进入脚本文件 `rpi-backup.sh` 所在目录，只需要下面两行命令即可完成 SD 卡备份，最终 img 文件会生成在`~/backupimg/`文件夹下。

```bash
sudo chmod +x rpi-backup.sh            #需要赋可执行权限
./rpi-backup.sh /dev/sdb1 /dev/sdb2    #脚本执行
```

脚本执行有两个参数：

1. 第一个参数是树莓派 SD 卡`/boot`分区的设备名：/dev/sdb1
2. 第二个参数是`/`分区的设备名：/dev/sdb2，视情况修改

# Resize root 分区

1. 将烧录镜像的 SD 插到电脑中, 系统为 ubuntu，识别为 `/dev/sdc2`，会自动挂载，我电脑挂载到 `/media/ubuntu/rootfs`
2. 取消挂载 `sudo umount /media/ubuntu/rootfs`
3. 可能提示设备 busy，结束使用磁盘的程序 `sudo fuser -m -i -v -k /media/ubuntu/rootfs`, 然后重新取消挂载
4. 重新分区 fdisk

   - `sudo fdisk /dev/sdc`<br>

   ```bash
    Welcome to fdisk (util-linux 2.27.1).
    Changes will remain in memory only, until you decide to write them.
    Be careful before using the write command.


    Command (m for help): p                                 # p 查看信息
    Disk /dev/sdc: 29.6 GiB, 31719424000 bytes, 61952000 sectors
    Units: sectors of 1 * 512 = 512 bytes
    Sector size (logical/physical): 512 bytes / 512 bytes
    I/O size (minimum/optimal): 512 bytes / 512 bytes
    Disklabel type: dos
    Disk identifier: 0x340bfd6e

    Device     Boot  Start      End  Sectors  Size Id Type
    /dev/sdc1         8192   532479   524288  256M  c W95 FAT32 (LBA)
    /dev/sdc2       532480 23443455 22910976 10.9G 83 Linux

    Command (m for help): d                                 # d 删除分区
    Partition number (1,2, default 2): 2

    Partition 2 has been deleted.

    Command (m for help): n                                 # n 新建分区
    Partition type
       p   primary (1 primary, 0 extended, 3 free)
       e   extended (container for logical partitions)
    Select (default p):

    Using default response p.
    Partition number (2-4, default 2):
    First sector (2048-61951999, default 2048): 532480      # 要和原来的磁盘柱一致
    Last sector, +sectors or +size{K,M,G,T,P} (532480-61951999, default 61951999):

    Created a new partition 2 of type 'Linux' and of size 29.3 GiB.

    Command (m for help): p
    Disk /dev/sdc: 29.6 GiB, 31719424000 bytes, 61952000 sectors
    Units: sectors of 1 * 512 = 512 bytes
    Sector size (logical/physical): 512 bytes / 512 bytes
    I/O size (minimum/optimal): 512 bytes / 512 bytes
    Disklabel type: dos
    Disk identifier: 0x340bfd6e

    Device     Boot  Start      End  Sectors  Size Id Type
    /dev/sdc1         8192   532479   524288  256M  c W95 FAT32 (LBA)
    /dev/sdc2       532480 61951999 61419520 29.3G 83 Linux

    Command (m for help): wp                                # 保存退出
    The partition table has been altered.

   ```

5. 检查分区信息 `e2fsck -f /dev/sdc2`
6. 调整分区大小 `resize2fs -p /dev/sdc2`
