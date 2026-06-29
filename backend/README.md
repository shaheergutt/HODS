# HODS Backend Setup Guide

## Prerequisites
- Node.js 18+ installed
- Firebase project: `hods-2810`

---

## Step 1: Download Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project **hods-2810**
3. Click **Project Settings** (gear icon) → **Service accounts** tab
4. Click **"Generate new private key"** → **"Generate key"**
5. A JSON file will be downloaded — rename it to **`serviceAccountKey.json`**
6. Place it in `d:\fyp1\backend\serviceAccountKey.json`

> ⚠️ NEVER commit this file to git! It's already in `.gitignore`.

---

## Step 2: Enable Email/Password Auth in Firebase Console

1. Firebase Console → **Authentication** → **Sign-in method**
2. Click **Email/Password** → Toggle **Enable** → **Save**

---

## Step 3: Set Firestore Security Rules

Go to Firebase Console → **Firestore Database** → **Rules** → paste:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Backend has full admin access via Admin SDK (bypasses these rules)
    // These rules are for any direct client reads (optional)
    match /{document=**} {
      allow read, write: if false; // All access via backend only
    }
  }
}
```

---

## Step 4: Install Dependencies & Start Backend

```bash
cd d:\fyp1\backend
npm install
npm run dev
```

You should see:
```
╔══════════════════════════════════════════════╗
║          HODS Backend Server Started          ║
╠══════════════════════════════════════════════╣
║  URL     : http://localhost:5000              ║
║  Project : hods-2810                         ║
╚══════════════════════════════════════════════╝
```

---

## Step 5: Seed the Admin Account (Run Once!)

```bash
# In a new terminal, call the seed endpoint:
curl -X POST http://localhost:5000/api/admin/seed \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ADMIN_JWT"
```

Or use a REST client (Postman/Insomnia) to POST to:
`http://localhost:5000/api/admin/seed`

**Admin credentials:**
- Email: `admin@hods.com`
- Password: `Admin@HODS2024`

---

## Step 6: Run Flutter App

The Flutter app connects to:
- **Android Emulator**: `http://10.0.2.2:5000` ✅
- **Real device (same WiFi)**: Change `baseUrl` in `api_service.dart` to your PC's IP: `http://192.168.x.x:5000`
- **iOS Simulator**: `http://localhost:5000`

```bash
cd d:\fyp1
flutter run
```

---

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/register/student` | ❌ | Register student |
| POST | `/api/auth/register/owner` | ❌ | Register owner |
| POST | `/api/auth/login` | ❌ | Login (get JWT) |
| GET | `/api/auth/me` | ✅ | Get current user |
| PUT | `/api/auth/profile` | ✅ | Update profile |
| GET | `/api/hostels` | ❌ | List all approved hostels |
| POST | `/api/hostels` | ✅ Owner | Create hostel |
| GET | `/api/hostels/:id` | ❌ | Get hostel by ID |
| PUT | `/api/hostels/:id` | ✅ Owner | Update hostel |
| DELETE | `/api/hostels/:id` | ✅ Owner | Delete hostel |
| GET | `/api/hostels/owner` | ✅ Owner | Get owner's hostels |
| POST | `/api/bookings` | ✅ | Create booking |
| GET | `/api/bookings/student` | ✅ | Student's bookings |
| GET | `/api/bookings/owner` | ✅ | Owner's bookings |
| PUT | `/api/bookings/:id/status` | ✅ Owner | Confirm/cancel booking |
| POST | `/api/reviews` | ✅ | Add review |
| GET | `/api/reviews/:hostelId` | ❌ | Get hostel reviews |
| GET | `/api/admin/stats` | ✅ Admin | Dashboard stats |
| GET | `/api/admin/owners/pending` | ✅ Admin | Pending owners |
| PUT | `/api/admin/owners/:uid/approve` | ✅ Admin | Approve owner |
| DELETE | `/api/admin/users/:uid` | ✅ Admin | Delete user |
| POST | `/api/admin/seed` | ✅ Admin | Seed admin account |
