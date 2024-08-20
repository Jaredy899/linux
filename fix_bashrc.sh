#!/bin/bash

# Define the lines to be added
line4="# Determine if the shell is interactive"
line5="if [[ \$iatest -gt 0 ]]; then"
line639="fi"

# File path
file="$HOME/linuxtoolbox/mybash/.bashrc"

# Function to insert lines at a specific position
insert_line_at_position() {
    local line="$1"
    local position="$2"
    local file="$3"

    sed -i "${position}i $line" "$file"
}

# Add the lines
insert_line_at_position "$line4" 4 "$file"
insert_line_at_position "$line5" 5 "$file"
insert_line_at_position "$line639" 639 "$file"

echo "Lines added successfully to $file."
