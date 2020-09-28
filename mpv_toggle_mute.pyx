#cython: language_level=3
import socket
import sys
import os
import stat
import json
import argparse
import subprocess
import re
from enum import Enum
from AppKit import NSWorkspace


cdef connect(unix_socket):
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(unix_socket)
        return sock
    except socket.error as msg:
        print('connection fail', msg)
        sys.exit(1)

cdef send(dest_socket, command):
    dest_socket.sendall(command + b'\n')
    recv_msg = b''
    while True:
        data = dest_socket.recv(16)
        recv_msg += data
        if b'\n' in data:
            return recv_msg[:-1].decode('utf-8')

class Commands(Enum):
    TOGGLE = b'{ "command": ["cycle", "mute"] }'
    MUTE = b'{ "command": ["set_property", "mute", true] }'
    UNMUTE = b'{ "command": ["set_property", "mute", false] }'

cdef toggle_mute(dest_socket, command):
    try:
        # print(command.value)
        send(dest_socket, command.value)
    finally:
        # print('closing socket')
        dest_socket.close()

cdef setup_args():
    parser = argparse.ArgumentParser(description='toggle mpv player sound via json ipc.')
    if len(sys.argv) == 1:
        parser.format_help()
    parser.print_usage = parser.print_help
    # parser.add_argument('--json', '-j', type=str, required=True, help='focused status of mpv and socket file in json.')
    # parser.add_argument('--sockets', '-s', nargs='+',
    #                     type=str, required=False, help='unix socket file path of the mpv player.')
    # parser.add_argument('--command', '-c', type=str, choices=['toggle', 'mute', 'unmute'], default='toggle')
    return parser.parse_known_args()

cdef mk_mpvsocket(pid):
    return f'/Volumes/Ramdisk/mpvCache/mpvsocket{pid}'

cdef mpv_status_with_pyobjc():
    result = []
    for rapp in NSWorkspace.new().runningApplications():
        if rapp.bundleIdentifier() == 'io.mpv':
            socket_file_path = mk_mpvsocket(rapp.processIdentifier())
            result.append({"path": socket_file_path, "focused": rapp.isActive()})
    return result

# def log(*msgs):
#     with open("/Volumes/Ramdisk/tmp/subprocessex.log", 'a+') as f:
#         for msg in msgs:
#             f.write(msg)
#         f.write('\n')

cdef mpv_main():
    for status in mpv_status_with_pyobjc():
        socket_path = status['path']
        focused = status['focused']
        # print(socket_path, state)
        if not os.path.isfile(socket_path):
            mode = os.stat(socket_path).st_mode
            if stat.S_ISSOCK(mode):
                # print("ok")
                client = connect(socket_path)
                if focused:
                    # print("unmute")
                    toggle_mute(client, Commands.UNMUTE)
                else:
                    # print("mute")
                    toggle_mute(client, Commands.MUTE)
                # else:
                #     toggle_mute(client, Commands.TOGGLE)
            else:
                print("not socket file: ", socket_path)
        else:
            print("file does not exists: ", socket_path)

if __name__ == '__main__':
    mpv_main()
