# STORY-004 : Style presets (color / look)

**Epic** : MVP V1 — Pré-montage assistant Kdenlive
**Priorité** : Must Have
**Story Points** : 3
**Status** : Not Started
**Sprint** : 1
**Créée** : 2026-05-28

---

## User Story

En tant qu'**utilisateur**,
je veux **choisir un style visuel ("Cinéma chaud", "Teal & Orange", "Vintage", "Doc")** avant de générer le montage,
afin que **le projet Kdenlive ouvert ait déjà un look cohérent et "monté" sans que je passe 10 min à régler des filtres color par caméra**.

---

## Description

### Background
Une LUT cinéma fait passer un montage de "vidéo de famille" à "film de famille". Plutôt que de demander à l'user de chercher/acheter des `.cube`, on propose des presets internes basés sur filtres MLT natifs (`brightness`, `lift_gamma_gain`, `saturation`, `hue` / `colorbalance`). Self-contained, instantané, et les filtres restent éditables dans Kdenlive.

### Scope
**In scope :**
- Combo UI "Style" : Neutre (défaut) / Cinéma chaud / Teal & Orange / Vintage / Doc punchy / Noir & Blanc / Custom LUT…
- Application : pile de filtres MLT empilés sur le tractor V1 dans le XML Kdenlive
- Application miroir dans `build_ffmpeg_cmd()` via filter_complex (`eq=`, `colorbalance=`, `hue=`)
- Si "Custom LUT…" : QFileDialog `.cube`, applique `<filter mlt_service="avfilter.lut3d" av.file=...>`
- Auto-detect : si `*.cube` ou `look.cube` existe dans le dossier source, présélectionné dans le combo

**Out of scope :**
- Édition manuelle des sliders (V2)
- Color-match inter-clips (V3)
- HDR detection (Insight 4 du brainstorm — V2)

### User Flow
1. User scanne le dossier
2. Auto-detect cherche `*.cube` dans le dossier → si trouvé, combo Style sur "Custom LUT (auto-detected)" avec le chemin
3. Sinon, combo Style sur "Neutre" par défaut
4. User choisit un preset dans la liste OU sélectionne "Custom LUT..."
5. Au lancement Kdenlive : XML contient les filtres sur tractor V1, look visible à l'ouverture
6. Au lancement Render : MP4 final a le look appliqué

---

## Acceptance Criteria

- [ ] Combo "Style" dans l'UI options grid avec 7 items
- [ ] CLI `--style {neutral|cinematic|teal-orange|vintage|doc|bw|custom}`, `--lut PATH` pour custom
- [ ] Chaque preset défini comme dict de paramètres (saturation, brightness, contrast, balance R/G/B, gamma)
- [ ] Application Kdenlive : pile de `<filter>` enfants du `tractor1` (V1)
  - `brightness` + `mlt_service=brightness` pour lift/exposure global
  - `mlt_service=avfilter.eq` ou similaires pour contrast/sat
  - `mlt_service=avfilter.colorbalance` pour teal&orange (split tone shadows/highlights)
  - `mlt_service=avfilter.hue` pour `s=0` (noir&blanc)
- [ ] Application ffmpeg render : chaîne `eq=brightness=…:contrast=…:saturation=…, colorbalance=rs=…:bs=…` insérée dans filter_complex juste après le scale
- [ ] Si "Custom LUT…" : `<filter mlt_service="avfilter.lut3d" av.file="/abs/path.cube"/>` sur V1, et `lut3d=/abs/path.cube` en ffmpeg
- [ ] Auto-detect `.cube` dans le dossier source : `scan_folder` ramène aussi un éventuel `lut_candidate`, l'UI le présélectionne
- [ ] Les filtres appliqués restent éditables/désactivables dans Kdenlive (vérifier en ouvrant le projet)
- [ ] Smoke test : générer projet en "Cinéma chaud" → ouvrir Kdenlive → preview montre look chaud différent du clip source
- [ ] Smoke test ffmpeg render : MP4 sortie a un look ≠ source

---

## Technical Notes

