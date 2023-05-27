# Cert Update

Method and tools for creating limited users in a chroot environment intended 
for performing certificate update, though the utility of the methods go way
beyond that.

## Setting up the environment

### Create a chroot directory

```
mkdir -p /var/chroot
```

Make certain the directory is owned by `root`.  

### Create a user that will have the limited rights in the chroot

```
useradd -M -R /var/chroot/home/certupdate certupdate
```

### Create the devices

These devices are needed by the login shell

```
mkdir /var/chroot/dev
mknod -m 666 null c 1 3
mknod -m 666 tty c 5 0
mknod -m 666 zero c 1 5
mknod -m 666 random c 1 8
```

### Copy the binaries 

You need to copy whatever binaries you want the chroot user to have access to the chroot environment as well as the dependent shared libraries.

For example, for `bash`

```
mkdir /var/chroot/bin
cp /bin/bash /var/chroot/bin

ldd /bin/bash
	linux-vdso.so.1 (0x00007ffe60f78000)
	libtinfo.so.5 => /lib/x86_64-linux-gnu/libtinfo.so.5 (0x00007fd3a0d4c000)
	libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007fd3a0b48000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007fd3a0757000)
	/lib64/ld-linux-x86-64.so.2 (0x00007fd3a1290000)
```

The first library is virtual but the rest need to be copied to the chroot:

```
mkdir -p /var/chroot/lib/x86_64-linux-gnu
mkdir -p /var/chroot/lib64
cp /lib/x86_64-linux-gnu/{libtinfo.so.5,libdl.so.2,libc.so.6} /var/chroot/lib/x86_64-linux-gnu
cp /lib64/ld-linux-x86-64.so.2 /var/chroot/lib64
```

Alternatively, use the tool in this repository, `chrootcp.pl` to copy the binaries and the dependencies:

```
cp /var/chroot
perl chrootcp.pl /bin/bash
perl chrootcp.pl /bin/cp
perl chrootcp.pl /bin/ls
perl chrootcp.pl /bin/rm
```

### Create /etc files

```
mkdir /var/chroot/etc
cp /etc/{passwd,group,nsswitch.conf} /var/chroot/etc
```

Question: what users ? groups are needed in the chroot jail?

### Compying NSS Libraries

`ldd` only shows what the binary is linked with, but wha tmight be dynamically loaded.  
NSS will dynamically load a shared library based on the contents of `nsswitch.conf` when 
a name lookup is performed, for example, when you scp a file from your client to the
chroot jail. The simplest way to deal with this is:

```
cp /lib/x86_64-linux-gnu/libnss*.so.* /var/chroot/lib/x86_64-linux-gnu/
```

The precise location will vary per system.  The above works for ubuntu 20.  Running `sctrace`
on the host system for the chroot jail can get you the needed details:

```
root:/var/chroot# strace scp 2>&1 | grep 'nss.*so'
openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libnss_compat.so.2", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libnss_nis.so.2", O_RDONLY|O_CLOEXEC) = 3
openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libnss_files.so.2", O_RDONLY|O_CLOEXEC) = 3
```

Copying these three shared libraries (in this example) makes things work smoothly.

For reference, the error received when `scp` fails (due to the name lookup failing 
because of the missing libraries) is the barely helpful:

```
unknown user 1003
lost connection
```

The userid will vary based on your `/etc/passwd`

Alternatively, you can look at using `sftp` which works in a differnet manner.  But I am 
stubborn.

Useful documentation on NSS [here](https://www.gnu.org/software/libc/manual/html_node/Services-in-the-NSS-configuration.html).

### Modify sshd_config

Add the following to /etc/ssh/sshd_config

```
Match User certupdate
ChrootDirectory /home/certupdate
```

Restart sshd:

```
service sshd restart
```

### Add the public key to the jailed user's authorized_keys

```
mkdir /var/chroot/home/certupdate/.ssh
# Create / add public key to ~/.ssh/authorized_keys
```

### Optional: set user shell to bash:

Edit `/var/chroot/etc/passwd`

## Special instructions for docker

If the user need to exec / restart docker containers we need to make the docker environment available to the chroot jail.  This will be done by:

- Copying the docker binary over ( and dependencies )
- Moving the dockerd socket to the jail
- Modifying the systemd stuff to use the new location for the socket
- Changing any docker / docker-compose files to use the new socket location

### Copy docker

Just use the script:

```
cd /var/chroot
perl chrootcp.pl /usr/bin/docker
```

### Creating the dockerd socket in the jail

For example, let's move it to `/var/chroot/var/run/docker.sock` by editing /lib/systemd/system/docker.socket by changing:

```
ListenStream=/var/run/docker.sock
```

to 

```
ListenStream=/var/chroot/var/run/docker.sock
```

Next you need to edit any services starting docker container with the `DOCKER_HOST` environment variable by putting the following in the `[Service]` section:

Environment=DOCKER_HOST=unix:///var/chroot/var/run/docker.sock

### Changing any docker-compose files

Lastly, there may be docker command or docker compose files that need access to the new location of the socket. A volume command like:


```
      - /var/run/docker.sock:/tmp/docker.sock:ro
```
 
Would be need to changed to:

```
      - /var/chroot/var/run/docker.sock:/tmp/docker.sock:ro
```


### Reload services

```
systemctl daemon-reload
service docker restart
```

## Final file tree for reference

```
.
├── bin
│   ├── bash
│   ├── cat
│   ├── cp
│   ├── ls
│   └── rm
├── dev
│   ├── null
│   ├── random
│   ├── tty
│   └── zero
├── etc
│   ├── certs
│   │   ├── [This is where certs will go - nginx points here]
│   ├── group
│   ├── nsswitch.conf
│   └── passwd
├── home
│   └── certupdate
├── lib
│   └── x86_64-linux-gnu
│       ├── libacl.so.1
│       ├── libattr.so.1
│       ├── libc.so.6
│       ├── libdl.so.2
│       ├── liblzma.so.5
│       ├── libnss_compat.so.2
│       ├── libnss_files.so.2
│       ├── libnss_nis.so.2
│       ├── libpcre.so.3
│       ├── libpthread.so.0
│       ├── libselinux.so.1
│       └── libtinfo.so.5
├── lib64
│   └── ld-linux-x86-64.so.2
├── usr
│   ├── bin
│   │   ├── docker
│   │   ├── scp
│   │   ├── strace [extra libraries brought in by strace]
│   │   └── whoami
│   └── lib
│       └── x86_64-linux-gnu
│           ├── libunwind-ptrace.so.0
│           ├── libunwind.so.8
│           └── libunwind-x86_64.so.8
└── var
    ├── letsencrypt 
        ├── [location for http-01 challenge files]
    └── run
        └── docker.sock
```

