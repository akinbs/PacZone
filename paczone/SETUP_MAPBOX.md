# Mapbox + Real Location Setup

## Step 1 — Get Your Mapbox Tokens

Sign up at https://account.mapbox.com and create two tokens:

| Token | Type | Where to use |
|-------|------|--------------|
| Public token (`pk.xxx`) | Read-only | `.env` file in this project |
| Secret token (`sk.xxx`) | Downloads | Your machine only (never in repo) |

---

## Step 2 — Add Public Token to .env

Copy `.env.example` to `.env` and fill in your public token:

```
MAPBOX_ACCESS_TOKEN=pk.YOUR_TOKEN_HERE
```

The app reads this on startup. When a valid `pk.` token is present,
`AppConfig.useRealMap` is set to `true` automatically.

---

## Step 3 — Android: Secret Token for SDK Download

Add your **secret** token to your local Gradle properties file.
This file is on your machine, not in the repo:

**File:** `~/.gradle/gradle.properties` (Windows: `C:\Users\<you>\.gradle\gradle.properties`)

```properties
MAPBOX_DOWNLOADS_TOKEN=sk.YOUR_SECRET_TOKEN_HERE
```

The `android/build.gradle.kts` already references this property to
authenticate Mapbox's Maven repository.

---

## Step 4 — iOS: Secret Token for CocoaPods

Add your **secret** token to `~/.netrc` (create if it doesn't exist):

```
machine api.mapbox.com
  login mapbox
  password sk.YOUR_SECRET_TOKEN_HERE
```

---

## Step 5 — minSdk (Android)

`mapbox_maps_flutter` 2.x (with Mapbox Maps SDK 11 + jni_flutter) requires
`minSdk = 26`. The project already sets this explicitly:

```kotlin
minSdk = 26
```

This means the app targets Android 8.0+ devices, which cover 95%+ of active
Android users.

---

## Real Location Without Real Map

You don't need Mapbox to get real GPS — `geolocator` works immediately
on both Android and iOS once the app permission is granted.

- **No `.env` token** → MockMapPainter (purple grid) + real GPS
- **Valid `.env` token + Mapbox credentials** → Mapbox dark map + real GPS

---

## Debug Panel

Long-press the **level badge** (top-left) on the home screen to open
the debug scenario panel and test all scan result states instantly.
