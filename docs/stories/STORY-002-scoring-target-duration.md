# STORY-002 : Sub-clip scoring + target duration

**Epic** : MVP V1 — Pré-montage assistant Kdenlive
**Priorité** : Must Have
**Story Points** : 5
**Status** : Not Started
**Sprint** : 1
**Créée** : 2026-05-28
**Dépend de** : STORY-001

---

## User Story

En tant qu'**utilisateur**,
je veux **pouvoir indiquer une durée cible globale (p.ex. 5 min) et que l'outil garde automatiquement les meilleurs moments de chaque clip pour s'en rapprocher**,
afin que **mon montage Kdenlive ouvert ait déjà la bonne longueur, sans contenir 25 min de B-roll quand je vise une vidéo souvenir de 5 min**.

---

## Description

### Background
Sans contrainte de durée, un dossier de 30 clips Sony fait facilement 25 min de timeline brut. Le monteur en sort 5-8 min utilisables. L'app peut faire 80% du tri si elle score chaque morceau et garde les meilleurs.

### Scope
**In scope :**
- Si un clip > 30s, le découper en sub-clips via PySceneDetect (ou heuristique d'optical flow simplifiée si dispo pas)
- Scorer chaque sub-clip : netteté (Laplacien) + énergie audio (RMS) + amplitude motion + bonus durée modeste
- Slider "Durée cible" dans l'UI (0 = tout garder, 3/5/10 min presets, custom)
- Algo gourmand : tri sub-clips par score décroissant, prendre jusqu'à atteindre la durée cible
- Re-trier les sub-clips retenus dans l'ordre chrono original pour l'output
- Préserver l'ordre des clips parents (sub-clips d'un même clip restent groupés)

**Out of scope :**
- Réordonnancement narratif (arc dramatique) — V3
- Détection faces dans le scoring (V2)
- Édition manuelle des scores
- Sub-clipping interactif

### User Flow
1. User scanne → auto-trim applique (STORY-001)
2. Pour clips > 30s, scenedetect produit des sub-clips
3. Chaque sub-clip est scoré
4. User choisit durée cible : 5 min (défaut)
5. Algo prend les top N sub-clips jusqu'à 5 min de cumul
6. Ordre chrono préservé
7. Kdenlive XML reflète : chaque sub-clip retenu = une `<entry>` avec `in`/`out` dans le clip parent
8. Log UI : "Gardé 12 sub-clips sur 24 (5min02 / 5min00 cible)"

---

## Acceptance Criteria

- [ ] Si clip > 30s : appel à PySceneDetect (`ContentDetector`) pour split
- [ ] Si PySceneDetect absent : fallback heuristique (split tous les 8s pour clips > 30s, simple mais OK)
- [ ] Scoring par sub-clip via ffmpeg :
  - `signalstats` pour luma stddev (proxy netteté/contraste)
  - `volumedetect` pour mean_volume (énergie audio)
  - `meta scenecut` ou différence de luma mean sur 1s pour motion
  - Score normalisé 0-1
- [ ] Slider durée cible dans UI : presets 0/3/5/10 min + custom spinbox (0 = pas de targeting)
- [ ] CLI `--target-duration N` (minutes), `--no-scoring` pour bypass
- [ ] Algo gourmand : trier par score desc, prendre tant que `sum(durations) < target * 60`
- [ ] Re-tri final par `(clip_index, sub_index)` pour préserver ordre temporel
- [ ] Output Kdenlive : pour chaque sub-clip retenu, une `<entry>` avec `in=sub_in, out=sub_out` du producteur parent
- [ ] Output ffmpeg : `filter_complex` avec `trim=start=sub_in:end=sub_out, asetpts/setpts=PTS-STARTPTS` puis concat
- [ ] Si durée cible non atteignable (tous clips < cible) : garde tout, log info
- [ ] Si durée cible = 0 : algorithme désactivé, on garde tous les sub-clips
- [ ] Groupes AVSplit : un groupe par sub-clip retenu (pas par clip parent)
- [ ] Fade-on-gap : break détecté entre sub-clips si leur `creation_time` réel diffère > seuil
- [ ] Smoke test sur dossier Vidéos : targeting 5 min → output Kdenlive ≈ 5 min ±10%

