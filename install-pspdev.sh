#!/data/data/com.termux/files/usr/bin/bash
folder=ubuntu-pspdev-fs
uv=22.04
tarball="ubuntu${uv}.tar.gz"
if [ "$first" != 1 ];then
	if [ ! -f $tarball ]; then
		echo "downloading ubuntu-image"
		case `dpkg --print-architecture` in
		aarch64)
			archurl="arm64" ;;
		arm)
			archurl="armhf" ;;
		amd64)
			archurl="amd64" ;;
		i*86)
			archurl="i386" ;;
		x86_64)
			archurl="amd64" ;;
		*)
			echo "unknown architecture"; exit 1 ;;
		esac
		wget "https://cdimage.ubuntu.com/ubuntu-base/releases/${uv}/release/ubuntu-base-${uv}-base-${archurl}.tar.gz" -O "$tarball"
	fi
	cur=`pwd`
echo removing any existing "$folder"
  rm -rf "$folder"
	mkdir -p "$folder"
	cd "$folder"
	echo "decompressing ubuntu image"
	proot --link2symlink tar -xf "${cur}/${tarball}" --exclude='dev'||:
echo removing ubunto image tarball
rm "${cur}/${tarball}"
	echo "fixing nameserver, otherwise it can't connect to the internet"
	echo "nameserver 1.1.1.1" > etc/resolv.conf
	cd "$cur"
fi
mkdir -p binds
bin=start-ubuntu-pspdev.sh
echo "writing launch script"
cat > $bin <<- EOM
#!/bin/bash
cd \$(dirname \$0)
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
command+=" --link2symlink"
command+=" -0"
command+=" -r $folder"
if [ -n "\$(ls -A binds)" ]; then
    for f in binds/* ;do
      . \$f
    done
fi
command+=" -b /dev"
command+=" -b /proc"
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
./$bin "rm /bin/sh; ln -s bash /bin/sh" &&
echo "exporting needed environmental variables for pspdev" &&
echo "export PSPDEV=/PSPDEV-ANDROID" >> "$folder/root/.bashrc" &&
echo "export PATH=/PSPDEV-ANDROID/bin:\$PATH" >> "$folder/root/.bashrc" &&
echo "updating apt for pspdev" &&
./$bin "apt update && apt install -y dialog && apt upgrade -y" &&
echo "installing packages for pspdev" &&
./$bin "apt install -y sudo git libipt* python2 libdebuginfo*" &&
echo cloning pspdev &&
./$bin git clone https://www.github.com/pspdev/pspdev &&
echo preparing pspdev &&
./$bin "cd pspdev ; ./prepare-debian-ubuntu.sh" &&
echo building pspdev &&
./$bin "cd pspdev ; ./build-all.sh" &&
echo "You can now launch Ubuntu pspdev with the ./${bin} script"
