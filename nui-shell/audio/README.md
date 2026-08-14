# Gameplay audio

The five short mono OGG effects in this directory are original procedural assets generated for Sonar Farm Public Job. They do not contain third-party recordings and may be distributed with this resource.

- `soil_scrape.ogg`: filtered soil friction and two restrained tool contacts.
- `water_pour.ogg`: shaped water-flow noise with a soft container resonance.
- `granules.ogg`: sparse dry-granule impacts.
- `spray.ogg`: pulsed pump hiss with a short mechanical transient.
- `crop_pick.ogg`: leaf rustle and a soft stem release.

Source format: mono 48 kHz PCM. Delivery format: Ogg Vorbis, dynamically normalized approximately to -16 LUFS with a -1.5 dBTP ceiling. Each effect is shorter than three seconds and the complete set is under 500 KB. Runtime playback volume and fades are controlled by `Config.Gameplay`.

No third-party samples are used, so no external attribution is required. Rebuild with:

```powershell
python scripts/generate_gameplay_audio.py --ffmpeg C:\path\to\ffmpeg.exe
```
