# Notes

The other things I need to do to get things working

## acme-challege directory

```
mkdir -p /var/chroot/var/letsencrypt/.well-known/acme-challenge
chown -R certupdate:certupdate /var/chroot/var/letsencrypt/.well-known/acme-challenge
```

## cert directory

```
mkdir /var/chroot/etc/certs
chown -R certupdate:certupdate /var/chroot/etc/certs
```

## Nginx in docker

Since symlinks to not work well (at all) in docker on some systems I need
to mount the chroot volumns for certs and acme-challenges.  In the docker-compose
file:

```
    volumes:
       ...
       - "/var/chroot/etc/certs:/etc/ssl"
       - "/var/chroot/var/letsencrypt:/var/www/letsencrypt"
       ...
```
