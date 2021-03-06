HOMEPAGE = "http://www.x.org"
SECTION = "x11/utils"
LICENSE = "MIT-X"

XORG_PN = "${BPN}"

SRC_URI = "${XORG_MIRROR}/individual/util/${XORG_PN}-${PV}.tar.gz"

S = "${WORKDIR}/${XORG_PN}-${PV}"

inherit autotools_stage pkgconfig
