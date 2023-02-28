#!/bin/bash
# to move original markdown file to _posts dir respectively

function get_file_change_time(){
    ls -l --time-style '+%Y-%m-%d %H:%M:%S' "$1" | awk '{print $6,$7}'
}

function get_f_ctime_no_sec(){
    ls -l --time-style '+%Y-%m-%d' "$1" | awk '{print $6}'
}

function get_file_change_timestamp(){
    tmp=$(get_file_change_time "$1")
    date -d "$tmp" "+%s"
}

anchor_time=0
anchor_file="time-anchor"
if [ -f "${anchor_file}" ];then
    anchor_time=$(get_file_change_timestamp "${anchor_file}")
    echo "anchor time: " "$(get_file_change_time ${anchor_file})"
else
    echo "no time anchor"
fi

all_md_file_path=$(find . -name "*.md" ! -path "*/_posts/*" ! -path "*/_site/*" ! -path "*/README.md" ! -path "*/404.md" ! -path "*/index.md")

old_IFS=$IFS
IFS=$'\n'

count=0
for md_file_path in $all_md_file_path;do
    md_file_change_timestamp=$(get_file_change_timestamp "$md_file_path")
    if [ ${md_file_change_timestamp} -gt ${anchor_time} ];then
        md_file_name=$(basename $md_file_path)
        md_file_dir=$(dirname $md_file_path)
        md_file_change_time=$(get_f_ctime_no_sec "$md_file_path")
        des_post_md_file_name=${md_file_change_time}-${md_file_name}
        des_dir="${md_file_dir}/_posts"
        des_path="${des_dir}/$des_post_md_file_name"
        [ -d ${des_dir} ] || mkdir "${des_dir}"

        find_ret=`find ${des_dir} -name "*${md_file_name}" -type f`
        if [ -n "$find_ret" ];then
            des_path=$find_ret
        fi
        echo "updating file: "$des_path
        cp -f "$md_file_path" "$des_path"
        let "count=count+1"
    fi
done
IFS=old_IFS

echo "total updated files: ${count}"

touch "$anchor_file"
