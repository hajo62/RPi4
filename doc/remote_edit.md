# Remote Edit
[Visual Studio Code](https://code.visualstudio.com/) bietet die Möglichkeit, remote über eine ssh-Verbindung Dateien auf einem anderen Rechner zu editieren. Wie das geht, steht in diesem [Tutorial](https://code.visualstudio.com/docs/remote/ssh-tutorial).


Als erstes muss auf dem Remote-Rechner - hier der RPi4 - **OpenSSH** installiert werden, da das bereits installierte ssh nicht funktionieren soll.  
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