#!/usr/bin/env bash
# Installs ArmadaNative (Star Trek: Armada for Apple Silicon Macs) and, if you want, the upscaled art packs.
#   curl -fsSL https://github.com/XSnelliusX/ArmadaReforged/releases/latest/download/install.sh | bash
# or from a clone: ./install.sh. Run it again to update or to switch between the looks. Never uses sudo.
#
# Environment (all optional):
#   ARMADA_RELEASE_URL  folder holding <name>-<version>-arm64.zip, SHA256SUMS and the pack zips (default: latest release;
#                       a file:// URL works, for testing)
#   ARMADA_LOOK         original | upscaled   (skips the question)
#   ARMADA_APP_DIR      where the app goes (default /Applications, else ~/Applications)
#   ARMADA_USER_DIR     settings folder (default ~/Library/Application Support/ArmadaNative); packs/ and game/ live there
#   ARMADA_GOG_INSTALLER  path of the GOG setup_star_trek*_armada_*.exe to extract (skips the question)
#   ARMADA_ASSUME_YES=1 answer yes to the confirmation questions (removing packs, installing innoextract)
#   ARMADA_TTY          where answers are read from (default /dev/tty, because stdin is the pipe)
set -euo pipefail

BASE_URL="${ARMADA_RELEASE_URL:-https://github.com/XSnelliusX/ArmadaReforged/releases/latest/download}"
BASE_URL="${BASE_URL%/}"
USER_DIR="${ARMADA_USER_DIR:-$HOME/Library/Application Support/ArmadaNative}"
PACKS_DIR="$USER_DIR/packs"
PACKS="borg federation klingon romulan hd"
GOG_URL="https://www.gog.com/en/game/star_trek_armada"

say() { printf '==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "this game build is for macOS only."
[ "$(uname -m)" = "arm64" ] || die "an Apple Silicon Mac (M1 or later) is required; this one reports $(uname -m)."
# a Rosetta shell reports x86_64 above, so a pass here is real Apple Silicon
macos="$(sw_vers -productVersion)"
[ "${macos%%.*}" -ge 13 ] || die "macOS 13 (Ventura) or later is required; this Mac runs $macos."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

TTY="${ARMADA_TTY:-/dev/tty}"
HAVE_TTY=0
if { exec 3<"$TTY"; } 2>/dev/null; then HAVE_TTY=1; fi

ask() {  # prompt -> answer in $REPLY ("" when there is no terminal)
  REPLY=""
  [ "$HAVE_TTY" = 1 ] || return 0
  printf '%s ' "$1" >&2
  read -r -u 3 REPLY || REPLY=""
}
confirm() {  # question -> 0 for yes
  [ "${ARMADA_ASSUME_YES:-0}" = 1 ] && return 0
  ask "$1 [y/N]"
  case "$REPLY" in y | Y | yes | YES) return 0 ;; *) return 1 ;; esac
}

download() {  # name destination
  curl -fL --progress-bar -o "$2" "$BASE_URL/$1" || die "download failed: $BASE_URL/$1"
}
verify() {  # file name-in-SHA256SUMS
  local want got
  want="$(awk -v n="$2" '$2 == n || $2 == "*" n { print $1 }' "$TMP/SHA256SUMS")"
  [ -n "$want" ] || die "$2 is not listed in SHA256SUMS"
  got="$(shasum -a 256 "$1" | awk '{ print $1 }')"
  [ "$want" = "$got" ] || die "checksum mismatch for $2 (expected $want, got $got)"
}

# ---- the app -------------------------------------------------------------------------------------------------------
say "Downloading the checksum list from $BASE_URL"
curl -fsSL -o "$TMP/SHA256SUMS" "$BASE_URL/SHA256SUMS" || die "cannot read $BASE_URL/SHA256SUMS"
app_zip="$(awk '$2 ~ /-arm64\.zip$/ { sub(/^\*/, "", $2); print $2; exit }' "$TMP/SHA256SUMS")"
[ -n "$app_zip" ] || die "no <name>-<version>-arm64.zip in SHA256SUMS"
say "Downloading $app_zip"
download "$app_zip" "$TMP/$app_zip"
verify "$TMP/$app_zip" "$app_zip"

if [ -n "${ARMADA_APP_DIR:-}" ]; then
  APP_DIR="$ARMADA_APP_DIR"
elif [ -w /Applications ]; then
  APP_DIR=/Applications
else
  APP_DIR="$HOME/Applications"
fi
mkdir -p "$APP_DIR"
ditto -x -k "$TMP/$app_zip" "$TMP/app"
APP="$(find "$TMP/app" -maxdepth 1 -name '*.app' -print -quit)"
[ -n "$APP" ] || die "$app_zip does not contain an app"
APP="$(basename "$APP")"  # the release's display name (ARMADA_APP_NAME in the top CMakeLists.txt)
say "Installing $APP into $APP_DIR (an older copy is replaced)"
rm -rf "${APP_DIR:?}/$APP"
ditto "$TMP/app/$APP" "$APP_DIR/$APP"
# A file fetched with curl carries no com.apple.quarantine attribute, so the ad-hoc signed app opens without the Gatekeeper
# "damaged" / "cannot be verified" dialog. Remove the attribute anyway in case a copy came from somewhere else.
xattr -dr com.apple.quarantine "$APP_DIR/$APP" 2>/dev/null || true
rm -f "$TMP/$app_zip"

# ---- the look ------------------------------------------------------------------------------------------------------
installed_packs=""
for p in $PACKS; do [ -d "$PACKS_DIR/$p" ] && installed_packs="$installed_packs $p"; done

