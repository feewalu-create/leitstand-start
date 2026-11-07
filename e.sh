#!/usr/bin/env bash
# einrichten.sh - bindet einen bestehenden Server mit EINEM Befehl an die Leitstand-Plattform an (als root).
#   curl -fsSL https://raw.githubusercontent.com/feewalu-create/leitstand-start/main/e.sh | bash -s leitstand leitstand
#   curl -fsSL https://raw.githubusercontent.com/feewalu-create/leitstand-start/main/e.sh | bash -s agent cx53-01 <Fingerabdruck>
# Erzeugt einen Nur-Lese-Schluessel, zeigt ihn an, wartet bis er auf GitHub eingetragen ist, holt das private
# Leitstand-Repo und installiert. Enthaelt keine Geheimnisse. Quelle: feewalu-create/Leitstand, bootstrap/einrichten.sh
set -euo pipefail

haupt() {   # alles in einer Funktion: bash liest das Skript vollstaendig ein, bevor es laeuft (sicher bei curl | bash)
  local ROLLE=${1:-} NAME=${2:-} FP=${3:-}
  case "$ROLLE" in leitstand|agent) ;; *) echo "Aufruf: … | bash -s leitstand <name>  oder  … | bash -s agent <name> <Fingerabdruck>"; exit 1;; esac
  [[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "Servername: Kleinbuchstaben, Ziffern, Bindestrich"; exit 1; }
  [ "$ROLLE" = leitstand ] || [ ${#FP} -ge 16 ] || { echo "Fuer Rolle agent den Fingerabdruck von der Statusseite des Leitstands angeben."; exit 1; }
  [ "$(id -u)" = 0 ] || { echo "Bitte als root ausfuehren (sudo -i)."; exit 1; }
  command -v git >/dev/null || { apt-get update -q; apt-get install -yq git; } </dev/null
  install -d -m 0700 /etc/leitstand
  [ -f /etc/leitstand/deploy_key ] || ssh-keygen -q -t ed25519 -N "" -C "leitstand@$NAME" -f /etc/leitstand/deploy_key </dev/null
  export GIT_SSH_COMMAND="ssh -i /etc/leitstand/deploy_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  local REPO=git@github.com:feewalu-create/Leitstand.git
  if ! git ls-remote "$REPO" >/dev/null 2>&1 </dev/null; then
    echo
    echo "Diesen Schluessel auf GitHub eintragen: Leitstand -> Settings -> Deploy keys -> Add deploy key"
    echo "Titel: leitstand-$NAME   (Haken bei 'Allow write access' NICHT setzen)"
    echo
    cat /etc/leitstand/deploy_key.pub
    echo
    echo "Ich warte, bis er eingetragen ist ..."
    until git ls-remote "$REPO" >/dev/null 2>&1 </dev/null; do sleep 10; done
    echo "Schluessel erkannt."
  fi
  [ -d /opt/leitstand/.git ] || git clone -q "$REPO" /opt/leitstand </dev/null
  git -C /opt/leitstand pull -q --ff-only </dev/null || true
  if [ "$ROLLE" = agent ]; then
    bash /opt/leitstand/install.sh --rolle agent --name "$NAME" --freigabe "$FP" </dev/null
  else
    bash /opt/leitstand/install.sh --rolle leitstand --name "$NAME" </dev/null
  fi
}

haupt "$@"
