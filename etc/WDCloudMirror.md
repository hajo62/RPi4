# WD Cloud Mirror
## Remote Shutdown
Remote login mit dem User `sshd` und ausführen des `shutdown.sh` shutdown-Skripts:
```
ssh sshd@192.168.178.2 /usr/sbin/shutdown.sh
```

Evtl. mal `ssh user@Host bash -c "echo mypass | sudo -S mycommand"` probieren, um das Kennwort automatisch zu übergeben.
