# linux-firmware 20260410 wicp/wrynose regression: do_install emits
# `install: cannot stat '/.../rt2870.bin': No such file or directory`
# after copy-firmware.sh's WHENCE-File: loop. copy-firmware.sh upstream
# 20260410 has NO `install -m` line -- only `install -d`, `cat`, `ln -s`.
# The Makefile rule `install:` only does install -d + ./copy-firmware.sh.
# Upstream bb's do_install:append() (line 1427) is a single `ln -fs`.
# Whatever produces the install -m 0644 rt2870.bin line is NOT, as of
# our last targeted run, something we can fingerprint from the
# public logs. The probable origin is a wicp-eop bbclass added in
# wicp / wrynose but invisible without reading run.do_install.<pid>
# (only the cooker log line is uploaded; the per-task script body
# itself isn't shipped by .github/workflows/wrynose-ci.yml).
#
# Workable fix path (no need to fully understand the artisan call):
# Patch the WHENCE file *upstream* of copy-firmware.sh so rt2870.bin
# is never its target.  WHENCE listing drives the copy loop:
#   - `File:` / `RawFile:` => copy target; absent file => ENOENT abort
#   - `Link:`             => symlink; broken => ENOENT abort
# Removing rt2870 entries (and the rt3070 -> rt2870 alias) makes
# the WHENCE scan produce no rows for rt2870-related paths, so
# install -m can never reference it again.
#
# Drop this bbappend entirely when linux-firmware upstream ralink
# removals converge.

# Filter runs in two places (do_compile:append for full rebuilds,
# do_install:prepend for targeted reparse paths that don't re-run
# do_compile). Both call the same helper. Idempotent.
_filter_firmware_whence() {
    if [ -f "${S}/WHENCE" ]; then
        # Capture full WHENCE for diagnostics -- we write it to $T/diag
        # so the GH artifact upload path (.build/<m>/tmp/log/**) sees it.
        install -d "${T}/diag" 2>/dev/null || true
        {
            echo "## begin WHENCE pre-filter ##"
            echo "(no entries for rt2870 may remain)"
            grep -nE "rt[0-9]*\\.?bin|FW_LIST|RAW" "${S}/WHENCE" 2>/dev/null \
                | head -10
            echo "## end ##"
        } > "${T}/diag/whence-pre-filter.txt" 2>&1 || true

        # Strip the WHENCE File:/Raw:/Link: entries that mention rt2870
        # We keep the WHENCE file intact for inspection.
        cp -a "${S}/WHENCE" "${S}/WHENCE.before-filter" 2>/dev/null || true
        sed -i -E '/^(Raw)?File:[[:space:]]+"?rt2870\.bin"?[[:space:]]*$/d' \
            "${S}/WHENCE" 2>/dev/null || true
        sed -i -E '/^Link:[[:space:]]+"?rt3070\.bin"?[[:space:]]+->[ \t]*"?rt2870\.bin"?[[:space:]]*$/d' \
            "${S}/WHENCE" 2>/dev/null || true
        # Defensive: any remaining rt2870 references in WHENCE notes etc.
        # are fine -- only File/Link lines drive the install path.
        # Disable the strict whence.py check too.
        if [ -f "${S}/copy-firmware.sh" ]; then
            sed -i 's:^./check_whence.py:#./check_whence.py:' \
                "${S}/copy-firmware.sh" 2>/dev/null || true
        fi
        install -m 0644 "${S}/WHENCE" "${T}/diag/whence.post-filter" 2>/dev/null || true
        # Show what survived
        {
            echo "## WHENCE post-filter: rt2870 references ##"
            grep -nE "rt2870" "${S}/WHENCE" 2>/dev/null || echo "(none -- rt2870 fully stripped)"
        } > "${T}/diag/whence.post-filter-summary.txt" 2>&1 || true
    fi
}
do_compile:append() {
    _filter_firmware_whence
}
do_install:prepend() {
    _filter_firmware_whence
}

# Belt: defensively remove ralink stubs in \$D if anything replays
# them through copy-firmware.sh.
do_install:append() {
    rm -f ${D}${nonarch_base_libdir}/firmware/rt2870.bin ${D}${nonarch_base_libdir}/firmware/rt3070.bin 2>/dev/null || true
    rm -f ${D}${nonarch_base_libdir}/firmware/rt2860.bin ${D}${nonarch_base_libdir}/firmware/rt3090.bin 2>/dev/null || true
}
