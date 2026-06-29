const express = require('express');
const router = express.Router();
const { db } = require('../firebase/admin');
const { verifyToken } = require('../middleware/auth');
const admin = require('firebase-admin');

// ─────────────────────────────────────────────────────────────
// Helper: build hostel object from Firestore doc
// ─────────────────────────────────────────────────────────────
const buildHostel = (id, data) => ({
  id,
  ownerId: data.ownerId || '',
  ownerName: data.ownerName || '',
  name: data.name || '',
  description: data.description || '',
  location: data.location || '',
  city: data.city || '',
  pricePerMonth: data.pricePerMonth || 0,
  pricePerDay: data.pricePerDay || 1200,
  totalRooms: data.totalRooms || 0,
  availableRooms: data.availableRooms || 0,
  facilities: data.facilities || [],
  imageUrls: data.imageUrls || [],
  rating: data.rating || 0.0,
  reviewCount: data.reviewCount || 0,
  genderPolicy: data.genderPolicy || 'Both',
  licenseNumber: data.licenseNumber || '',
  isApproved: data.isApproved || false,
  createdAt: data.createdAt instanceof admin.firestore.Timestamp
    ? data.createdAt.toDate().toISOString()
    : (data.createdAt || new Date().toISOString()),
});

// ─────────────────────────────────────────────────────────────
// GET /api/hostels  — all approved hostels
// ─────────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const snap = await db.collection('hostels')
      .where('isApproved', '==', true)
      .orderBy('createdAt', 'desc')
      .get();
    const hostels = snap.docs.map(d => buildHostel(d.id, d.data()));
    return res.json(hostels);
  } catch (err) {
    console.error('[GET /hostels]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/hostels/owner  — hostels belonging to logged-in owner
// ─────────────────────────────────────────────────────────────
router.get('/owner', verifyToken, async (req, res) => {
  try {
    const snap = await db.collection('hostels')
      .where('ownerId', '==', req.user.uid)
      .orderBy('createdAt', 'desc')
      .get();
    const hostels = snap.docs.map(d => buildHostel(d.id, d.data()));
    return res.json(hostels);
  } catch (err) {
    console.error('[GET /hostels/owner]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/hostels/:id  — single hostel
// ─────────────────────────────────────────────────────────────
router.get('/:id', async (req, res) => {
  try {
    const doc = await db.collection('hostels').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ msg: 'Hostel not found.' });
    return res.json(buildHostel(doc.id, doc.data()));
  } catch (err) {
    console.error('[GET /hostels/:id]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// POST /api/hostels  — create hostel (owner only)
// ─────────────────────────────────────────────────────────────
router.post('/', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'owner' && req.user.role !== 'admin') {
      return res.status(403).json({ msg: 'Only hostel owners can create hostels.' });
    }

    const docRef = db.collection('hostels').doc();
    const id = docRef.id;

    // Get owner's name from Firestore
    let ownerName = req.body.ownerName || '';
    if (!ownerName) {
      const ownerDoc = await db.collection('users').doc(req.user.uid).get();
      ownerName = ownerDoc.exists ? (ownerDoc.data().name || '') : '';
    }

    const hostelData = {
      id,
      ownerId: req.user.uid,
      ownerName,
      name: req.body.name || '',
      description: req.body.description || '',
      location: req.body.location || '',
      city: req.body.city || '',
      pricePerMonth: req.body.pricePerMonth || 0,
      pricePerDay: req.body.pricePerDay || 1200,
      totalRooms: req.body.totalRooms || 0,
      availableRooms: req.body.availableRooms || req.body.totalRooms || 0,
      facilities: req.body.facilities || [],
      imageUrls: req.body.imageUrls || [],
      rating: 0.0,
      reviewCount: 0,
      genderPolicy: req.body.genderPolicy || 'Both',
      licenseNumber: req.body.licenseNumber || '',
      isApproved: false, // Admin must approve
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await docRef.set(hostelData);
    return res.status(201).json(buildHostel(id, { ...hostelData, createdAt: new Date().toISOString() }));
  } catch (err) {
    console.error('[POST /hostels]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// PUT /api/hostels/:id  — update hostel
// ─────────────────────────────────────────────────────────────
router.put('/:id', verifyToken, async (req, res) => {
  try {
    const doc = await db.collection('hostels').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ msg: 'Hostel not found.' });

    // Only the owner or admin can update
    if (doc.data().ownerId !== req.user.uid && req.user.role !== 'admin') {
      return res.status(403).json({ msg: 'Not authorized.' });
    }

    const updates = { ...req.body };
    delete updates.id;
    delete updates.ownerId;
    delete updates.createdAt;

    await db.collection('hostels').doc(req.params.id).update(updates);
    const updated = await db.collection('hostels').doc(req.params.id).get();
    return res.json(buildHostel(updated.id, updated.data()));
  } catch (err) {
    console.error('[PUT /hostels/:id]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// DELETE /api/hostels/:id  — delete hostel
// ─────────────────────────────────────────────────────────────
router.delete('/:id', verifyToken, async (req, res) => {
  try {
    const doc = await db.collection('hostels').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ msg: 'Hostel not found.' });

    if (doc.data().ownerId !== req.user.uid && req.user.role !== 'admin') {
      return res.status(403).json({ msg: 'Not authorized.' });
    }

    await db.collection('hostels').doc(req.params.id).delete();
    return res.json({ msg: 'Hostel deleted.' });
  } catch (err) {
    console.error('[DELETE /hostels/:id]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

module.exports = router;
