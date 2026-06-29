const express = require('express');
const router = express.Router();
const { db, auth } = require('../firebase/admin');
const { verifyToken, requireAdmin } = require('../middleware/auth');

// Apply verifyToken + requireAdmin to ALL admin routes
router.use(verifyToken, requireAdmin);

// ─────────────────────────────────────────────────────────────
// GET /api/admin/owners/pending  — owners awaiting approval
// ─────────────────────────────────────────────────────────────
router.get('/owners/pending', async (req, res) => {
  try {
    const snap = await db.collection('users')
      .where('role', '==', 'owner')
      .where('isApproved', '==', false)
      .get();
    return res.json(snap.docs.map(d => ({ uid: d.id, ...d.data() })));
  } catch (err) {
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/admin/owners/approved  — approved owners
// ─────────────────────────────────────────────────────────────
router.get('/owners/approved', async (req, res) => {
  try {
    const snap = await db.collection('users')
      .where('role', '==', 'owner')
      .where('isApproved', '==', true)
      .get();
    return res.json(snap.docs.map(d => ({ uid: d.id, ...d.data() })));
  } catch (err) {
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/admin/owners  — all owners
// ─────────────────────────────────────────────────────────────
router.get('/owners', async (req, res) => {
  try {
    const snap = await db.collection('users')
      .where('role', '==', 'owner')
      .get();
    return res.json(snap.docs.map(d => ({ uid: d.id, ...d.data() })));
  } catch (err) {
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/admin/students  — all students
// ─────────────────────────────────────────────────────────────
router.get('/students', async (req, res) => {
  try {
    const snap = await db.collection('users')
      .where('role', '==', 'student')
      .get();
    return res.json(snap.docs.map(d => ({ uid: d.id, ...d.data() })));
  } catch (err) {
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// PUT /api/admin/owners/:uid/approve  — approve an owner
// ─────────────────────────────────────────────────────────────
router.put('/owners/:uid/approve', async (req, res) => {
  try {
    const { licenseNumber } = req.body;
    await db.collection('users').doc(req.params.uid).update({
      isApproved: true,
      licenseNumber: licenseNumber || '',
    });
    return res.json({ msg: 'Owner approved.' });
  } catch (err) {
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// DELETE /api/admin/users/:uid  — delete a user
// ─────────────────────────────────────────────────────────────
router.delete('/users/:uid', async (req, res) => {
  try {
    const uid = req.params.uid;
    // Delete from Firebase Auth
    try { await auth.deleteUser(uid); } catch (_) {}
    // Delete from Firestore
    await db.collection('users').doc(uid).delete();
    return res.json({ msg: 'User deleted.' });
  } catch (err) {
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/admin/stats  — dashboard statistics
// ─────────────────────────────────────────────────────────────
router.get('/stats', async (req, res) => {
  try {
    const [usersSnap, hostelsSnap, bookingsSnap] = await Promise.all([
      db.collection('users').get(),
      db.collection('hostels').get(),
      db.collection('bookings').get(),
    ]);

    const users = usersSnap.docs.map(d => d.data());
    const hostels = hostelsSnap.docs.map(d => d.data());

    return res.json({
      totalUsers: users.length,
      totalStudents: users.filter(u => u.role === 'student').length,
      totalOwners: users.filter(u => u.role === 'owner').length,
      totalHostels: hostels.length,
      totalBookings: bookingsSnap.size,
      pendingOwners: users.filter(u => u.role === 'owner' && !u.isApproved).length,
      pendingHostels: hostels.filter(h => !h.isApproved).length,
    });
  } catch (err) {
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// PUT /api/admin/hostels/:id/approve  — approve a hostel listing
// ─────────────────────────────────────────────────────────────
router.put('/hostels/:id/approve', async (req, res) => {
  try {
    await db.collection('hostels').doc(req.params.id).update({ isApproved: true });
    return res.json({ msg: 'Hostel approved.' });
  } catch (err) {
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// POST /api/admin/seed  — seed admin user (run once)
// ─────────────────────────────────────────────────────────────
router.post('/seed', async (req, res) => {
  try {
    const adminEmail = 'admin@hods.com';
    const adminPassword = 'Admin@HODS2024';

    // Check if admin already exists
    const existing = await db.collection('users')
      .where('role', '==', 'admin')
      .limit(1)
      .get();

    if (!existing.empty) {
      return res.json({ msg: 'Admin already seeded.' });
    }

    let uid;
    try {
      const record = await auth.getUserByEmail(adminEmail);
      uid = record.uid;
    } catch (_) {
      const record = await auth.createUser({
        email: adminEmail,
        password: adminPassword,
        displayName: 'Super Admin',
      });
      uid = record.uid;
    }

    await db.collection('users').doc(uid).set({
      uid,
      name: 'Super Admin',
      email: adminEmail,
      role: 'admin',
      phone: '',
      profileImageUrl: '',
      isApproved: true,
      licenseNumber: '',
      preferredFacilities: [],
      preferredGender: 'mixed',
      budgetMin: 0, budgetMax: 0,
      createdAt: new Date().toISOString(),
    });

    return res.json({ msg: 'Admin seeded successfully.', uid });
  } catch (err) {
    return res.status(500).json({ msg: err.message });
  }
});

module.exports = router;
