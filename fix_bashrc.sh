#!/bin/bash

# The following line is assumed to be present at line 2
iatest=$(expr index "$-" i)

# Add the iatest check below line 2
if [[ $iatest -gt 0 ]]; then

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

    echo "Lines added successfully to $file."

fi