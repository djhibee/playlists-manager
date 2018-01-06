#!/bin/awk -f

# Get artist name
# Split using the ability to set the awk input field separator to be more than one character.

BEGIN {
	FS=" - ";
}
{
		print $2;
}
