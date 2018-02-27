FROM debian:stretch-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    debootstrap \
    dosfstools \
    memtest86+ \
    parted \
    pciutils \
    squashfs-tools \
    syslinux \
    syslinux-common \
    && rm -rf /var/lib/apt/lists/*

COPY xixer.sh syslinux.cfg /xixer/

WORKDIR /xixer

ENTRYPOINT ["/xixer/xixer.sh"]
