## Docker CE auf Raspberry Pi 5 (64-bit) mit Raspberry Pi OS Trixie

```bash
# System aktualisieren
sudo apt update
sudo apt install -y ca-certificates curl

# Keyring anlegen
sudo install -m 0755 -d /etc/apt/keyrings

# Docker GPG-Key laden
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

# Docker-Repository (arm64, Trixie) hinzufügen
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: arm64
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Paketliste aktualisieren
sudo apt update

# Docker installieren
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker-Dienst aktivieren & starten
sudo systemctl enable docker
sudo systemctl start docker

# User zur docker-Gruppe hinzufügen (ohne sudo nutzbar)
sudo usermod -aG docker hajo

# Neue Gruppenzugehörigkeit laden (oder neu einloggen)
newgrp docker

# Test
docker run hello-world
```


## Fix: "No memory limit support" auf Raspberry Pi 5 (64-bit, Trixie)
Das Kommando `docker info` meckert fehlenden Memory Limit support:
```
...
WARNING: No memory limit support
WARNING: No swap limit support
```

# 1. Boot-Config öffnen
sudo nano /boot/firmware/cmdline.txt

# 2. Am ENDE der EINZIGEN Zeile hinzufügen:
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1

# Wichtig:
# - Alles muss in EINER Zeile stehen
# - Kein Zeilenumbruch
# - Nur Leerzeichen trennen

# Beispiel wie die Zeile am Ende aussehen kann:
# ... rootwait cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1

# 3. Speichern und reboot
sudo reboot

# 4. Danach prüfen
docker info | grep -i memory






# Docker-Optimierung für Raspberry Pi 5 (16GB RAM + SSDs)

## System-Spezifikationen
- **Hardware**: Raspberry Pi 5
- **RAM**: 16 GB
- **System-Drive**: 250 GB SSD
- **Home-Drive**: 950 GB SSD (`/home`)

## Optimale Docker Daemon Konfiguration

### Datei: `/etc/docker/daemon.json`

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "features": {
    "buildkit": true
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "userland-proxy": false,
  "live-restore": true,
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "default-shm-size": "512M"
}
```

**Hinweis**: Die Option `storage-opts: ["overlay2.override_kernel_check=true"]` wird auf Raspberry Pi 5 nicht benötigt und führt zu Fehlern beim Docker-Start.

## Erklärung der Einstellungen

### Logging
- **`log-driver: json-file`**: Standard JSON-Logging
- **`max-size: 100m`**: Maximale Größe pro Log-Datei (großzügig für SSDs)
- **`max-file: 5`**: Anzahl rotierter Log-Dateien (500MB gesamt pro Container)

### Storage
- **`storage-driver: overlay2`**: Optimaler Storage-Driver für moderne Linux-Systeme
- **`storage-opts`**: Kernel-Check-Override für Raspberry Pi Kompatibilität

### Build-Features
- **`buildkit: true`**: Moderne Docker Build-Engine mit besserer Performance und Caching

### Ressourcen-Limits
- **`default-ulimits`**: 
  - Erhöht File-Descriptor-Limits auf 65536
  - **Kritisch** für MariaDB-Container (5 Instanzen im Setup)
  - Verhindert "Too many open files" Fehler

### Netzwerk
- **`userland-proxy: false`**: 
  - Nutzt iptables direkt statt userland-proxy
  - Reduziert CPU-Last und Latenz
  - Bessere Performance bei vielen Containern

### Verfügbarkeit
- **`live-restore: true`**: 
  - Container laufen weiter bei Docker-Daemon-Updates
  - Zero-Downtime bei Wartungsarbeiten
  - Wichtig für Home Assistant und andere kritische Services

### Performance
- **`max-concurrent-downloads: 10`**: Parallele Image-Downloads (nutzt volle Bandbreite)
- **`max-concurrent-uploads: 10`**: Parallele Image-Uploads
- **`default-shm-size: 512M`**: Shared Memory für Container
  - Wichtig für Nextcloud (große Datei-Operationen)
  - PhotoPrism (Bildverarbeitung)
  - MariaDB (Shared Memory Tables)

## Installation

### 1. Datei erstellen/bearbeiten
```bash
sudo nano /etc/docker/daemon.json
```

### 2. Konfiguration einfügen
Kopiere die obige JSON-Konfiguration in die Datei.

### 3. Docker-Daemon neu starten
```bash
sudo systemctl restart docker
```

### 4. Konfiguration überprüfen
```bash
docker info | grep -A 20 "Server:"
```

## Wichtige Hinweise

### Container-spezifische Einstellungen
Die individuellen Logging-Einstellungen in deinen Docker-Compose-Dateien (z.B. `homeassistant-db` mit `max-file: 5`, `max-size: 15m`) **überschreiben** diese globalen Einstellungen. Das ist gewollt und ermöglicht feinere Kontrolle pro Service.

### Memory-Limits in Docker-Compose
Deine bestehenden Memory-Limits bleiben aktiv:
- Home Assistant: 2048M
- Nextcloud: 4G
- Nextcloud-DB: 4G
- PhotoPrism: Standard
- etc.

Diese Limits sind unabhängig von der `daemon.json` und sollten beibehalten werden.

### Monitoring
Überwache nach der Umstellung:
```bash
# Docker-Logs prüfen
sudo journalctl -u docker -f

