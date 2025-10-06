#!/usr/bin/env bash

imageFile="$1"
output="$2"

qemu-img convert -f qcow2 -O vmdk "$imageFile" "$output"

