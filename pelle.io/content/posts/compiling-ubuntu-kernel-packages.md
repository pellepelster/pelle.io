---
title: "Compiling Ubuntu Kernel Packages"
date: 2022-11-01T20:00:00+01:00
draft: false
---

Although the situation greatly improved over the last 10 years, with very new hardware under Linux you sometimes may run into hardware compatibility issues. The following guide shows how to build an installable Ubuntu/Debian kernel package from a Linux kernel source tree.

This post is based on a wakeup-from-sleep issue that I had with my new Lenovo ThinkPad T14s G3. The Wi-Fi card had trouble coming back from sleep and the system ran into IO issues after wakeup looking the whole system. So hopefully all those keywords land in the Google index and may help the next person to work around the issue until the final fix is upstreamed into the linux kernel.

To prepare for compiling the kernel, the first step is to install all needed prerequisites

```shell
$ sudo apt-get install \
    git \
    build-essential \
    fakeroot \
    libncurses5-dev \
    libssl-dev \
    ccache \
    bison \
    flex \
    libelf-dev \
    dwarves
```

Now the important question: what to build? In my case I am on an Ubuntu based distribution called PopOS, that manages its own kernel source tree under `https://github.com/pop-os/linux`, and the fix I am looking for lives at `https://git.kernel.org/pub/scm/linux/kernel/git/kvalo/ath.git/commit/drivers/net/wireless/ath/ath11k?h=ath-next&id=d99884ad9e3673a12879bc2830f6e5a66cccbd78`.

So the first step is to fork and clone the PopOS linux kernel source tree, add the repository with the fix and cherry pick the fix into our fork

```shell
$ git clone git@github.com:pellepelster/linux-t14sg3.git
$ cd linux-t14sg3

$ git remote add ath git://git.kernel.org/pub/scm/linux/kernel/git/kvalo/ath.git
$ git fetch ath
$ git cherry-pick d99884ad9e3673a12879bc2830f6e5a66cccbd78
```

To ensure the kernel is compiled with a configuration that matches the currently running kernel we use the config of the current kernel that stored in the `/boot/` folder as a starting point. 

> Ubuntu/Debian uses a set of keys for code signing that we obviously don't possess, so we have to disable this option for our build. 

```shell

$ cp /boot/config-$(uname -r) .config
$ ./scripts/config --disable SYSTEM_TRUSTED_KEYS
$ ./scripts/config --disable SYSTEM_REVOCATION_KEYS
```

Now we can create a kernel configuration based on that config, and start the build (be patient this may take a while)

```shell
$ make olddefconfig
$ make clean
$ make -j $(getconf _NPROCESSORS_ONLN) deb-pkg LOCALVERSION=-t14sg3
```

After the build the installable packages are saved to the parent folder and can be installed

```shell
$ cd ..
sudo dpkg -i linux-headers-6.0.3-t14sg3_6.0.3-t14sg3-1_amd64.deb
sudo dpkg -i linux-image-6.0.3-t14sg3_6.0.3-t14sg3-1_amd64.deb 
```

For all users that are affected by the same issues, here the built PopOS kernel images with the fix:

* [linux-headers-6.0.3-t14sg3_6.0.3-t14sg3-1_amd64.deb](http://pelle.io/static/linux-headers-6.0.3-t14sg3_6.0.3-t14sg3-1_amd64.deb)
* [linux-image-6.0.3-t14sg3_6.0.3-t14sg3-1_amd64.deb](http://pelle.io/static/linux-image-6.0.3-t14sg3_6.0.3-t14sg3-1_amd64.deb)


