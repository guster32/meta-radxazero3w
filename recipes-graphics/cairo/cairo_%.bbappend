DEPENDS:append = " ${PREFERRED_PROVIDER_virtual/gpu}"

RDEPENDS:${PN} = "${PREFERRED_PROVIDER_virtual/gpu}"
RDEPENDS:cairo-script-interpreter = "${PREFERRED_PROVIDER_virtual/gpu}"
RDEPENDS:cairo-gobject = "${PREFERRED_PROVIDER_virtual/gpu}"

PACKAGECONFIG:append = " glesv2 "
PACKAGECONFIG:remove = "opengl"