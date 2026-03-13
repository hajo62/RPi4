# Nextcloud
## Nextcloud Maria-Db initialisieren
Siehe: https://docs.nextcloud.com/server/latest/admin_manual/configuration_database/linux_database_configuration.html

```
mysql -uroot -p

CREATE USER 'hajo'@'localhost' IDENTIFIED BY 'MARIARat1onal';
CREATE DATABASE IF NOT EXISTS nextclouddb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
GRANT ALL PRIVILEGES on nextclouddb.* to 'hajo'@'localhost';
FLUSH privileges;
```
[Hier](https://github.com/nextcloud/docker#first-use) ist ein kleiner _Trick_ beschrieben, bei dem ich bei der Installation hereingefallen bin. Man muss im Installation-Wizzard die im `docker-compose.yaml` gesetzten User-, Password- und Datenbank-Namen-Wert nutzen.

## Kleinere Anpassungen
### Change nextcloud footer text
admin account --> setup --> theming --> slogan --> (enter new slogan) 

---
Damit man über die App drankommt: https://help.nextcloud.com/t/nc-connection-wizard-tries-to-access-token-endpoint-via-http-instead-of-https/79111/12

config.php:
```
 // 'overwrite.cli.url' => 'http://192.168.178.3:8088',
  'overwrite.cli.url' => 'https://nc.hajo62.duckdns.org',
  'overwriteprotocol' => 'https',
```

---
## nfs Freigabe(n)
Siehe [hier](https://wiki.ubuntuusers.de/Autofs/).

Zum Einbinden der NFS-Freigabe `Public` des NAS auf dem Client in die Datei `/etc/auto.master` folgende Zeile anhängen:
```
/nfs    /etc/auto.nfs   --timeout=180 --ghost
```

Nun die Datei `/etc/auto.nfs` erzeugen:
```
Public    -fstype=nfs,rw,retry=0  192.168.178.2:/nfs/Public
Nextcloud -fstype=nfs,rw,retry=0  192.168.178.2:/nfs/Nextcloud
```

Ich hatte aus anderen Artikeln auch diese Kommandos ausgeführt. Ob die benötigt werden, weiß ich nicht:
```
sudo /etc/init.d/autofs start 
sudo systemctl enable autofs.service
 ```

Beim `mount` kam bei mir der Fehler:
```
$ sudo mount 192.168.178.3:/srv/nfs4/Photos_WD /nfs/Photos_wd
mount_nfs: can't mount with remote locks when server (192.168.178.3) is not running rpc.statd: RPC prog. not avail
mount: /private/tmp/Photos failed with 74
```

Der nachfolgende Befehl hat geholfen: 
```
sudo systemctl start rpc-statd
```

## svg missing module
Wenn bei den [Sicherheits- & Einrichtungswarnungen](https://nc.hajo62.duckdns.org/settings/admin/overview) die Meldung `odule php-imagick in this instance has no SVG support. For better compatibility it is recommended to install it.` erscheint, hilft dieser Befehl:
```
docker exec -it <nextcloud> apt -y update

docker exec -it <nextcloud> apt -y install libmagickcore-6.q16-6-extra
```
Siehe z.B. [hier](https://www.virtualconfusion.net/docker-nextcloud-module-php-imagick-in-this-instance-has-no-svg-support/).


## Home Assistant Integration
Siehe [Documentation](https://www.home-assistant.io/integrations/nextcloud/).




## Fotos:
https://rayagainstthemachine.net/linux%20administration/nextcloud-photos/

Beispiel für config.php: https://help.nextcloud.com/t/solved-cant-login-via-web-ui-anymore/31483