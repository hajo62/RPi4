# Installation von docker
ubuntu 20.04 und 20.10 bietet **snap** zur Installation von Paketen. Damit läßt sich **docker** ganz einfach installieren. Ich habe jedoch festgestellt, dass dann z.B. bei der Verwendung einer `.env`-Datei bei docker-compose ein Rechteproblem auftrat.

👉 Ich bin dann doch lieber der Installationsbescheibung auf docker.com gefolgt: [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

## docker-Repository hinzufügen
Update the apt package index and install packages to allow apt to use a repository over HTTPS:
```
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
```

Add Docker’s official GPG key:
```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Verify that you now have the key with the fingerprint
sudo apt-key fingerprint 0EBFCD88

pub   rsa4096 2017-02-22 [SCEA]
      9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid           [ unknown] Docker Release (CE deb) <docker@docker.com>
sub   rsa4096 2017-02-22 [S]
```

Use the following command to set up the stable repository:
```
sudo add-apt-repository \
   "deb [arch=arm64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
```
## Installation der Docker-Engine

```
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
```

## Prüfen der Installation 
User `ubuntu` zur Gruppe `docker` hinzufügen:  
Bei Problemen mal [hier](https://docs.docker.com/engine/install/linux-postinstall/) nachlesen, da dort andere Kommados aufgelistet sind.  
```
sudo addgroup --system docker
sudo adduser $USER docker
newgrp docker
```

Testen der Installation und Aufräumen:
```
sudo docker run hello-world

docker container ls -a
docker rm <CONTAINER ID>
docker images
docker rmi <IMAGE ID>
```

## docker-compose
Eine Bescheibung der Installation von docker-compose steht [hier](https://docs.docker.com/compose/install/  ). 
Leider ist dort aber kein Download für den RPi vefügbar, so dass man sich die Software selbst bauen muss.

```
cd /tmp
git clone https://github.com/docker/compose
cd compose
make
```
Der Build dauert ca. 20 Minuten und anschließend findet sich im Verzeichnis `dist` das  `docker-compose-Linux-aarch64`-Executable. Dieses nun noch nach `/usr/bin/docker` schieben.
```
sudo mv dist/docker-compose-Linux-aarch64 /usr/bin/docker-compose
``` 

## Memory
Unter ubuntu 20.04 zeigt das Kommand `docker info` fehlenden Memory Limit support:
```
...
WARNING: No memory limit support
WARNING: No swap limit support
WARNING: No kernel memory limit support
WARNING: No kernel memory TCP limit support
WARNING: No oom kill disable support
```
Dies sorgt dafür, dass z.B. das Kommando `docker stats` keine Memory-Informationen anzeigt. Aus diesem Grund zeigt auch die [Monitor Docker component](https://github.com/ualex73/monitor_docker) keine Informationen zu Speicher-Nutzung, CPU, etc. an. Abhilfe schafft hier das Aktivieren der `memory cgroup` on Ubuntu 20.04  
Siehe dazu [hier](https://askubuntu.com/a/1237856).
In der Datei `/boot/firmware/cmdline.txt` den Wert `cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1` an den vorhandenen Eintrag anhängen:
```
usb-storage.quirks=152d:0578:u net.ifnames=0 dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=PARTUUID=42684546-01 rootfstype=ext4 elevator=deadline rootwait fixrtc cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
```



---
>> 🛑 Nicht genutzt wg. Zugriffproblemen bei .env für docker-compose!
---

## Installation mit snap

```
sudo addgroup --system docker
sudo adduser $USER docker
newgrp docker

sudo snap install docker

docker info
```
Bei mir kommen dann 5 Warnungen, die ich vorerst mal ignoriert habe:
```
WARNING: No memory limit support
WARNING: No swap limit support
WARNING: No kernel memory limit support
WARNING: No kernel memory TCP limit support
WARNING: No oom kill disable support
```
