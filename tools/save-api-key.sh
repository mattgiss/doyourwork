#!/bin/bash
# Save an API key to a private file without it showing on screen or landing in shell history.
#
#   tools/save-api-key.sh elevenlabs
#   tools/save-api-key.sh gemini
#
# The key goes to ~/.config/doyourwork/<name>.key, readable only by you.
set -euo pipefail
NAME="${1:-elevenlabs}"
case "$NAME" in
  elevenlabs|gemini) ;;
  *) echo "usage: $0 [elevenlabs|gemini]   (no word means elevenlabs)" >&2; exit 1 ;;
esac
if [ "$NAME" = elevenlabs ]; then
  echo "Get the key at elevenlabs.io: your profile picture > API Keys > Create API Key, then Copy."
  echo "It starts with sk_ ."
else
  echo "Get the key at aistudio.google.com/apikey: open the key, then Copy key."
fi
DIR="$HOME/.config/doyourwork"
FILE="$DIR/$NAME.key"
mkdir -p "$DIR" && chmod 700 "$DIR"
printf "Paste your %s API key (it won't show), then press Return: " "$NAME"
IFS= read -rs KEY
echo
KEY="$(printf %s "$KEY" | tr -d '[:space:]')"
[ -n "$KEY" ] || { echo "Nothing entered; nothing saved." >&2; exit 1; }
umask 077
printf %s "$KEY" > "$FILE"
chmod 600 "$FILE"
echo "Saved to $FILE (${#KEY} characters)."
