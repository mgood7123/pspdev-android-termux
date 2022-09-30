#!/data/data/com.termux/files/usr/bin/bash
case `dpkg --print-architecture` in
  aarch64)
    psparch="aarch64"
    linarch="arm64"
    ;;
#  arm)
#		 psparch="armv7"
#    linarch="armhf"
#    ;;
	*)
			echo "unsupported architecture, we only support aarch64 for now"
    exit 1
    ;;
esac

folder="ubuntu-$linarch--pspdev-$psparch--rootfs"
uv=22.04
tarball="ubuntu.tar.gz"

echo "downloading ubuntu-image"
wget "https://cdimage.ubuntu.com/ubuntu-base/releases/${uv}/release/ubuntu-base-${uv}-base-${linarch}.tar.gz" -O "$tarball"
cur=`pwd`
echo removing any existing "$folder"
rm -rf "$folder"
mkdir -p "$folder"
cd "$folder"
echo "decompressing ubuntu image"
proot --link2symlink tar -xf "${cur}/${tarball}" --exclude='dev'||:
echo "removing ubuntu image tarball"
rm "${cur}/${tarball}"
echo "fixing nameserver, otherwise it can't connect to the internet"
echo "nameserver 1.1.1.1" > etc/resolv.conf
echo "127.0.0.1 localhost" > etc/hosts
cd "$cur"
bin=enter_ubuntu.sh
echo "writing launch script"
cat > $bin <<- EOM
#!/bin/bash
cd "$cur"
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
echo "root is required to enable psp debugging"
command="su -c /data/data/com.termux/files/usr/bin/proot"
command+=" --link2symlink"
command+=" -0"
command+=" -r $folder"
command+=" -b /dev"
command+=" -b /proc"
command+=" -b /sys"
## uncomment the following line to have access to the home directory of termux
#command+=" -b /data/data/com.termux/files/home:/root"
## uncomment the following line to mount /sdcard directly to / 
#command+=" -b /sdcard"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
com="\$@"
if [ -z "\$1" ];then
    exec \$command
else
    \$command -c "\$com"
fi
EOM

echo "fixing shebang of $bin"
termux-fix-shebang $bin &&
echo "making $bin executable" &&
chmod +x $bin &&
echo symlinking sh to bash &&
./$bin "rm /bin/sh; ln -s /bin/bash /bin/sh" &&
echo "updating package list" &&
./$bin "apt update" &&
echo "installing core packages for apt" &&
./$bin "apt install -y apt-utils" &&
./$bin "apt install -y dialog" &&
./$bin "apt install -y sudo" &&
./$bin "apt install -y wget curl tzdata" &&
echo "installing dependancies" &&
./$bin "curl -L https://raw.githubusercontent.com/pspdev/pspdev/master/prepare-debian-ubuntu.sh > i.sh && chmod +x ./i.sh && ./i.sh -y && rm i.sh" &&
echo "downloading pspdev" &&
wget https://github.com/pspdev/pspdev/releases/download/v20220202/pspdev-ubuntu-${uv}-${psparch}.tar.gz -O "$cur/pspdev.tar.gz" &&
echo "extracting pspdev..." &&
cd "$folder/usr/local/" &&
tar -xzf "$cur/pspdev.tar.gz" &&
rm "$cur/pspdev.tar.gz" &&
cd "$cur" &&
./$bin "unminimize"
echo "exporting needed environmental variables for pspdev" &&
echo "export PSPDEV=/usr/local/pspdev" >> "$folder/root/.bashrc" &&
echo "export PATH=/usr/local/pspdev/bin:\$PATH" >> "$folder/root/.bashrc" &&
echo "You can now launch Ubuntu pspdev with the ./${bin} script"
