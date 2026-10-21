param([string]$SourceVideo = 'C:\Users\ding5\Downloads\ff5416069efe484883df0caaad39fee4.mp4')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$videoDirectory = Join-Path $projectRoot 'assets/story/video'
New-Item -ItemType Directory -Force -Path $videoDirectory | Out-Null
$outputVideo = Join-Path $videoDirectory 'opening.ogv'
# Preserve the complete image, including provenance labels, and original audio.
& ffmpeg -hide_banner -loglevel error -y -i $SourceVideo -filter_complex '[0:v]split=2[bg][fg];[bg]scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,boxblur=28:2,eq=brightness=-0.24[base];[fg]scale=720:960[front];[base][front]overlay=0:160,setsar=1[out]' -map '[out]' -map 0:a -c:v libtheora -q:v 7 -g:v 64 -c:a libvorbis -q:a 5 -map_metadata 0 $outputVideo
if ($LASTEXITCODE -ne 0) { throw 'Video conversion failed.' }
$provenance = [ordered]@{
 source = (Split-Path -Leaf $SourceVideo)
 sha256 = (Get-FileHash -LiteralPath $SourceVideo -Algorithm SHA256).Hash
 creator_tool = '用户提供：通义千问生成'
 runtime_file = 'opening.ogv'
 conversion = '9:16 720x1280；完整主体 720x960，上下柔化背景补齐；Theora / Vorbis；原声与可见 AI 来源标识保留。'
}
$provenance | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $videoDirectory 'provenance.json')

