#!/bin/bash

# Define the target file path
CONFIG_FILE="$HOME/.config/starship.toml"

# Define the new configuration content
NEW_CONFIG_CONTENT='
# Global prompt format configuration
format = """
[](#3B4252)\
$python\
$username\
[](bg:#434C5E fg:#3B4252)\
$directory\
[](fg:#434C5E bg:#4C566A)\
$git_branch\
$git_status\
[](fg:#4C566A bg:#86BBD8)\
$c\
$elixir\
$elm\
$golang\
$haskell\
$java\
$julia\
$nodejs\
$nim\
$rust\
[](fg:#86BBD8 bg:#06969A)\
$docker_context\
[](fg:#06969A bg:#33658A)\
$time\
[ ](fg:#33658A)\
"""

command_timeout = 5000

# Disable the blank line at the start of the prompt
# add_newline = false

# Username configuration
[username]
show_always = true
style_user = "bg:#3B4252"
style_root = "bg:#3B4252"
format = "[$user ]($style)"

# Directory configuration
[directory]
style = "bg:#434C5E"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"
home_symbol = "" # This sets the symbol for the home directory

# Directory path substitutions (shortening)
[directory.substitutions]
"Documents" = " 󰈙 "
"Downloads" = "  "
"Music" = "  "
"Pictures" = "  "
"Applications" = " 󰀻 "
"Desktop" = " 󰟀 "
"Movies" = "  "
"Google Drive" = "  "
"Contacts" = " 󰛋 "
"Favorites" = " 󰚝 "
"Users" = "  "
"Videos" = "  "
".config" = "  "
".ssh" = " 󰣀 "

# C module configuration
[c]
symbol = " "
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Docker context configuration
[docker_context]
symbol = " "
style = "bg:#06969A"
format = "[ $symbol ]($style)"

# Elixir configuration
[elixir]
symbol = " "
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Elm configuration
[elm]
symbol = " "
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Golang configuration
[golang]
symbol = " "
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Haskell configuration
[haskell]
symbol = " "
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Java configuration
[java]
symbol = " "
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Julia configuration
[julia]
symbol = " "
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Node.js configuration
[nodejs]
symbol = ""
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Nim configuration
[nim]
symbol = " "
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Python configuration
[python]
style = "bg:#3B4252"
format = "[ (\\($virtualenv\\) ) ]($style)"

# Rust configuration
[rust]
symbol = ""
style = "bg:#86BBD8"
format = "[ $symbol ($version) ]($style)"

# Git branch configuration (disabled)
[git_branch]
symbol = ""
style = "bg:#4C566A"
format = "[ $symbol $branch ]($style)"
disabled = true

# Git status configuration (disabled)
[git_status]
style = "bg:#4C566A"
format = "[$all_status$ahead_behind ]($style)"
disabled = true

# Time configuration
[time]
disabled = false
time_format = "%R" # Hour:Minute Format
style = "bg:#33658A"
format = "[ $time ]($style)"
'

# Create the directory if it doesn't exist
mkdir -p "$(dirname "$CONFIG_FILE")"

# Replace the contents of the config file with the new content
echo "$NEW_CONFIG_CONTENT" > "$CONFIG_FILE"

echo "Configuration file updated successfully at $CONFIG_FILE"