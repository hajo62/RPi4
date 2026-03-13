

# nfs mount
```
sudo mount  -t nfs 192.168.178.2:/nfs/Photos_WD /mnt/Photos_WD
```


# samba mount
Hierbei gibt's Probleme z.B. beim Löschen von bestehenden Dateien.
```
showmount -e 192.168.178.2
Export list for 192.168.178.2:
/mnt/HD/HD_a2/Photos_WD   192.168.178.0/24
/mnt/HD/HD_a2/Photos_2021 192.168.178.0/24
/mnt/HD/HD_a2/Public      192.168.178.0/24
/mnt/HD/HD_a2/hajo        192.168.178.0/24
```

```
sudo mount -t nfs 192.168.178.2:/mnt/HD/HD_a2/Photos_WD /nfs/Photos_WD
```
