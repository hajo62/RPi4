# RPi absichern
## ssh Standardport 22 ändern

Dazu in der Konfigurationsdatei `/etc/ssh/sshd_config` einen Port oberhalb von 1023 eintragen.  

```
[...]
Port 53122
#AddressFamily any
[...]
```

Nun noch mit `sudo service ssh restart` den ssh-Dämon neu starten, damit die geänderte Konfiguration aktiv wird. Ab jetzt muss bei jedem Remote Login der Port mit angegeben werden:  
```
ssh hajo@192.168.178.111 -p 53122
```

Am besten auch gleich die Firewall-Regeln entsprechend anpassen:
```
sudo ufw allow 51222/tcp comment 'Open port ssh tcp port 53122'
```

## ssh über Schlüsselpaar - ohne Kennwort
### OpenSSH Public Key Authentifizierung konfigurieren

Zuerst wird auf dem **_Client_** das Schlüsselpaar - bestehend aus public und private key - generiert und anschließend wird der public key zum Server übertragen. Der Private Schlüssel sollte mit einem Kennwort gesichert werden.  

Schlüsselpaar generieren:  
`ssh-keygen -b 4096 -f ~/.ssh/pi_rsa`

Öffentlichen Schlüssel auf den Ziel-Server übertragen:  
`ssh-copy-id -i ~/.ssh/pi_rsa.pub -p 53122 hajo@192.168.178.111`  

#### Privaten Schlüssel in keychain speichern
Da es lästig ist, immer wieder das Kennwort für den private key eingeben zu müssen, kann man diesen in der keychain des eigenen Clients speichern. Unter MacOS sieht geschieht dies mit:  
`ssh-add -K ~/.ssh/pi_rsa`

Von nun an ist es möglich, von diesem Client den RPi ohne Eingabe eines Kennwortes zu erreichen. Auch das _passende_ Zertifikat wird automatisch _gefunden_. Hier ein paar Beispielaufrufe:  

```
ssh ubuntu@192.168.178.112 -p 53022
sftp ubuntu@192.168.178.112 -p 53022
scp /tmp/tst ubuntu@192.168.178.112:/tmp/tst -p 53022
```

#### Permission denied (publickey)

Ab und an, z.B. nach einem Update meines Macs, funktionierte der ssh-Login nicht mehr. Abhilfe schafft das Kommando:  

```
ssh-add ~/.ssh/pi_rsa
Enter passphrase for /Users/hajo/.ssh/pi_rsa:
Identity added: /Users/hajo/.ssh/pi_rsa (/Users/hajo/.ssh/pi_rsa)
```
Neuerdinds (Dez 2021) kommt hier eine Warnung. Bei Zeiten mal drum kümmern:
```
WARNING: The -K and -A flags are deprecated and have been replaced
         by the --apple-use-keychain and --apple-load-keychain
         flags, respectively.  To suppress this warning, set the
         environment variable APPLE_SSH_ADD_BEHAVIOR as described in
         the ssh-add(1) manual page.
Identity added: /Users/hajo/.ssh/pi_rsa (hajo@MacBook von Hajo)
```


### ssh-login mit Kennwort deaktivieren

> **Achtung:** Wenn dies durchgeführt ist, kann man den Pi über ssh nicht mehr ohne die Private-Key-Datei erreichen!

In der Konfigurationsdatei (auf dem Pi) `/etc/ssh/sshd_config` den Schlüssel `PasswordAuthentication` auf `no` setzen.

Nun wie schon bekannt, den ssh-Dämon neu starten:  
`sudo service ssh restart`

Ein Anmeldeversuch von einem Rechner ohne Zertifikat führt nun zu:  
`pi@192.168.178.112: Permission denied (publickey).`  

Wenn man nun einen weiteren Client zulassen möchte, muss man kurzfristig den ssh-login mit Kennwort wieder aktivieren.  

### Kein Login für Benutzer ohne Kennwort
Jedes System hat Standard-Benutzer für die kein Passwort festgelegt ist. Für diese Benutzer sollte kein Zugriff per SSH möglich sein. 
```
PermitEmptyPasswords no
```

### Kein login für root per SSH
root login ist verboten. Login als _normaler_ User und dann sudo.
```
PermitRootLogin no
```

# ssl
[Übersicht von einigen Prüfungssites](https://geekflare.com/de/ssl-test-certificate/)

## Überprüfung der korrekten Einstellungen
### ssl labs
Ergebnis von [ssl labs](https://www.ssllabs.com/ssltest/index.html):
* IPv4: **A+**
* IPv6: "Unable to connect to the server"

### wormly
Ergebnis von [wormly](https://www.wormly.com/test_ssl): 98%  
Es fehlt TLSv1.3 - wg. iPhone.

### digicert
Ergebnis bei [digicert](https://www.digicert.com/help/)

OCSP Staple: 	Not Enabled
CRL Status: 	Not Enabled

### observatory
Ergebnis bei [observatory](https://observatory.mozilla.org/analyze): B

"The X-Content-Type-Options header tells browsers to stop automatically detecting the contents of files. This protects against attacks where they're tricked into incorrectly interpreting files as JavaScript.

- [ Mozilla Web Security Guidelines (X-Content-Type-Options)](https://infosec.mozilla.org/guidelines/web_security#x-content-type-options)

Once you've successfully completed your change, click Initiate Rescan for the next piece of advice."
 ### Cryptocheck
 Ergebnis bei [Cryptocheck](https://tls.imirhil.fr/http): A (mit 81%).

### Pentest-Tool
Ergebnis bei [Pentest-Tool](https://pentest-tools.com/website-vulnerability-scanning/website-scanner): Overall risk level: **Low**

### Immuniweb
Ergebnis bei [Immuniweb](https://www.immuniweb.com/websec/): **A** (mit ein paar kleineres Lücken; bei Zeiten mal anschauen)






---

---

---
Diese Einstellung habe ich noch nicht verstanden und auch nicht gemacht...

* fail2ban?  
https://www.heise.de/tipps-tricks/Ubuntu-Firewall-einrichten-4633959.html
* ufw Firewall aktiviern und konfigurieren
 
```
[...]
# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication no
#PermitEmptyPasswords no
[...]
```