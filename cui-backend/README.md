# CampusPulse API

Express provides authenticated REST endpoints and Socket.IO delivers group chat, presence, emergencies, and live announcement updates.

## Run locally

```powershell
npm install
npm start
```

The API listens on port `3000` by default. Use `PORT` to change it and set `JWT_SECRET` outside local development. Use the sample usernames and passwords in [DEMO_CREDENTIALS.md](DEMO_CREDENTIALS.md) for local sign-in.

## REST API

- `POST /api/login` — issue a signed session for a demo account
- `GET /api/users` — authenticated user directory
- `GET /api/me/groups` — groups and permissions for the signed-in user
- `GET /api/announcements` — announcements visible to the signed-in role
- `POST /api/announcements` — publish an event or scholarship notice (authority checked server-side)
- `DELETE /api/announcements/:id` — publisher or admin only
- `/api/groups` is admin-only. `POST /api/users` and `DELETE /api/users/:id` are admin-only; `GET /api/users` requires authentication.

## Realtime events

Connect Socket.IO with `auth: { token }`. Existing chat, direct message, presence, typing, and emergency events remain available. Announcement events are `announcement:new` and `announcement:removed`; the server sends them only to rooms for selected audience roles (admins receive them as well).

## Announcement authority

- Events: admin, academic office, registrar/administrative office, and teaching HODs.
- Scholarships: admin, academic office, registrar/administrative office, and finance.
- The publisher chooses recipient roles. The backend enforces both publisher authority and audience role validity.

## MVP persistence and scaling

Announcements are written atomically to `data/announcements.json` and survive a backend restart. Existing users, groups, and chat history are still held in memory. This supports a single local MVP process; production or multiple API instances need a shared database for all records, external university identity integration, and the Socket.IO Redis adapter for cross-instance delivery.
