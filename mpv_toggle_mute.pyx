#cython: language_level=3
import socket
import sys
import os
import stat
from enum import Enum


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


cdef mk_mpvsocket(pid):
    return f'/Volumes/Ramdisk/mpvCache/mpvsocket{pid}'


cdef mpv_main(active_socket_path):
    cache_path = "/Volumes/Ramdisk/mpvCache"
    for socket_file in os.listdir(cache_path):
        if socket_file == "mpvsocket_server":
            print("skipping server socket")
            continue
        socket_path = f'{cache_path}/{socket_file}'
        mode = os.stat(socket_path).st_mode
        if stat.S_ISSOCK(mode):
            # print("ok")
            try:
                client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                client.connect(socket_path)
                if active_socket_path == socket_path:
                    print(f'unmute: {socket_path}, active_socket_path was {active_socket_path}')
                    toggle_mute(client, Commands.UNMUTE)
                else:
                    print(f'mute: {socket_path}, active_socket_path was {active_socket_path}')
                    toggle_mute(client, Commands.MUTE)
            except socket.error as msg:
                print(f'Connection fail: {msg}')
                print(f'Removing socket file: {socket_path}')
                os.remove(socket_path)
            finally:
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
        try:
            print(sys.stderr, 'waiting for a connection')
            connection, client_address = sock.accept()
            print(sys.stderr, 'connection from', client_address)
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
                print(sys.stderr, 'received', socket_path)
                mpv_main(socket_path)
        finally:
            # Clean up the connection
            connection.close()


if __name__ == '__main__':
    init_server()
