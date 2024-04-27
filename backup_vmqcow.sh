#!/bin/bash
{
RETURN=0

cd || exit 1

readonly YMD_VAL=$(date +%Y%m%d%H%M%S)
readonly XML_DUMP_DIRNAME="kvm_vmdump_${YMD_VAL}"
readonly QEMU_PROC_NAME='qemu-system'
readonly VM_RUNNING_STATE="running"
readonly VM_LIST_SRC=$(export LANG=C ; virsh list --all | grep -v "^$")
readonly VM_LIST=$(echo "${VM_LIST_SRC}"| sed -e '1d' -e '2d' | awk -F" " '{print $2}' | sort | uniq)

readonly VM_RUNNING_LIST=$(echo "${VM_LIST_SRC}" | grep "${VM_RUNNING_STATE}")
readonly VM_RUNNING_COUNT=$(echo "${VM_RUNNING_LIST}" | grep -v "^$" | wc -l)
if [ 0 -ne ${VM_RUNNING_COUNT} ]; then
	echo "VM IS RUNNING. EXIT." 1>&2
	echo "${VM_RUNNING_LIST}" 1>&2
	exit 10
fi

readonly SORTED_VM_LIST="${VM_LIST}"
mkdir -pv "${XML_DUMP_DIRNAME}" || exit 2
echo "${SORTED_VM_LIST}" | while read line;do
	VM_RUNNING=0
	VM_RUNNING=$(ps aux | grep "${QEMU_PROC_NAME}" | grep "${line}" | wc -l)
	if [ 0 -eq ${VM_RUNNING} ]; then
		QCOW_PATH=$(find "${HOME}/.local/share/libvirt/images" -name "*${line}*" 2>/dev/null | grep "\.qcow2")
		virsh dumpxml "${line}" > "${XML_DUMP_DIRNAME}/${line}.xml"
		RETURN=${?}
		if [ 0 -ne ${RETURN} ]; then
			echo "XML OUTPUT ERROR . VM:${line}" 1>&2
			exit ${RETURN}
		fi
		cp "${QCOW_PATH}" "${XML_DUMP_DIRNAME}/"
		RETURN=${?}
		if [ 0 -ne ${RETURN} ]; then
			echo "QCOW2 COPY ERROR . VM:${line}" 1>&2
			exit ${RETURN}
		fi
	else
		echo "VM ${line} IS RUNNING. SKIP." 1>&2
	fi
done

readonly ARCHIVE_COMMAND="tar cvfz ${XML_DUMP_DIRNAME}.tgz ${XML_DUMP_DIRNAME}"
cpulimit -l 50 ${ARCHIVE_COMMAND}
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
