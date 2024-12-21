def make_dtb_boot_files(d):
    # Generate IMAGE_BOOT_FILES entries for device tree files listed in
    # KERNEL_DEVICETREE.
    alldtbs = d.getVar('KERNEL_DEVICETREE')

    def transform(dtb):
        base = os.path.basename(dtb)
        if dtb.endswith('dtb'):
            # eg: whatever/meson64_odroidc4.dtb has:
            #     DEPLOYDIR file: meson64_odroidc4.dtb
            #     destination: meson64_odroidc4.dtb
            return base
        elif dtb.endswith('dtbo'):
            # overlay dtb:
            # eg: amlogic/overlays/odroidc4/spi0.dtbo has:
            #     DEPLOYDIR file: spi0.dtbo
            #     destination: amlogic/overlays/odroidc4/spi0.dtbo
            return '{};{}'.format(base, dtb)

    return ' '.join([transform(dtb) for dtb in alldtbs.split(' ') if dtb])
