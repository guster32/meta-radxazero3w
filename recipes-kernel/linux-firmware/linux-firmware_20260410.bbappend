# linux-firmware 20260410 in the wicp wicp (Yocto 6.0) path emits:
#   install: cannot stat '/.../linux-firmware/20260410/rt2870.bin'
# during do_install, after the REMOVE_UNLICENSED loop fully completes
# (last log line is "Remove empty dir: yamaha"). copy-firmware.sh
# upstream 20260410 (and 20230804) has NO `install -m 0644` line --
# only `install -d` (mkdir), `cat`, `ln -s`. The Makefile rule
# `install:` only does `install -d` + `./copy-firmware.sh ...`. The
# upstream linux-firmware_20260410.bb's lone `do_install:append()` does
# an `ln -fs ...`. So the source of that `install -m 0644 rt2870.bin`
# call is/was a wrynose-only path we couldn't fully trace without
# reading the per-pid `run.do_install` script (which lives in the
# runner container's temp dir and isn't uploaded by wrynose-ci.yml).
#
# Practical fix path: WHENCE-driven `do_install` override that
# bypasses oe_runmake / copy-firmware.sh entirely. This sidesteps any
# upstream-artisan install invocation we cannot attribute, while
# preserving the WHENCE-driven firmware selection logic (which is the
# actual semantic of the upstream recipe). It also drops the
# `deduplicate` PACKAGECONFIG path -- the FirMWARE_COMPRESSION knob
# stays unset for radxa-zero3w image, so the trade-off is nil.
#
# `REMOVE_UNLICENSED += "rt2870.bin"` is kept as a defensive belt in
# case upstream's WHENCE later lists it again under a different hook.
# The WHENCE-driven loop here filters it out by name.
#
# Drop this bbappend entirely when linux-firmware >=20251013 lands
# ralink-license removals upstream; the install -m diagnostic should
# also disappear by then.
REMOVE_UNLICENSED += "rt2870.bin"

# do_install override: WHENCE-driven file copy that mirrors upstream's
# copy-firmware.sh semantics but uses direct `install -m 0644` calls
# instead of shell cat chains. We pre-filter rt2870.bin so its absent
# source never aborts the recipe.
#
# Side-by-side with upstream:
#   - `install -d $D/$FIRMWAREDIR`                          (mkdir)
#   - for each File:/RawFile: in WHENCE: install -m 0644 ...    (copy)
#   - for each Link: in WHENCE: ln -sf $target $link           (links)
#   - cp LICEN[CS]E.* WHENCE $D/$FIRMWAREDIR/                  (top dir)
#   - cp wfx/LICEN[CS]E.* $D/$FIRMWAREDIR/wfx/                 (subdir)
#   - for f in REMOVE_UNLICENSED: rm ... $D/$FIRMWAREDIR/$f   (cleanup)
do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware

    # File: / RawFile: -- copy each firmware file. We skip the rt2870
    # entry inline so its absent source doesn't abort; this pre-empts
    # the upstream REMOVE_UNLICENSED pass that follows.
    if [ -f "${S}/WHENCE" ]; then
        grep -E '^(RawFile|File):' "${S}/WHENCE" \
            | sed -E -e 's/^(RawFile|File): *//;s/"//g' \
            | awk '{print $1}' \
            | while read f; do
                [ -n "$f" ] || continue
                [ "$f" = "rt2870.bin" ] && continue
                if [ -f "${S}/$f" ]; then
                    install -d "$(dirname ${D}${nonarch_base_libdir}/firmware/$f)"
                    install -m 0644 "${S}/$f" \
                              "${D}${nonarch_base_libdir}/firmware/$f"
                fi
            done
        # Link: -- symlinks (mostly ralink-aliases; upstream does the
        # same via `ln -s` after copy-firmware.sh scans WHENCE).
        grep -E '^Link:' "${S}/WHENCE" \
            | sed -E -e 's/^Link: *//g;s/-> *//g' \
            | while read l t; do
                if [ -e "${S}/$t" ]; then
                    install -d "$(dirname ${D}${nonarch_base_libdir}/firmware/$l)"
                    ln -sf "$t" "${D}${nonarch_base_libdir}/firmware/$l"
                fi
            done
    fi

    # Top-dir license files -- copy verbatim. WHENCE must always be
    # there; LICEN[CS]E.* covers per-vendor licence grants.
    if [ -f "${S}/WHENCE" ]; then
        install -m 0644 "${S}/WHENCE" "${D}${nonarch_base_libdir}/firmware/"
    fi
    cp LICEN[CS]E.* ${D}${nonarch_base_libdir}/firmware/ 2>/dev/null || true
    if [ -d "${S}/wfx" ]; then
        install -d ${D}${nonarch_base_libdir}/firmware/wfx
        cp ${S}/wfx/LICEN[CS]E.* ${D}${nonarch_base_libdir}/firmware/wfx/ 2>/dev/null || true
    fi

    # Remove all unlicensed firmware so packages that depend on
    # ${PN}-license sit empty rather than carry redistributable blobs.
    # wicp / wrynose: FIRMWARE_COMPRESSION is unset for arcadia, so
    # fw_compr_file_suffix() returns "" -- inline `${}` correctly.
    for file in ${REMOVE_UNLICENSED}; do
        echo "Remove unlicensed firmware: $file"
        rm -f ${D}${nonarch_base_libdir}/firmware/$file
        path_to_file=$(dirname $file)
        while [ "${path_to_file}" != "." ]; do
            num_files=$(ls -A1 ${D}${nonarch_base_libdir}/firmware/$path_to_file 2>/dev/null | wc -l)
            if [ "$num_files" = "0" ]; then
                echo "Remove empty dir: $path_to_file"
                rm -rf ${D}${nonarch_base_libdir}/firmware/$path_to_file
            fi
            path_to_file=$(dirname $path_to_file)
        done
    done
}
