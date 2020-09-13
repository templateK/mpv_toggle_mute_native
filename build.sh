#!/bin/sh

echo "generating mpv_toggle_mute.c with cython"
cython mpv_toggle_mute.pyx --embed

echo "compiling and linking mpv_toggle_mute executable"
gcc -Os -I/usr/local/Cellar/python@3.8/3.8.5/Frameworks/Python.framework/Versions/3.8/include/python3.8 \
        -L/usr/local/Cellar/python@3.8/3.8.5/Frameworks/Python.framework/Versions/3.8/lib/ \
        -lpython3.8 -o mpv_toggle_mute mpv_toggle_mute.c
