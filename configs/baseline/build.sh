#!/usr/bin/env bash

set -e -u

iso_name=archlinux
iso_label="ARCH_$(date +%Y%m)"
iso_version=$(date +%Y.%m.%d)
install_dir=arch
arch=$(uname -m)
work_dir=work
out_dir=out

script_path="$( cd -P "$( dirname "$(readlink -f "$0")" )" && pwd )"

umask 0022

# Helper function to run make_*() only one time per architecture.
run_once() {
    if [[ ! -e "${work_dir}/build.${1}_${arch}" ]]; then
        "$1"
        touch "${work_dir}/build.${1}_${arch}"
    fi
}

# Base installation (airootfs)
make_basefs() {
    mkarchiso -v -w "${work_dir}" -D "${install_dir}" init
}

# Copy mkinitcpio archiso hooks and build initramfs (airootfs)
make_setup_mkinitcpio() {
    mkdir -p "${work_dir}/airootfs/etc/initcpio/hooks"
    mkdir -p "${work_dir}/airootfs/etc/initcpio/install"
    cp /usr/lib/initcpio/hooks/archiso "${work_dir}/airootfs/etc/initcpio/hooks"
    cp /usr/lib/initcpio/install/archiso "${work_dir}/airootfs/etc/initcpio/install"
    cp "${script_path}/mkinitcpio.conf" "${work_dir}/airootfs/etc/mkinitcpio-archiso.conf"
    mkarchiso -v -w "${work_dir}" -D "${install_dir}" \
        -r 'mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img' run
}

# Prepare ${install_dir}/boot/
make_boot() {
    mkdir -p "${work_dir}/iso/${install_dir}/boot/${arch}"
    cp "${work_dir}/airootfs/boot/archiso.img" "${work_dir}/iso/${install_dir}/boot/${arch}/archiso.img"
    cp "${work_dir}/airootfs/boot/vmlinuz-linux" "${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz"
}

# Prepare /${install_dir}/boot/syslinux
make_syslinux() {
    mkdir -p "${work_dir}/iso/${install_dir}/boot/syslinux"
    sed "s|%ARCHISO_LABEL%|${iso_label}|g;
         s|%INSTALL_DIR%|${install_dir}|g;
         s|%ARCH%|${arch}|g" "${script_path}/syslinux/syslinux.cfg" > \
             "${work_dir}/iso/${install_dir}/boot/syslinux/syslinux.cfg"
    cp "${work_dir}/airootfs/usr/lib/syslinux/bios/ldlinux.c32" "${work_dir}/iso/${install_dir}/boot/syslinux/"
    cp "${work_dir}/airootfs/usr/lib/syslinux/bios/menu.c32" "${work_dir}/iso/${install_dir}/boot/syslinux/"
    cp "${work_dir}/airootfs/usr/lib/syslinux/bios/libutil.c32" "${work_dir}/iso/${install_dir}/boot/syslinux/"
}

# Prepare /isolinux
make_isolinux() {
    mkdir -p "${work_dir}/iso/isolinux"
    sed "s|%INSTALL_DIR%|${install_dir}|g" "${script_path}/isolinux/isolinux.cfg" > \
        "${work_dir}/iso/isolinux/isolinux.cfg"
    cp "${work_dir}/airootfs/usr/lib/syslinux/bios/isolinux.bin" "${work_dir}/iso/isolinux/"
    cp "${work_dir}/airootfs/usr/lib/syslinux/bios/isohdpfx.bin" "${work_dir}/iso/isolinux/"
    cp "${work_dir}/airootfs/usr/lib/syslinux/bios/ldlinux.c32" "${work_dir}/iso/isolinux/"
}

# Build airootfs filesystem image
make_prepare() {
    mkarchiso -v -w "${work_dir}" -D "${install_dir}" prepare
}

# Build ISO
make_iso() {
    mkarchiso -v -w "${work_dir}" -D "${install_dir}" -L "${iso_label}" -o "${out_dir}" iso \
        "${iso_name}-${iso_version}-${arch}.iso"
}

run_once make_basefs
run_once make_setup_mkinitcpio
run_once make_boot
run_once make_syslinux
run_once make_isolinux
run_once make_prepare
run_once make_iso
