# leitstand-start

Öffentliches Startskript, um einen Server mit einem Befehl an die (private) Leitstand-Plattform anzubinden.
Enthält **keine Geheimnisse** – es erzeugt auf dem Server einen eigenen Nur-Lese-Schlüssel und wartet, bis er auf
GitHub eingetragen ist. Quelle und Pflege: `bootstrap/einrichten.sh` im privaten Repo `feewalu-create/Leitstand`.

```bash
curl -fsSL https://raw.githubusercontent.com/feewalu-create/leitstand-start/main/e.sh | bash -s leitstand leitstand
curl -fsSL https://raw.githubusercontent.com/feewalu-create/leitstand-start/main/e.sh | bash -s agent <name> <Fingerabdruck>
```