look="${ARMADA_LOOK:-}"
if [ -z "$look" ]; then
  if [ "$HAVE_TTY" = 1 ]; then
    printf '\nChoose the look of the game:\n  1) Original look\n  2) Upscaled look (HD textures and remodelled ships, about 3 GB download)\n' >&2
    ask "Your choice [1/2]:"
    case "$REPLY" in 2) look=upscaled ;; *) look=original ;; esac
  elif [ -n "$installed_packs" ]; then
    look=upscaled  # no terminal and no choice given: an update keeps what is there
  else
    look=original
  fi
fi

case "$look" in
  upscaled)
    n=0
    for p in $PACKS; do
      n=$((n + 1))
      say "Pack $n of 5: $p"
      zip="Armada-pack-$p.zip"
      download "$zip" "$TMP/$zip"
      verify "$TMP/$zip" "$zip"
      rm -rf "$TMP/x" && mkdir "$TMP/x"
      ditto -x -k "$TMP/$zip" "$TMP/x"  # keeps the links that stand in for duplicate files
      rm -f "$TMP/$zip"
      [ -d "$TMP/x/$p/addon" ] || die "$zip does not contain $p/addon"
      mkdir -p "$PACKS_DIR"
      rm -rf "${PACKS_DIR:?}/$p"
      mv "$TMP/x/$p" "$PACKS_DIR/$p"
    done
    say "Upscaled look installed in $PACKS_DIR"
    ;;
  original)
    if [ -n "$installed_packs" ]; then
      if confirm "The upscaled packs ($installed_packs ) are installed in $PACKS_DIR. Remove them?"; then
        for p in $installed_packs; do rm -rf "${PACKS_DIR:?}/$p"; done
        rmdir "$PACKS_DIR" 2>/dev/null || true
        say "Packs removed: the game runs on the original art."
      else
        say "Packs kept: the game keeps the upscaled look. Run this script again to change that."
      fi
    else
      say "Original look: nothing more to download."
    fi
    ;;
  *) die "ARMADA_LOOK must be original or upscaled, not '$look'" ;;
esac
# The app's record of the look (look.txt, src/platform/packs.h; it would ask again without one): upscaled while packs are here.
look_now=original
for p in $PACKS; do [ -d "$PACKS_DIR/$p" ] && look_now=upscaled; done
mkdir -p "$USER_DIR"
echo "$look_now" >"$USER_DIR/look.txt"

# ---- the game data -------------------------------------------------------------------------------------------------
is_game_dir() {  # folder with Armada.exe, assets.zfs and startrek.zix, any letter case
  local f
  [ -d "$1" ] || return 1
  for f in Armada.exe assets.zfs startrek.zix; do
    [ -n "$(find "$1" -maxdepth 1 -iname "$f" -print -quit)" ] || return 1
  done
}

extract_gog() {  # path of the installer .exe
  local exe="$1" work found
  [ -f "$exe" ] || { say "No such file: $exe"; return 1; }
  if ! command -v innoextract >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1 && confirm "innoextract is needed to unpack the GOG installer. Install it with Homebrew?"; then
      brew install innoextract
    else
      say "innoextract is missing. Install it (brew install innoextract) and run this script again."
      return 1
    fi
  fi
  work="$TMP/gog"
  mkdir -p "$work"
  say "Unpacking the installer (needs about 1.5 GB free; this takes a few minutes)"
  innoextract --silent -d "$work" "$exe" || { say "innoextract failed."; return 1; }
  found="$(find "$work" -iname Armada.exe -print -quit)"
  [ -n "$found" ] && is_game_dir "$(dirname "$found")" || { say "The installer did not contain the game files."; return 1; }
  mkdir -p "$USER_DIR"
  rm -rf "$USER_DIR/game"
  mv "$(dirname "$found")" "$USER_DIR/game"
  printf '%s\n' "$USER_DIR/game" >"$USER_DIR/data_path.txt"  # the line the app's folder picker writes
  say "Game files are in $USER_DIR/game"
}

have_game=0
stored="$(head -n 1 "$USER_DIR/data_path.txt" 2>/dev/null || true)"
if [ -n "$stored" ] && is_game_dir "$stored"; then
  have_game=1
  say "Game data found: $stored"
fi
if [ "$have_game" = 0 ]; then
  exe="${ARMADA_GOG_INSTALLER:-}"
  if [ -z "$exe" ] && [ "$HAVE_TTY" = 1 ]; then
    printf '\nArmada needs the original game, which this package does not contain.\n' >&2
    printf 'If you have the GOG installer (setup_star_trek*_armada_*.exe) on this Mac, enter its path (or drag the file here);\n' >&2
    ask "press Return to skip:"
    exe="${REPLY//\\ / }"                    # a dragged path has escaped spaces
    exe="${exe%\'}"; exe="${exe#\'}"          # ... or quotes
  fi
  if [ -n "$exe" ] && extract_gog "$exe"; then have_game=1; fi
fi

# ---- done ----------------------------------------------------------------------------------------------------------
cat <<EOF

${APP%.app} is installed: $APP_DIR/$APP

EOF
if [ "$have_game" = 1 ]; then
  echo "The game data is set up. Open ${APP%.app} from Applications (or Launchpad) to play."
else
  cat <<EOF
The original game is still required. On first start the app asks for the game's install folder: the folder that contains
Armada.exe, assets.zfs and startrek.zix.
  1. Buy Star Trek: Armada at GOG: $GOG_URL
  2. The GOG offline installer is a Windows .exe, so unpack it on the Mac:
       brew install innoextract
       innoextract -d ~/Armada-game ~/Downloads/setup_star_trek*_armada_*.exe
     and pick the folder ~/Armada-game/app when the app asks.
  Or run this script again with the installer: ARMADA_GOG_INSTALLER=<path to the .exe> ./install.sh
EOF
fi
echo "To switch between the original and the upscaled look, or to update, run this script again."
