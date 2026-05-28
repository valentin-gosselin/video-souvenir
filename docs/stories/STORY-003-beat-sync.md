# STORY-003 : Music beat-sync (optionnel)

**Epic** : MVP V1 — Pré-montage assistant Kdenlive
**Priorité** : Should Have
**Story Points** : 5
**Status** : Not Started
**Sprint** : 1
**Créée** : 2026-05-28
**Dépend de** : STORY-001, STORY-002

---

## User Story

En tant qu'**utilisateur qui monte un souvenir familial avec une musique de fond**,
je veux **fournir un fichier audio (MP3/WAV) et que les cuts entre sub-clips s'alignent sur les beats détectés**,
afin que **le montage final ait un rythme qui suit la musique sans que je passe 30 min à aligner manuellement chaque coupe**.

---

## Description

### Background
Un montage où les cuts tombent sur les temps forts d'une musique passe d'amateur à pro instantanément. Détecter les beats automatiquement (librosa) et ajuster les `in`/`out` des sub-clips pour caler dessus est faisable et a un impact visuel énorme.

### Scope
**In scope :**
- Champ UI "Musique" (fichier MP3/WAV/FLAC/M4A) + bouton "Parcourir"
- Si fourni : analyse beats avec librosa
- Ajustement des in/out des sub-clips sélectionnés (STORY-002) pour aligner le cut sur le beat le plus proche (±0.3s tolérance)
- Ajout d'une piste audio A2 dans le Kdenlive XML avec le fichier musique
- Ducking simple en MLT : volume de A1 (audio source) à -12dB pendant que A2 (musique) joue
- Le toggle "Activer beat-sync" doit être explicite (musique fournie ≠ beat-sync, car parfois on veut juste de la musique de fond sans aligner les cuts)

**Out of scope :**
- Édition de tempo / time-stretch
- Mood matching auto (V2)
- Génération de musique
- Cross-fades audio sophistiqués

### User Flow
1. User scanne, trim et scoring tournent
2. User parcourt et sélectionne `family-2026.mp3`
3. User active "Sync sur beats"
4. Au lancement, librosa détecte les beats
5. L'algo ajuste chaque cut pour qu'il tombe sur un beat à ±0.3s
6. Si pas de beat proche : cut conservé
7. Kdenlive XML : musique sur A2, ducking sur A1 (audio caméra)
8. Log : "Beat-sync : 18 cuts alignés sur 20"

---

## Acceptance Criteria

- [ ] Champ "Musique" dans l'UI (QLineEdit + bouton "Parcourir...")
- [ ] Si vide : pipeline normal (pas de musique, pas de beat sync)
- [ ] Checkbox "Sync sur beats" (visible si musique fournie)
- [ ] CLI `--music FILE`, `--beat-sync` (les deux requis pour activer sync)
- [ ] `librosa.beat.beat_track()` détecte BPM + array beats (s)
- [ ] Pour chaque transition entre sub-clip i et i+1 :
  - chercher beat le plus proche de la position de cut
  - si distance < 0.3s : ajuster `out_i` ou `in_{i+1}` (le plus proche)
  - sinon : laisser
- [ ] Kdenlive XML : nouveau producer pour musique (`mlt_service=avformat-novalidate`)
- [ ] Nouvelle paire de playlists pour A2 (playlist4, playlist5)
- [ ] Nouveau tractor A2 (tractor2 ou autre numérotation)
- [ ] Sequence tractor liste : black, A1, A2, V1
- [ ] Track indices dans groups (AVSplit) restent valides
- [ ] Ducking : filter `volume` sur tractor A1 avec level=0.25 (= -12dB), keyframé éventuellement
- [ ] Render ffmpeg : input musique additionnel, mix dans filter_complex (`amix=inputs=2:weights=1 0.25`)
- [ ] Si beat-sync activé mais durée musique < durée montage : musique loopée (`-stream_loop -1`) ou tronquée (paramétrable, défaut loop)
- [ ] Si durée musique > durée montage : musique tronquée à la fin du montage
- [ ] Si librosa absent : message clair "Installer librosa pour activer beat-sync (`pip install librosa`)"
- [ ] Smoke test : Vidéos + musique gratuite quelconque (1-2 min) → Kdenlive ouvre, musique jouable, cuts alignés

