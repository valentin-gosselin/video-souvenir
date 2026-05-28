# STORY-005 : Instant 12s preview

**Epic** : MVP V1 — Pré-montage assistant Kdenlive
**Priorité** : Could Have (nice-to-have V1)
**Story Points** : 3
**Status** : Not Started
**Sprint** : 1
**Créée** : 2026-05-28
**Dépend de** : STORY-001, STORY-002 (preview = échantillonne dans la sélection)

---

## User Story

En tant qu'**utilisateur**,
je veux **pouvoir générer en moins de 10s un MP4 de preview ~12s assemblé à partir d'extraits clés du montage proposé**,
afin que **je puisse vérifier le rendu (auto-trim + scoring + style) avant de lancer un render complet qui prend plusieurs minutes**.

---

## Description

### Background
Le user lance le scan, choisit son style, sa durée cible. Avant de partir sur 3-5 min de render, il veut un "thumbnail vidéo" du résultat. 12s de preview composé de 12 mini-clips d'1s pris à intervalle régulier dans la sélection → vérifie le look, l'ordre, le rythme.

### Scope
**In scope :**
- Bouton "Preview" dans l'UI (à côté du bouton "Lancer")
- À la pression : génère un MP4 court (12s ≈ 12 mini-clips de 1s) en NVENC fastest preset
- Affiche le résultat dans une fenêtre Qt simple (ou via QDesktopServices.openUrl si trop complexe)
- Préserve les params de style + scoring courants (mais skip beat-sync pour rapidité)
- Tempo cible : < 10s de génération sur la machine du user

**Out of scope :**
- Preview vidéo embedded en live (trop complexe pour V1)
- Preview audio interactif
- Scrubbing dans l'app

### User Flow
1. User scanne, ajuste style/durée
2. User clique "Preview"
3. UI freeze < 10s (avec un spinner)
4. Petite fenêtre s'ouvre avec player vidéo simple OU lecture externe (mpv/vlc)
5. User valide ou ajuste les params

---

## Acceptance Criteria

- [ ] Bouton "Preview" dans l'UI, à côté du bouton Lancer
- [ ] CLI `--preview` flag : génère le preview au lieu du montage complet (path = `souvenir-…-preview.mp4`)
- [ ] Sélection des moments : prendre N=12 sub-clips répartis uniformément dans la sélection finale (modulo N)
- [ ] Chaque échantillon = 1.0s pris au milieu du sub-clip parent
- [ ] Concat avec fade très court (50ms) entre eux (sinon trop saccadé)
- [ ] Encodage NVENC `-preset p1 -tune ll` (fastest) à 1080p max
- [ ] Style preset appliqué (cohérent avec le rendu final)
- [ ] Pas de beat-sync, pas de fondu sur gap (simplification)
- [ ] Output : `souvenir-…-preview.mp4` dans `/tmp/` ou dossier source
- [ ] Affichage : ouvrir avec `xdg-open` (système handle ça) — pas de player embed pour V1
- [ ] Temps total cible : < 10s sur la machine user
- [ ] Si échec preview, ne pas bloquer le bouton Lancer

---

## Technical Notes

### Composants à toucher
- Nouvelle fonction `build_preview_cmd(selected_subclips, style, output_path, max_w=1920, max_h=1080)`
- UI : `QPushButton "Preview"` + thread separé (réutilise EncodeThread avec preview flag)
- CLI : argparse `--preview` flag

### Stratégie d'échantillonnage
```python
def pick_preview_samples(subclips, n=12):
    if len(subclips) <= n:
        # Pour chaque sub-clip, prendre 1s au milieu
        return [(s['parent_path'], s['in'] + (s['out'] - s['in'])/2 - 0.5, 1.0) for s in subclips]
    # Sinon, échantillon uniforme
    step = len(subclips) // n
    chosen = [subclips[i * step] for i in range(n)]
    return [(s['parent_path'], s['in'] + (s['out'] - s['in'])/2 - 0.5, 1.0) for s in chosen]
```

### ffmpeg command
```bash
ffmpeg -y \
  -ss T1 -t 1.0 -i clip1.mp4 \
  -ss T2 -t 1.0 -i clip2.mp4 \
  ... (12 inputs)
  -filter_complex \
    "[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=…,setsar=1,fps=30,eq=…,format=yuv420p[v0];
     [1:v]…[v1]; … 
     [v0][0:a][v1][1:a]…[v11][11:a]concat=n=12:v=1:a=1[outv][outa]" \
  -map [outv] -map [outa] \
  -c:v hevc_nvenc -preset p1 -tune ll -cq 30 -b:v 0 -tag:v hvc1 \
  -c:a aac -b:a 96k \
  preview.mp4
```

### Performance budget
- 12 seeks ffmpeg (~0.5s chacun en NVENC HW = 6s)
- Encode 12s @ 1080p NVENC fastest : ~2-3s
- Total : ~8-9s sur la machine user (RTX présumé OK)
- Fallback x265 ultrafast si pas de NVENC : 15-20s acceptable

### UI integration
- Reuse `EncodeThread` avec un `preview=True` flag : skip Kdenlive gen, skip beat-sync, lance ffmpeg preview cmd
- À la fin : `QDesktopServices.openUrl(QUrl.fromLocalFile(preview_path))` ouvre dans le player système

### Edge cases
- Sélection vide : bouton désactivé tant que pas de scan
- Sub-clip < 1s : prendre toute sa durée (pas 1s)
- ffmpeg fail : message d'erreur clair dans le log UI

---

## Dépendances

**Prerequisite Stories :** STORY-001, STORY-002 (logique de sub-clipping)
**Blocked Stories :** aucune
**External :** aucune (réutilise ffmpeg existant)

---

## Definition of Done

- [ ] Bouton Preview UI + flag CLI
- [ ] Génération preview en < 10s sur la machine user
- [ ] Style preset visible dans le preview
- [ ] xdg-open lance le player système
- [ ] Pas de régression sur bouton Lancer
- [ ] Réinstallé + commit + push

---

## Story Points : 3 (~1h)

---

## Notes

Si la latence dépasse 10s, repli sur preview en 720p (au lieu de 1080p) ou réduction à 8 samples au lieu de 12.
