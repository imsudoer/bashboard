#!/bin/bash
field "Host"   "$(hostname -f 2>/dev/null || hostname)"
field "OS"     "$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
field "Kernel" "$(uname -r)"
field "Arch"   "$(uname -m)"
