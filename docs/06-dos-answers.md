# 6. The emulator's DOS answers as MS-DOS does

Offered as two pull requests, one for a mounted folder, an overlay drive and a zip drive and one for a CD image, which is on top of the first; each answer it changes is checked against MS-DOS 7.10 and MS-DOS 6.22 booted from their own disks.

## What was wrong

Unpatched upstream answers a program otherwise than MS-DOS does in a few lines outside every
other subject here:

- an error code;
- a leading space accepted in a name;
- the label in a listing of the root.
