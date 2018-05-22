#!/bin/sh

if [ -f execution.log ]; then
    rm -f execution.log
fi

ansible-playbook -i inventory/hosts site.yml -vv

