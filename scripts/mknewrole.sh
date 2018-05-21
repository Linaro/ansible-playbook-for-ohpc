#!/bin/bash

role_subdir_yaml="tasks handlers defaults vars meta"
role_subdir_jinja2="templates"

show_usage(){
    echo "mknewrole.sh [-h] role-name"
    echo " -h show this help"
    exit 1
}

main(){
    local rolename
    local yesno
    local dir

    while getopts "h" OPT
    do
	case $OPT in
            "h" ) 
		show_usage;
		shift;
		;;
	esac
    done

    rolename="${@}"
    if [ "x${rolename}" != "x" ]; then
	
	echo "Try to create a role: ${rolename}"
	if [ -d "roles/${rolename}" ]; then
	    echo "Role: ${rolename} already exists."
	    exit 1
	fi
	echo "Create a new role:${rolename}(Y/N)"
	read yesno
	if [ "x${yesno}" != "xn" -o "x${yesno}" != "xN" ]; then

	    echo "Create directories"
	    for dir in `echo ${role_subdir_yaml} ${role_subdir_jinja2}`
	    do
		echo ${dir}
		mkdir -p "roles/${rolename}/${dir}"
	    done
	    
	    echo "Create empty YAML files"
	    for dir in `echo ${role_subdir_yaml}`
	    do
		echo ${dir}
		cat <<EOF > "roles/${rolename}/${dir}/main.yml"
---

#
#roles/${rolename}/${dir}/main.yml
#

EOF
	    done

	    echo "Create empty template files"
	    for dir in `echo ${role_subdir_jinja2}`
	    do
		echo ${dir}
		cat <<EOF > "roles/${rolename}/${dir}/template.j2"
---

#
#roles/${rolename}/${dir}/template.j2
#

EOF
	    done
	fi
    fi
}

main $@
