const admin = require('firebase-admin');
require('dotenv').config();

const path = require('path');

let serviceAccount;
try {
  serviceAccount = require(path.resolve(process.env.SERVICE_ACCOUNT_KEY_PATH || './serviceAccountKey.json'));
} catch (e) {
  console.error('❌ serviceAccountKey.json not found!');
  console.error('   Download from: Firebase Console → Project Settings → Service Accounts → Generate new private key');
  console.error('   Place the file at: backend/serviceAccountKey.json');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  });
}

const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

module.exports = { admin, db, auth, storage };
