# Remote Edit
[Visual Studio Code](https://code.visualstudio.com/) bietet die Möglichkeit, remote über eine ssh-Verbindung Dateien auf einem anderen Rechner zu editieren. Wie das geht, steht in diesem [Tutorial](https://code.visualstudio.com/docs/remote/ssh-tutorial).


Als erstes muss auf dem Remote-Rechner - hier der RPi4 - **OpenSSH** installiert werden, da das bereits installierte ssh nicht funktionieren soll.  
```
sudo apt-get install openssh-client
```

Auf dem Client muss die [Remote - SSH extension](vscode:extension/ms-vscode-remote.remote-ssh) in **Visual Studio Code** installiert werden.  
Nun wird über **Remote-SSH: Connect to host...** die Verbindung zum Remote-Rechner konfiguriert. Da ich den Standard-Port 22 geändert habe, muss das **Configuration File** - ich habe hier `<home>.ssh/config` genutzt - angepasst werden:  
```
Host "Raspberry Pi 4B"
  HostName <RPi IP>
  User <me>
  Port <myPort>
```

Da ich für den RPi4 den Kennwort-losen login über ssh-key konfiguriert habe (siehe [security](./security.md)), erfolgt der Login aus Visual Studio Code auch hier ohne Kennwortabfrage.