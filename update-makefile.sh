#!/bin/bash

function get_file_change_time(){
    ls -l --time-style '+%Y-%m-%d' "$1" | awk '{print $6}'
}

function get_file_change_timestamp(){
    tmp=$(get_file_change_time "$1")
    date -d "$tmp" "+%s"
}

anchor_time=0
anchor_file="index-time-anchor"
if [ -f "${anchor_file}" ];then
    anchor_time=$(get_file_change_timestamp "${anchor_file}")
    echo "index anchor time: " ${anchor_time}
fi

all_md_file_path=$(find . -name "*.md" -type f)

for md_file_path in $all_md_file_path;do
    md_file_change_timestamp=$(get_file_change_timestamp $md_file_path)
    echo $anchor_time $md_file_change_timestamp
    if [ ${md_file_change_time} -gt ${anchor_time} ];then
        md_file_name=$(basename $md_file_path)
        md_file_dir=$(dirname $md_file_path)
        md_file_change_time=$(get_file_change_time $md_file_path)
        des_post_md_file_name=${md_file_change_time}-${md_file_name}
        echo $des_post_md_file_name
    fi
done