---

## Technical Notes

### Composants à toucher
- Nouveau module `detect_beats(audio_path)` → `(bpm, beats_sec: list[float])`
- Nouvelle fonction `snap_to_beats(subclips, beats, tolerance=0.3)` → modifie les in/out
- `generate_kdenlive()` :
  - Si musique fournie : ajouter producer musique, tracks A2, ducking sur A1
  - Recalculer positions de frames groups en fonction des in/out snapés
- `build_ffmpeg_cmd()` :
  - Ajouter `-i music.mp3`
  - `filter_complex` : amix entre audio source et musique avec poids
- UI : champ + bouton + checkbox dans le grid des options

### Librosa
```python
def detect_beats(audio_path):
    y, sr = librosa.load(audio_path, sr=22050, mono=True)
    tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr)
    beats_sec = librosa.frames_to_time(beat_frames, sr=sr)
    return float(tempo), beats_sec.tolist()
```

### Snap algo
```python
def snap_to_beats(subclips, beats, tolerance=0.3):
    timeline_pos = 0.0
    for i, sc in enumerate(subclips):
        if i == 0:
            sc['timeline_start'] = 0.0
            timeline_pos += sc['out'] - sc['in']
            continue
        # cut intervient à timeline_pos
        nearest = min(beats, key=lambda b: abs(b - timeline_pos))
        offset = nearest - timeline_pos
        if abs(offset) <= tolerance:
            # ajuster en allongeant ou raccourcissant sc précédent
            prev = subclips[i-1]
            prev['out'] = min(prev['parent_duration'], max(prev['in'] + 0.5, prev['out'] + offset))
            timeline_pos = nearest
        sc['timeline_start'] = timeline_pos
        timeline_pos += sc['out'] - sc['in']
    return subclips
```

### Ducking (MLT)
Sur le tractor A1, ajouter un filter volume :
```xml
<filter id="filter_ducking">
  <property name="mlt_service">volume</property>
  <property name="level">0.25</property>
</filter>
```
Pour V1, simple constant. V2 = keyframé (baisser pendant parlé fort).

### Dépendances Python
- `librosa` (avec numba dépendance lourde, ~500MB) — Conditionnel : importé lazily, message clair si manquant
- Alternative légère : `madmom` mais plus complexe à installer

### Edge cases
- Pas de beats détectés (musique très calme) : log warning, pas de snap
- BPM erratique : on snap quand même au beat le plus proche (librosa gère)
- Musique trop courte : loop par défaut
- Cut snap-back fait sub-clip < 0.5s : skip ce snap, garder cut original

---

## Dépendances

**Prerequisite Stories :** STORY-001, STORY-002
**Blocked Stories :** STORY-005 (preview = peut inclure musique aussi)
**External :** `librosa` (avec dépendances numba/scipy, ~500MB d'install). Optionnel — l'app fonctionne sans, juste pas ce feature.

---

## Definition of Done

- [ ] librosa importé conditionnellement, instructions claires si manquant
- [ ] UI : champ musique + bouton parcourir + checkbox sync
- [ ] CLI : `--music` + `--beat-sync`
- [ ] Snap algo testé avec une musique fournie par le user
- [ ] Kdenlive XML : A2 valide, audio musique audible à l'ouverture
- [ ] Render MP4 : audio mixé correctement
- [ ] Logs : BPM détecté, nb beats alignés
- [ ] Réinstallé + commit + push

---

## Story Points : 5 (1.5-2h)

---

## Notes

Si librosa rebute par sa taille, fallback possible : `aubio` (binaire C, plus léger). À évaluer si l'install user-side pose souci.
