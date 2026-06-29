const express = require('express');
const router = express.Router();
const { db } = require('../firebase/admin');
const { verifyToken } = require('../middleware/auth');
const admin = require('firebase-admin');

// ─────────────────────────────────────────────────────────────
// Helper: build review from Firestore doc
// ─────────────────────────────────────────────────────────────
const buildReview = (id, data) => ({
  id,
  hostelId: data.hostelId || '',
  studentId: data.studentId || '',
  studentName: data.studentName || '',
  studentImageUrl: data.studentImageUrl || '',
  rating: data.rating || 0.0,
  comment: data.comment || '',
  createdAt: data.createdAt instanceof admin.firestore.Timestamp
    ? data.createdAt.toDate().toISOString()
    : (data.createdAt || new Date().toISOString()),
});

// ─────────────────────────────────────────────────────────────
// POST /api/reviews  — add a review
// ─────────────────────────────────────────────────────────────
router.post('/', verifyToken, async (req, res) => {
  try {
    const { hostelId, rating, comment, studentName, studentImageUrl } = req.body;
    if (!hostelId || !rating) {
      return res.status(400).json({ msg: 'hostelId and rating are required.' });
    }

    const docRef = db.collection('reviews').doc();
    const reviewData = {
      id: docRef.id,
      hostelId,
      studentId: req.user.uid,
      studentName: studentName || '',
      studentImageUrl: studentImageUrl || '',
      rating: parseFloat(rating),
      comment: comment || '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await docRef.set(reviewData);

    // Recompute hostel average rating
    const reviewsSnap = await db.collection('reviews')
      .where('hostelId', '==', hostelId)
      .get();
    const ratings = reviewsSnap.docs.map(d => parseFloat(d.data().rating) || 0);
    const avg = ratings.reduce((a, b) => a + b, 0) / ratings.length;

    await db.collection('hostels').doc(hostelId).update({
      rating: parseFloat(avg.toFixed(2)),
      reviewCount: ratings.length,
    });

    return res.status(201).json({ id: docRef.id, msg: 'Review added.' });
  } catch (err) {
    console.error('[POST /reviews]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/reviews/:hostelId  — get reviews for a hostel
// ─────────────────────────────────────────────────────────────
router.get('/:hostelId', async (req, res) => {
  try {
    const snap = await db.collection('reviews')
      .where('hostelId', '==', req.params.hostelId)
      .orderBy('createdAt', 'desc')
      .get();
    return res.json(snap.docs.map(d => buildReview(d.id, d.data())));
  } catch (err) {
    console.error('[GET /reviews/:hostelId]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

module.exports = router;
