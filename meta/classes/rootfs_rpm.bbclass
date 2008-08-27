#
# Creates a root filesystem out of rpm packages
#

ROOTFS_PKGMANAGE = "opkg" 
# "rpm" "yum"
ROOTFS_PKGMANAGE_BOOTSTRAP  = "run-postinsts"

do_rootfs[depends] += "rpm-native:do_populate_staging yum-native:do_populate_staging createrepo-native:do_populate_staging fakechroot-native:do_populate_staging"
do_rootfs[recrdeptask] += "do_package_write_rpm"

YUMCONF = "${IMAGE_ROOTFS}/etc/yum.conf"
YUMARGS = "-c ${YUMCONF} --installroot ${IMAGE_ROOTFS}"

fakeroot rootfs_rpm_do_rootfs () {
	set -x

	# Update the repository index
	createrepo ${DEPLOY_DIR_RPM}

	mkdir -p ${IMAGE_ROOTFS}/etc/rpm/
	#echo "arm" > ${IMAGE_ROOTFS}/etc/rpm/platform

	# Copy the packages into the target image
	# Ugly ugly ugly but rpm is braindead and can't see outside the chroot 
	# when installing :(
	mkdir -p ${IMAGE_ROOTFS}${DEPLOY_DIR_RPM}
	cp -r ${DEPLOY_DIR_RPM}/* ${IMAGE_ROOTFS}${DEPLOY_DIR_RPM}/

	# Generate an apprpriate yum.conf
	rm -rf ${YUMCONF}
	cat > ${YUMCONF} << EOF
[main]
cachedir=/var/cache2/yum
keepcache=1
debuglevel=10
logfile=/var/log2/yum.log
exactarch=0
obsoletes=1
tolerant=1
arch=arm
basearch=arm

[poky-feed]
name = Poky RPM Feed
baseurl=file://${DEPLOY_DIR_RPM}
gpgcheck=0

EOF
	#mkdir -p ${IMAGE_ROOTFS}/var/lib/rpm
	#rpm --root ${IMAGE_ROOTFS} --initdb
	#rpm --root ${IMAGE_ROOTFS} --dbpath ${IMAGE_ROOTFS}/var/lib/rpm -ihv --nodeps --ignoreos  
	#rpm -ihv --root ${IMAGE_ROOTFS} ${PACKAGE_INSTALL}

	#package_update_index_rpm
	#package_generate_ipkg_conf

	# Uclibc builds don't provide this stuff...
	if [ x${TARGET_OS} = "xlinux" ] || [ x${TARGET_OS} = "xlinux-gnueabi" ] ; then 
		if [ ! -z "${LINGUAS_INSTALL}" ]; then
			for i in ${LINGUAS_INSTALL}; do
				fakechroot yum ${YUMARGS} -y install $i 
			done
		fi
	fi
	if [ ! -z "${PACKAGE_INSTALL}" ]; then
		fakechroot yum ${YUMARGS} -y install ${PACKAGE_INSTALL}
	fi

	#export D=${IMAGE_ROOTFS}
	#export OFFLINE_ROOT=${IMAGE_ROOTFS}
	#export IPKG_OFFLINE_ROOT=${IMAGE_ROOTFS}
	#export OPKG_OFFLINE_ROOT=${IPKG_OFFLINE_ROOT}

	#mkdir -p ${IMAGE_ROOTFS}/etc/opkg/
	#grep "^arch" ${IPKGCONF_TARGET} >${IMAGE_ROOTFS}/etc/opkg/arch.conf

	${ROOTFS_POSTINSTALL_COMMAND}
	
	#for i in ${IMAGE_ROOTFS}${libdir}/opkg/info/*.preinst; do
	#	if [ -f $i ] && ! sh $i; then
	#		opkg-cl ${IPKG_ARGS} flag unpacked `basename $i .preinst`
	#	fi
	#done
	#for i in ${IMAGE_ROOTFS}${libdir}/opkg/info/*.postinst; do
	#	if [ -f $i ] && ! sh $i configure; then
	#		opkg-cl ${IPKG_ARGS} flag unpacked `basename $i .postinst`
	#	fi
	#done

	install -d ${IMAGE_ROOTFS}/${sysconfdir}
	echo ${BUILDNAME} > ${IMAGE_ROOTFS}/${sysconfdir}/version

	${ROOTFS_POSTPROCESS_COMMAND}
	
	rm -rf ${IMAGE_ROOTFS}/var/cache2/
	rm -rf ${IMAGE_ROOTFS}/var/run2/
	rm -rf ${IMAGE_ROOTFS}/var/log2/
	rm -rf ${IMAGE_ROOTFS}${DEPLOY_DIR_RPM}/

	log_check rootfs 	
}

rootfs_rpm_log_check() {
	target="$1"
        lf_path="$2"

	lf_txt="`cat $lf_path`"
	for keyword_die in "Cannot find package" "exit 1" ERR Fail
	do				
		if (echo "$lf_txt" | grep -v log_check | grep "$keyword_die") >/dev/null 2>&1
		then
			echo "log_check: There were error messages in the logfile"
			echo -e "log_check: Matched keyword: [$keyword_die]\n"
			echo "$lf_txt" | grep -v log_check | grep -C 5 -i "$keyword_die"
			echo ""
			do_exit=1				
		fi
	done
	test "$do_exit" = 1 && exit 1
	true
}

remove_packaging_data_files() {
	rm -rf ${IMAGE_ROOTFS}/usr/lib/opkg/
}

install_all_locales() {

    PACKAGES_TO_INSTALL=""

	INSTALLED_PACKAGES=`grep ^Package: ${IMAGE_ROOTFS}${libdir}/opkg/status |sed "s/^Package: //"|egrep -v -- "(-locale-|-dev$|-doc$|^kernel|^glibc|^ttf|^task|^perl|^python)"`

    for pkg in $INSTALLED_PACKAGES
    do
        for lang in ${IMAGE_LOCALES}
        do
            if [ `opkg-cl ${IPKG_ARGS} info $pkg-locale-$lang | wc -l` -gt 2 ]
            then
                    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $pkg-locale-$lang"
            fi
        done
    done
    if [ "$PACKAGES_TO_INSTALL" != "" ]
    then
        opkg-cl ${IPKG_ARGS} install $PACKAGES_TO_INSTALL
    fi
}
