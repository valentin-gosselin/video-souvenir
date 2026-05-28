# STORY-001 : Auto-trim par clip (silence / noir / flou)

**Epic** : MVP V1 — Pré-montage assistant Kdenlive
**Priorité** : Must Have (fondation)
**Story Points** : 5
**Status** : Not Started
**Sprint** : 1
**Créée** : 2026-05-28

---

## User Story

En tant qu'**utilisateur qui assemble ses clips familiaux dans video-souvenir**,
je veux **que l'outil détecte et trimme automatiquement les portions creuses (silence prolongé, frames noires, flou caméra)** au début et à la fin de chaque clip,
afin que **le projet Kdenlive ouvert ait déjà des in/out points propres et que je n'aie pas à couper manuellement les premières/dernières secondes de chaque clip**.

---

## Description

### Background
Quand on filme, on appuie sur REC un peu avant l'action et on coupe un peu après. Les 1-5 premières/dernières secondes d'un clip contiennent souvent : caméra qui se range, sol, micro coupé, plan flou avant focus, etc. Trimer ces portions manuellement sur 30+ clips = 30 min de boulot fastidieux et déterministe → parfait pour automatiser.

### Scope
**In scope :**
- Analyse par clip via `ffmpeg`/`ffprobe` (silence, luma, blur via variance Laplacienne ou fallback)
- Calcul d'un `in_point` et `out_point` (en secondes) qui éliminent les segments creux des bordures
- Application des trim points dans le XML Kdenlive généré (modifier `in`/`out` des `<entry>` ET `<producer>`)
- Application des trim points dans le pipeline ffmpeg render (`-ss`/`-to` ou trim filter)
- Option globale "agressivité" (slider 0-100, défaut 30 = conservateur)
- Toggle ON/OFF dans l'UI (défaut ON)
- Log dans la console UI : chaque trim affiché ("C0094.MP4: trimmed 0-2.3s (silence) + 12.0-12.5s (black)")

**Out of scope :**
- Trim au milieu d'un clip (juste début/fin pour V1)
- Détection contextuelle (voix vs silence intentionnel) — heuristique simple
- Recadrage automatique
- Stabilisation