---

## Technical Notes

### Composants à toucher
- Nouveau module logique `score_clips(clips)` : prend la liste de clips trimmés, retourne `subclips` (liste de dicts avec `parent_path`, `parent_creation_time`, `in`, `out`, `score`)
- `scan_folder()` : appeler `score_clips` après l'analyse trim
- `generate_kdenlive()` : itérer sur les sub-clips retenus (pas les clips entiers), créer un producer par sub-clip OU réutiliser le producer parent et différer via `in`/`out` sur l'entry (préférable, moins de redondance)
- `build_ffmpeg_cmd()` : `filter_complex` adapté avec un trim par sub-clip retenu avant concat
- UI : combo "Durée cible" (0/3/5/10/Custom) avec spinbox custom révélé sur "Custom"

### Algo de scoring
```python
def score_subclip(parent_path, in_sec, out_sec, fps=30):
    # 1 frame au milieu pour blur :
    mid = (in_sec + out_sec) / 2
    sharpness = laplacian_variance(extract_frame(parent_path, mid))  # 0-100+

    # Audio RMS sur le segment :
    audio_rms = ffmpeg_volumedetect(parent_path, in_sec, out_sec)  # dB, -50 (calme) à 0 (fort)
    audio_energy = max(0, (audio_rms + 50) / 50)  # 0-1

    # Motion : différence luma entre 3 frames échantillonnées
    motion = compute_motion_proxy(parent_path, in_sec, out_sec)  # 0-1

    # Pénalité durée trop courte (< 2s)
    dur_factor = min(1.0, (out_sec - in_sec) / 2.0)

    # Pondération
    score = 0.4 * normalize(sharpness, 0, 100) \
          + 0.3 * audio_energy \
          + 0.2 * motion \
          + 0.1 * dur_factor
    return score
```

### Algo de sélection (greedy)
```python
def select_subclips(subclips, target_minutes):
    if target_minutes <= 0:
        return subclips
    target_sec = target_minutes * 60
    sorted_by_score = sorted(subclips, key=lambda s: -s['score'])
    selected = []
    total = 0
    for sc in sorted_by_score:
        dur = sc['out'] - sc['in']
        if total + dur > target_sec * 1.1:
            continue  # skip si dépasse trop la cible
        selected.append(sc)
        total += dur
        if total >= target_sec * 0.95:
            break
    # Réordonne par temps original
    selected.sort(key=lambda s: (s['parent_index'], s['in']))
    return selected
```

### Dépendances Python
- `scenedetect` (PySceneDetect) : optionnel, fallback heuristique simple si absent
- `numpy` : déjà requis par STORY-001

### Edge cases
- Tous sub-clips ont scores égaux → ordre chrono par défaut
- Un seul sub-clip avec score élevé domine → pad avec les suivants meilleurs
- Sub-clip de < 1.5s : exclu (trop court pour être utile)
- PySceneDetect échoue : fallback split à intervalles fixes
- `target = 0` : no-op (tous gardés)

---

## Dépendances

**Prerequisite Stories :** STORY-001 (utilise `in_point`/`out_point` des clips trimmés)
**Blocked Stories :** STORY-003 (beat sync agit sur les sub-clips retenus), STORY-005 (preview = échantillonne dans la sélection)
**External :** `scenedetect` recommandé (`pip install scenedetect`)

---

## Definition of Done

- [ ] Fonction de scoring testée sur 3-5 clips représentatifs du dossier Vidéos
- [ ] Algorithm de sélection respecte target ±10%
- [ ] UI combo durée cible + intégration CLI
- [ ] Output Kdenlive valide (XML parsable, pas de chevauchement)
- [ ] Output ffmpeg render valide (MP4 lisible)
- [ ] Logs UI : "Sélectionné X/Y sub-clips, durée Z (cible W)"
- [ ] Réinstallé + smoke test passant
- [ ] Commit + push

---

## Story Points : 5 (1.5-2h)

---

## Notes

Le scoring est volontairement simple en V1 (pas de ML, juste heuristiques ffmpeg). V2 ajoutera face detection pour bonus famille-friendly.
