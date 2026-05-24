#!/usr/bin/env bash
# Installe video-souvenir (script Python + .desktop) dans le user-space.
# Detecte le Python a utiliser, installe PySide6, substitue les chemins.

set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33mATTENTION: %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mOK\033[0m %s\n' "$*"; }
err()  { printf '\033[31mERREUR: %s\033[0m\n' "$*" >&2; }

# --- Prerequis ---
bold "Verification des prerequis"

command -v ffmpeg >/dev/null  || { err "ffmpeg manquant"; exit 1; }
command -v ffprobe >/dev/null || { err "ffprobe manquant"; exit 1; }
ok "ffmpeg / ffprobe"

if ffmpeg -hide_banner -decoders 2>/dev/null | grep -qE '^\s*V[FX]?S\.\.D\s+h264\s'; then
  ok "decodeur H.264 natif"
else
  warn "ffmpeg-free detecte (seul libopenh264). Tu vas avoir 'Impossible de lire les dimensions' au scan."
  echo "    Lance:  sudo dnf swap ffmpeg-free ffmpeg --allowerasing"
fi

if command -v kdenlive >/dev/null || flatpak list --app 2>/dev/null | grep -qi kdenlive; then
  ok "kdenlive (mode projet utilisable)"
else
  warn "kdenlive absent (le mode 'Kdenlive' generera le fichier mais tu ne pourras pas l'ouvrir)"
fi

# --- Detection Python ---
bold "Detection de Python"
PYTHON=""
for cand in "$HOME/miniconda3/bin/python3" "$HOME/anaconda3/bin/python3" "$HOME/.local/bin/python3" "$(command -v python3 || true)"; do
  if [[ -n "$cand" && -x "$cand" ]]; then
    PYTHON="$cand"
    break
  fi
done
[[ -z "$PYTHON" ]] && { err "Python 3 introuvable"; exit 1; }
ok "Python: $PYTHON"

# --- Install PySide6 ---
bold "Installation de PySide6 (si manquant)"
if "$PYTHON" -c "import PySide6" 2>/dev/null; then
  ok "PySide6 deja installe"
else
  echo "  Installation via pip..."
  if ! "$PYTHON" -m pip install --quiet PySide6 2>/dev/null; then
    # Retry avec --user si l'install user-wide est refusee (PEP 668)
    "$PYTHON" -m pip install --quiet --user PySide6
  fi
  ok "PySide6 installe"
fi

# --- Install script ---
bold "Installation du script"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
mkdir -p "$BIN_DIR" "$APP_DIR"

# Substitue le shebang avec le Python detecte (pour que .desktop fonctionne sans PATH shell)
sed "1s|.*|#!$PYTHON|" video-souvenir > "$BIN_DIR/video-souvenir"
chmod +x "$BIN_DIR/video-souvenir"
ok "$BIN_DIR/video-souvenir"

# Substitue le chemin du Exec= dans le .desktop pour matcher le user actuel
sed "s|/home/goss/.local/bin/video-souvenir|$BIN_DIR/video-souvenir|g" video-souvenir.desktop > "$APP_DIR/video-souvenir.desktop"
ok "$APP_DIR/video-souvenir.desktop"

# --- Refresh menu KDE/GNOME ---
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true
command -v kbuildsycoca5 >/dev/null && kbuildsycoca5 >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null && update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

# --- Verif PATH ---
if ! echo ":$PATH:" | grep -q ":$BIN_DIR:"; then
  warn "$BIN_DIR n'est pas dans ton PATH. Ajoute a ton ~/.bashrc :"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

bold "Installe."
echo "  Lance avec: video-souvenir                   (UI)"
echo "          ou: video-souvenir <dossier>         (CLI)"
echo "  Ou via le menu Plasma: cherche 'Video Souvenir'"