### User Flow
1. User scanne un dossier (comme aujourd'hui)
2. Pendant le scan, l'analyse trim auto tourne en parallèle pour chaque clip
3. La liste des clips affiche maintenant la durée *trimmée* (et entre parenthèses la durée originale, p.ex. `1m23s (orig 1m30s)`)
4. Au lancement Kdenlive/Render, les in/out points trimmés sont utilisés
5. Console log montre les décisions prises

---

## Acceptance Criteria

- [ ] Une fonction `analyze_trim(clip_path)` retourne `(in_sec, out_sec)` calculés depuis ffmpeg analysis
- [ ] Détection silence début/fin : `ffmpeg ... -af silencedetect=n=-30dB:d=0.5` → trim si silence en début et/ou fin
- [ ] Détection noir/cramé début/fin : `ffmpeg ... -vf blackdetect=d=0.3:pix_th=0.10` → trim si black détecté
- [ ] Détection flou : extraction frame avec ffmpeg + variance Laplacienne via numpy/PIL (fallback heuristique si opencv non dispo)
- [ ] Slider "Agressivité trim" (0=disabled, 30=conservatif default, 70=normal, 100=agressif) dans l'UI grid des options
- [ ] Checkbox "Auto-trim" dans l'UI (défaut ON)
- [ ] CLI `--auto-trim` (défaut ON), `--no-auto-trim` pour désactiver, `--trim-strength N` pour slider
- [ ] Kdenlive XML reflète les nouveaux `in`/`out` (entries ET producers)
- [ ] Render ffmpeg utilise `-ss` et `-to` ou un trim filter
- [ ] Log UI ajoute une ligne par clip avec ce qui a été trimmé et combien
- [ ] Si trim conduit à durée trimmée < 1s, le clip est exclu (warning log)
- [ ] Le trim ne casse pas les groupes AVSplit (positions de frame recalculées)
- [ ] Le trim ne casse pas les fondus sur gap (durée trimmée utilisée)
- [ ] Smoke test : run sur `/mnt/Fichiers/Nextcloud/Gosselin 2026/Vidéos` → projet Kdenlive ouvrable et durée totale < durée totale sans trim

---

## Technical Notes

### Composants à toucher
- `probe_video()` : étendre avec optional analyse trim si flag activé, retourner `in_point`/`out_point`
- Nouvelle fonction `analyze_trim(path, strength)` : retourne `(in_sec, out_sec, reasons: list[str])`
- `generate_kdenlive()` : utiliser `c['in_point']` / `c['out_point']` dans les `<entry>` et `<producer>` (`in=` et `out=` au lieu de `00:00:00.000` et `dur_tc`)
- `build_ffmpeg_cmd()` : ajouter `-ss in_point -to out_point` avant chaque `-i path` (input seeking, rapide en NVENC)
- `compute_break_indices()` : utiliser la durée trimmée (et `creation_time + in_point` pour l'heure réelle de début)
- Fade filters : recalculer sur `dur_trimmed`
- Groupes AVSplit : frame positions calculées sur cumul des durées trimmées

### Heuristique d'analyse
**Silence (audio)** :
```
ffmpeg -i clip.mp4 -af silencedetect=n=-30dB:d=0.5 -f null - 2>&1
# Parse "silence_start: 0" et "silence_end: 2.3 | silence_duration: 2.3"
# Si silence touche le début (start=0) → trim_in = silence_end
# Si silence touche la fin (end >= duration - 0.1) → trim_out = silence_start
```

**Noir/cramé (vidéo)** :
```
ffmpeg -i clip.mp4 -vf blackdetect=d=0.3:pix_th=0.10 -an -f null - 2>&1
# Parse "black_start:0 black_end:1.5"
# Mêmes règles : si touche début → trim_in = black_end, si touche fin → trim_out = black_start
```

**Flou (variance Laplacienne)** :
```
# Pour les N premières et N dernières frames :
ffmpeg -i clip.mp4 -ss X -vframes 1 -vf "scale=320:-1" -f image2pipe - | PIL/numpy → Laplacien
# Variance < seuil (par strength) → frame floue → trim depuis cette frame
# Implémentation minimaliste : numpy.std(np.gradient(grayscale)) comme proxy si opencv pas dispo
```

**Strength mapping** :
- 0 : disabled (in=0, out=duration)
- 30 : silence >2s en début/fin, black >0.5s, flou variance <15
- 70 : silence >0.5s, black >0.2s, flou variance <30
- 100 : silence >0.2s, black >0.1s, flou variance <50

Prendre `trim_in = max(silence_in, black_in, blur_in)` ; pareil pour `trim_out` avec `min`.

### Dépendances Python
- `numpy` : nécessaire pour Laplacien (vérifier si déjà installable via miniconda du user — probable yes)
- `PIL` (Pillow) ou stdlib-only via parsing PPM ffmpeg : Pillow plus propre
- Pas d'opencv pour V1 (lourd, optionnel V2)

### Edge cases
- Clip 100% silence : exclu (durée trimmée < 1s)
- Clip très court (< 3s) : skip trim, garder tel quel
- Audio absent : skip silence detection
- Vidéo sans frames noires détectables : skip
- Performance : analyse en parallèle (`concurrent.futures.ThreadPoolExecutor`, max 4 workers)

### Sécurité / robustesse
- Subprocess timeout 60s par clip
- Fallback gracieux : si analyse foire, garder `in=0, out=duration` (= comportement actuel)
- Cache : stocker les résultats trim dans `.video-souvenir-cache.json` à côté des clips → re-run instantané

---

## Dépendances

**Prerequisite Stories :** aucune (fondation du MVP V1)
**Blocked Stories :** STORY-002 (scoring lit la durée trimmée), STORY-003 (beat sync sur structure trimmée), STORY-005 (preview sur clips trimmés)
**External :** `numpy` (vérifier dispo), Pillow optionnelle

---

## Definition of Done

- [ ] Code dans `video-souvenir` (1 nouvelle fonction d'analyse + modifications dans `probe_video`, `generate_kdenlive`, `build_ffmpeg_cmd`, UI)
- [ ] Réinstallé dans `~/.local/bin/video-souvenir`
- [ ] Smoke test CLI sur le dossier Vidéos du user : pas d'erreur, durée totale réduite, Kdenlive ouvre le projet
- [ ] Cache écrit/lu correctement (re-run sans recalcul si clips inchangés)
- [ ] Le slider et la checkbox fonctionnent dans l'UI Plasma
- [ ] Logs UI explicites par clip
- [ ] Commit + push

---

## Story Points

- Analyse ffmpeg + parsing : 2
- Pipeline integration (Kdenlive + ffmpeg + UI + cache) : 2
- Tests + ajustements seuils : 1
- **Total : 5 points (1.5-2h)**

---

## Notes

L'agressivité par défaut à 30 est volontairement très conservatrice : mieux vaut laisser 1-2s de silence en début que couper un moment important. Le user augmente s'il veut être plus radical.
