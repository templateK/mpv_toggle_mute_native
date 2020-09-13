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



cdef mpv_status():
    process = subprocess.Popen(["yabai", "-m", "query", "--windows", "--space", "3"], stdout=subprocess.PIPE)
    result = process.communicate()[0]
    decoded = result.decode('utf-8')
    jsons = json.loads(decoded)
    socket_file_path = "not found"
    result = []
    for item in jsons:
        if item['app'] == 'mpv':
            # witefile('[DEACTIVATED]:', item['title'])
            socket_file_path = mk_mpvsocket(item['title'])
            result.append({"path": socket_file_path, "focused": item['focused']})
    return result

cdef mk_mpvsocket(string):
    streamer_account = next((x.group(0) for x in re.finditer(r"^\S+", string)), None)
    if streamer_account:
        return '/Volumes/Ramdisk/mpvCache/mpvsocket_' + streamer_account
    return 'cannot parse mpv stream title'

# def log(*msgs):
#     with open("/Volumes/Ramdisk/tmp/subprocessex.log", 'a+') as f:
#         for msg in msgs:
#             f.write(msg)
#         f.write('\n')

cdef mpv_main():
    statuses = mpv_status()
    for status in statuses:
        socket_path = status['path']
        focused = status['focused']
        # print(socket_path, state)
        if not os.path.isfile(socket_path):
            mode = os.stat(socket_path).st_mode
            if stat.S_ISSOCK(mode):
                # print("ok")
                client = connect(socket_path)
                if focused == 0:
                    # print("mute")
                    toggle_mute(client, Commands.MUTE)
                elif focused == 1:
                    # print("unmute")
                    toggle_mute(client, Commands.UNMUTE)
                else:
                    toggle_mute(client, Commands.TOGGLE)
            else:
                print("not socket file: ", socket_path)
        else:
            print("file does not exists: ", socket_path)

if __name__ == '__main__':
    mpv_main()
