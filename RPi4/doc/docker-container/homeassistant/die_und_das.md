# Die und das
## Lovelace
### Farbverlauf für gauge
https://ha.labtool.pl/en.lims

## Foto
### EXIF-Daten reparieren
Findet defekte Daten:  
`exiftool -warning -a *`
Repariert die Daten:  
`exiftool -all= -tagsfromfile @ -all:all -unsafe -icc_profile IMG*.jpg`