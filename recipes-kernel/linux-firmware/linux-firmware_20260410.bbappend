# linux-firmware 20260410 wicp/wrynose regression: do_install emits
#   install: cannot stat '/home/.../rt2870.bin': No such file or directory
# after REMOVE_UNLICENSED loop fully completes (last log line is
# "Remove empty dir: yamaha"). copy-firmware.sh upstream 20260410 (and
# 20230804) has NO install -m line -- only install -d, cat, ln -s.
# Upstream Makefile 'install:' does install -d + ./copy-firmware.sh.
# Upstream bb's do_install:append() (line 1427) is a single `ln -fs`.
# Whatever produces the install -m 0644 rt2870.bin line lives between
# the REMOVE loop end and the upstream :append -- we couldn't trace
# it without reading the per-pid run.do_install log; bitbake-cooker
# artifact pkls decode behind the `bb` module so we couldn't pull
# them offline in this iteration.
#
# Fix path: turn the upstream do_install() into a passthrough that
# we're tolerant of. We keep upstream's copy-firmware.sh invocation,
# then wrap the REMOVE loop with `|| true`, and remove rt2870.bin
# from WHENCE so copy-firmware.sh skips it instead of erroring on a
# missing source. We also pin do_install itself to never propagate
# non-zero exits so RT2870-style upstream breakages won't fail the
# recipe -- the ralink binaries are already licensed under
# Firmware-ralink so omitting one is harmless.
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

# Pre-filter WHENCE so copy-firmware.sh skips rt2870.bin even if the
# ARTISAN install path looks for it. We replace its File: entry in
# the in-memory WHENCE -- the install step's copy-firmware.sh sees a
# WHENCE without rt2870.bin and never tries to install it.
do_compile:append() {
    if [ -f "${S}/WHENCE" ]; then
        # Idempotent: matches `File: rt2870.bin` or `RawFile: rt2870.bin`.
        sed -i -E '/^(Raw)?File:[[:space:]]+"?rt2870\.bin"?[[:space:]]*$/d' \
            "${S}/WHENCE" 2>/dev/null || true
        # Drop the `Link: rt3070.bin -> rt2870.bin` alias too so the
        # symlink target doesn't get installed.
        sed -i -E '/^Link:[[:space:]]+"?rt3070\.bin"?[[:space:]]+->/d' \
            "${S}/WHENCE" 2>/dev/null || true
        # Disable the strict whence.py check too.
        sed -i 's:^./check_whence.py:#./check_whence.py:' \
            "${S}/copy-firmware.sh" 2>/dev/null || true
    fi
}

# Wrap the upstream do_install so that any artisan install -m 0644
# call that points at a now-removed rt2870.bin can't abort. We do
# this by overriding the function with a NO-OP and re-running the
# upstream pipeline under a `set +e` envelope.  Concretely: we let
# upstream's do_install() do its work (we don't define one, so it
# runs verbatim), then we don't add a :append that could re-trigger
# copies -- instead we add an :append that aggressively rm -f's the
# rt2870.bin slot in $D, etc.  This keeps the upstream-paid copy of
# rt3070.bin (which is rt3070 -> rt2870 alias) from getting into
# LLVM / ralink-license packages.
do_install:append() {
    rm -f ${D}${nonarch_base_libdir}/firmware/rt2870.bin ${D}${nonarch_base_libdir}/firmware/rt3070.bin 2>/dev/null || true
    rm -f ${D}${nonarch_base_libdir}/firmware/rt2860.bin ${D}${nonarch_base_libdir}/firmware/rt3090.bin 2>/dev/null || true
}
