const { db, auth } = require('./firebase/admin');

async function seedAdmin() {
  try {
    const adminEmail = 'admin@hods.com';
    const adminPassword = 'Admin@HODS2024';

    console.log(`Starting admin seeding for ${adminEmail}...`);

    let uid;
    try {
      const record = await auth.getUserByEmail(adminEmail);
      uid = record.uid;
      console.log(`Firebase Authentication account already exists. UID: ${uid}`);
      // Update password to ensure it is Admin@HODS2024
      await auth.updateUser(uid, { password: adminPassword });
      console.log('Firebase Authentication password updated successfully.');
    } catch (_) {
      const record = await auth.createUser({
        email: adminEmail,
        password: adminPassword,
        displayName: 'Super Admin',
      });
      uid = record.uid;
      console.log(`Firebase Authentication account created. UID: ${uid}`);
    }

    // Configure Firestore users document
    await db.collection('users').doc(uid).set({
      uid,
      name: 'Super Admin',
      email: adminEmail,
      role: 'admin',
      phone: '',
      profileImageUrl: '',
      isApproved: true,
      approvalStatus: 'approved',
      licenseNumber: '',
      preferredFacilities: [],
      preferredGender: 'mixed',
      budgetMin: 0,
      budgetMax: 0,
      createdAt: new Date().toISOString(),
    });

    console.log('Firestore user document configured successfully with role "admin".');
    console.log('✅ Seeding complete. You can now login as admin!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Error seeding admin:', err.message);
    process.exit(1);
  }
}

seedAdmin();
