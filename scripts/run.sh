#!/bin/sh

if [ -f execution.log ]; then
    rm -f execution.log
fi

ansible-playbook -i inventory/target site.yml -vv

