# CampusPulse — Flutter client

CampusPulse is a university communication MVP for COMSATS University Islamabad. The app includes role-based group chat, direct messages, emergency alerts, official campus events, and scholarship notices.

## Run locally

1. Start the Express/Socket.IO API from `cui-backend` with `npm start`.
2. From `cui_connect_app`, run `flutter pub get` and `flutter run`.
3. Android emulator uses `http://10.0.2.2:3000`. For a physical phone, connect both devices to the same network and set the PC's LAN URL with the settings icon on the sign-in screen.

Use the demo credentials in `cui-backend/DEMO_CREDENTIALS.md`. The sign-in page has no demo account selector.

## App structure

- `lib/screens/home_screen.dart` — app shell and Chats/Announcements navigation
- `lib/screens/announcements_screen.dart` — role-filtered official notices
- `lib/screens/announcement_compose.dart` — authorized event and scholarship publishing
- `lib/providers/app_state.dart` — authenticated session and Socket.IO state
- `lib/services/api.dart` — REST API client

The runnable Android/iOS/web Flutter project is in `cui_connect_app`; the top-level `lib` folder is kept as the shareable client source.
