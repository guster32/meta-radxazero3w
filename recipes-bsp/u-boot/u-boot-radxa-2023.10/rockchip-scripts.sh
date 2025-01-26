#!/bin/sh

#RKBIN_TOOLS=$(pwd)/rkbin/tools
#INI_LOADER=rkbin/RKBOOT/RK3568-ODROIDM1S.ini
#ARM64_TRUSTZONE
#PLAT_TYPE
#RKBIN
prepare()
{
	if [ -d ${RKBIN_TOOLS} ]; then
		absolute_path=$(cd `dirname ${RKBIN_TOOLS}`; pwd)
		RKBIN=${absolute_path}
	else
		echo "ERROR: No $(pwd)/rkbin repository"
		exit 1
	fi

	if grep -Eq ''^CONFIG_ARM64=y'|'^CONFIG_ARM64_BOOT_AARCH32=y'' .config ; then
		ARM64_TRUSTZONE="y"
	fi

	if grep  -q '^CONFIG_ROCKCHIP_FIT_IMAGE_PACK=y' .config ; then
		PLAT_TYPE="FIT"
	elif grep  -q '^CONFIG_SPL_DECOMP_HEADER=y' .config ; then
		PLAT_TYPE="DECOMP"
	fi
}

filt_val() {
	sed -n "/${1}=/s/${1}=//p" $2 | tr -d '\r' | tr -d '"'
}

