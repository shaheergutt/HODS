const express = require('express');
const router = express.Router();
const { db } = require('../firebase/admin');
const { verifyToken } = require('../middleware/auth');
const admin = require('firebase-admin');

// ─────────────────────────────────────────────────────────────
// Helper: build booking from Firestore doc
// ─────────────────────────────────────────────────────────────
const buildBooking = (id, data) => ({
  id,
  studentId: data.studentId || '',
  studentName: data.studentName || '',
  hostelId: data.hostelId || '',
  hostelName: data.hostelName || '',
  ownerId: data.ownerId || '',
  checkInDate: data.checkInDate instanceof admin.firestore.Timestamp
    ? data.checkInDate.toDate().toISOString()
    : (data.checkInDate || new Date().toISOString()),
  checkOutDate: data.checkOutDate instanceof admin.firestore.Timestamp
    ? data.checkOutDate.toDate().toISOString()
    : (data.checkOutDate || new Date().toISOString()),
  status: data.status || 'pending',
  totalAmount: data.totalAmount || 0,
  durationMonths: data.durationMonths || 1,
  durationDays: data.durationDays || 0,
  bookingType: data.bookingType || 'monthly',
  specialRequests: data.specialRequests || '',
  createdAt: data.createdAt instanceof admin.firestore.Timestamp
    ? data.createdAt.toDate().toISOString()
    : (data.createdAt || new Date().toISOString()),
  roomId: data.roomId || '',
  roomNumber: data.roomNumber || '',
  roomType: data.roomType || '',
  bedsBooked: data.bedsBooked || 1,
});

// Helper for recalculating hostel availability
const recalculateHostelAvailability = async (hostelId) => {
  const roomsSnap = await db.collection('rooms').where('hostelId', '==', hostelId).get();
  let availableRoomsCount = 0;
  roomsSnap.forEach(doc => {
    const data = doc.data();
    if (data.isActive !== false) {
      const availableBeds = data.availableBeds || 0;
      if (availableBeds > 0) {
        availableRoomsCount++;
      }
    }
  });
  await db.collection('hostels').doc(hostelId).update({
    availableRooms: availableRoomsCount,
  });
};

// ─────────────────────────────────────────────────────────────
// POST /api/bookings  — create booking
// ─────────────────────────────────────────────────────────────
router.post('/', verifyToken, async (req, res) => {
  try {
    const docRef = db.collection('bookings').doc();
    const id = docRef.id;

    const bookingData = {
      id,
      studentId: req.user.uid,
      studentName: req.body.studentName || '',
      hostelId: req.body.hostelId || '',
      hostelName: req.body.hostelName || '',
      ownerId: req.body.ownerId || '',
      checkInDate: req.body.checkInDate ? new Date(req.body.checkInDate) : new Date(),
      checkOutDate: req.body.checkOutDate ? new Date(req.body.checkOutDate) : new Date(),
      status: 'pending',
      totalAmount: req.body.totalAmount || 0,
      durationMonths: req.body.durationMonths || 1,
      durationDays: req.body.durationDays || 0,
      bookingType: req.body.bookingType || 'monthly',
      specialRequests: req.body.specialRequests || '',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      roomId: req.body.roomId || '',
      roomNumber: req.body.roomNumber || '',
      roomType: req.body.roomType || '',
      bedsBooked: req.body.bedsBooked || 1,
    };

    await docRef.set(bookingData);

    // Bed count subtraction and availability check is deferred to Owner Confirmation stage

    return res.status(201).json({ id, msg: 'Booking created.' });
  } catch (err) {
    console.error('[POST /bookings]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/bookings/student  — student's bookings
// ─────────────────────────────────────────────────────────────
router.get('/student', verifyToken, async (req, res) => {
  try {
    const snap = await db.collection('bookings')
      .where('studentId', '==', req.user.uid)
      .orderBy('createdAt', 'desc')
      .get();
    return res.json(snap.docs.map(d => buildBooking(d.id, d.data())));
  } catch (err) {
    console.error('[GET /bookings/student]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/bookings/owner  — owner's bookings
// ─────────────────────────────────────────────────────────────
router.get('/owner', verifyToken, async (req, res) => {
  try {
    const snap = await db.collection('bookings')
      .where('ownerId', '==', req.user.uid)
      .orderBy('createdAt', 'desc')
      .get();
    return res.json(snap.docs.map(d => buildBooking(d.id, d.data())));
  } catch (err) {
    console.error('[GET /bookings/owner]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// GET /api/bookings  — all bookings (admin only)
// ─────────────────────────────────────────────────────────────
router.get('/', verifyToken, async (req, res) => {
  try {
    const snap = await db.collection('bookings')
      .orderBy('createdAt', 'desc')
      .get();
    return res.json(snap.docs.map(d => buildBooking(d.id, d.data())));
  } catch (err) {
    console.error('[GET /bookings]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

// ─────────────────────────────────────────────────────────────
// PUT /api/bookings/:id/status  — update booking status
// ─────────────────────────────────────────────────────────────
router.put('/:id/status', verifyToken, async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = ['pending', 'confirmed', 'cancelled', 'completed'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ msg: `Invalid status. Use: ${validStatuses.join(', ')}` });
    }

    const bookingDoc = await db.collection('bookings').doc(req.params.id).get();
    if (!bookingDoc.exists) {
      return res.status(404).json({ msg: 'Booking not found.' });
    }
    const booking = bookingDoc.data();

    // Perform allocations if status changed to confirmed (and was not confirmed before)
    if (status === 'confirmed' && booking.status !== 'confirmed') {
      if (booking.roomId) {
        const roomDoc = await db.collection('rooms').doc(booking.roomId).get();
        if (roomDoc.exists) {
          const room = roomDoc.data();
          const bedsBooked = booking.bedsBooked || 1;
          const capacity = room.capacity || 1;

          const newAvailable = Math.max(0, Math.min(capacity, (room.availableBeds || 0) - bedsBooked));
          const newOccupied = Math.max(0, Math.min(capacity, (room.occupiedBeds || 0) + bedsBooked));

          await db.collection('rooms').doc(booking.roomId).update({
            availableBeds: newAvailable,
            occupiedBeds: newOccupied,
          });

          await recalculateHostelAvailability(booking.hostelId);
        }
      }

      // Create notification
      try {
        const notifId = db.collection('notifications').doc().id;
        await db.collection('notifications').doc(notifId).set({
          id: notifId,
          userId: booking.studentId,
          title: 'Booking Confirmed 🎉',
          body: `Your booking for ${booking.bedsBooked || 1} bed(s) in Room ${booking.roomNumber || ''} at ${booking.hostelName || ''} is confirmed!`,
          type: 'booking_confirmed',
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err) {
        console.error('FCM notification simulation logging error:', err.message);
      }
    }

    await db.collection('bookings').doc(req.params.id).update({ status });
    return res.json({ msg: `Booking ${status}.` });
  } catch (err) {
    console.error('[PUT /bookings/:id/status]', err.message);
    return res.status(500).json({ msg: err.message });
  }
});

module.exports = router;
