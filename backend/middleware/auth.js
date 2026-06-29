const jwt = require('jsonwebtoken');
require('dotenv').config();

/**
 * Middleware: Verify JWT token from Authorization header
 * Attaches { uid, role } to req.user
 */
const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // "Bearer <token>"

  if (!token) {
    return res.status(401).json({ msg: 'Access denied. No token provided.' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // { uid, role }
    next();
  } catch (err) {
    return res.status(401).json({ msg: 'Invalid or expired token.' });
  }
};

/**
 * Middleware: Require admin role
 */
const requireAdmin = (req, res, next) => {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ msg: 'Admin access required.' });
  }
  next();
};

/**
 * Helper: Generate a JWT for a given user
 */
const generateToken = (uid, role) => {
  return jwt.sign({ uid, role }, process.env.JWT_SECRET, { expiresIn: '30d' });
};

module.exports = { verifyToken, requireAdmin, generateToken };
