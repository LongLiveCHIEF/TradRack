#!/bin/bash

set -e

# parse options
cflag=0
while getopts ":c" opt; do
    case $opt in
        c)
            cflag=1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

# branch may be provided as positional argument after any flags
branch=${1:-main}
module_dir=Kalico/klippy_module
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
repo_source=https://github.com/Annex-Engineering/TradRack.git
repo_dir=trad_rack_klippy_module
base_config_dir=Kalico/kalico/config/base_config_options

if [[ "$script_dir" == *$module_dir ]]; then
    cd $script_dir
    git checkout $branch
    git pull
    repo_root=$(git rev-parse --show-toplevel)
else
    cd ~
    git clone --filter=blob:none --no-checkout $repo_source $repo_dir
    cd $repo_dir
    git sparse-checkout set --cone
    git checkout $branch
    git sparse-checkout set $module_dir
    repo_root=$(pwd)
    cd $module_dir
fi

# If -c was requested, add the base config dir to sparse-checkout and
# allow the user to choose a config file to copy into the Klipper config
# path.
if [[ "$cflag" -eq 1 ]]; then
    # make sure we are at repo root when adjusting sparse-checkout
    pushd "$repo_root" > /dev/null
    git sparse-checkout add "$base_config_dir"
    popd > /dev/null

    cfg_dir="$repo_root/$base_config_dir"
    if [[ ! -d "$cfg_dir" ]]; then
        echo "Config directory not found: $cfg_dir" >&2
        exit 1
    fi

    # list files (regular files only)
    mapfile -t cfg_files < <(find "$cfg_dir" -maxdepth 1 -type f -printf "%f\n" | sort)
    if [[ ${#cfg_files[@]} -eq 0 ]]; then
        echo "No config files found in $cfg_dir" >&2
        exit 1
    fi

    echo "Select a config file to install into \$HOME/printer_data/config/tradrack:"
    for i in "${!cfg_files[@]}"; do
        printf "%3d) %s\n" "$i" "${cfg_files[$i]}"
    done

    while true; do
        read -rp "Enter the number of the file to copy: " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 0 && selection < ${#cfg_files[@]} )); then
            break
        fi
        echo "Invalid selection. Please enter a number between 0 and $(( ${#cfg_files[@]} - 1 ))."
    done

    src="$cfg_dir/${cfg_files[$selection]}"
    dest_dir="$HOME/printer_data/config/tradrack"
    mkdir -p "$dest_dir"
    cp -v "$src" "$dest_dir/"
    echo "Copied ${cfg_files[$selection]} to $dest_dir"
fi

find * -name '*.py' -exec ln -sf $PWD/{} ~/klipper/klippy/extras/{} \;
