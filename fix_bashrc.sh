#!/bin/sh

# Define the lines to be added
line4="# Determine if the shell is interactive"
line5="if [ \$iatest -gt 0 ]; then"
line_end="fi"

# File path
file="$HOME/linuxtoolbox/mybash/.bashrc"

# Function to insert lines at a specific position
insert_line_at_position() {
    local line="$1"
    local position="$2"
    local file="$3"

    # Check if the line already exists in the file
    if ! grep -Fxq "$line" "$file"; then
        sed -i "${position}i\\
$line" "$file"
    fi
}

# Add the lines at specific positions
insert_line_at_position "$line4" 4 "$file"
insert_line_at_position "$line5" 5 "$file"

# Check if the file already ends with 'fi' and remove it if present to avoid duplicates
if ! grep -Fxq "$line_end" "$file"; then
    sed -i '$s/^\s*fi\s*$//' "$file"
    echo "$line_end" >> "$file"
fi

echo "Lines added successfully to $file."
