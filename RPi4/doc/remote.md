# ssh connection
## ssh-key für login hinzufügen

```
% ssh-add --apple-use-keychain ~/.ssh/pi_rsa
Enter passphrase for /Users/hajo/.ssh/pi_rsa: 
Identity added: /Users/hajo/.ssh/pi_rsa (hajo@MacBook von Hajo)
```

## ssh login
```
ssh hajo@192.168.178.3 -p 53122
```
# Remote Edit
[Visual Studio Code](https://code.visualstudio.com/) bietet die Möglichkeit, remote über eine ssh-Verbindung Dateien auf einem anderen Rechner zu editieren. Wie das geht, steht in diesem [Tutorial](https://code.visualstudio.com/docs/remote/ssh-tutorial).

Ich habe bei meinen Rechnern den Standard-ssh-Port geändert [hier](./security.md) und den Login über UserId/Passwort ausgeschaltet.
 
Falls nicht bereicht vorhanden, muss auf dem Remote-Rechner - hier der RPi4 - zu erst **OpenSSH** installiert werden. Ein (bei ubuntu 20.04) bereits installiertes ssh nicht funktioniert.  
```
sudo apt-get install openssh-client
```

Auf dem Client muss die **Remote - SSH extension** (Link zur Extension: vscode:extension/ms-vscode-remote.remote-ssh) in **Visual Studio Code** installiert werden.  
![](/images/2021-03-02-22-52-46.png)  

Nun wird über **Remote-SSH: Connect to host...** die Verbindung zum Remote-Rechner konfiguriert. Da ich den Standard-Port 22 geändert habe, muss das **Configuration File** - ich habe hier `<home>/.ssh/config` genutzt - angepasst werden:  
```
Host "Raspberry Pi 4B"
  HostName <RPi IP>
  User <me>
  Port <myPort>
```

Da ich für den RPi4 den Kennwort-losen login über ssh-key konfiguriert habe (siehe [security](./security.md)), erfolgt der Login aus Visual Studio Code auch hier ohne Kennwortabfrage.


## vscode-Extension: Bilder aus der Zwischenablage in Markdown einfügen
Bilder in ein Markdown-Dokument einzufügen und zu verlinken, ist manuell recht mühsam. Mit dieser [Extension](https://marketplace.visualstudio.com/items?itemName=mushan.vscode-paste-image) lässt sich das automatisieren.

Bei der Konfiguration bin ich noch unsicher, wie es am sinnvollsten zu machen ist. Derzeit ergänze ich dies in jedem Workspace in der Datei `<workspace>.code-workspace`:
```
	"settings": {
		"pasteImage.path": "${projectRoot}/images",
		"pasteImage.basePath": "${projectRoot}",
		"pasteImage.forceUnixStyleSeparator": true,
		"pasteImage.prefix": "/"
	}
```
Hierdurch werden die eingefügten Bilder in das Verzeichnis `images` kopiert.


# Remote Directory browse
Zuerst wid samba installiert.
```
sudo apt install samba
```

Anschließend wird z.B. das home-Verzeichnis als Freigabe in die `/etc/samba/smb.conf` eingetragen. Die beiden letzten _veto_-Zeilen verhindern, dass MAC-spezifische Dateien beim Browsen oder Kopieren erstellt bzw. übertragen werden.
```
...
[RPi3B+]
    comment = Samba on RPi 3B+
    path = /home/hajo
    read only = no
    browsable = yes
    veto files = /._*/.DS_Store/
    delete veto files = yes
```

Anschließend der Service neu starten und in den Firewall-Regeln Samba-Traffic erlauben.
```
sudo service smbd restart
sudo ufw allow samba
```

Welche User gibt es _im_ Samba? `sudo pdbedit -L -v`

# Transfer sehr großer Dateien auf andere Systeme
Hier am Beispiel von holen einer Datein von WD myCloud (auf den Raspberry):
```
rsync --partial --append --progress --stats -e ssh sshd@192.168.178.2:/mnt/HD/HD_a2/hajo/BackUp/RPi4B/256.dmp ./256.dmp
```
Garage
Fr. Opitz

€ 142,80