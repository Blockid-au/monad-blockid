# Monad Metropolis demo video (2:30)

Narrated walkthrough of the live Monad testnet demo. 1920×1080, English voice-over (edge-tts
`en-AU-WilliamMultilingualNeural`, rate +6%), loudness-normalised to −16 LUFS.

| File | Use |
|---|---|
| `site/video/blockid-business-passport-monad-captions.mp4` | captions burned in (submission) |
| `site/video/blockid-business-passport-monad.mp4` | clean video |
| `site/video/blockid-business-passport-monad.srt` | caption track |

Served at https://monad.blockid.au/video/ and mirrored at https://eth.blockid.au/deck/.

Transaction scenes are rendered by `chain.py` from the Monad testnet RPC (`cast receipt`), because block explorers
put a bot check in front of headless browsers. Every value on those cards is read from the chain at build time.

## Rebuild

```bash
cd docs/video/monad
python3 chain.py                                   # chain-*.html from site/monad-deploy.json + RPC
sudo docker run --rm --user $(id -u):$(id -g) -e HOME=/tmp -v $PWD:/w -w /w \
  mcr.microsoft.com/playwright:v1.63.0-noble npm i  # once
sudo docker run --rm --network host --ipc host --user $(id -u):$(id -g) -e HOME=/tmp -v $PWD:/w -w /w \
  mcr.microsoft.com/playwright:v1.63.0-noble node capture.mjs   # shots/*.png (site via local nginx)
while IFS=$'\t' read n text; do
  edge-tts --voice en-AU-WilliamMultilingualNeural --rate=+6% --text "$text" \
    --write-media audio/$n.mp3 --write-subtitles audio/$n.vtt; done < narration.tsv
python3 build.py                                   # Docker ffmpeg → site/video/
```