#INI_TRUST=rkbin/RKTRUST/RK3568TRUST.ini
#INI_LOADER=rkbin/RKBOOT/RK3568-ODROIDM1S.ini
#ARM64_TRUSTZONE=$(check_arm64_trustzone)
#RKBIN=rkbin
pack_uboot_itb_image()
{
	INI=${INI_TRUST}
	if [ ! -f ${INI} ]; then
		bberror "ERROR: No ${INI}"
		exit 1
	fi

	if [ "${ARM64_TRUSTZONE}" = "y" ]; then
		BL31_ELF=`sed -n '/_bl31_/s/PATH=//p' ${INI} | tr -d '\r'`
		BL32_BIN=`sed -n '/_bl32_/s/PATH=//p' ${INI} | tr -d '\r'`
		rm bl31.elf tee.bin -rf
		cp ${RKBIN}/${BL31_ELF} bl31.elf
		if grep BL32_OPTION -A 1 ${INI} | grep SEC=1 ; then
			cp ${RKBIN}/${BL32_BIN} tee.bin
			TEE_OFFSET=`grep BL32_OPTION -A 3 ${INI} | grep ADDR= | awk -F "=" '{ printf $2 }' | tr -d '\r'`
			TEE_ARG="-t ${TEE_OFFSET}"
		fi
	else
		# TOS
		TOS=`filt_val "TOS" ${INI}`
		TOSTA=`filt_val "TOSTA" ${INI}`
		if [ ! -z "${TOSTA}" ]; then
			cp ${RKBIN}/${TOSTA} tee.bin
		elif [ ! -z "${TOS}" ]; then
			cp ${RKBIN}/${TOS}   tee.bin
		else
			bbnote "WARN: No tee bin"
		fi
		if [ ! -z "${TOSTA}" -o ! -z "${TOS}" ]; then
			TEE_OFFSET=`filt_val "ADDR" ${INI}`
			if [ "${TEE_OFFSET}" = "" ]; then
				TEE_OFFSET=0x8400000
			fi
			TEE_ARG="-t ${TEE_OFFSET}"
		fi
	fi

	#MCUs
	bbnote "Starting MCUs"
	i=0
	while :; do
		[ "$i" -gt 4 ] && break
		MCU_BIN="mcu${i}.bin"
		MCU_IDX="MCU${i}"

		# Compatible: use "MCU" to replace "MCU0" if "MCU" is present.
		if [ "$i" -eq 0 ]; then
				ENABLED=$(awk -F"," '/MCU=/ { print $3 }' "${INI}" | tr -d ' ')
				if [ -n "${ENABLED}" ]; then
						MCU_IDX="MCU"
				fi
		fi

		ENABLED=$(awk -F "," "/${MCU_IDX}=/ { print $3 }" "${INI}" | tr -d ' ')
		if [ "${ENABLED}" = "enabled" ] || [ "${ENABLED}" = "okay" ]; then
				NAME=$(awk -F "," "/${MCU_IDX}=/ { print $1 }" "${INI}" | tr -d ' ' | awk -F "=" '{ print $2 }')
				OFFS=$(awk -F "," "/${MCU_IDX}=/ { print $2 }" "${INI}" | tr -d ' ')
				cp "${RKBIN}/${NAME}" "${MCU_BIN}"
				if [ -z "${OFFS}" ]; then
						echo "ERROR: No ${MCU_BIN} address in ${INI}"
						exit 1
				fi
				MCU_ARG="${MCU_ARG} -m${i} ${OFFS}"
		fi
		i=$((i + 1))
	done

	# Loadables
	bbnote "Starting Loadables"
	i=0
	while :; do
		[ "$i" -gt 4 ] && break
		LOAD_BIN="load${i}.bin"
		LOAD_IDX="LOAD${i}"
		ENABLED=`awk -F "," '/'${LOAD_IDX}'=/  { printf $3 }' ${INI} | tr -d ' '`
		if [ "${ENABLED}" = "enabled" -o "${ENABLED}" = "okay" ]; then
			NAME=`awk -F "," '/'${LOAD_IDX}'=/ { printf $1 }' ${INI} | tr -d ' ' | awk -F "=" '{ print $2 }'`
			OFFS=`awk -F "," '/'${LOAD_IDX}'=/ { printf $2 }' ${INI} | tr -d ' '`
			cp ${RKBIN}/${NAME} ${LOAD_BIN}
			if [ -z ${OFFS} ]; then
				bberror "ERROR: No ${LOAD_BIN} address in ${INI}"
				exit 1
			fi
			LOAD_ARG=${LOAD_ARG}" -l${i} ${OFFS}"
		fi
				i=$((i + 1))
	done

	# COMPRESSION
    COMPRESSION=$(awk -F"," '/COMPRESSION=/ { print $1 }' "${INI}" | tr -d ' ' | cut -c 13-)
    if [ -n "${COMPRESSION}" ] && [ "${COMPRESSION}" != "none" ]; then
		bbnote "Using ${COMPRESSION} compression"
        COMPRESSION_ARG="-c ${COMPRESSION}"
    fi

    if [ -d "${REP_DIR}" ]; then
		bbnote "Using ${REP_DIR} as source for u-boot.its"
        mv "${REP_DIR}"/* ./
    fi

    SPL_FIT_SOURCE=$(filt_val "CONFIG_SPL_FIT_SOURCE" .config)
    if [ -n "${SPL_FIT_SOURCE}" ]; then
		bbnote "Using ${SPL_FIT_SOURCE} as source for u-boot.its"
        cp "${SPL_FIT_SOURCE}" u-boot.its
    else
        SPL_FIT_GENERATOR=$(filt_val "CONFIG_SPL_FIT_GENERATOR" .config)
		bbnote "Using ${SPL_FIT_GENERATOR} as generator for u-boot.its"
        # Check for legacy *.py files
        case "${SPL_FIT_GENERATOR}" in
            *.py)
                "${SPL_FIT_GENERATOR}" u-boot.dtb > u-boot.its
                ;;
            *)
                "${SPL_FIT_GENERATOR}" ${TEE_ARG} ${COMPRESSION_ARG} ${MCU_ARG} ${LOAD_ARG} > u-boot.its
                ;;
        esac
    fi
	bbnote "Will make u-boot.itb from u-boot.its"
	./tools/mkimage -f u-boot.its -E u-boot.itb >/dev/null 2>&1
	bbnote "pack u-boot.itb okay! Input: ${INI}"
	echo
}

# loader.sh
# INI_LOADER=rkbin/RKBOOT/RK3568-ODROIDM1S.ini
script_loader()
{
	if [ ! -f ${INI_LOADER} ]; then
		echo "pack loader failed! Can't find: ${INI_LOADER}"
		exit 0
	fi

	COUNT=`cat ${INI_LOADER} | wc -l`
	if [ ${COUNT} -eq 1 ]; then
		IMG=`sed -n "/PATH=/p" ${INI_LOADER} | tr -d '\r' | cut -d '=' -f 2`
		cp ${IMG} ./
	else
		./tools/boot_merger ${INI_LOADER}
	fi

	echo "pack loader okay! Input: ${INI_LOADER}"
}

pack_loader_image()
{
	rm -f *loader*.bin *download*.bin *idblock*.img
	cd ${RKBIN}
	DEF_PATH=${RKBIN}/`filt_val "^PATH" ${INI_LOADER}`
	IDB_PATH=${RKBIN}/`filt_val "IDB_PATH" ${INI_LOADER}`
	script_loader
	cd -
	if [ -f ${DEF_PATH} ]; then
		mv ${DEF_PATH} ./
	fi
	if [ -f ${IDB_PATH} ]; then
		mv ${IDB_PATH} ./
	fi
}

# FIT_DIR="fit"
# ITB_UBOOT="${FIT_DIR}/uboot.itb"
fit_gen_uboot_img()
{
	ITB=$1

	if [ -z ${ITB} ]; then
		ITB=${ITB_UBOOT}
	fi

	ITB_MAX_NUM=`sed -n "/SPL_FIT_IMAGE_MULTIPLE/p" .config | awk -F "=" '{ print $2 }'`
	ITB_MAX_KB=`sed  -n "/SPL_FIT_IMAGE_KB/p" .config | awk -F "=" '{ print $2 }'`
	ITB_MAX_BS=$((ITB_MAX_KB*1024))
	ITB_BS=`ls -l ${ITB} | awk '{ print $5 }'`

	if [ ${ITB_BS} -gt ${ITB_MAX_BS} ]; then
		echo "ERROR: pack ${IMG_UBOOT} failed! ${ITB} actual: ${ITB_BS} bytes, max limit: ${ITB_MAX_BS} bytes"
		exit 1
	fi

	rm -f ${IMG_UBOOT}
	i=0
	while [ $i -lt ${ITB_MAX_NUM} ]; do
			cat ${ITB} >> ${IMG_UBOOT}
			truncate -s %${ITB_MAX_KB}K ${IMG_UBOOT}
			i=$((i + 1))
	done
}
