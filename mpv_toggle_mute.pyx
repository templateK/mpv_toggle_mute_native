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

cdef mpv_main(active_socket_path):
    cache_path = "/Volumes/Ramdisk/mpvCache"
    for socket_file in os.listdir(cache_path):
        if socket_file == "mpvsocket_server":
            # print("skipping server socket")
            continue
        socket_path = f'{cache_path}/{socket_file}'
        mode = os.stat(socket_path).st_mode
        if stat.S_ISSOCK(mode):
            # print("ok")
            client = connect(socket_path)
            if active_socket_path == socket_path:
                # print(f'unmute: {socket_path}, active_socket_path was {active_socket_path}')
                toggle_mute(client, Commands.UNMUTE)
            else:
                # print(f'mute: {socket_path}, active_socket_path was {active_socket_path}')
                toggle_mute(client, Commands.MUTE)
            client.close()
            # else:
            #     toggle_mute(client, Commands.TOGGLE)
        else:
            print("not socket file: ", socket_path)


cdef init_server():
    server_address = '/Volumes/Ramdisk/mpvCache/mpvsocket_server'
    # Make sure the socket does not already exist
    try:
        os.unlink(server_address)
    except OSError:
        if os.path.exists(server_address):
            raise

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)

    # Bind the socket to the port
    print(sys.stderr, 'starting up on %s' % server_address)
    sock.bind(server_address)

    # Listen for incoming connections
    sock.listen(0)
    while True:
        # Wait for a connection
        # print(sys.stderr, 'waiting for a connection')
        connection, client_address = sock.accept()
        try:
            # print(sys.stderr, 'connection from', client_address)
            # Receive the data in small chunks and retransmit it
            recv_data = bytearray()
            while True:
                data = connection.recv(8)
                if data:
                    recv_data += data
                else:
                    break
            if recv_data:
                socket_number = recv_data[:-1].decode('utf8')
                socket_path = mk_mpvsocket(socket_number)
                # print(sys.stderr, 'received', socket_path)
                mpv_main(socket_path)
        finally:
            # Clean up the connection
            connection.close()


if __name__ == '__main__':
    init_server()
    # mpv_main()
