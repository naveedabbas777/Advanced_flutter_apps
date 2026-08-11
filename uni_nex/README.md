# uni_nex

UniNex — university campus companion app built with Flutter.

## Overview

`uni_nex` is a Flutter mobile app designed to help university students and staff discover campus services, manage events, navigate buildings, and save favourite locations. The app includes authentication, role-based user management (student/admin), event creation and management, campus maps, and building search.

## Key Features

- **Authentication:** Email/password login and registration screens.
- **Role management:** User and admin roles with management UI.
- **Events:** Browse, favourite, create, and manage campus events.
- **Campus map:** Interactive map with markers and favourite locations.
- **Search:** Building search and navigation helpers.
- **Profile:** User profile and settings.

## Tech Stack

- Flutter (Dart)
- Firebase (Authentication, Firestore)
- Mapbox or native map plugins for campus mapping

## Quick Start

1. Install Flutter and set up your environment: https://docs.flutter.dev/get-started
2. From the project root, run:

```
flutter pub get
flutter run
```

3. This project includes Firebase config files and a generated `firebase_options.dart` for initialization. Ensure you have your Firebase project setup and `google-services.json` (Android) and iOS plist files present.

## Screenshots

Below are sample UI screens from the app. Images are stored in the repository under the `Uninex screens/` folder.

**Login**

![Login screen](Uninex%20screens/Login%20screen.jpeg)

**Registration**

![Registration screen](Uninex%20screens/Registration%20screen.jpeg)

**Dashboard**

![Dashboard screen](Uninex%20screens/Dashboard%20screen.jpeg)

**Navigation / Main Menu**

![Navigation screen](Uninex%20screens/Navigation%20screen.jpeg)

**Campus Map**

![Campus map screen](Uninex%20screens/Campus%20map%20screen.jpeg)

**Event Management**

![Event Management](Uninex%20screens/Event%20Management.jpeg)

**Add Event**

![Add event screen](Uninex%20screens/Add%20event%20screen.jpeg)

**User / Admin Profile**

![User or Admin profile screen](Uninex%20screens/User%20or%20Admin%20profile%20screen.jpeg)

**Building Search**

![Building Search](Uninex%20screens/Building%20Search.jpeg)

**Favourites & Events**

![My Favourite events](Uninex%20screens/My%20Favourite%20events.jpeg)

## Notes for Maintainers

- Screenshots are kept in `Uninex screens/` — feel free to move them into a `screenshots/` folder if you prefer cleaner paths.
- Update `firebase_options.dart` when changing Firebase projects.

## Next Steps

- Add a CONTRIBUTING section and license if you plan to accept contributions.
- Optionally create a `screenshots/` directory and relocate images for nicer paths.

---
Generated README content updated to include app overview and visual samples.
