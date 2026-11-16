# 8. An option given as the last word of a command line is not read past its end

In progress: the fix goes in `CommandLine::FindString`, which reads the word after an option
as its value.

## What was wrong

An option typed as the last word of a command, with no value after it, makes the emulator read
past the end of the command line.