### Définition des presets
```python
STYLE_PRESETS = {
    'neutral': {},  # rien
    'cinematic': {
        'brightness': -0.02,     # léger lift sombres
        'contrast': 1.10,
        'saturation': 0.92,      # désaturé légèrement
        'gamma': 1.05,
        'gamma_r': 1.02, 'gamma_g': 1.00, 'gamma_b': 0.96,  # teint plus chaud
    },
    'teal-orange': {
        'shadows_b': 0.15,       # ombres bleu/teal
        'shadows_g': 0.05,
        'highlights_r': 0.10,    # hautes lumières orange
        'highlights_g': 0.03,
        'saturation': 1.15,
    },
    'vintage': {
        'brightness': 0.03,
        'contrast': 0.92,
        'saturation': 0.75,
        'gamma_r': 0.95, 'gamma_g': 1.00, 'gamma_b': 1.05,  # delavé légèrement froid
    },
    'doc': {
        'contrast': 1.18,
        'saturation': 1.20,
        'sharpness': 0.5,        # léger sharpen
    },
    'bw': {
        'saturation': 0.0,
        'contrast': 1.15,
    },
    'custom': None,  # signale "utiliser le .cube"
}
```

### Génération XML (Kdenlive)
Sur `tractor1` (V1), ajouter avant les `<track>` :
```xml
<filter id="filter_style_eq">
  <property name="mlt_service">avfilter.eq</property>
  <property name="av.brightness">-0.02</property>
  <property name="av.contrast">1.10</property>
  <property name="av.saturation">0.92</property>
  <property name="av.gamma">1.05</property>
  <property name="av.gamma_r">1.02</property>
  <property name="av.gamma_g">1.00</property>
  <property name="av.gamma_b">0.96</property>
  <property name="kdenlive_id">avfilter.eq</property>
</filter>
```

Pour teal-orange (split tone) :
```xml
<filter id="filter_style_colorbalance">
  <property name="mlt_service">avfilter.colorbalance</property>
  <property name="av.bs">0.15</property>
  <property name="av.gs">0.05</property>
  <property name="av.rh">0.10</property>
  <property name="av.gh">0.03</property>
  <property name="kdenlive_id">avfilter.colorbalance</property>
</filter>
```

Pour custom .cube :
```xml
<filter id="filter_style_lut3d">
  <property name="mlt_service">avfilter.lut3d</property>
  <property name="av.file">/abs/path/look.cube</property>
  <property name="kdenlive_id">avfilter.lut3d</property>
</filter>
```

### Render ffmpeg
Insérer dans filter_complex juste après le `scale,pad` de chaque entrée :
```
[i:v]scale=…,pad=…,setsar=1,fps=…,
  eq=brightness=-0.02:contrast=1.10:saturation=0.92:gamma=1.05:gamma_r=1.02:gamma_g=1.00:gamma_b=0.96,
  colorbalance=bs=0.15:gs=0.05:rh=0.10:gh=0.03,
  format=yuv420p[v_i];
```

Pour `.cube` : `lut3d=/path.cube` à la place.

### Auto-detect LUT
Dans `scan_folder`, après le scan des clips :
```python
lut_candidates = [p for p in folder.iterdir() if p.suffix.lower() == '.cube']
preferred = next((p for p in lut_candidates if p.stem.lower() == 'look'), None)
return clips, preferred or (lut_candidates[0] if lut_candidates else None)
```

### Dépendances
- Aucune nouvelle dépendance Python
- Filtres ffmpeg : `eq`, `colorbalance`, `hue`, `lut3d` — tous standard
- Kdenlive : `avfilter.eq`, `avfilter.colorbalance`, `avfilter.lut3d` — disponibles dans Kdenlive 24+ via wrappers MLT

---

## Dépendances

**Prerequisite Stories :** aucune (indépendant)
**Blocked Stories :** aucune
**External :** aucune nouvelle

---

## Definition of Done

- [ ] Dict `STYLE_PRESETS` défini
- [ ] Combo UI fonctionnelle, auto-detect du `.cube` éventuel
- [ ] Génération Kdenlive ajoute les `<filter>` sur tractor V1
- [ ] Render ffmpeg applique les mêmes corrections (cohérence)
- [ ] Pour chaque preset, vérifier visuellement (ouvrir Kdenlive, comparer monitors avant/après)
- [ ] Custom LUT charge un `.cube` user
- [ ] Auto-detect : déposer un `look.cube` test dans Vidéos → combo le sélectionne
- [ ] Réinstallé + commit + push

---

## Story Points : 3 (~1h)

---

## Notes

Si certains filtres Kdenlive 26 utilisent des `kdenlive_id` différents (p.ex. `colorbalance` natif Kdenlive ≠ `avfilter.colorbalance`), il faudra inspecter un projet Kdenlive qui utilise ces effets natifs et utiliser le bon ID. À ajuster pendant l'implémentation.
