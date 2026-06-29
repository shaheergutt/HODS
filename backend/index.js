require('dotenv').config();

const express = require('express');
const cors = require('cors');

// ── Initialize Firebase Admin first ──────────────────────────
const { db } = require('./firebase/admin');

// ── Import Routes ─────────────────────────────────────────────
const authRoutes = require('./routes/auth.routes');
const hostelRoutes = require('./routes/hostel.routes');
const bookingRoutes = require('./routes/booking.routes');
const reviewRoutes = require('./routes/review.routes');
const adminRoutes = require('./routes/admin.routes');

const { verifyToken } = require('./middleware/auth');

// ── App Setup ─────────────────────────────────────────────────
const app = express();

app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Request Logger (dev) ──────────────────────────────────────
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.path}`);
  next();
});

// ── Health Check ──────────────────────────────────────────────
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    app: 'HODS Backend',
    project: process.env.FIREBASE_PROJECT_ID,
    timestamp: new Date().toISOString(),
  });
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

// ── API Routes ────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/hostels', hostelRoutes);         // Some public, some protected
app.use('/api/bookings', verifyToken, bookingRoutes);
app.use('/api/reviews', reviewRoutes);          // GET public, POST protected
app.use('/api/admin', adminRoutes);             // All protected + admin role

// ── 404 Handler ───────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ msg: `Route ${req.method} ${req.path} not found.` });
});

// ── Global Error Handler ──────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ msg: 'Internal server error.' });
});

// ── Start Server ──────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log('');
  console.log('╔══════════════════════════════════════════════╗');
  console.log('║          HODS Backend Server Started          ║');
  console.log('╠══════════════════════════════════════════════╣');
  console.log(`║  URL     : http://localhost:${PORT}              ║`);
  console.log(`║  Project : ${process.env.FIREBASE_PROJECT_ID}                    ║`);
  console.log('╠══════════════════════════════════════════════╣');
  console.log('║  Endpoints:                                   ║');
  console.log('║  POST /api/auth/register/student              ║');
  console.log('║  POST /api/auth/register/owner                ║');
  console.log('║  POST /api/auth/login                         ║');
  console.log('║  GET  /api/auth/me                            ║');
  console.log('║  GET  /api/hostels                            ║');
  console.log('║  POST /api/admin/seed  (run once!)            ║');
  console.log('╚══════════════════════════════════════════════╝');
  console.log('');
});
