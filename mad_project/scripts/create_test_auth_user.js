const admin = require('firebase-admin');

try {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
} catch (e) {
  // ignore if already initialized
}

const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('Usage: node scripts/create_test_auth_user.js <email> <password> [uid] [displayName]');
  process.exit(1);
}

const [email, password, uid, displayName] = args;

const userProps = {
  email,
  password,
  emailVerified: false,
  disabled: false,
};
if (uid) userProps.uid = uid;
if (displayName) userProps.displayName = displayName;

admin.auth().createUser(userProps)
  .then((userRecord) => {
    console.log('Created user:', userRecord.uid);
    console.log('Email:', userRecord.email);
    process.exit(0);
  })
  .catch((err) => {
    console.error('Error creating user:', err);
    process.exit(1);
  });
