# video-souvenir

Assemble des clips video bruts (style camescope familial) en un seul fichier HEVC pret pour Plex, ou en projet Kdenlive pre-monte si tu veux trim/couper avant.

Trie automatiquement les clips par date d'enregistrement (metadata EXIF), normalise resolution + framerate + audio, et encode avec acceleration GPU (NVENC / QSV / VAAPI) ou x265 CPU en fallback.

## Prerequis

- **Fedora** (testé sur 44) avec ffmpeg complet (pas ffmpeg-free) :
  ```
  sudo dnf swap ffmpeg-free ffmpeg --allowerasing
  ```
- **Python 3** (utilise miniconda si dispo, sinon system python3)
- **Kdenlive** (optionnel, requis seulement pour ouvrir les projets generes)

## Installation

```bash
git clone https://github.com/valentin-gosselin/video-souvenir.git
cd video-souvenir
bash install.sh
```

Le script installe :
- `~/.local/bin/video-souvenir` (executable)
- `~/.local/share/applications/video-souvenir.desktop` (entree menu Plasma)
- `PySide6` via pip dans le Python detecte

## Usage

### UI
Lance `video-souvenir` sans argument, ou cherche **Video Souvenir** dans le menu Plasma.

- Selectionne le dossier source contenant tes clips
- La liste se rempli, triee par date d'enregistrement
- Drag-drop pour reordonner, Suppr pour retirer un clip
- Choisis mode (MP4 / Kdenlive / les deux), encoder, qualite, resolution, fps
- Clique **Lancer**

### CLI
```bash
video-souvenir <dossier> [sortie.mp4]
video-souvenir ~/Videos/Weekend --mode both --quality 22 --fps 25
```

Options :
- `--mode {render,kdenlive,both}` : MP4 seul, projet Kdenlive seul, ou les deux (defaut: render)
- `--encoder {auto,nvenc,qsv,vaapi,x265}` : encoder HEVC (defaut: auto)
- `--quality N` : 18 = tres haute qualite / 28 = compact (defaut: 24)
- `--fps N` : framerate de sortie (defaut: 30)
- `--max-res {4k,1080p,source}` : plafond de resolution (defaut: 4k)

## Notes

- Les fichiers `souvenir-YYYYMMDD-HHMMSS.{mp4,kdenlive}` (anciens exports) sont automatiquement exclus du scan.
- Pour Sony Alpha (XAVC S Europe) : utilise `--fps 25` pour rester natif.
- Le `.kdenlive` genere est un MLT XML basique compatible Kdenlive 24.x — il peut etre ouvert/edite normalement, les pistes sont organisees correctement.
- Sortie : `souvenir-YYYYMMDD-HHMMSS.mp4` dans le dossier source par defaut.

## Format de sortie

- Container : MP4 + `movflags +faststart` (streaming Plex)
- Video : HEVC tag `hvc1` (compat Apple/Plex)
- Audio : AAC 192k stereo, 48kHz
- Pixel format : yuv420p (compat universelle)
