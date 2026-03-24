# Git-basiertes Deployment Setup

Vollständige Anleitung zum Einrichten des Git-basierten Deployment-Workflows zwischen Mac und Pi5.

## 📋 Übersicht

Dieser Workflow ermöglicht es, Änderungen vom Mac per `git push` auf den Pi5 zu deployen:
- **Docker-Services**: Werden automatisch neu gestartet
- **System-Konfigurationen**: Werden kopiert, müssen manuell angewendet werden

## 🎯 Architektur

```
Mac (Development)
    ↓ git push
Pi5 Git Server (Bare Repository)
    ↓ post-receive hook
Pi5 Working Directory (/home/hajo/BOB)
    ↓ automatisch
Docker Services neu starten
```

## 🚀 Einrichtung auf dem Pi5

### 1. Bare Repository erstellen

```bash
# Vom Mac aus auf den Pi5 verbinden
ssh hajo@pi5 -p 22

# Jetzt auf dem Pi5: Bare Repository erstellen
mkdir -p /home/hajo/git/BOB.git
cd /home/hajo/git/BOB.git
git init --bare

# Berechtigungen setzen
chown -R hajo:hajo /home/hajo/git/BOB.git
```

### 2. Working Directory vorbereiten

```bash
# Weiterhin auf dem Pi5: Working Directory erstellen
mkdir -p /home/hajo/BOB
cd /home/hajo/BOB

# Initial checkout (falls noch nicht vorhanden)
git clone /home/hajo/git/BOB.git /home/hajo/BOB
```

### 3. Post-receive Hook erstellen

```bash
# Weiterhin auf dem Pi5: Hook-Datei erstellen
cd /home/hajo/git/BOB.git/hooks
nano post-receive
```

**Inhalt des post-receive Hooks:**

```bash
#!/bin/bash
# Post-receive Hook für automatisches Deployment

TARGET="/home/hajo/BOB"
GIT_DIR="/home/hajo/git/BOB.git"

echo "🔄 Deploying to $TARGET..."

# Checkout der neuesten Version
git --work-tree=$TARGET --git-dir=$GIT_DIR checkout -f main

cd $TARGET

# Docker-Services neu starten (automatisch)
if [ -f "docker/docker-compose.yml" ]; then
    echo "🐳 Restarting Docker services..."
    cd docker
    docker-compose down
    docker-compose up -d
    cd ..
    echo "✅ Docker services restarted"
fi

# System-Konfigurationen (nur kopiert, nicht angewendet)
if [ -d "system" ]; then
    echo "📋 System configurations updated"
    echo "⚠️  Run manually: sudo /home/hajo/BOB/system/apply-system-config.sh"
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Summary:"
echo "  - Files updated in: $TARGET"
echo "  - Docker services: Restarted automatically"
echo "  - System configs: Manual apply needed"
```

**Hook ausführbar machen:**

```bash
chmod +x /home/hajo/git/BOB.git/hooks/post-receive
```

### 4. Sudo-Rechte für System-Config-Script (Optional)

Falls du das System-Config-Script ohne Passwort ausführen möchtest:

```bash
# Weiterhin auf dem Pi5
sudo visudo
```

**Im visudo-Editor:**

Die Zeile wird **am Ende der Datei** hinzugefügt, nach allen anderen Einträgen:

```
# ... (bestehende Einträge) ...

# User privilege specification
root    ALL=(ALL:ALL) ALL

# Members of the admin group may gain root privileges
%admin ALL=(ALL) ALL

# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL

# ... (weitere Einträge) ...

# BOB System Config Script - no password required
hajo ALL=(ALL) NOPASSWD: /home/hajo/BOB/system/apply-system-config.sh
```

**Wichtig:**
- Füge die Zeile **ganz am Ende** hinzu
- Speichern mit `Ctrl+O`, dann `Enter`, dann `Ctrl+X` (bei nano)
- Oder `:wq` bei vim
- visudo prüft automatisch die Syntax beim Speichern

## 💻 Einrichtung auf dem Mac

### 1. Remote hinzufügen

```bash
# Im BOB-Verzeichnis auf dem Mac
cd /Users/hajo/Privat/RaspberryPi/BOB

# Pi5 als Remote hinzufügen
git remote add pi5 ssh://hajo@<pi5-ip-oder-hostname>/home/hajo/git/BOB.git

# Alternativ mit SSH-Config-Namen:
git remote add pi5 ssh://pi5/home/hajo/git/BOB.git
```

### 2. SSH-Config einrichten (Empfohlen)

```bash
# SSH-Config bearbeiten
nano ~/.ssh/config
```

**Inhalt:**

```
Host pi5
    HostName 192.168.178.55
    User hajo
    Port 22
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
```

**Danach kannst du einfach `ssh pi5` verwenden statt `ssh hajo@pi5 -p 22`**

### 3. Initial Push

