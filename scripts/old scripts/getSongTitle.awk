#!/bin/awk -f

# Get song title
# Split using the ability to set the awk input field separator to be more than one character.

BEGIN {
	FS=" - ";
}
{
		print $1;
}
