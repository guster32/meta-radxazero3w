FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}-6.6:"


SRC_URI:append = " file://radxa-kmeta;type=kmeta;name=radxa-kmeta;destsuffix=radxa-kmeta"
SRC_URI:append = " file://radxa/radxa-arm64.scc"


COMPATIBLE_MACHINE:radxa-zero3w = "radxa-zero3w"
