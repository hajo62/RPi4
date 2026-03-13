#!/bin/bash
# ============================================
# Nextcloud Minimal Setup
# ============================================
#
# Deaktiviert unnötige Apps und aktiviert nur
# die minimal benötigten Apps.
#
# Verwendung:
#   docker exec -u www-data nextcloud bash /var/www/html/minimal-setup.sh
#
# ============================================

echo "🔧 Nextcloud Minimal Setup wird ausgeführt..."

# ============================================
# Apps DEAKTIVIEREN (nicht benötigt)
# ============================================
echo "📦 Deaktiviere unnötige Apps..."

# Produktivitäts-Apps
php occ app:disable calendar
php occ app:disable contacts
php occ app:disable mail
php occ app:disable tasks

# Office & Collaboration
php occ app:disable richdocuments
php occ app:disable richdocumentscode
php occ app:disable collabora
php occ app:disable onlyoffice

# Foto-Apps
php occ app:disable photos
php occ app:disable memories
php occ app:disable recognize

# Social & Communication
php occ app:disable talk
php occ app:disable circles
php occ app:disable deck

# Weitere Apps
php occ app:disable news
php occ app:disable notes
php occ app:disable bookmarks
php occ app:disable music
php occ app:disable maps

# ============================================
# Apps AKTIVIEREN (minimal benötigt)
# ============================================
echo "✅ Aktiviere benötigte Apps..."

# Kern-Apps (sollten bereits aktiv sein)
php occ app:enable files
php occ app:enable files_sharing
php occ app:enable files_trashbin
php occ app:enable files_versions

# Text-Editor (für .txt, .md Dateien)
php occ app:enable text

# Empfohlen für Sicherheit
php occ app:enable bruteforce_protection
php occ app:enable suspicious_login

# Empfohlen für Performance
php occ app:enable files_external  # Falls externe Speicher benötigt

# ============================================
# Optionale Apps (auskommentiert)
# ============================================
# Aktiviere bei Bedarf:

# PDF-Viewer
# php occ app:enable files_pdfviewer

# Video-Player
# php occ app:enable viewer

# Externe Speicher (SMB, FTP, etc.)
# php occ app:enable files_external

# ============================================
# Status anzeigen
# ============================================
echo ""
echo "📊 Aktivierte Apps:"
php occ app:list --enabled

echo ""
echo "✅ Minimal Setup abgeschlossen!"
echo ""
echo "💡 Tipp: Weitere Apps kannst du jederzeit über die Web-UI aktivieren:"
echo "   Einstellungen → Apps"

# Made with Bob
