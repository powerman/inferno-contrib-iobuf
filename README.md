# Description

This module provide simpler alternative to bufio(2).


# Install

Make directory with this module available in /opt/powerman/iobuf/.

Install system-wide:

```
# git clone https://github.com/powerman/inferno-contrib-iobuf.git $INFERNO_ROOT/opt/powerman/iobuf
```

or in your home directory:

```
$ git clone https://github.com/powerman/inferno-contrib-iobuf.git $INFERNO_USER_HOME/opt/powerman/iobuf
$ emu
; bind opt /opt
```

or locally for your project:

```
$ git clone https://github.com/powerman/inferno-contrib-iobuf.git $YOUR_PROJECT_DIR/opt/powerman/iobuf
$ emu
; cd $YOUR_PROJECT_DIR_INSIDE_EMU
; bind opt /opt
```

If you want to run commands and read man pages without entering full path
to them (like `/opt/VENDOR/APP/dis/cmd/NAME`) you should also install and
use https://github.com/powerman/inferno-opt-setup 

## Dependencies

* https://github.com/powerman/inferno-opt-mkfiles


# Usage

See man page.
