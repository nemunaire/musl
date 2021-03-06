# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI="5"

inherit autotools eutils flag-o-matic multilib-minimal

DESCRIPTION="Libraries/utilities to handle ELF objects (drop in replacement for libelf)"
HOMEPAGE="https://fedorahosted.org/elfutils/"
SRC_URI="https://fedorahosted.org/releases/e/l/${PN}/${PV}/${P}.tar.bz2"

LICENSE="|| ( GPL-2+ LGPL-3+ ) utils? ( GPL-3+ )"
SLOT="0"
KEYWORDS="amd64 arm ia64 ~mips ppc sh sparc x86"
IUSE="bzip2 lzma nls static-libs test +threads +utils"

# This pkg does not actually seem to compile currently in a uClibc
# environment (xrealloc errs), but we need to ensure that glibc never
# gets pulled in as a dep since this package does not respect virtual/libc
RDEPEND=">=sys-libs/zlib-1.2.8-r1[${MULTILIB_USEDEP}]
	bzip2? ( >=app-arch/bzip2-1.0.6-r4[${MULTILIB_USEDEP}] )
	lzma? ( >=app-arch/xz-utils-5.0.5-r1[${MULTILIB_USEDEP}] )
	!dev-libs/libelf
	abi_x86_32? (
		!<=app-emulation/emul-linux-x86-baselibs-20130224-r11
		!app-emulation/emul-linux-x86-baselibs[-abi_x86_32(-)]
	)"
DEPEND="${RDEPEND}
	nls? ( sys-devel/gettext )
	>=sys-devel/flex-2.5.4a
	sys-devel/m4
	elibc_musl? (
		sys-libs/argp-standalone
		sys-libs/fts-standalone
		sys-libs/obstack-standalone
	)"

src_prepare() {
	epatch "${FILESDIR}"/${PN}-0.118-PaX-support.patch

	# Add MUSL patches
	epatch "${FILESDIR}"/${P}-musl-obstack-fts.patch
	epatch "${FILESDIR}"/${P}-musl-libs.patch
	epatch "${FILESDIR}"/${P}-musl-utils.patch

	eautoreconf

	use static-libs || sed -i -e '/^lib_LIBRARIES/s:=.*:=:' -e '/^%.os/s:%.o$::' lib{asm,dw,elf}/Makefile.in
	sed -i 's:-Werror::' */Makefile.in
	# some patches touch both configure and configure.ac
	find -type f -exec touch -r configure {} +
}

src_configure() {
	use test && append-flags -g #407135
	multilib-minimal_src_configure
}

multilib_src_configure() {
	ECONF_SOURCE="${S}" econf \
		$(use_enable nls) \
		$(use_enable threads thread-safety) \
		--program-prefix="eu-" \
		--with-zlib \
		--disable-symbol-versioning \
		$(use_with bzip2 bzlib) \
		$(use_with lzma)
}

multilib_src_test() {
	env	LD_LIBRARY_PATH="${BUILD_DIR}/libelf:${BUILD_DIR}/libebl:${BUILD_DIR}/libdw:${BUILD_DIR}/libasm" \
		LC_ALL="C" \
		emake check || die
}

multilib_src_install_all() {
	einstalldocs
	dodoc NOTES
	# These build quick, and are needed for most tests, so don't
	# disable their building when the USE flag is disabled.
	use utils || rm -rf "${ED}"/usr/bin
}
