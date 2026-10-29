#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "testsrc2=size=640x360:rate=24" \
  -f lavfi -i "sine=frequency=440:sample_rate=48000" \
  -t 96 -vf "format=yuv420p" -c:v libx264 -preset fast -crf 32 \
  -af "volume=0.02" -c:a aac -b:a 48k -movflags +faststart \
  JoeToep/Resources/fixture.mp4
