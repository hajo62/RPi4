# signal-cli-rest-api

[Githup-Repo](https://github.com/bbernhard/signal-cli-rest-api)

[Anleitung](https://github.com/bbernhard/signal-cli-rest-api/blob/master/doc/HOMEASSISTANT.md)

Man benötigt eine weitere Telefonnummer, da signal sonst vom Handy _entfernt_ wird und an die API gebunden wird.  
[Hier](https://getfreesmsnumber.com/virtual-phone/p-12045003686) gibt es solche Nummern. Ich habe es mit +12045003686 mal probiert...

## Installieren und Starten über docker-compise:

```
  signal-cli-rest-api:
    image: bbernhard/signal-cli-rest-api:latest
    dns:
      8.8.8.8
    ports:
      - "8080:8080" # map docker port 8080 to host port 8080.
    volumes:
      - "/home/hajo/docker-volumes/signal-cli-rest-api:/home/.local/share/signal-cli"
      # map "signal-cli-config" folder on host system into docker container. the folder contains the password and cryptographic keys when a new number is registered
```

## Konfigurieren: +32463001882
Konfiguration einleiten:  
```
curl -X POST -H "Content-Type: application/json" 'http://192.168.178.3:8080/v1/register/+46726418639'

{"error":"Captcha required for verification, use --captcha CAPTCHA\nTo get the token, go to https://signalcaptchas.org/registration/generate.html\nCheck the developer tools (F12) console for a failed redirect to signalcaptcha://\nEverything after signalcaptcha:// is the captcha token.\n"}
```

captcha eingeben:  
```
curl -X POST -H "Content-Type: application/json" -d '{"captcha":"signal-hcaptcha.5fad97ac-7d06-4e44-b18a-b950b20148ff.registration.P1_eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.haJwZACjZXhwzmmXjv-ncGFzc2tlecUFDjAiB97Iyj0uKQHtOneSa8RQwR-gG5st0BZyr0XluRvfAu-k2HJf5t33ZYfJWZUt9051dHPcIMy9cgmniw9bOHogYrQiq1uf_8CzbiNsryzT516BAEj306Cr6-ctAFFD7ur_NXUhMRT7LAhFpIHiC8tbLAyqmTkxVdQwHUywIbvdHiakudBTNOxFoHnR-K-4el1VOWzTDlq9fZux6huwHEsAfIDBgnJLGePdvaoyLqFRLG7zSicGkJvVqkAHnFG4kMVI66hnceTkwlgqTjEtfKFrcPhQgv15BtyqfZTR3N444sKP4D47NGsabt6u7rAeBr9tbeoDLJzRQvoDiAme52nEjWa6hvGmgIQxqEEF7wyXo1h--H_oZ_mzS7CxYffa9728-VNJgbufZBWGHgGjfSRqKdx_mWNYM98oUBg6n9wLZ6C8HSn9TE36IUbHa-CCjNrI-5CDSK3V7hj7MrnnYeN-9Kk0my_oZv9dHT829NSrUeFtgKZPz-gv9mjsfmgTxa0iCXJleY55UborUqJsknp3EjQVbn_O4PxUoJ1UF9FkqA3et9pgkdkQktW5gnOO8pu4_Q28xudFFPTPquQAKevuctdf1KvVbYAnljk5-PuhEqsuUKGP3fuGdB4HLlB06dqtje1nW7HBA09j-Q96dnK-HzJg7_8diO9g5ZL5BcsZXiiojdtOfCVKlMUlJ8Pp-pe2MLKWxQ8PKOeCtpMSDyfaH0aBwRAszAQdbrghPz4VKiJ0KUp6nAajEygIEf3jn3TAVwLzS0tdv4FL4u5ggUMaN0f1GYD09j4BdSNbcvYcMVt1JfUt1AH0g562NdS4uiO34I7Vk8Z92o4gb_h6LU3NiN-m79jFYAAVjs5eOeZKbnjpTW1uu6JvB019Ua_g1i-9JfESRLuA3OdFwC51yxSkWNBaOMijTPBhFEpFy04HM2ccm_eV5Wbd9FLSAMMmFBnwA7SVXyipti9HH6Ff42Qw57VUH1xbE_2okQoZ_b1SsClA41a2pE2gVmVnXagCQ-FxASlrjtL8e3ahD5ZsS44k6Shbnw2dgP9YThBsAkjohpeC7tiChGcaFflJK7ipbAC4AtAO4FKViG854ZauAfbKsdSIxlsWY-BP9hotJVbzpSosxk2Tklu2VDo8aYYhD5noN6fN9MnMJBY3Aq74TmaGBFtABIcHBYrHIiYdWfVzVEUpdM1JAwOkObQi9LD1CD-O488aUNAjt37jDF2iUQIuaIWdv2JUsxwV4QmVfg-IQ41wATchzD-b1_dANzA_axYcXaX0RCQ2wv2mrqki52_gQrvrKLFGjr8-CWt11fFqcd-tfcrZXCT3TvfZMIR9Hm5twX44kTi-iw39SPFrZ_YQWWqnJz73I4lq4B8QBy0P2_cDVHsHXdj5_BffvKTwSALTmgBMejmTXECosohM77uF5vWCIVq4Lx6dL9RBDX8YgX9hBhT-cI_5-kMrYujBWgMnIS3XdAfz2oc_spuGT7SO1D2s-0tMhptNB2QO0ue8dxnZTlGzMyjn3DXLi6xsOvgie5Z2PJrdQqryVn3qxwYJA2k_atvnPIg0_QhdGJ14blwmHrHmWNcVyL-SYtMv-xwv_DQTIhXNzR1qp21MH8B4x2przMkjscNaj2WdNjtOD2JwEHXKOjRuuMSJv8iS_lX8JZuXn0-JAUU1yB5L34GP6fr10dbqU4mzrESuPvcn64kcQMwj6fL5MRdmUIeia3KoMTg1NTA2NTKoc2hhcmRfaWTOFDyEHw.MgNVx_-C9JzqAtpQaLm5Zt5KDE8kCJ1j6gX17EG6YJk"}' 'http://192.168.178.3:8080/v1/register/+46726418639'
```

Den Verifikationscode eingeben:
```
curl -X POST -H "Content-Type: application/json" 'http://192.168.178.3:8080/v1/register/+46726418639/verify/999-217'
```

Message senden:  
```
curl -X POST -H "Content-Type: application/json" -d '{"message": "Viele Grüße von Hajo per API", "number": "+16606457867", "recipients": ["+491704532333"]}' 'http://127.0.0.1:8080/v2/send'
```


### Receive
```
curl -X GET -H "Content-Type: application/json" 'http://127.0.0.1:8080/v1/receive/+12045003686'
```

### Expiring messages
Auf dem Client die Zeit einstellen und anschließend einen Receive-API-Call ausführen.

### Name und Avatar
```
curl -X PUT -H "Content-Type: application/json" -d '{"name": "HomeAssistant","base64_avatar":"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"}' "http://127.0.0.1:8080/v1/profiles/+12045003686"
```






{
  "version" : 2,
  "username" : "+12045003686",
  "uuid" : "d18474a1-bf3c-47d7-add0-78da0ae32352",
  "deviceName" : null,
  "deviceId" : 1,
  "isMultiDevice" : false,
  "lastReceiveTimestamp" : 0,
  "password" : "Atob9eJcuCoJl5/w7aj/ZuAk",
  "registrationId" : 9706,
  "identityPrivateKey" : "0ITPmZmJ7ttQYVQMZ/xoNIkzaZ+8dyijHFz30nuinX8=",
  "identityKey" : "BfXJc+GKzPyeZrbXEfstKcDgfcsObeY22uqJKtKh8tpP",
  "registrationLockPin" : null,
  "pinMasterKey" : null,
  "storageKey" : null,
  "storageManifestVersion" : null,
  "preKeyIdOffset" : 100,
  "nextSignedPreKeyId" : 1,
  "profileKey" : "5V86Vx/vYEuWABtECjIa+3kWBgWTxhT1R6yJpa+QuSY=",
  "registered" : true,
  "messageExpirationTime": 60,
  "groupStore" : {
    "groups" : [ ]
  },
  "stickerStore" : {
    "stickers" : [ ]
  },
  "configurationStore" : null
}