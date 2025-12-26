const express = require('express');
const bodyParser = require('body-parser');
const sgMail = require('@sendgrid/mail');
const admin = require('firebase-admin');
const fs = require('fs');
const cors = require('cors');

// Configuration via environment variables (set in your hosting platform)
const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY || '';
const SENDGRID_SENDER = process.env.SENDGRID_SENDER || '';
const SERVICE_ACCOUNT_JSON = process.env.SERVICE_ACCOUNT_JSON || ''; // JSON string of service account

// Prefer SERVICE_ACCOUNT_JSON env; if not provided, fall back to local serviceAccount.json file (for dev)
let initialized = false;
if (SERVICE_ACCOUNT_JSON) {
  try {
    const sa = JSON.parse(SERVICE_ACCOUNT_JSON);
    admin.initializeApp({ credential: admin.credential.cert(sa) });
    initialized = true;
    console.log('Firebase admin initialized from SERVICE_ACCOUNT_JSON env');
  } catch (e) {
    console.error('Failed to parse SERVICE_ACCOUNT_JSON env var:', e.message || e);
  }
}

if (!initialized) {
  const localPath = './serviceAccount.json';
  if (fs.existsSync(localPath)) {
    try {
      const sa = JSON.parse(fs.readFileSync(localPath, 'utf8'));
      admin.initializeApp({ credential: admin.credential.cert(sa) });
      initialized = true;
      console.log('Firebase admin initialized from local serviceAccount.json');
    } catch (e) {
      console.error('Failed to parse local serviceAccount.json:', e.message || e);
    }
  }
}

if (!initialized) {
  try {
    admin.initializeApp();
    initialized = true;
    console.log('Firebase admin initialized with default application credentials');
  } catch (e) {
    console.warn('Firebase admin initialization skipped (no credentials available). Firestore operations will fail.');
  }
}

if (SENDGRID_API_KEY) sgMail.setApiKey(SENDGRID_API_KEY);

const db = admin.firestore ? admin.firestore() : null;

const app = express();
app.use(cors());
app.use(bodyParser.json());

function generateCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let out = '';
  for (let i = 0; i < 6; i++) out += chars[Math.floor(Math.random() * chars.length)];
  return `FAC-${out}`;
}

app.post('/invite', async (req, res) => {
  try {
    const email = (req.body && req.body.email) ? String(req.body.email).trim() : '';
    if (!email || !email.includes('@')) return res.status(400).json({ error: 'Invalid email' });

    const code = generateCode();

    // Persist to Firestore if available
    if (db) {
      await db.collection('invites').add({
        code,
        email,
        role: 'faculty',
        isUsed: false,
        createdBy: 'external-service',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Send email via SendGrid if configured
    let emailed = false;
    if (SENDGRID_API_KEY && SENDGRID_SENDER) {
      const msg = {
        to: email,
        from: SENDGRID_SENDER,
        subject: 'Your Faculty Invite Code',
        text: `Your faculty invite code is: ${code}`,
        html: `<p>Your faculty invite code is: <strong>${code}</strong></p><p>Use this code to register as faculty.</p>`,
      };
      try {
        await sgMail.send(msg);
        emailed = true;
      } catch (sgErr) {
        console.error('SendGrid send error:', sgErr.message || sgErr);
        if (sgErr.response && sgErr.response.body) console.error('SendGrid response body:', sgErr.response.body);
        // do not throw — return response to client with emailed=false
      }
    }

    return res.json({ success: true, emailed, code });
  } catch (e) {
    console.error('Invite error', e);
    return res.status(500).json({ error: e.message || String(e) });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`External Invite Service running on port ${PORT}`));
