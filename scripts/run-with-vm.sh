#!/bin/bash 

export LANG=C

execution_log=execution-logs
date_str=`date +%F|sed -e 's|-||g'`
cwd=`pwd`
log_dir="${cwd}/${execution_log}/${date_str}"
logfile="${log_dir}/execution.log"

do_login_and_run(){

    echo "Run the test"
    expect -c "
set timeout -1
#ログイン
spawn vagrant ssh sms
expect \"\[vagrant@sms\ ~\]\$\" {
# 既存ディレクトリ削除
send -- \"rm -fr ohpcOrchestration\r\"
}
expect \"\[vagrant@sms\ ~\]\$\" {
# 展開
send -- \"tar xf ohpcOrchestration.tar.gz\r\"
}

expect \"\[vagrant@sms\ ~\]\$\" {
# ディレクトリ移動
send -- \"cd ohpcOrchestration\r\"
}

expect \"\[vagrant@sms ohpcOrchestration\]\$\" {
# 既存ログ削除
send -- \"rm -f execution.log\r\"
}

expect \"\[vagrant@sms ohpcOrchestration\]\$\" {
# テスト開始
send -- \"ansible-playbook -i inventory/target site.yml -vv\r\"
}

expect \"\[vagrant@sms ohpcOrchestration\]\$\" {
# テスト終了
send -- \"logout\r\"
}
interact
"
}
#
prepare_archive(){

    if [ -f vconfig ]; then
	echo "Remove old vconfig"
	rm -f vconfig
    fi

    echo "Renew vconfig"
    vagrant ssh-config > vconfig

    echo "Copy the archive"
    scp -F vconfig ohpcOrchestration.tar.gz sms:
}

prepare_vm() {
    
    echo "Destroy VMs"
    vagrant destroy -f

    echo "Create VMs"
    vagrant up --provision
}

usage_exit(){

    echo "run.sh [-v][-h]"
    echo "  -v  Re-new vm environment(destroy and up with provision)"
    echo "  -h  Show this help and exit"
    exit 0
}

fetch_log(){

    mkdir -p ${log_dir}
    scp -F vconfig "sms:ohpcOrchestration/execution.log" "${logfile}"
}
main() {
    local vm_up

    vm_up=no
    while getopts vh OPT
    do
	case $OPT in
            v)  vm_up=yes
		;;
            h)  usage_exit
		;;
            \?) usage_exit
		;;
	esac
    done
    if [ "x${vm_up}" != "xno" ]; then
	prepare_vm
    fi
    prepare_archive
    do_login_and_run
    fetch_log
}

main $@
