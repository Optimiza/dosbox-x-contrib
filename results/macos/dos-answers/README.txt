What: the folder half and the CD half of the DOS answers (joncampbell123/dosbox-x pull requests 6877 and 6878), against what MS-DOS 7.10 and MS-DOS 6.22 answer. The real DOS reports are realdos.sh's output; the other files are what each comparing script printed, A's report and B's report whole where the script prints them, then the verdict and the lines that differ. agree.txt holds what bench/agree.py counted from them.
Host: macOS 26 on Apple silicon (Mac mini M4); builds made with ./configure --enable-sdl2 (SDL2, no debug), not the flags of the other files here.
Date: 2026-11-19
Builds (source commit, sha256 of the executable):
  base         joncampbell123/dosbox-x main-ai 72ee221bf     59a08006aea862ae99d2fae26bc3de62dca23459ffffd1f7e5d0966df72077ea
  folder half  dos-answers-path-mainai 53dcf4782             526de5561844baba743b831d3f0e27bc054e10c71baad34a8ce556910aa57b7d
  CD half      dos-answers-cd-mainai 5b14ea87a               897a658f67b501570fb1ad912f90663e77e000c1c03c14a9aad113ffbe607d01
The real DOS images: MS-DOS 7.10 is the system disk of a Windows 98; MS-DOS 6.22 is the "MS-DOS 6.22 with CD-Rom Support" VHD. For 7.10 on a CD, DIRCACHE_CD1_SYS named the CD1.SYS of the 6.22 disk. realdos.sh was run with the CD half's build as the machine: it is only the PC.
Commands (each file is named by its first word):
  real-710-<program>.txt, real-622-<program>.txt   realdos.sh <build> msdos710|msdos622 <image> <program>, program exact, template, dosans, dosans-labelled, dosans-cd; exit code 0 each
  exact.txt              exact.sh base folder-half off; exit code 1
  template-fat.txt       template.sh base folder-half fat off; exit code 1
  template-host.txt      template.sh base folder-half host off; exit code 1
  dosans-unlabelled.txt  dosans.sh base folder-half unlabelled off; exit code 1
  dosans-labelled.txt    dosans.sh base folder-half labelled off; exit code 1
  dosans-cd-main.txt     dosans.sh base CD-half cd off; exit code 1
  dosans-cd-folder.txt   dosans.sh base folder-half cd off; exit code 1
  dosans-cd-cd.txt       dosans.sh folder-half CD-half cd off; exit code 1
