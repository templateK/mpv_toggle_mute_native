#!/bin/sh

launchctl unload ~/Library/LaunchAgents/com.taemu.mpv_toggle_mute.plist
launchctl load ~/Library/LaunchAgents/com.taemu.mpv_toggle_mute.plist
