# NFS-Freigabe: Pi4 (Server) → Pi5 (Client)

In diesem Szenario stellt der **Pi4** das Verzeichnis `/home/hajo/Photos`
per NFS bereit. Der **Pi5** greift lesend darauf zu.

**Konfiguration:**
- **Pi4 (Server)**: IP `192.168.178.3`, stellt `/home/hajo/Photos` via bind-Mount unter `/srv/nfs/photos` bereit
- **Pi5 (Client)**: Aktuell `192.168.178.55`, später `192.168.178.5`
- **Zugriff**: Nur lesend (ro), beschränkt auf Pi5
- **User**: `hajo` mit UID 1000 auf beiden Systemen

------------------------------------------------------------------------

## 1. NFS-Server auf Pi4 einrichten

### Installation

``` bash
sudo apt update
sudo apt install nfs-kernel-server
```

### Bind-Mount für photos einrichten

**WICHTIG:** Auf Ihrem System ist der Pfad `/home/hajo/Photos` (mit großem P), nicht `/home/hajo/photos`!

**Schritt 1:** Prüfe, ob `/home/hajo/Photos` existiert und Inhalte hat:

``` bash
ls -la /home/hajo/Photos
```

**Schritt 2:** Erstelle den NFS-Freigabeordner (falls noch nicht vorhanden):

``` bash
sudo mkdir -p /srv/nfs/photos
```

**Schritt 3:** Bind-Mount in `/etc/fstab` eintragen für **automatisches Mounten beim Boot**:

``` bash
sudo nano /etc/fstab
```

Folgende Zeile **am Ende** der Datei hinzufügen (beachte: Quellpfad mit großem P):

``` bash
/home/hajo/Photos  /srv/nfs/photos  none  bind  0  0
```

**STATUS:** ✅ **Dieser Eintrag ist bereits in Ihrer `/etc/fstab` vorhanden!**

**Schritt 4:** Bind-Mount sofort aktivieren (ohne Neustart):

``` bash
sudo mount -a
```

**Falls diese Meldung erscheint:**

``` bash
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
```

**Dann zusätzlich ausführen:**

``` bash
sudo systemctl daemon-reload
sudo mount -a
```

**Erklärung:** Systemd cached die `/etc/fstab`. Nach Änderungen muss der Cache neu geladen werden.

**Schritt 5:** Prüfen, ob der bind-Mount jetzt aktiv ist:

``` bash
findmnt /srv/nfs/photos
```

**Erwartete und korrekte Ausgabe:**

``` bash
TARGET          SOURCE                       FSTYPE OPTIONS
/srv/nfs/photos /dev/sda2[/home/hajo/Photos] ext4   rw,relatime,discard,errors=remount-ro
```

**✅ PERFEKT!** Der bind-Mount ist aktiv!

**Erklärung:**
- Die Ausgabe zeigt `/dev/sda2[/home/hajo/Photos]` - das `[/home/hajo/Photos]` bedeutet, dass es ein bind-Mount ist
- Der Mount wird als `ext4` angezeigt (das Dateisystem der Quelle), nicht als `none`
- Das ist die moderne Art, wie Linux bind-Mounts anzeigt
- `mount | grep bind` zeigt es nicht, weil moderne Kernel bind-Mounts anders darstellen

**STATUS:**
- ✅ `/etc/fstab` Eintrag vorhanden
- ✅ Bind-Mount ist AKTIV und funktioniert
- ✅ Verzeichnisse sind korrekt verbunden
- ✅ Wird automatisch beim Reboot gemountet

**Der bind-Mount ist fertig eingerichtet!** Sie können jetzt mit der NFS-Konfiguration fortfahren.

Prüfen, ob der Mount funktioniert:

``` bash
ls -la /srv/nfs/photos
df -h | grep photos
mount | grep /srv/nfs/photos
```

**Erwartete Ausgabe von `mount | grep /srv/nfs/photos`:**

``` bash
/home/hajo/photos on /srv/nfs/photos type none (rw,bind)
```

**Falls die Ausgabe stattdessen so aussieht:**

``` bash
/dev/sda2 on /srv/nfs/photos type ext4 (rw,relatime,discard,errors=remount-ro)
```

**Dann ist der bind-Mount NICHT aktiv!** Das bedeutet:
- `/srv/nfs/photos` ist nur ein normales Verzeichnis auf der Root-Partition
- Der bind-Mount wurde noch nicht ausgeführt
- **Lösung:** Führe `sudo mount -a` aus, um den bind-Mount zu aktivieren

