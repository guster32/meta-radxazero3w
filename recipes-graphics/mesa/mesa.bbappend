# The Wrynose Mesa recipe gates the Panfrost Gallium driver on libclc. Without
# it, the build emits libdril_dri.so but no panfrost_dri.so loader entry, so
# wlroots falls back to software rendering or fails EGL initialization.
PACKAGECONFIG:append:radxa-zero3w = " libclc panfrost"
