const express = require('express');
const router = express.Router();
const fetch = require('node-fetch');
require('dotenv').config();

const { db, auth } = require('../firebase/admin');
const { verifyToken, generateToken } = require('../middleware/auth');

// ─────────────────────────────────────────────────────────────
// Helper: build a clean user object from Firestore data
// ─────────────────────────────────────────────────────────────
const buildUser = (uid, data) => ({
  uid,
  name: data.name || '',
  email: data.email || '',
  role: data.role || 'student',
  phone: data.phone || '',
  profileImageUrl: data.profileImageUrl || '',
  university: data.university || null,
  preferredCity: data.preferredCity || null,
  preferredFacilities: data.preferredFacilities || [],
  preferredGender: data.preferredGender || 'mixed',
  budgetMin: data.budgetMin || 0,
  budgetMax: data.budgetMax || 50000,
  cleanlinessPref: data.cleanlinessPref || 'any',
  noisePref: data.noisePref || 'any',
  sharingPref: data.sharingPref || 'any',
  dietPref: data.dietPref || 'any',
  transportPref: data.transportPref || 'any',
  licenseNumber: data.licenseNumber || '',
  isApproved: data.isApproved || false,
  businessName: data.businessName || null,
  cnic: data.cnic || null,
  createdAt: data.createdAt || new Date().toISOString(),
});

// ─────────────────────────────────────────────────────────────
// POST /api/auth/register/student
// ─────────────────────────────────────────────────────────────
router.post('/register/student', async (req, res) => {
  try {
    const {
      email, password, name, phone, university,
      preferredCity, preferredFacilities, preferredGender,
      budgetMin, budgetMax,
    } = req.body;

    if (!email || !password || !name) {
      return res.status(400).json({ msg: 'email, password and name are required.' });
    }

    // 1. Create Firebase Auth user (Admin SDK — no email verification needed)
    const userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
    });
    const uid = userRecord.uid;

    // 2. Save profile to Firestore
    const userData = {
      uid, name, email, role: 'student',
      phone: phone || '',
      university: university || null,
      preferredCity: preferredCity || null,
      preferredFacilities: preferredFacilities || [],
      preferredGender: preferredGender || 'mixed',
      budgetMin: budgetMin || 5000,
      budgetMax: budgetMax || 30000,
      profileImageUrl: '',
      cleanlinessPref: 'any', noisePref: 'any',
      sharingPref: 'any', dietPref: 'any', transportPref: 'any',
      licenseNumber: '', isApproved: false,
      businessName: null, cnic: null,
      createdAt: new Date().toISOString(),
    };
    await db.collection('users').doc(uid).set(userData);

    // 3. Return JWT token + user
    const token = generateToken(uid, 'student');
    return res.status(201).json({ token, user: userData });
  } catch (err) {
    console.error('[register/student]', err.message);
    if (err.code === 'auth/email-already-exists') {
      return res.status(400).json({ msg: 'email-already-in-use' });
    }
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// POST /api/auth/register/owner
// ─────────────────────────────────────────────────────────────
router.post('/register/owner', async (req, res) => {
  try {
    const { email, password, name, phone, businessName, cnic } = req.body;

    if (!email || !password || !name) {
      return res.status(400).json({ msg: 'email, password and name are required.' });
    }

    const userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
    });
    const uid = userRecord.uid;

    const userData = {
      uid, name, email, role: 'owner',
      phone: phone || '',
      businessName: businessName || null,
      cnic: cnic || null,
      isApproved: false, licenseNumber: '',
      profileImageUrl: '',
      preferredFacilities: [], preferredGender: 'mixed',
      budgetMin: 0, budgetMax: 0,
      cleanlinessPref: 'any', noisePref: 'any',
      sharingPref: 'any', dietPref: 'any', transportPref: 'any',
      createdAt: new Date().toISOString(),
    };
    await db.collection('users').doc(uid).set(userData);

    const token = generateToken(uid, 'owner');
    return res.status(201).json({ token, user: userData });
  } catch (err) {
    console.error('[register/owner]', err.message);
    if (err.code === 'auth/email-already-exists') {
      return res.status(400).json({ msg: 'email-already-in-use' });
    }
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// POST /api/auth/login
// Uses Firebase Auth REST API to verify email + password
// ─────────────────────────────────────────────────────────────
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ msg: 'email and password are required.' });
    }

    // Call Firebase Auth REST API to validate credentials
    const firebaseApiKey = process.env.FIREBASE_API_KEY;
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebaseApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true }),
      }
    );
    const firebaseData = await response.json();

    if (firebaseData.error) {
      const code = firebaseData.error.message;
      if (code === 'EMAIL_NOT_FOUND' || code === 'INVALID_LOGIN_CREDENTIALS') {
        return res.status(401).json({ msg: 'invalid-credential' });
      }
      if (code === 'INVALID_PASSWORD') {
        return res.status(401).json({ msg: 'wrong-password' });
      }
      if (code.includes('TOO_MANY_ATTEMPTS')) {
        return res.status(429).json({ msg: 'too-many-requests' });
      }
      return res.status(401).json({ msg: code });
    }

    const uid = firebaseData.localId;

    // Fetch user profile from Firestore
    const doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) {
      return res.status(404).json({ msg: 'user-not-found' });
    }

    const user = buildUser(uid, doc.data());
    const token = generateToken(uid, user.role);
    return res.json({ token, user });
  } catch (err) {
    console.error('[login]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/auth/me  (requires token)
// ─────────────────────────────────────────────────────────────
router.get('/me', verifyToken, async (req, res) => {
  try {
    const doc = await db.collection('users').doc(req.user.uid).get();
    if (!doc.exists) {
      return res.status(404).json({ msg: 'User not found.' });
    }
    return res.json(buildUser(req.user.uid, doc.data()));
  } catch (err) {
    console.error('[/me]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// PUT /api/auth/profile  (requires token)
// ─────────────────────────────────────────────────────────────
router.put('/profile', verifyToken, async (req, res) => {
  try {
    const updates = { ...req.body };
    // Protect immutable fields
    delete updates.uid;
    delete updates.email;
    delete updates.role;
    delete updates.createdAt;

    await db.collection('users').doc(req.user.uid).update(updates);
    const doc = await db.collection('users').doc(req.user.uid).get();
    return res.json(buildUser(req.user.uid, doc.data()));
  } catch (err) {
    console.error('[profile update]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

module.exports = router;
