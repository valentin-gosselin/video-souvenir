# Brainstorm — LUT + correctifs colorimétriques

**Date** : 2026-05-28
**Projet** : video-souvenir
**Facilitateur** : BMAD Creative Intelligence

## Objectif

Intégrer LUT cinéma + correctifs colorimétriques de base dans video-souvenir, pour que la sortie Kdenlive ait l'air d'un pré-montage qualitatif et pas d'un simple assemblage chrono. Couvrir : intégration pipeline (Kdenlive XML + render HEVC ffmpeg), UI, niveau d'automatisation, formats LUT, presets.

## Contexte

- Pipeline = `scan_folder` → `generate_kdenlive` (V1+A1, AVSplit groups, fondus brillance/volume) + `build_ffmpeg_cmd` (HEVC NVENC/QSV/VAAPI/x265)
- Sources hétérogènes : Sony C0xxx 4K + autres caméras potentielles + smartphones
- ~750 lignes Python, dépendances minimales (PySide6, ffmpeg, ffprobe)
- Le user édite ensuite dans Kdenlive — l'output doit rester éditable, pas figé

## Techniques appliquées

1. **Mind Mapping** — cartographier l'espace de design
2. **SCAMPER** — variantes via Substitute/Combine/Adapt/Modify/Eliminate/Reverse
3. **Six Thinking Hats** — pressure-test (Yellow/Black/Green/White)

## Insights clés

### 1. Pile d'effets sur le tractor V1, pas par-clip
Un seul (ou une pile) de `<filter>` MLT sur `tractor1`. Le user voit *un* effet éditable, pas N effets identiques. Pour cohérence Kdenlive↔MP4, soit dupliquer la pile en ffmpeg, soit router le render via `kdenlive_render`.
- **Impact** : Élevé · **Effort** : Faible

### 2. "Styles" bundlés > LUTs nues
Combo UI "Style: Neutre / Cinéma chaud / Teal&Orange / Vintage / Doc". Chaque style = `.cube` bundlé CC0 + defaults pour sliders correctifs. Option "Custom LUT…" reste dispo.
- **Impact** : Élevé · **Effort** : Moyen

### 3. Auto-detect LUT dans le dossier source
Convention : si `look.cube` (ou tout `.cube`) à côté des clips → sélectionné par défaut. Pattern "magic file", zéro UI.
- **Impact** : Moyen · **Effort** : Très faible

### 4. Détection HDR/HLG → désactiver LUT REC709 par défaut
`ffprobe` rapporte `color_primaries=bt2020` ou `color_trc=arib-std-b67`/`smpte2084` → warning UI + LUT off. Sinon LUT REC709 sur source HDR = vert/violet cassé.
- **Impact** : Moyen · **Effort** : Faible

### 5. Sliders correctifs sous "Avancé" replié
3 sliders (Exposition / Saturation / Température). Chaque style définit des defaults. Repliable, n'effraie pas le casual user.
- **Impact** : Moyen · **Effort** : Faible

### 6. (Parking V3) Auto-WB et color-match inter-clips
`signalstats` par clip, détection outliers (>2σ luma/sat), `colorbalance` correctif par-entry. À reporter — double le scan, complexifie. Après V1+V2 validées.

## MVP recommandé

**V1 (1-2h)** :
- Combo "Style" + 4 LUTs CC0 dans `~/.local/share/video-souvenir/luts/`
- `<filter avfilter.lut3d>` sur tractor V1
- Auto-detect `*.cube` dans le dossier source
- Détection HDR/HLG dans `probe_video` + warning
- Injection `lut3d=` dans `build_filter_complex` pour cohérence MP4

**V2** :
- Sliders Exposition/Saturation/Température (filtres `eq`/`colorbalance` dans la pile)
- Slider intensité LUT 0-100% (`mix=`)

**V3 (parking)** :
- Auto-WB par dossier
- Color-match inter-clips outliers

## Stats

- Idées : ~75 brutes
- Insights : 6 (5 actionnables + 1 parking)
- Techniques : 3
- Durée : ~15 min

## Next step recommandé

`/bmad:tech-spec` pour formaliser V1 en spec implémentable, ou implémentation directe si pas besoin de formalisme.

---

*Généré par BMAD Method v6 — Creative Intelligence*