**Wichtig:** Nach `sudo mount -a` sollte die Ausgabe von `mount | grep /srv/nfs/photos` **zwei Zeilen** zeigen:
1. Die Root-Partition (normal)
2. Den bind-Mount von `/home/hajo/photos`

Oder verwende diesen spezifischeren Befehl:

``` bash
mount | grep "bind"
```

Erwartete Ausgabe:

``` bash
/home/hajo/photos on /srv/nfs/photos type none (rw,bind)
```

### NFS-Freigabe konfigurieren

Datei öffnen:

``` bash
sudo nano /etc/exports
```

Folgende Zeilen ergänzen (für aktuelle und zukünftige IP des Pi5):

``` bash
# Pi5 - aktuelle IP
/srv/nfs/photos 192.168.178.55(ro,sync,no_subtree_check,root_squash)

# Pi5 - zukünftige IP
/srv/nfs/photos 192.168.178.5(ro,sync,no_subtree_check,root_squash)
```

**Wichtig:** Die `/etc/exports` Datei wird beim Systemstart automatisch geladen. Der NFS-Server (`nfs-kernel-server`) startet automatisch und liest diese Konfiguration. Die Freigabe bleibt also nach einem Reboot erhalten!

**Erklärung der Optionen:**
- `ro`: Read-only (nur Lesezugriff)
- `sync`: Synchrones Schreiben (erhöht Datensicherheit)
- `no_subtree_check`: Verbessert Zuverlässigkeit
- `root_squash`: **Wichtige Sicherheitsoption!** Mappt Root-Zugriffe (UID 0) vom Client auf den unprivilegierten User `nobody` (UID 65534).
  - **Warum wichtig?** Wenn jemand auf dem Pi5 Root-Rechte hat, kann er NICHT als Root auf die Dateien des Pi4 zugreifen
  - **Schutz vor:** Unbefugtem Root-Zugriff über NFS
  - **Ergebnis:** Selbst Root auf Pi5 hat nur die Rechte von `nobody` auf die NFS-Freigabe
  - **Alternative:** `all_squash` würde ALLE User auf nobody mappen (noch restriktiver)

Einstellungen übernehmen:

``` bash
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

Prüfen:

``` bash
sudo exportfs -v
```

Erwartete Ausgabe sollte beide IPs zeigen:

``` bash
/srv/nfs/photos 192.168.178.55(ro,wdelay,root_squash,no_subtree_check,...)
/srv/nfs/photos 192.168.178.5(ro,wdelay,root_squash,no_subtree_check,...)
```

### Firewall-Konfiguration (falls nftables aktiv)

Falls auf Pi4 eine Firewall läuft, NFS-Zugriff für Pi5 erlauben:

``` bash
# Für ufw (falls verwendet):
sudo ufw allow from 192.168.178.55 to any port nfs
sudo ufw allow from 192.168.178.5 to any port nfs

# Für nftables: Regel in entsprechende Chain einfügen
# (siehe nftables-Konfiguration)
```

------------------------------------------------------------------------

## 2. NFS-Client auf Pi5 einrichten

### Installation des Clients

``` bash
sudo apt update
sudo apt install nfs-common
```

### Erreichbarkeit testen

Prüfe, ob der Pi4-Server erreichbar ist (IP des Pi4 anpassen):

``` bash
showmount -e 192.168.178.3
```

**Hinweis:** `192.168.178.3` durch die tatsächliche IP des Pi4 ersetzen.

Erwartete Ausgabe:

``` bash
Export list for 192.168.178.3:
/srv/nfs/photos 192.168.178.55,192.168.178.5
```

### Mountpunkt erstellen

``` bash
sudo mkdir -p /mnt/pi4-photos
```

### Manuell mounten (zum Testen)

``` bash
sudo mount 192.168.178.3:/srv/nfs/photos /mnt/pi4-photos
```

### Inhalt prüfen

``` bash
ls -la /mnt/pi4-photos
```

Du solltest jetzt die Inhalte von `/home/hajo/Photos` vom Pi4 sehen.

### Berechtigungen prüfen

``` bash
# Prüfe, ob User hajo (UID 1000) lesend zugreifen kann
id hajo
# Sollte UID 1000 zeigen

# Teste Lesezugriff
cat /mnt/pi4-photos/irgendeine-datei.txt

