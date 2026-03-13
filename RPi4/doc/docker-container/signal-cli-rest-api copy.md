# signal-cli-rest-api

[Githup-Repo](https://github.com/bbernhard/signal-cli-rest-api)

[Anleitung](https://github.com/bbernhard/signal-cli-rest-api/blob/master/doc/HOMEASSISTANT.md)

Man benötigt eine weitere Telefonnummer, da signal sonst vom Handy _entfernt_ wird und an die API gebunden wird.  
[Hier](https://getfreesmsnumber.com/virtual-phone/p-12045003686) gibt es solche Nummern. Ich habe es mit +3197058048512 mal probiert...

## Installieren und Starten über docker-compise:

```yaml
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

## Konfigurieren: +3197058048512
Konfiguration einleiten:  
```
curl -X POST -H "Content-Type: application/json" 'http://192.168.178.55:8090/v1/register/+491637928873'

{"error":"Captcha required for verification, use --captcha CAPTCHA\nTo get the token, go to https://signalcaptchas.org/registration/generate.html\nCheck the developer tools (F12) console for a failed redirect to signalcaptcha://\nEverything after signalcaptcha:// is the captcha token.\n"}
```

captcha eingeben:  
```
curl -X POST -H "Content-Type: application/json" -d '{"captcha":"signal-hcaptcha.5fad97ac-7d06-4e44-b18a-b950b20148ff.registration.P1_eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.haJwZACjZXhwzmmY6HqncGFzc2tlecUFMLhjO9WX37LQkOObToPOds-a1IZSHABg5AzIKdzIPBk5DPMnAlHfeeKSXPOPtLTUTpZUWYShNQ6GwJq2qPbf_ikvY43WyO-IQHafP8DMDy8qam6gw0mbZ_l0QdgL1BinYTUeff0b3eO9ja6zD2ouVzbIke4Szd3BClEswfUv6iWrm9H8XJXqg0_7_AOk8nO7gjNih2a02JxZjQB4QjX-NyAPrE9MOSvxCxJXTEw46IhMHyJBBJfL2WLSRDrd9upHbA1giEmbFKVEN19WZSiy-det2KPE6fWQ3b_fUudJZQBB1DU5Bzg-voh1yh2dMuyiE3dSxxdeMVo5GF71BhKlHlpaTecFhdrcZsyMMkMcbdR6QxTlP-GDcp6j62mMpDS6583EBPA5nRHe2OGzg8JjB2FMArMqMHUy9gwPZWflNfbFoL755_mqJ2fpiCTatpidoacbkev4wesGNb2RHFXYSi6LUFTos5E7YfOn_zdnTfgTwY3WqyMGCwaIUMWBo0Dc_ezcekJ9RxXI-8Azj7bwVRqZRe524zGJmnmhkLJOqtV1B06Xi3d_QDHHI9395TEWsGCeIiLHcQPiWEvSH9rRYUW_HduMWgtxLIyHrDM1j-fADoR-C1psCZMi5ESmBtsgUCQEy9hfX8h2RpBn7KVDuhCHYEA3e24upjCtF1opbwE6AAVoQqeeiDp2AAeIE1qxtEAqF6mVqyjV-nW-Y3FP6SNYJVQQKvCWUVhCOWZfuLTmWv22AiClG8SlGG3D-ckWAOa-vVm4LmZKt0zfip0RucWuiqY72fJ4Lk5_94FpPdoXPBlJheoE4__LMvYPhO38S3NXyFBXho4JMtd6f2E6rM8ciw7pDY3N_XAWkfWNIigQquMB3HJhxZWvSplrLq-CrbKzobpTBDrU7MaAn0oOOBVQ0i-5XyfHAZCibQPTYEVbJNWT4OA_AcJu0YuvUFP6nzN5B8YHsPYfuyZ0fdFQhF9PGj-ECNhP_iG6ilL4twcfJpP8GWKc6az_JvluzsEaL66ujs2gqeUnjZm6hwi2WOXh3wDxDFy-vqBcl81XmE-We3Den0BSKi-wE4WE26zaz3aDwFbDxMitiNV723XIWttxqh0_Snj7zPkxjx5JQdrli_x-SefMpz7L0pquSuVGxz435gkL8BdXeehfa3oMRiFQtcHxsblfDioJ6z6BqZa6H4R21s0k69TYjsqsK-tHxTKBdAc3bNg03RcxjFpGp3-qZJ_8KaDNf5XRRXrMym9m_6giPbAVoBJgVKKWnvCPcPI8xtQMnhS-ljbIZRKVxODvVjtzoBblL3F9Xb-drytDTK9ZnMrdxBQ9WmRGwB2olr0UZmg41jtwIGsf4BJMn7zEOZXYaWtXaIeXFYKkenQT1erYKQvcg1VGlJxYa6xMiTzk2RoUVVSx7L9q8I0jQx34sg9f7u0R8cCOJMiHQJq0_3IDySr2geMMOfsTPrF68wciIQ_Kvv_gCTPxbt1nRTMiysepqZ9MnfMJ1WSI5LBni0QMWwjTpo_xYCpBHwEgFIbTA_D2D0OU5-_4TGEsVDQ5ezUdmw_nZO-NIjq7eOOqaDOVdd3qTsGrdFBxy4Okx5NcZNCQDKvY7-h64eMVYWrnvdu3l30QV0q9d1Wjz8NH7aIkDQ1ebFSYD4w4076ZzdGMhligbpBWnxbLl-64sdhTwPthxOFTccLqwYpCWEATGkrTfVd3FOJQQb1dWY_hZYl3F7se3IJJyrEkwdfL-C45Zbrfy9Fl-jh2B2m6U08GomtyqDMzMTNiYzkzqHNoYXJkX2lkzhQ8hB8.03zeN4dRdNLE1kf69ZYATBDm7nfDBzAo3fr_YyYO_5I"}' 'http://192.168.178.55:8090/v1/register/+491637928873'
```

Den Verifikationscode eingeben:
```
curl -X POST -H "Content-Type: application/json" 'http://192.168.178.55:8090/v1/register/+491637928873/verify/855429'
```

Message senden:  
```
curl -X POST -H "Content-Type: application/json" -d '{"message": "Viele Grüße von Hajo per API", "number": "+491637928873", "recipients": ["+491704532333"]}' 'http://192.168.178.55:8090/v2/send'
```


### Receive
```
curl -X GET -H "Content-Type: application/json" 'http://192.168.178.55:8090/v1/receive/+491637928873'
```

### Expiring messages
Auf dem Client die Zeit einstellen und anschließend einen Receive-API-Call ausführen.

### Name und Avatar
```
curl -X PUT -H "Content-Type: application/json" -d '{"name": "HomeAssistant","base64_avatar":"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"}' "http://192.168.178.55:8090/v1/profiles/+491637928873"
```




Was ist das?

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