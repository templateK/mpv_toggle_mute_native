# mpv_toggle_mute_native

## Explanation

A utility program for controlling mpv mute state. <br>
it uses json-rpc api of mpv. the json-rpc commands sent through UNIX domain socket, and also uses <br>
`yabai` titling manager on macOS. If there's multiple mpv instances are running, activated one will play <br>
the sounds and other instances will be muted.


## Caveat

macOS only due to it depends yabai which is used for getting the window state of mpv instances.<br>

The socket path is fixed on `/Volumes/Ramdisk/mpvCache/mpvsocket_` and concatenated <br>
by substring of the stream's title right before the first whitespace. This should be configurable <br>
in the future. 


## Example Usage

This command will automatically mute/unmute the mpv on activation/deactivation. <br>
`yabai -m signal --add event=application_activated action='(~/.local/bin/mpv_toggle_mute)' app='^mpv$'`
