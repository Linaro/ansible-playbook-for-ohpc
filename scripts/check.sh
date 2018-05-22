#!/bin/sh

ansible-playbook -i inventory/hosts site.yml --syntax-check
