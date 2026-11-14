#!/usr/bin/env bash
# einrichten.sh - bindet einen bestehenden Server mit EINEM Befehl an die Leitstand-Plattform an (als root).
#   curl -fsSL https://raw.githubusercontent.com/feewalu-create/leitstand-start/main/e.sh | bash -s leitstand leitstand
#   curl -fsSL https://raw.githubusercontent.com/feewalu-create/leitstand-start/main/e.sh | bash -s agent cx53-01 <Fingerabdruck>
#   curl -fsSL https://raw.githubusercontent.com/feewalu-create/leitstand-start/main/e.sh | bash -s live-waechter live-waechter <Fingerabdruck>
# Erzeugt einen Nur-Lese-Schluessel, zeigt ihn an, wartet bis er auf GitHub eingetragen ist, holt das private
# Leitstand-Repo und installiert. Enthaelt keine Geheimnisse. Quelle: feewalu-create/Leitstand, bootstrap/einrichten.sh
set -euo pipefail

haupt() {   # alles in einer Funktion: bash liest das Skript vollstaendig ein, bevor es laeuft (sicher bei curl | bash)
  local ROLLE=${1:-} NAME=${2:-} FP=${3:-}
  case "$ROLLE" in leitstand|agent|live-waechter) ;; *) echo "Aufruf: … | bash -s leitstand <name>  oder  … | bash -s agent|live-waechter <name> <Fingerabdruck>"; exit 1;; esac
  [[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "Servername: Kleinbuchstaben, Ziffern, Bindestrich"; exit 1; }
  [ "$ROLLE" = leitstand ] || [ ${#FP} -ge 16 ] || { echo "Fuer Rolle agent den Fingerabdruck von der Statusseite des Leitstands angeben."; exit 1; }
  [ "$(id -u)" = 0 ] || { echo "Bitte als root ausfuehren (sudo -i)."; exit 1; }
  export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1
  command -v git >/dev/null || { apt-get update -q; apt-get install -yq git; } </dev/null
  install -d -m 0700 /etc/leitstand
  [ -f /etc/leitstand/deploy_key ] || ssh-keygen -q -t ed25519 -N "" -C "leitstand@$NAME" -f /etc/leitstand/deploy_key </dev/null
  export GIT_SSH_COMMAND="ssh -i /etc/leitstand/deploy_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  local REPO=git@github.com:feewalu-create/Leitstand.git
  local STATUS_PID=""
  if ! git ls-remote "$REPO" >/dev/null 2>&1 </dev/null && [ "$ROLLE" != leitstand ]; then
    # Beim Leitstand anmelden: er traegt den Schluessel selbst bei GitHub ein (wenn dort ein GitHub-Token hinterlegt ist)
    command -v age-keygen >/dev/null || { apt-get install -yq age; } </dev/null >/dev/null 2>&1 || true
    [ -f /etc/leitstand/age.key ] || { age-keygen -o /etc/leitstand/age.key 2>/dev/null; chmod 600 /etc/leitstand/age.key; } || true
    local TS_IP LS_IP; TS_IP=$(tailscale ip -4 2>/dev/null | head -1 || true); LS_IP=$(tailscale ip -4 leitstand 2>/dev/null | head -1 || true)
    install -d -m 0755 /var/lib/leitstand/agent
    printf '{"name": "%s", "anmeldung": true, "zustand": "wartet auf Freischaltung", "deploy_key": "%s", "age_empfaenger": "%s"}\n' \
      "$NAME" "$(cat /etc/leitstand/deploy_key.pub)" "$(age-keygen -y /etc/leitstand/age.key 2>/dev/null || true)" > /var/lib/leitstand/agent/status.json
    if [ -n "$TS_IP" ] && [ -n "$LS_IP" ]; then
      python3 - /var/lib/leitstand/agent/status.json "$TS_IP" "$LS_IP" <<'PY' </dev/null &
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
datei, bind, erlaubt = sys.argv[1], sys.argv[2], {"127.0.0.1", sys.argv[2], sys.argv[3]}
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.client_address[0] not in erlaubt or self.path != "/status.json":
            self.send_response(403); self.end_headers(); return
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers()
        self.wfile.write(open(datei, "rb").read())
HTTPServer((bind, 8201), H).serve_forever()
PY
      STATUS_PID=$!
      echo "Beim Leitstand angemeldet – er traegt den Schluessel selbst ein, sobald ein GitHub-Token hinterlegt ist."
    fi
  fi
  if ! git ls-remote "$REPO" >/dev/null 2>&1 </dev/null; then
    echo
    echo "Falls nicht automatisch: diesen Schluessel auf GitHub eintragen: Leitstand -> Settings -> Deploy keys -> Add deploy key"
    echo "Titel: leitstand-$NAME   (Haken bei 'Allow write access' NICHT setzen)"
    echo
    cat /etc/leitstand/deploy_key.pub
    echo
    echo "Ich warte, bis er eingetragen ist ..."
    until git ls-remote "$REPO" >/dev/null 2>&1 </dev/null; do sleep 10; done
    echo "Schluessel erkannt."
  fi
  [ -n "$STATUS_PID" ] && kill "$STATUS_PID" 2>/dev/null || true
  [ -d /opt/leitstand/.git ] || git clone -q "$REPO" /opt/leitstand </dev/null
  git -C /opt/leitstand pull -q --ff-only </dev/null || true
  if [ "$ROLLE" != leitstand ]; then
    bash /opt/leitstand/install.sh --rolle "$ROLLE" --name "$NAME" --freigabe "$FP" </dev/null
  else
    bash /opt/leitstand/install.sh --rolle leitstand --name "$NAME" </dev/null
  fi
}

haupt "$@"
