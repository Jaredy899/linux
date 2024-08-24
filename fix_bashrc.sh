#!/bin/bash

# Define the lines to be added for interactive shell check
line4="# Determine if the shell is interactive"
line5="if [[ \$- == *i* ]]; then"
line_end="fi"

# File path
file="$HOME/linuxtoolbox/mybash/.bashrc"

# Define the alias lines to be added
alias_line_ff="alias ff='fastfetch -c all'"
alias_line_jc="alias jc='bash -c \"\$(curl -fsSL jaredcervantes.com/linux)\"'"

# Function to insert lines at a specific position
insert_line_at_position() {
    local line="$1"
    local position="$2"
    local file="$3"

    if ! grep -Fq "$line" "$file"; then
        sed -i "${position}i $line" "$file"
    else
        echo "Line '$line' already exists at position $position in $file."
    fi
}

# Check if the alias already exists in the .bashrc file and add it if not
if ! grep -Fq "$alias_line_ff" "$file"; then
    echo "$alias_line_ff" >> "$file"
    echo "Alias 'ff' added successfully to $file."
else
    echo "Alias 'ff' already exists in $file."
fi

if ! grep -Fq "$alias_line_jc" "$file"; then
    echo "$alias_line_jc" >> "$file"
    echo "Alias 'jc' added successfully to $file."
else
    echo "Alias 'jc' already exists in $file."
fi

# Add the lines at specific positions
insert_line_at_position "$line4" 4 "$file"
insert_line_at_position "$line5" 5 "$file"

# Check if the file already ends with 'fi' to avoid duplicates
if ! tail -n 1 "$file" | grep -q "^\s*fi\s*$"; then
    echo "$line_end" >> "$file"
    echo "End 'fi' added to $file."
else
    echo "'fi' already present at the end of $file."
fi

echo "Lines added successfully to $file."
