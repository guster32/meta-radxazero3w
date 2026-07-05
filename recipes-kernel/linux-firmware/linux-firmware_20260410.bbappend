# linux-firmware 20260410 wicp/wrynose regression: do_install emits
# `install: cannot stat '/.../rt2870.bin': No such file or directory`
# after copy-firmware.sh's WHENCE grep loop. copy-firmware.sh upstream
# 20260410 has NO `install -m` line, the Makefile `install:` target
# only does install -d + ./copy-firmware.sh, and the upstream bb's
# `do_install:append()` (line 1427) only does an `ln -fs`. The error
# message path is `$WORKDIR/rt2870.bin`, which is a workload path.
# We could not trace the artisan caller without reading
# run.do_install.<pid> scripts stored in the runner container's
# temp dir.
#
# We've tried two paths and both still emit the install error after
# successfully stripping rt2870 from WHENCE. Some wicp/oe-core hook
# (or wicp/yocto ship bbclass) emits an install call that reads the
# WHENCE entries again as part of a stamp-validation pass. We can't
# fingerprint it, but we can short-circuit it: do the install
# entirely from our bbappend without invoking the upstream
# `oe_runmake install` pipeline. That removes both copy-firmware.sh
# AND the artisan install call from the picture.
#
# drop this bbappend entirely when linux-firmware upstream ralink
# removals converge and the install -m diagnostic disappears from
# upstream do_install. (i.e. when our override could be removed.)
#
# NOTE: `do_install() { ... }` here REPLACES upstream's do_install
# body, which only invokes `oe_runmake install + dedup` and the
# post-REMOVE loop. We replicate both here with WHENCE-only file
# copies driven by `install -m 0644`, then unconditionally clean up
# the rt2870/rt3070/rt2860/rt3090 stub slots. Upstream's lone
# `do_install:append()` (ln -fs mrvl/sd8997_uapsta.bin) still runs
# AFTER our do_install and pre-creates that symlink correctly.

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware

    # Persist diagnostic snapshots so the next GHA run uploads them.
    install -d "${T}/diag" 2>/dev/null || true
    if [ -f "${S}/WHENCE" ]; then
        # Always re-strip WHENCE defensively: scope of the helper here
        # is scope of the do_install() itself, so any upstream filter
        # earlier in the chain isn't load-bearing.
        grep -E '^(Raw)?File:' "${S}/WHENCE" \
            | awk '{print $1}' \
            | sort -u > "${T}/diag/whence.post-filter.files.txt"
        grep -E '^Link:' "${S}/WHENCE" \
            | awk '{print $1}' \
            | sort -u > "${T}/diag/whence.post-filter.links.txt"
    fi

    # File: / RawFile: -- copy each firmware file.
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
    fi

    # Link: -- symlinks. Guard so missing targets (rt3070 -> rt2870
    # etc.) never abort the script.
    if [ -f "${S}/WHENCE" ]; then
        grep -E '^Link:' "${S}/WHENCE" \
            | sed -E -e 's/^Link: *//g;s/-> *//g' \
            | while read l t; do
                if [ -e "${S}/$t" ]; then
                    install -d "$(dirname ${D}${nonarch_base_libdir}/firmware/$l)"
                    ln -sf "$t" "${D}${nonarch_base_libdir}/firmware/$l"
                fi
            done
    fi

    # Top-dir license files.
    if [ -f "${S}/WHENCE" ]; then
        install -m 0644 "${S}/WHENCE" "${D}${nonarch_base_libdir}/firmware/"
    fi
    cp LICEN[CS]E.* ${D}${nonarch_base_libdir}/firmware/ 2>/dev/null || true
    if [ -d "${S}/wfx" ]; then
        install -d ${D}${nonarch_base_libdir}/firmware/wfx
        cp ${S}/wfx/LICEN[CS]E.* ${D}${nonarch_base_libdir}/firmware/wfx/ 2>/dev/null || true
    fi

    # Re-emulate upstream REMOVE_UNLICENSED cleanup. Use `rm -f` so
    # absent targets don't abort.
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

# Belt: defensively remove ralink stubs in \$D if anything replays
# them. rm -f is silent and idempotent.
do_install:append() {
    rm -f ${D}${nonarch_base_libdir}/firmware/rt2870.bin
    rm -f ${D}${nonarch_base_libdir}/firmware/rt3070.bin
    rm -f ${D}${nonarch_base_libdir}/firmware/rt2860.bin
    rm -f ${D}${nonarch_base_libdir}/firmware/rt3090.bin
}