# Container-Status
docker ps -a

# Ressourcen-Nutzung
docker stats
```

## Vorteile für dein Setup

### ✅ Performance
- Schnellere Image-Verwaltung (10 parallele Downloads)
- Reduzierte Netzwerk-Latenz (kein userland-proxy)
- Optimiertes Shared Memory für datenbankintensive Apps

### ✅ Stabilität
- Keine File-Descriptor-Probleme bei MariaDB
- Container-Kontinuität bei Docker-Updates
- Robuste Log-Rotation

### ✅ Wartbarkeit
- Großzügige Logs für Debugging (500MB pro Container)
- Live-Restore für wartungsfreundliche Updates
- BuildKit für schnellere Image-Builds

## Backup-Empfehlung

Vor Änderungen an der Docker-Konfiguration:
```bash
# Backup der aktuellen Konfiguration
sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup

# Falls Rollback nötig
sudo cp /etc/docker/daemon.json.backup /etc/docker/daemon.json
sudo systemctl restart docker
```

## Weitere Optimierungen

### Optional: Docker-Compose-Override
Für Services mit besonderen Anforderungen kannst du in `docker-compose.yml` überschreiben:

```yaml
services:
  service-name:
    logging:
      driver: "json-file"
      options:
        max-size: "200m"  # Noch größer für spezielle Services
        max-file: "10"
    shm_size: "1g"        # Mehr Shared Memory wenn nötig
```

### System-Tuning für Raspberry Pi 5

#### 1. GPU Memory Optimierung
Ergänze in `/boot/firmware/config.txt` im `[all]` Abschnitt:

```bash
sudo nano /boot/firmware/config.txt
```

Füge **am Ende** des `[all]` Abschnitts hinzu:
```
[all]
dtparam=pciex1
dtparam=pciex1_gen=3
gpu_mem=256
```

**Wichtig**:
- Die bestehende Zeile `[cm5] dtoverlay=dwc2,dr_mode=host` **NICHT ändern** - sie ist wichtig für USB-Funktionalität
- `arm_64bit=1` und `dtoverlay=vc4-kms-v3d` sind bereits korrekt gesetzt
- Nach Änderungen Neustart erforderlich: `sudo reboot`

#### Warum gpu_mem=256?
- Reserviert 256MB RAM für GPU
- Verbessert Performance bei:
  - Video-Streaming (Home Assistant Kameras)
  - Thumbnail-Generierung (Nextcloud, PhotoPrism, PiGallery2)
  - Hardware-beschleunigte Transcoding-Operationen

#### 2. CGroup-Parameter (bereits korrekt konfiguriert! ✅)

Deine `/boot/firmware/cmdline.txt` enthält bereits alle wichtigen Parameter:
```
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1
```

**Status**: ✅ **Perfekt konfiguriert** - keine Änderungen nötig!

Diese Parameter ermöglichen:
- `cgroup_enable=cpuset` - CPU-Pinning für Container
- `cgroup_enable=memory` - Memory-Limits (essentiell für deine docker-compose Limits!)
- `cgroup_memory=1` - Memory-Accounting
- `swapaccount=1` - Swap-Accounting bei hoher Last

#### 3. Skalierung für mehr als 20 Container

**Aktuell (bis ~20 Container)**: Keine Änderungen nötig - deine Konfiguration ist optimal!

**Bei mehr als 20 Containern** (z.B. 30-40+), erwäge folgende Anpassungen:

##### In `/etc/docker/daemon.json`:
```json
{
  "default-ulimits": {
    "nofile": {
      "Hard": 131072,     // Verdoppelt (war 65536)
      "Soft": 131072
    },
    "nproc": {
      "Hard": 8192,       // Neu: Process-Limits
      "Soft": 8192
    }
  },
  "max-concurrent-downloads": 15,  // Erhöht (war 10)
  "max-concurrent-uploads": 15,
  "default-shm-size": "1G"         // Erhöht (war 512M)
}
```

##### In `/boot/firmware/cmdline.txt` ergänzen:
```
systemd.unified_cgroup_hierarchy=1
```
(Aktiviert cgroup v2 für besseres Resource-Management bei vielen Containern)

##### System-Limits erhöhen:
```bash
# In /etc/sysctl.conf ergänzen:
sudo nano /etc/sysctl.conf

# Am Ende hinzufügen:
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
net.core.somaxconn=4096
vm.max_map_count=262144

# Aktivieren:
sudo sysctl -p
```

**Monitoring-Empfehlung** bei Skalierung:
```bash
# Container-Ressourcen überwachen
docker stats

# System-Limits prüfen
cat /proc/sys/fs/inotify/max_user_watches
ulimit -n

# Memory-Druck überwachen
free -h
vmstat 1
```

Docker-Konfiguration prüfen (wichtig!):  
Vor demu neu starten testen, ob die Syntax korrekt ist, um einen Startabbruch zu vermeiden:
```bash
sudo dockerd --validate --config-file /etc/docker/daemon.json

# wenn okay:
sudo systemctl restart docker
```

---

**Erstellt**: 2026-02-17  
**System**: Raspberry Pi 5, 16GB RAM, Docker mit 25+ Containern  
**Services**: Home Assistant, Nextcloud, 5x MariaDB, PhotoPrism, PiGallery2, etc.