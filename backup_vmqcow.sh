#!/bin/bash
{

	declare -a COMPRESS_PIDS=()
	declare -i COMPRESS_RESULTS=0
	
	readonly QEMU_PROC_NAME='qemu-system'
	readonly VM_RUNNING_STATE='running'
	readonly VM_SHUT_OFF_STATE='shut off'
	# VM状態チェック関数
	function check_vm_state(){
		local -r VM_NAME="${1}"
		local -r CHECK_TYPE="${2:-normal}"  # normal, strict
		
		# VM名の入力値検証
		if [[ ! "${VM_NAME}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
			echo "INVALID VM NAME . VM:${VM_NAME}" 1>&2
			return 1
		fi
		
		if [[ "${CHECK_TYPE}" = 'strict' ]]; then
			# 厳密チェック：複数回の状態確認
			local VM_STATE1=$(export LANG=C ; virsh domstate "${VM_NAME}" 2>/dev/null || echo "unknown")
			local VM_PROC_COUNT=$(pgrep -f "${QEMU_PROC_NAME}" | grep "${VM_NAME}" | grep -v "^$" | wc -l)
			sleep 0.5  # 短い待機時間でタイミングをずらす
			local VM_STATE2=$(export LANG=C ; virsh domstate "${VM_NAME}" 2>/dev/null || echo "unknown")
			
			# 両方のチェックで停止状態かつプロセスが存在しないことを確認
			if [[ "${VM_STATE1}" = "${VM_SHUT_OFF_STATE}" ]] && [[ "${VM_STATE2}" = "${VM_SHUT_OFF_STATE}" ]] && [ 0 -eq "${VM_PROC_COUNT}" ]; then
				return 0  # VM停止中
			else
				return 1  # VM実行中または不明
			fi
		else
			# 通常チェック：単回の状態確認
			local VM_STATE=$(export LANG=C ; virsh domstate "${VM_NAME}" 2>/dev/null || echo "unknown")
			if [[ "${VM_STATE}" = "${VM_SHUT_OFF_STATE}" ]]; then
				return 0  # VM停止中
			else
				return 1  # VM実行中または不明
			fi
		fi
	}
	
	function compress_vm_files(){
		local -r VM_FILES_DIRECTORY_PATH="${1}"
		local RETURN=0
		SUB_DIR_NAME=$(basename "${VM_FILES_DIRECTORY_PATH}")
		#SUB_DIR_NAMEが実在するディレクトリであることを確認する。
		if [ ! -d "${SUB_DIR_NAME}" ]; then
			echo "VM BACKUP DIRECTORY NOT FOUND . DIRNAME:${SUB_DIR_NAME}" 1>&2
			return 10
		fi
		#アーカイブする。
		tar -I pigz -cf "${SUB_DIR_NAME}.tgz" "${SUB_DIR_NAME}"
		RETURN=${?}
		if [ 0 -ne ${RETURN} ]; then
			echo "VM BACKUP DIRECTORY ARCHIVE ERROR . DIRNAME:${SUB_DIR_NAME}" 1>&2
		fi
		rm -rf "${SUB_DIR_NAME}"
		RETURN=${?}
		if [ 0 -ne ${RETURN} ]; then
			echo "VM BACKUP DIRECTORY DELETE ERROR . DIRNAME:${SUB_DIR_NAME}" 1>&2
		fi
		return ${RETURN}
	}

	readonly START_UNIXTIME=$(date +%s)
 	
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
	readonly YMD_VAL=$(date -d "@${START_UNIXTIME}" +%Y%m%d%H%M%S)
	readonly XML_DUMP_DIRNAME="${CURRENT_PATH}/kvm_vmdump_${YMD_VAL}"
	
	# VM一覧を取得（エラーハンドリング付き）
	VM_LIST_SRC_TEMP=$(
		export LANG=C
		virsh list --all | grep -v "^$"
	) || {
		echo "FAILED TO GET VM LIST. CHECK IF LIBVIRT IS RUNNING AND YOU HAVE PROPER PERMISSIONS." 1>&2
		exit 30
	}
	readonly VM_LIST_SRC="${VM_LIST_SRC_TEMP}"
	readonly VM_LIST=$(echo "${VM_LIST_SRC}" | grep -v "^$" | sed -e '1d' -e '2d' | awk -F" " '{print $2}' | sort | uniq)

	readonly VM_RUNNING_LIST=$(echo "${VM_LIST_SRC}" | grep "${VM_RUNNING_STATE}"| grep -v "^$")
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
		# 厳密なVM状態チェックを実行
		if check_vm_state "${line}" "strict"; then
			VM_BACKUP_DEST="${XML_DUMP_DIRNAME}/${line}"
			mkdir -pv "${VM_BACKUP_DEST}"
			RETURN=${?}
			if [ 0 -ne ${RETURN} ]; then
				echo "COULD NOT MAKE DUMP  SUB DIRECTORY . DIRNAME:${VM_BACKUP_DEST}" 1>&2
				exit ${RETURN}
			fi
			
			# バックアップ処理開始前に再度VM状態をチェック
			if ! check_vm_state "${line}" "normal"; then
				echo "VM ${line} STARTED DURING BACKUP PREPARATION. ABORTING." 1>&2
				rm -rf "${VM_BACKUP_DEST}"
				continue
			fi
			
			virsh dumpxml "${line}" >"${VM_BACKUP_DEST}/${line}.xml"
			RETURN=${?}
			if [ 0 -ne ${RETURN} ]; then
				echo "XML OUTPUT ERROR . VM:${line}" 1>&2
				exit ${RETURN}
			fi
			# VMのディスクリストを取得（エラーハンドリング付き）
			QCOW_PATH_LIST_SRC_TEMP=$(
				export LANG=C
				virsh domblklist "${line}" | grep '\.qcow2$'
			) || {
				echo "FAILED TO GET DISK LIST FOR VM:${line}. Skipping this VM." 1>&2
				rm -rf "${VM_BACKUP_DEST}"
				continue
			}
			QCOW_PATH_LIST_SRC="${QCOW_PATH_LIST_SRC_TEMP}"
			QCOW_PATH_LIST=$(echo "${QCOW_PATH_LIST_SRC}" | grep -v "^$" | awk -F" " '{print $2}' | sort | uniq)
			echo "${QCOW_PATH_LIST}" | while read QCOW_PATH; do
				# QCOW2ファイルコピー前に再度VM状態をチェック
				if ! check_vm_state "${line}" "normal"; then
					echo "VM ${line} STARTED DURING QCOW2 COPY. ABORTING." 1>&2
					rm -rf "${VM_BACKUP_DEST}"
					break
				fi
				
				if [ -f "${QCOW_PATH}" ]; then
					cp "${QCOW_PATH}" "${VM_BACKUP_DEST}/"
					RETURN=${?}
					if [ 0 -ne ${RETURN} ]; then
						echo "QCOW2 COPY ERROR . VM:${line}" 1>&2
						exit ${RETURN}
					fi
					
					# コピー後も状態をチェック
					if ! check_vm_state "${line}" "normal"; then
						echo "VM ${line} STARTED DURING QCOW2 COPY. BACKUP MAY BE INCONSISTENT." 1>&2
						rm -rf "${VM_BACKUP_DEST}"
						break
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

	#XML_DUMP_DIRNAME直下に移動する。
	cd "${XML_DUMP_DIRNAME}"
	RETURN=${?}
	if [ 0 -ne ${RETURN} ]; then
		echo "COULD NOT CHANGE DIRECTORY . DIRNAME:${XML_DUMP_DIRNAME}" 1>&2
		exit ${RETURN}
	fi
	
	#XML_DUMP_DIRNAME直下にあるディレクトリごとにアーカイブする。
	for SUB_DIR in $(find . -maxdepth 1 -type d | grep -v '^.$'); do
		compress_vm_files "${SUB_DIR}" &
		COMPRESS_PIDS+=($!)
	done

	for pid in "${COMPRESS_PIDS[@]}"; do
		wait $pid
		COMPRESS_RESULTS+=$?
	done
	RETURN="${COMPRESS_RESULTS}"

	tar -cf "${XML_DUMP_DIRNAME}.tar" "${XML_DUMP_DIRNAME}"
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

 	readonly END_UNIXTIME=$(date +%s)
	echo "TIME : $(( ${END_UNIXTIME}-${START_UNIXTIME}))"

	exit ${RETURN}
}
