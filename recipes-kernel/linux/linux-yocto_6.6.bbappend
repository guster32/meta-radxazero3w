FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}-6.6:"


SRC_URI:append = " file://odroid-kmeta;type=kmeta;name=odroid-kmeta;destsuffix=odroid-kmeta"
SRC_URI:append = " file://odroid/odroid-arm64.scc"


COMPATIBLE_MACHINE:radxa-zero3w = "radxa-zero3w"
