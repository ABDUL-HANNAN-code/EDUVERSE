External Invite Service
=======================

This small Express service generates `FAC-XXXXXX` invite codes, writes them to Firestore (using a service account), and emails the code via SendGrid.

Environment variables (set in your host like Vercel / Render):

- `SENDGRID_API_KEY` — SendGrid API key (optional; if not set, email won't be sent)
- `SENDGRID_SENDER` — verified sender email for SendGrid (e.g. no-reply@yourdomain.com)
- `SERVICE_ACCOUNT_JSON` — JSON string of your Firebase service account key (recommended). Alternatively configure default application credentials on the host.
- `PORT` — optional port (default 3000)

Deploy: use Vercel, Render, or any node host. Example (Render):

1. Push this `external_invite_service` folder to a Git repo.
2. Create a new Web Service on Render, connect the repo, set `index.js` as start command: `node index.js`.
3. Add environment variables in Render settings: `SERVICE_ACCOUNT_JSON`, `SENDGRID_API_KEY`, `SENDGRID_SENDER`.

Client usage
------------
POST JSON to `/invite` with `{ "email": "prof@example.edu" }` and the service will return `{ success:true, emailed:true|false, code: 'FAC-XXXXXX' }`.

Security
--------
Treat `SERVICE_ACCOUNT_JSON` and `SENDGRID_API_KEY` as secrets. Do not embed them in the Flutter client. Use this server as a secure backend.
