What: the folder half and the CD half of the DOS answers (joncampbell123/dosbox-x pull requests 6877 and 6878), run with the same bench scripts as on macOS. What MS-DOS 7.10 and 6.22 answered does not depend on the host, so agree.txt counts these runs against the real DOS reports in ../../macos/dos-answers. The CD runs mount the same ISO as D:, so their files equal macOS's byte for byte.
Host: Windows 11 x64, Git Bash; builds made with MSBuild vs/dosbox-x.sln, Release, x64 (SDL1). Pull request 6857 is merged in main-ai, so no build needed it merged in.
Date: 2026-11-19
Builds (source commit, sha256 of the executable):
  base         joncampbell123/dosbox-x main-ai 72ee221bf     69e56781ae3b3ebd9963f79d651df71686448183bb765d9edc9f2b23f7c5fd95
  folder half  dos-answers-path-mainai 53dcf4782             ad8cf90de31c0e9d455448d9834132c1fce64d4ba2349a7ead5258867053afb4
  CD half      dos-answers-cd-mainai 5b14ea87a               cc8d6698f83d3cada8a08c550fc6c9bca62513b765e854ecf81432b345592515
Commands (each file is named by its first word; long names off):
  exact.txt              exact.sh base folder-half off; exit code 1
  template-fat.txt       template.sh base folder-half fat off; exit code 1
  template-host.txt      template.sh base folder-half host off; exit code 1
  dosans-unlabelled.txt  dosans.sh base folder-half unlabelled off; exit code 1
  dosans-labelled.txt    dosans.sh base folder-half labelled off; exit code 1
  dosans-cd-folder.txt   dosans.sh base folder-half cd off; exit code 1
  dosans-cd-cd.txt       dosans.sh folder-half CD-half cd off; exit code 1
One line of template-host.txt differs from macOS: a short name that NTFS generates for a long name, which the host-folder drive shows as it is.
