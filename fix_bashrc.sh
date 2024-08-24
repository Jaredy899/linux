#!/bin/bash

# Define the lines to be added for interactive shell check
line4="# Determine if the shell is interactive"
line5="if [[ \$iatest -gt 0 ]]; then"
line_end="fi"

# File path
file="$HOME/linuxtoolbox/mybash/.bashrc"

# Define the alias line to be added
alias_line="alias ff='fastfetch -c all'"

# Function to insert lines at a specific position
insert_line_at_position() {
    local line="$1"
    local position="$2"
    local file="$3"

    sed -i "${position}i $line" "$file"
}

# Check if the alias already exists in the .bashrc file and add it if not
if ! grep -q "$alias_line" "$file"; then
    echo "$alias_line" >> "$file"
    echo "Alias added successfully to $file."
else
    echo "Alias already exists in $file."
fi

# Add the lines at specific positions
insert_line_at_position "$line4" 4 "$file"
insert_line_at_position "$line5" 5 "$file"

# Check if the file already ends with 'fi' and remove it if present to avoid duplicates
sed -i '$s/^\s*fi\s*$//' "$file"

# Append "fi" at the end of the file
echo "$line_end" >> "$file"

echo "Lines added successfully to $file."
