# Shivam Cyber Cafe — Cloud + Android setup

The app remains offline-first. Firebase cloud backup is optional until configured.

## 1. Create Firebase project

Create a Firebase project and register the Flutter app for **Android and Windows**.

## 2. Enable services

- Authentication → Sign-in method → enable **Anonymous**.
- Storage → create the default Cloud Storage bucket.

## 3. Configure FlutterFire

From the project root on a machine with Flutter installed:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

Select the same Firebase project and the Android + Windows platforms.

The official FlutterFire setup generates the platform configuration and keeps it in sync when platforms/services change.

## 4. Enable the cloud switch

Open `lib/cloud/cloud_config.dart` and set `enabled` to `true`, then copy the values from the generated Firebase configuration into that file if you are not using the generated `firebase_options.dart` approach.

## 5. Security rules

Do not make Storage public. Allow access only to authenticated users and scope the `shops/{shopId}` path appropriately. The app currently signs in anonymously, so your Storage rules should require `request.auth != null` and restrict each shop path to the intended account/device strategy.

## 6. What this version does

- Keeps SQLite as the local database.
- Uploads the complete SQLite database as a cloud snapshot.
- Lets another Windows/Android installation restore the latest snapshot.
- Does **not** merge simultaneous edits from two devices. Use one active device at a time until a row-level Firestore sync layer is added.
