# RPi absichern
## ssh Standartport 22 verändern

Dazu in der Konfigurationsdatei `/etc/ssh/sshd_config` einen Port oberhalb von 1023 eintragen.  

```
[...]
Port 53022
#AddressFamily any
[...]
```

Nun noch mit `sudo service ssh restart` den ssh-Dämon neu starten, damit die geänderte Konfiguration aktiv wird. Ab jetzt muss bei jedem Remote Login der Port mit angegeben werden:  
```
ssh hajo@192.168.178.113 -p 53022
```

# Todo

## ssh über Schlüsselpaar - ohne Kennwort
### OpenSSH Public Key Authentifizierung konfigurieren

Zuerst wird auf dem **_Client_** das Schlüsselpaar - bestehend aus public und private key - generiert und anschließend wird der public key zum Server übertragen. Der Private Schlüssel sollte mit einem Kennwort gesichert werden.  

Schlüsselpaar generieren:  
`ssh-keygen -b 4096 -f ~/.ssh/pi_rsa`

Öffentlichen Schlüssel auf den Ziel-Server übertragen:  
`ssh-copy-id -i ~/.ssh/pi_rsa.pub -p 53022 ubuntu@192.168.178.112`  

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

Nach einem Update meines Macs funktionierte der ssh-Login nicht mehr. Abhilfe schaft das Kommando:  

```
ssh-add ~/.ssh/pi_rsa
Enter passphrase for /Users/hajo/.ssh/pi_rsa:
Identity added: /Users/hajo/.ssh/pi_rsa (/Users/hajo/.ssh/pi_rsa)
```

### ssh-login mit Kennwort deaktivieren

> **Achtung:** Wenn dies durchgeführt ist, kann man den Pi über ssh nicht mehr ohne die Private-Key-Datei erreichen!

In der Konfigurationsdatei `/etc/ssh/sshd_config` den Schlüssel `PasswordAuthentication` auf `no` setzen.

```
[...]
# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication no
#PermitEmptyPasswords no
[...]
```

Nun wie schon bekannt, den ssh-Dämon neu starten:  
`sudo service ssh restart`

Ein Anmeldeversuch von einem Rechner ohne Zertifikat führt nun zu:  
`pi@192.168.178.112: Permission denied (publickey).`  

Wenn man nun einen weiteren Client zulassen möchte, muss man kurzfristig den ssh-login mit Kennwort wieder aktivieren.  
