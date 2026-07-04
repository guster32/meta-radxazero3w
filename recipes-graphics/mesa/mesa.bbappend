
# Radxa Zero 3W uses the Mali-G52 GPU through the Panfrost driver.
# Mesa 26.0.x (wrynose 6.0) dropped the rockchip PACKAGECONFIG: it doesn't
# ship a rockchip gallium driver anymore — modern radxa BSPs are expected
# to use Panfrost (or v4l2-egl for the drm accelerator layer) instead.
#
# gallium  : meta-PACKAGECONFIG that folds GALLIUMDRIVERS into a single
#            -Dgallium-drivers=... flag, set so the platform drivers below
#            compose into a single build.
# etnaviv  : for the on-board Display(via vivante) chip — we keep the
#            gbm-only branch because radxa-zero3w has no vivante GPU.
# panfrost : Mali-G52 / Mali-G31 driver (Mali uses Panfrost via DRM).
# lima     : older Mali (Mali-400/450); included as a no-op safety net —
#            the build will collate it into the gallium-drivers list but
#            the runtime picks panfrost for G52.
PACKAGECONFIG:append = " gallium panfrost lima "
