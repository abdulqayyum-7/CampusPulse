# CampusPulse

University campus communication MVP for COMSATS University Islamabad. This repository contains a Flutter mobile/web client and an Express + Socket.IO API.

## Run locally

1. Start the backend: `cd cui-backend`, `npm install`, `npm start`.
2. Start the Flutter app: `cd cui_connect/cui_connect_app`, `flutter pub get`, `flutter run`.
3. Android emulator API URL defaults to `http://10.0.2.2:3000`. For a physical device, use the settings control on the sign-in page to enter the computer's LAN URL.
4. Local demo usernames and passwords are documented in `cui-backend/DEMO_CREDENTIALS.md`.

## Features

- Role and department-based group conversations and direct messaging.
- Server-enforced group access and read/send permissions.
- Authenticated REST APIs and Socket.IO live updates.
- Official campus events and scholarship announcements with publisher authority checks and role-based audiences.
- Sign-in flow with no demo account selector.

This is an MVP. Demo accounts are for local development only. Production use requires university identity integration, durable shared storage for users/groups/messages, and a Socket.IO adapter for multiple server instances.
