# xixer

A docker based tool for Debian Live install to USB

### Instructions

Build the docker image:
```bash
$ docker build -t xixer .
```

**WARNING**: `--usb-device` will be erased

Run `xixer` in the container:
```bash
$ docker run --privileged --rm -it xixer --hostname=xixer --usb-device=sdb
```

Options:
  - --hostname - hostname
  - --password - root password
  - --arch, --suite, --mirror - options passed to debootstrap
  - --usb-device - device name of the USB flash drive (e.g. sdb)

---
Inspired by Will Haley's article [Create a Custom Debian Live Environment (CD or USB)](https://willhaley.com/blog/custom-debian-live-environment/)
