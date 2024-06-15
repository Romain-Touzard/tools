#!/bin/bash

for i in `seq 1 26`; do
    nvme_device_name="/dev/nvme${i}n1"

    if [ -e  $nvme_device_name ]; then
        block_device_name="$(nvme id-ctrl ${nvme_device_name} --output binary | cut -c3073-3104 | tr -d '[:space:]')"
        if [[ $block_device_name != *"/dev"* ]]; then
            block_device_name="/dev/${block_device_name}"
        fi

        if [ -e $block_device_name ]; then
            echo "${block_device_name} > ${nvme_device_name} symlink already exists. Skipping..."
        else
            echo "Creating ${block_device_name} > ${nvme_device_name} symlink."
            ln -sfn $nvme_device_name $block_device_name
        fi
    fi
done