```bash
# Ersten Push durchführen
git push pi5 main

# Als Standard-Remote setzen (optional)
git branch --set-upstream-to=pi5/main main
```

## 📝 Täglicher Workflow

### Änderungen deployen

```bash
# 1. Änderungen machen (z.B. Traefik-Config)
vim docker/traefik/config/traefik.yml

# 2. Änderungen committen
git add docker/traefik/config/traefik.yml
git commit -m "Update Traefik rate limiting"

# 3. Auf Pi5 deployen
git push pi5 main

# → Docker-Services werden automatisch neu gestartet
```

### System-Konfigurationen deployen

```bash
# 1. System-Config ändern (z.B. Firewall)
vim system/firewall/nftables-pi5-fixed.conf

# 2. Committen und pushen
git add system/firewall/nftables-pi5-fixed.conf
git commit -m "Update firewall rules"
git push pi5 main

# 3. Auf Pi5 manuell anwenden
ssh pi5
cd /home/hajo/BOB
sudo ./system/apply-system-config.sh
```

## 🌿 Feature-Branches

### Experimente mit Branches

```bash
# 1. Feature-Branch erstellen
git checkout -b feature/crowdsec-test

# 2. Änderungen machen und committen
vim docker/crowdsec/config/scenarios/custom.yaml
git add docker/crowdsec/config/scenarios/custom.yaml
git commit -m "Add custom CrowdSec scenario"

# 3. Auf Pi5 testen (Branch pushen)
git push pi5 feature/crowdsec-test

# 4. Auf Pi5 Branch auschecken und testen
ssh pi5
cd /home/hajo/BOB
git checkout feature/crowdsec-test
cd docker
docker-compose up -d

# 5. Wenn erfolgreich: Zurück zu main und mergen
git checkout main
git merge feature/crowdsec-test
git push pi5 main
```

## 🔄 Rollback bei Problemen

### Letzten Commit rückgängig machen

```bash
# Auf dem Mac
git revert HEAD
git push pi5 main
```

### Zu einem bestimmten Commit zurück

```bash
# Commit-Hash finden
git log --oneline

# Zu Commit zurücksetzen
git reset --hard <commit-hash>
git push pi5 main --force
```

### Auf dem Pi5 manuell zurücksetzen

```bash
ssh pi5
cd /home/hajo/BOB
git log --oneline
git reset --hard <commit-hash>
cd docker
docker-compose up -d
```

## 🔍 Troubleshooting

### Push schlägt fehl

```bash
# Remote-URL prüfen
git remote -v

# SSH-Verbindung testen
ssh hajo@pi5 -p 22
# Oder mit SSH-Config:
ssh pi5

# Git-Status auf Pi5 prüfen
ssh hajo@pi5 -p 22 "cd /home/hajo/BOB && git status"
```

### Hook wird nicht ausgeführt

```bash
# Vom Mac aus auf Pi5: Hook-Berechtigungen prüfen
ssh hajo@pi5 -p 22
ls -l /home/hajo/git/BOB.git/hooks/post-receive

# Hook ausführbar machen
chmod +x /home/hajo/git/BOB.git/hooks/post-receive

# Hook manuell testen
/home/hajo/git/BOB.git/hooks/post-receive
```

### Docker-Services starten nicht

```bash
# Vom Mac aus auf Pi5 verbinden und Logs prüfen
ssh hajo@pi5 -p 22
cd /home/hajo/BOB/docker
docker-compose logs

# Services manuell neu starten
docker-compose down
docker-compose up -d
```

## 📊 Status prüfen

### Auf dem Mac

```bash
# Lokale Änderungen anzeigen
git status

# Commits anzeigen
git log --oneline -10

# Remotes anzeigen
git remote -v
```

### Auf dem Pi5

```bash
# Working Directory Status
ssh pi5 "cd /home/hajo/BOB && git status"

# Letzter Commit
ssh pi5 "cd /home/hajo/BOB && git log -1"

# Docker-Services Status
ssh pi5 "cd /home/hajo/BOB/docker && docker-compose ps"
```

## 🔐 Sicherheit

### SSH-Key statt Passwort

```bash
# SSH-Key generieren (falls noch nicht vorhanden)
ssh-keygen -t ed25519 -C "mac-to-pi5"

# Public Key auf Pi5 kopieren
ssh-copy-id -i ~/.ssh/id_ed25519.pub hajo@pi5

# Testen
ssh pi5
```

### .gitignore prüfen

Stelle sicher, dass sensible Daten nicht committed werden:

```bash
# .gitignore prüfen
cat .gitignore

# Wichtig:
# - .env Dateien
# - Passwörter
# - Private Keys
# - Zertifikate
```

## 📚 Weiterführende Informationen

- [Git Hooks Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
- [Bare Repository Explained](https://git-scm.com/book/en/v2/Git-on-the-Server-Getting-Git-on-a-Server)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

**Erstellt**: 2026-03-24  
**Letzte Aktualisierung**: 2026-03-24