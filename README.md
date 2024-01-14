# YTDL
YTDL is a SwiftUI GUI for yt-dlp and ffmpeg. It supports .mp3, .opus and .mkv and works with any website that the underlying tools support.
It runs on macOS 12.0 and newer. It will download [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases/tag/2023.12.30) and [ffmpeg](https://evermeet.cx/ffmpeg) binaries at runtime.

## Features
* Open-source (but you have to build it yourself using Xcode)
* Supports playlists (won't crash on error)
* Guaranteed conversion to mp3, opus or mkv (depends on user selection)
* Minimalistic and intuitive (no unnecessary options. output name will be <channel>-<title>
* Uses yt-dlp auto-update function so that it won't stop working in two weeks

## Screenshots
[[https://downioads.github.io/images/ytdl/light1.png)|alt=Light Mode 1]]

Check out my [blog post](https://downioads.github.io/posts/swiftui-ytdl/) to get more background info about this app.
