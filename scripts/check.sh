#!/bin/sh

ansible-playbook -i inventory/target site.yml --syntax-check
