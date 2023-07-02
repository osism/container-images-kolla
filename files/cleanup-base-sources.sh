#!/usr/bin/env bash

for e in $(find /*-base-source -name '*config-generator*'); do
    if [[ -d $e ]]; then
        mkdir -p /x/$e
        cp -r $e/* /x/$e
    else
        f=$(dirname $e)
        mkdir -p /x/$f
        cp -r $f/* /x/$f
    fi
done

rm -rf /*-base-source
mv /x/* /
rm -rf /x
