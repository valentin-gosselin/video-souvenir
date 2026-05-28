# Brainstorm — Direction produit globale

**Date** : 2026-05-28
**Projet** : video-souvenir
**Scope** : élargi — pas que LUT, vraiment "comment faire un super montage depuis un dossier"

## Cadrage

Objectif : à partir d'un dossier de clips bruts, produire un montage qui ressemble à un travail humain. Tout sur la table : stack (Python/Rust/Go/Tauri…), niveau d'auto, features.

Le user édite ses vidéos familiales en post dans Kdenlive. L'app actuelle ne lui fait gagner que ~3 min. Il vise un outil qui fait 70-80% du boulot avant qu'il ouvre Kdenlive — ou un outil qui élimine Kdenlive complètement.

## Techniques

1. **Starbursting** — Who/What/Where/When/Why/How sur "le monteur idéal"
2. **Mind Mapping** — design space complet
3. **SCAMPER + Reverse Brainstorming** — variantes radicales + identification des pièges

## Insights synthétiques

### Sur le produit
- Cible primaire : **soi + famille**, narratif émotionnel > technique parfaite
- L'app doit s'insérer **avant Kdenlive** (sinon oubliée), **réversible** (tout doit pouvoir être défait), **transparente** (log de chaque décision), **conservatrice par défaut**, **tunable** via 1 slider d'agressivité
- "Bon montage" = pas de moments creux + cuts au bon moment + rythme variable + cohérence visuelle + arc dramatique + durée raisonnable (5-10 min)

### Sur les pièges à éviter
1. Trop opinionné (un seul style imposé)
2. Pas réversible
3. Lent (> 5 min pour 50 clips = abandonné)
4. Installation pénible (Python deps qui cassent)
5. Faux positifs scoring (coupe le moment crucial parce que "flou")
6. Trop de réglages (panel à 30 sliders → paralysie)
7. Re-run impossible / lent (pas de cache d'analyse)
8. Pas de preview rapide
9. Pas portable (Linux-only pour une app de famille)
10. Stack exotique qui s'effondre dans 2 ans

### Sur les killer features (au-delà du chrono assembly actuel)
- Trim auto silence + flou + noir/cramé (Auto-Editor-style)
- Scoring par sous-clip et garder le meilleur N%
- Sync musique (beats librosa → cuts alignés)
- Mood/style bundles complets (LUT + musique + pacing + transitions)
- Geoloc-based scene grouping
- Preview 12s instantané avant render final
- Output toujours = Kdenlive éditable + MP4 final

## 3 directions produit

### A. Assistant de pré-montage Kdenlive (évolution)
- **Stack** : Python + ffmpeg + OpenCV + librosa + ONNX. PySide6.
- **Output** : Kdenlive richement annoté (trims, scènes, fondus, score)
- **Effort** : 2-4 semaines en sessions
- **Risque** : faible
- **Pour qui** : moi (workflow Kdenlive préservé)

### B. Générateur autonome cross-platform (pivot)
- **Stack** : Rust + ffmpeg-next + onnxruntime + Tauri/egui. Single binary.
- **Output** : MP4 prêt à partager, Kdenlive en option
- **Effort** : 2-4 mois
- **Risque** : élevé (Rust learning, ambition produit)
- **Pour qui** : moi + famille + potentiellement public

### C. Studio self-hosted (pivot service)
- **Stack** : Python + FastAPI + frontend SPA, déployé Docker sur home server
- **Output** : Upload depuis device → render serveur → lien partage
- **Effort** : 3-6 semaines
- **Risque** : moyen
- **Pour qui** : moi (ergonomie remote)

## Recommandation

**A maintenant, B plus tard**. A capitalise sur l'existant (70% déjà là), valide les heuristiques en conditions réelles. Quand on connaîtra précisément ce qui marche, on aura les specs pour B.

Pour A, MVP V1 :
1. Trim auto par clip (silence + flou + noir) via Auto-Editor lib ou heuristique custom
2. Scoring par sous-clip + slider "durée cible globale" (3 / 5 / 10 min)
3. Beat sync optionnel (musique fournie)
4. Styles LUT bundlés
5. Preview 12s instantané

## Stats

- Idées générées : ~110
- Catégories : 8
- Directions : 3
- Techniques : 3
- Durée : ~20 min

---

*Généré par BMAD Method v6 — Creative Intelligence*
