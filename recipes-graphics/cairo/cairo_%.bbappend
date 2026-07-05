DEPENDS:append = " ${PREFERRED_PROVIDER_virtual/gpu}"

RDEPENDS:${PN} = "${PREFERRED_PROVIDER_virtual/gpu}"
RDEPENDS:cairo-script-interpreter = "${PREFERRED_PROVIDER_virtual/gpu}"
RDEPENDS:cairo-gobject = "${PREFERRED_PROVIDER_virtual/gpu}"

# cairo 1.18.4 (wrynose 6.0) dropped the 'glesv2' PACKAGECONFIG. The
# flag used to toggle -Dglesv2 on/off directly; today the meson option
# is 'gl-backend=gles2' and is enabled indirectly via the gbm/gpu
# virtualisation chain (handled by upstream noop now).
# Was: PACKAGECONFIG:append = " glesv2 "
# Was: PACKAGECONFIG:remove = "opengl"
# Both no longer valid; explicit noop keep here for readability.