# Teste, dass Schreibzugriff verweigert wird
touch /mnt/pi4-photos/test.txt
# Sollte fehlschlagen mit "Read-only file system"
```

------------------------------------------------------------------------

## 3. Automatisches Einbinden beim Systemstart auf Pi5

Datei bearbeiten:

``` bash
sudo nano /etc/fstab
```

Folgende Zeile ergänzen (IP des Pi4 anpassen):

``` bash
192.168.178.3:/srv/nfs/photos  /mnt/pi4-photos  nfs  defaults,_netdev,ro  0  0
```

**Erklärung der Optionen:**
- `defaults`: Standard-Mount-Optionen
- `_netdev`: Wartet auf Netzwerk vor dem Mounten
- `ro`: Read-only Mount
- `0 0`: Kein Dump, kein fsck

Konfiguration testen:

``` bash
# Erst unmounten, falls manuell gemountet
sudo umount /mnt/pi4-photos

# Dann automatisches Mounten testen
sudo mount -a

# Prüfen
df -h | grep pi4-photos
ls -la /mnt/pi4-photos
```

------------------------------------------------------------------------

## 4. Zusammenfassung und Sicherheitshinweise

### Was wurde erreicht:

✅ **Pi4 (Server)** (IP: 192.168.178.3):
- `/home/hajo/Photos` wird via bind-Mount unter `/srv/nfs/photos` bereitgestellt
- NFS-Export nur für Pi5 (192.168.178.55 und 192.168.178.5)
- Read-only Zugriff
- Root-Squash aktiviert (Sicherheit)

✅ **Pi5 (Client)**:
- Mountet `/srv/nfs/photos` vom Pi4 unter `/mnt/pi4-photos`
- Nur Lesezugriff
- Automatisches Mounten beim Boot
- User hajo (UID 1000) kann auf die Dateien zugreifen

### Sicherheitsaspekte:

1. **Bind-Mount**: Trennt Benutzerverzeichnis von NFS-Export
2. **IP-Beschränkung**: Nur Pi5 kann zugreifen
3. **Read-only**: Keine Schreibzugriffe möglich
4. **Root-Squash**: Root-Zugriffe werden gemappt
5. **Firewall**: Optional zusätzliche Absicherung

### Troubleshooting:

**Problem: "Permission denied"**
- Prüfe UID auf beiden Systemen: `id hajo`
- Prüfe Berechtigungen: `ls -la /home/hajo/Photos` (auf Pi4)

**Problem: "Connection refused"**
- Prüfe NFS-Server: `sudo systemctl status nfs-kernel-server` (auf Pi4)
- Prüfe Firewall-Regeln
- Prüfe Netzwerkverbindung: `ping 192.168.178.3`

**Problem: Mount hängt beim Boot**
- Option `_netdev` in fstab vorhanden?
- Netzwerk beim Boot verfügbar?

**Problem: "No such file or directory"**
- Prüfe Exports: `sudo exportfs -v` (auf Pi4)
- Prüfe showmount: `showmount -e 192.168.178.3` (auf Pi5)

### Nützliche Befehle:

``` bash
# Auf Pi4 (Server):
sudo exportfs -v                    # Zeige aktive Exports
sudo exportfs -ra                   # Exports neu laden
sudo systemctl restart nfs-kernel-server

# Auf Pi5 (Client):
showmount -e 192.168.178.3         # Zeige verfügbare Exports
mount | grep nfs                    # Zeige gemountete NFS-Shares
sudo umount /mnt/pi4-photos        # Unmount
```

------------------------------------------------------------------------

## 5. Wichtige Hinweise zur Systemd-Integration

### Systemd daemon-reload nach fstab-Änderungen

Wenn Sie die `/etc/fstab` bearbeiten und dann `sudo mount -a` ausführen, kann folgende Meldung erscheinen:

``` bash
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
```

**Lösung:**

``` bash
sudo systemctl daemon-reload
sudo mount -a
```

**Erklärung:** Systemd cached die `/etc/fstab` beim Systemstart. Nach manuellen Änderungen muss dieser Cache mit `systemctl daemon-reload` aktualisiert werden, damit systemd die neue Konfiguration erkennt.

**Wann ist das nötig?**
- Nach dem Hinzufügen neuer Mount-Einträge in `/etc/fstab`
- Nach dem Ändern bestehender Mount-Optionen
- Nicht nötig nach einem Neustart (systemd liest dann automatisch die aktuelle `/etc/fstab`)
