# 8. `CommandLine::FindString` does not read past the last word

In progress.

## What was wrong

An option typed as the last word of a command, with no value after it, makes the emulator read
past the end of the command line.
