#!/bin/bash

# -----------------------------------------------------
# Check to use wallpaper cache
# -----------------------------------------------------

use_cache=0

if [ "$use_cache" == "1" ]; then
  echo ":: Using Wallpaper Cache"
else
  echo ":: Wallpaper Cache disabled"
fi

# -----------------------------------------------------
# Set defaults
# -----------------------------------------------------

force_generate=0
generated_versions="$HOME/.cache/wallpaper/wallpaper-generated"
waypaper_running=$HOME/.cache/wallpaper/waypaper-running
cache_file="$HOME/.cache/wallpaper/current_wallpaper"
blurred_wallpaper="$HOME/.cache/wallpaper/blurred_wallpaper.png"
square_wallpaper="$HOME/.cache/wallpaper/square_wallpaper.png"
rasi_file="$HOME/.cache/wallpaper/current_wallpaper.rasi"
default_wallpaper="$HOME/wallpaper/default.jpg"
blur="50x30"

# Ensures that the script only run once if wallpaper effect enabled
if [ -f $waypaper_running ]; then
  rm $waypaper_running
  exit
fi

# Create folder with generated versions of wallpaper if not exists
if [ ! -d $generated_versions ]; then
  mkdir $generated_versions
fi

# -----------------------------------------------------
# Get selected wallpaper
# -----------------------------------------------------

if [ -z $1 ]; then
  if [ -f $cache_file ]; then
    wallpaper=$(cat $cache_file)
  else
    wallpaper=$default_wallpaper
  fi
else
  wallpaper=$1
fi
used_wallpaper=$wallpaper
echo ":: Setting wallpaper with original image $wallpaper"
tmp_wallpaper=$wallpaper

# -----------------------------------------------------
# Copy path of current wallpaper to cache file
# -----------------------------------------------------

if [ ! -f $cache_file ]; then
  touch $cache_file
fi
echo "$wallpaper" >$cache_file
echo ":: Path of current wallpaper copied to $cache_file"

# -----------------------------------------------------
# Get wallpaper filename
# -----------------------------------------------------
wallpaper_filename=$(basename $wallpaper)
echo ":: Wallpaper Filename: $wallpaper_filename"


# -----------------------------------------------------
# Execute pywal
# -----------------------------------------------------

echo ":: Execute pywal with $used_wallpaper"
wal -q -i $used_wallpaper
source "$HOME/.cache/wal/colors.sh"

# -----------------------------------------------------
# Reload Waybar
# -----------------------------------------------------
# killall waybar
# waybar &

# -----------------------------------------------------
# Reload AGS
# -----------------------------------------------------
killall ags
ags &

# -----------------------------------------------------
# Create rasi file
# -----------------------------------------------------

if [ ! -f $rasi_file ]; then
  touch $rasi_file
fi
echo "* { current-image: url(\"$blurred_wallpaper\", height); }" >"$rasi_file"

# -----------------------------------------------------
# Created square wallpaper
# -----------------------------------------------------

echo ":: Generate new cached wallpaper square-$wallpaper_filename"
magick $tmp_wallpaper -gravity Center -extent 1:1 $square_wallpaper
cp $square_wallpaper $generated_versions/square-$wallpaper_filename.png
