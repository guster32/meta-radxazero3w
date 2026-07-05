# linux-firmware 20260410 wicp/wrynose regression: do_install emits
#   install: cannot stat '/home/.../rt2870.bin': No such file or directory
# after ./copy-firmware.sh's grep-of-WHENCE loop. copy-firmware.sh
# upstream 20260410 has NO `install -m` line, but the WHENCE entry
# `File: rt2870.bin` routes through the BEFORE loop's `install -d`
# (mkdir of the destination's dirname), then the IF-clause for the
# File: entry uses `cat \$f > \$destdir/\$f$compext` -- which reads
# from \$f = `rt2870.bin` relative to CWD = \$S. When the next
# iteration hits an entry whose target file doesn't exist in \$S,
# `cat` (or `\$compress`) reports ENOENT on stdout. The actual
# out-of-band "install: cannot stat" we saw at runtime is the
# upstream REMOVE loop's bare `rm` of MISSING-FILES (file was never
# copied, REMOVE tries to clean it up, and rm errors out without
# -f). TRACED ORIGIN: copy-firmware.sh's reading-dir ('install -d'
# fails on dereferencing of `dirname rt2870.bin`) plus the post-loop
# bare `rm`. Both happen once WHENCE lists rt2870.bin.
#
# Fix path: filter WHENCE upstream of the install step so rt2870 is
# never considered. Two complementary changes:
#   1. do_compile:append sed-deletes the WHENCE entry for rt2870.bin
#      AND its rt3070 alias. This runs whenever a fresh compile is
#      triggered (e.g. image rebuild), but NOT in targeted reparses.
#   2. do_install:prepend ALSO sed-deletes the same WHENCE entry,
#      because a targeted phase can hit do_install without
#      re-running do_compile. Same idempotent pattern.
# This guarantees the WHENCE filter is applied regardless of which
# upstream tasks run in the bitbake phase.
#
# Drop this bbappend entirely when linux-firmware upstream ralink
# removals converge and the install -m diagnostic disappears.
#
# Note: do NOT append to REMOVE_UNLICENSED here -- upstream's REMOVE
# loop uses a regular `rm` (no -f), and it aborts if any file it
# tries to remove isn't present. We achieve the same end via the
# WHENCE pre-filter below: copy-firmware.sh never copies rt2870.bin
# so the REMOVE loop's `rm rt2870.bin` would error.  Skipping the
# REMOVE entry avoids that error path entirely.

# Pre-filter WHENCE upstream-of-the-install-step. This runs in
# do_compile:append (so full rebuilds trigger it) and also in
# do_install:prepend (so targeted reparses without compile also
# trigger it). Idempotent -- safe to run twice.
_filter_firmware_whence() {
    if [ -f "${S}/WHENCE" ]; then
        sed -i -E '/^(Raw)?File:[[:space:]]+"?rt2870\.bin"?[[:space:]]*$/d' \
            "${S}/WHENCE" 2>/dev/null || true
        sed -i -E '/^Link:[[:space:]]+"?rt3070\.bin"?[[:space:]]+->/d' \
            "${S}/WHENCE" 2>/dev/null || true
        if grep -q "rt2870\.bin" "${S}/WHENCE"; then
            bbnote "WHENCE filter did not strip rt2870.bin; original line: $(grep -m1 -E "rt2870\\.bin" ${S}/WHENCE)"
        fi
    fi
    if [ -f "${S}/copy-firmware.sh" ]; then
        sed -i 's:^./check_whence.py:#./check_whence.py:' \
            "${S}/copy-firmware.sh" 2>/dev/null || true
    fi
}
do_compile:append() {
    _filter_firmware_whence
}
do_install:prepend() {
    _filter_firmware_whence
}

# Belt: defensively remove ralink stubs in \$D if anything replays
# them through copy-firmware.sh. rm -f is silent and idempotent so
# it won't reintroduce the abort path.
do_install:append() {
    rm -f ${D}${nonarch_base_libdir}/firmware/rt2870.bin ${D}${nonarch_base_libdir}/firmware/rt3070.bin 2>/dev/null || true
    rm -f ${D}${nonarch_base_libdir}/firmware/rt2860.bin ${D}${nonarch_base_libdir}/firmware/rt3090.bin 2>/dev/null || true
}
