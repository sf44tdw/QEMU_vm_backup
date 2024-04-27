#!/bin/bash
{
	RETURN=0

	cd || exit 1

	readonly USER_BASH_PROFILE_PATH="${HOME}/.bash_profile"
	readonly USER_PROFILE_PATH="${HOME}/.profile"

	if [ -f "${USER_BASH_PROFILE_PATH}" ]; then
		source "${USER_BASH_PROFILE_PATH}" >/dev/null 2>&1 || exit 200
	elif [ -f "${USER_PROFILE_PATH}" ]; then
		source "${USER_PROFILE_PATH}" >/dev/null 2>&1 || exit 210
	else
		exit 220
	fi

	readonly CURRENT_PATH=$(pwd)
	readonly YMD_VAL=$(date +%Y%m%d%H%M%S)
	readonly XML_DUMP_DIRNAME="${CURRENT_PATH}/kvm_vmdump_${YMD_VAL}"
	readonly QEMU_PROC_NAME='qemu-system'
	readonly VM_RUNNING_STATE="running"
	readonly VM_LIST_SRC=$(
		export LANG=C
		virsh list --all | grep -v "^$"
	)
	readonly VM_LIST=$(echo "${VM_LIST_SRC}" | sed -e '1d' -e '2d' | awk -F" " '{print $2}' | sort | uniq)

	readonly VM_RUNNING_LIST=$(echo "${VM_LIST_SRC}" | grep "${VM_RUNNING_STATE}")
	readonly VM_RUNNING_COUNT=$(echo "${VM_RUNNING_LIST}" | grep -v "^$" | wc -l)
	if [ 0 -ne "${VM_RUNNING_COUNT}" ]; then
		echo "VM IS RUNNING. EXIT." 1>&2
		echo "${VM_RUNNING_LIST}" 1>&2
		exit 10
	fi

	readonly SORTED_VM_LIST="${VM_LIST}"

	mkdir -pv "${XML_DUMP_DIRNAME}"
	RETURN=${?}
	if [ 0 -ne ${RETURN} ]; then
		echo "COULD NOT MAKE DUMP DIRECTORY . DIRNAME:${XML_DUMP_DIRNAME}" 1>&2
		exit ${RETURN}
	fi

	echo "${SORTED_VM_LIST}" | while read line; do
		VM_RUNNING=0
		VM_RUNNING=$(pgrep -f "${QEMU_PROC_NAME}" | grep "${line}" | wc -l)

		if [ 0 -eq "${VM_RUNNING}" ]; then
			VM_BACKUP_DEST="${XML_DUMP_DIRNAME}/${line}"
			mkdir -pv "${VM_BACKUP_DEST}"
			RETURN=${?}
			if [ 0 -ne ${RETURN} ]; then
				echo "COULD NOT MAKE DUMP  SUB DIRECTORY . DIRNAME:${VM_BACKUP_DEST}" 1>&2
				exit ${RETURN}
			fi
			virsh dumpxml "${line}" >"${VM_BACKUP_DEST}/${line}.xml"
			RETURN=${?}
			if [ 0 -ne ${RETURN} ]; then
				echo "XML OUTPUT ERROR . VM:${line}" 1>&2
				exit ${RETURN}
			fi
			QCOW_PATH_LIST_SRC=$(
				export LANG=C
				virsh domblklist "${line}" | grep '\.qcow2$'
			)
			QCOW_PATH_LIST=$(echo "${QCOW_PATH_LIST_SRC}" | awk -F" " '{print $2}' | sort | uniq)
			echo "${QCOW_PATH_LIST}" | while read QCOW_PATH; do
				if [ -f "${QCOW_PATH}" ]; then
					cp "${QCOW_PATH}" "${VM_BACKUP_DEST}/"
					RETURN=${?}
					if [ 0 -ne ${RETURN} ]; then
						echo "QCOW2 COPY ERROR . VM:${line}" 1>&2
						exit ${RETURN}
					fi
				else
					echo "QCOW2 NOT FOUND . PATH:${QCOW_PATH}" 1>&2
					exit 10
				fi
			done
		else
			echo "VM ${line} IS RUNNING. SKIP." 1>&2
		fi
	done

	tar cvfz "${XML_DUMP_DIRNAME}.tgz" "${XML_DUMP_DIRNAME}"
	RETURN=${?}
	if [ 0 -ne ${RETURN} ]; then
		echo "ARCHIVE ERROR . DIRNAME:${XML_DUMP_DIRNAME}" 1>&2
		exit ${RETURN}
	fi

	rm -rf "${XML_DUMP_DIRNAME}"
	RETURN=${?}
	if [ 0 -ne ${RETURN} ]; then
		echo "DIRECTORY DELETE ERROR . DIRNAME:${XML_DUMP_DIRNAME}" 1>&2
		exit ${RETURN}
	fi

	exit 0
}
