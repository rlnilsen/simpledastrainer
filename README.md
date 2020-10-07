# Simple DAS Trainer

The purpose of this modification to NES Tetris is to assist learning the DAS method of playing. An unfavourable DAS charge value (0-9) is visualized by changing the color of the background from dark gray to something else:
* During entry delay: red
* Pressing `left` or `right` just after entry delay: yellow
* All other times: bright gray

Pressing `select` during play turns on visualization of *all* DAS charge values during entry delay, using blue for 10-15 and green for 16.

## How to run

Pre-built IPS mod files are available in the
[releases section of GitHub](https://github.com/rlnilsen/simpledastrainer/releases). They
must be applied to the USA Tetris ROM:

```
Database match: Tetris (USA)
Database: No-Intro: Nintendo Entertainment System (v. 20180803-121122)
File SHA-1: 77747840541BFC62A28A5957692A98C550BD6B2B
File CRC32: 6D72C53A
ROM SHA-1: FD9079CB5E8479EB06D93C2AE5175BFCE871746A
ROM CRC32: 1394F57E
```

You can use [Hasher-js](https://www.romhacking.net/hash/) or [ROM
Hasher](https://www.romhacking.net/utilities/1002/) to verify your ROM matches.
It is generally okay if the "ROM" checksum matches, but the "File" checksum
differs. But note that `make test` will fail.

## How to build

You only need to build if you are making changes or want to try out changes
that have not yet been included in a release.

Dependencies (should be in PATH):
1. [Flips](https://github.com/Alcaro/Flips). [Flips
   1.31](https://www.smwcentral.net/?p=section&a=details&id=11474) is fine
2. [cc65](https://cc65.github.io/getting-started.html). Starting in Debian 10
   (Buster) and Ubuntu 18.04 (Bionic) a package is available via
   `sudo apt install cc65`. The Fedora package is available via
   `sudo dnf install cc65`. Arch Linux has an
   [AUR package](https://aur.archlinux.org/packages/cc65/) available.
3. GNU Make. Windows users can use `make.exe` (just the one file) from the
   `bin/` folder of `make-*-without-guile-w32-bin.zip` available at
   [ezwinports](https://sourceforge.net/projects/ezwinports/files/)
4. GNU Coreutils and Sed. These are standard on Linux. On Windows they are
   provided by [Git for Windows](https://git-scm.com/download/win) when using
   the "Git Bash" command line. Note that it uses a Unix directory structure;
   the Windows directory structure is within the `/c/` directory

On Windows, to modify your PATH, run `SystemPropertiesAdvanced.exe`. On the
"Advanced" tab click "Environment Variables" and then change `Path` in your
"User variables" and hit Okay. You will need to restart any terminals for the
changes to take effect.

Manual prep:
1. Copy tetris ROM to `tetris.nes` in the `simpledastrainer` folder. If the
   iNES header is different than mentioned above you can still use the ROM,
   but you need to adjust the header in `tetris.s` to match your rom to make
   `$ make test` happy.

Use `$ make` to build artifacts into `build/`, which includes disassembling
into `build/tetris-PRG.s`. `$ make test` verifies the reassembled version
matches the original. The mod will be generated at `build/simpledastrainer.ips`
and will have been applied to `build/simpledastrainer.nes`.

## Structure

tetris-PRG.info is the location for all tetris ROM knowledge. It is used to
disassemble tetris into build/tetris-PRG.s. tetris.s and tetris.nes.info
contain the pieces to reassemble tetris into a iNES file. Reassembly is able to
output debug information.

The main debug output is the .lbl file. It is basic and just contains the
labels with their addresses, so doesn't have any more information than
tetris-PRG.info. However, it is easy to parse so the file format is used for
several other tasks; it is transformed into build/tetris.inc using sed and can
be read directly by the LUA testing tools.

NES and IPS files are output directly by the linker, because our .s files
define the headers for the formats and the .cfg files specify the ordering of
the headers/chunks. The linker is fairly well suited to the job and provides
the ability to mix-and-match source files when generating an IPS file, only
needing to manually sort the hunks. It is useful to have understanding of the
IPS format and how it works. It is basically the simplest possible patch
format, only supporting 1:1 replacing, so should be easy to learn.

The [Nesdev Wiki](https://wiki.nesdev.com/w/index.php/NES_reference_guide) has
good resources for the various file formats. The .info file format is described
in the [da65 (disassembler)
documentation](https://www.cc65.org/doc/da65-4.html). The .cfg file format is
described in the [ld65 (linker)
documentation](https://www.cc65.org/doc/ld65-5.html).

## Thank you

This project is based on [TAUS](https://github.com/ejona86/taus) (the Actually Useful Statistics Tetris mod) which among other things provides an infrastructure for creating NES Tetris modifications.
