# ~/.config/hypr/hyprlock.conf
# https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock

$font = Intel One Mono Bold
# $font = JetBrains Mono NL ExtraBold

general {
  text_trim = true
  hide_cursor = true
  ignore_empty_input = true
  disable_loading_bar = false
}

background {
  blur_passes = 0
  color = rgb(000000) #000000
  path = $HOME/wallpaper/DeepSand_V1_Dark.png
  
# Time
label {
  text = $TIME
  valign = top
  halign = right
  position = -30, 0
  font_size = 72
  font_family = $font
  color = rgb(ffffff) #ffffff
}

# Date
label {
  valign = top
  halign = right
  position = -30, -128
  font_size = 17
  font_family = $font
  color = rgb(ffffff) #ffffff
  text = cmd[update:43200000] date +"%A, %d %B %Y"
}

# Failed
label {
  halign = right
  valign = bottom
  position = -30, 15
  font_size = 11
  font_family = $font
  color = rgb(fa005f) #fa005f
  text = $FAIL [ $ATTEMPTS[!] ]
}

# KBD Layout
label {
  halign = center
  valign = center
  position = 0, -50
  font_size = 11
  font_family = $font
  text = $LAYOUT[!]
  color = rgb(ffffff) #ffffff
}

# Input
input-field {
  size = 480, 0
  halign = center
  valign = center
  position = 0, 0
  rounding = 0
  dots_size = 0.2
  dots_spacing = 0.2
  dots_center = true
  outline_thickness = 4
  hide_input = true
  fade_on_empty = true
  font_color = rgb(000000) #000000
  inner_color = rgb(ffffff) #ffffff
  outer_color = rgb(000000) #000000
  check_color = rgb(32f891) #32f891
  fail_color = rgb(fa005f) #fa005f
  capslock_color = rgb(faf76e) #faf76e
  placeholder_text = <span>󰌾 $USER</span>
  fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i>
}
