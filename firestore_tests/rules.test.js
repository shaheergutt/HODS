const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

let testEnv;
const projectId = 'hods-test-project';

describe('Firestore Security Rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: projectId,
      firestore: {
        rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  // Helper to get database context with custom auth
  function getDb(auth) {
    if (auth) {
      return testEnv.authenticatedContext(auth.uid, auth.claims || {}).firestore();
    }
    return testEnv.unauthenticatedContext().firestore();
  }

  // Helper to bypass rules and seed data (runs as Admin / system)
  async function runWithRulesDisabled(callback) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await callback(adminDb);
    });
  }

  // Helper to seed a user document to the /users collection
  // (needed because rules check getUserData() via get() to look up role)
  async function seedUser(uid, role) {
    await runWithRulesDisabled(async (db) => {
      await db.collection('users').doc(uid).set({
        uid: uid,
        name: `Test ${role}`,
        email: `${role}@test.com`,
        role: role,
      });
    });
  }

  // ── USERS ───────────────────────────────────────────────────────
  describe('users collection', () => {
    it('allows anyone authenticated to read users', async () => {
      const db = getDb({ uid: 'student1' });
      await assertSucceeds(db.collection('users').doc('userA').get());
    });

    it('denies unauthenticated to read users', async () => {
      const db = getDb(null);
      await assertFails(db.collection('users').doc('userA').get());
    });

    it('allows user to write their own user doc', async () => {
      const db = getDb({ uid: 'student1' });
      await assertSucceeds(db.collection('users').doc('student1').set({ role: 'student' }));
    });

    it('denies user to write another user doc', async () => {
      const db = getDb({ uid: 'student1' });
      await assertFails(db.collection('users').doc('student2').set({ role: 'student' }));
    });

    it('allows admin to update any user doc', async () => {
      await seedUser('admin1', 'admin');
      await seedUser('student1', 'student');
      const db = getDb({ uid: 'admin1' });
      await assertSucceeds(db.collection('users').doc('student1').update({ name: 'Updated Student' }));
    });
  });

  // ── HOSTELS ──────────────────────────────────────────────────────
  describe('hostels collection', () => {
    it('allows anyone (even unauthenticated) to read hostels', async () => {
      const db = getDb(null);
      await assertSucceeds(db.collection('hostels').get());
    });

    it('allows hostel owner to create a hostel', async () => {
      await seedUser('owner1', 'owner');
      const db = getDb({ uid: 'owner1' });
      await assertSucceeds(db.collection('hostels').doc('hostel1').set({
        name: 'Grand Hostel',
        ownerId: 'owner1',
        isApproved: false,
      }));
    });

    it('denies student to create a hostel', async () => {
      await seedUser('student1', 'student');
      const db = getDb({ uid: 'student1' });
      await assertFails(db.collection('hostels').doc('hostel1').set({
        name: 'Grand Hostel',
        ownerId: 'student1',
      }));
    });

    it('allows owner to update their own hostel', async () => {
      await seedUser('owner1', 'owner');
      await runWithRulesDisabled(async (db) => {
        await db.collection('hostels').doc('hostel1').set({ ownerId: 'owner1', name: 'Grand' });
      });

      const db = getDb({ uid: 'owner1' });
      await assertSucceeds(db.collection('hostels').doc('hostel1').update({ name: 'Grand II' }));
    });

    it('denies owner to update another owners hostel', async () => {
      await seedUser('owner1', 'owner');
      await runWithRulesDisabled(async (db) => {
        await db.collection('hostels').doc('hostel1').set({ ownerId: 'owner2', name: 'Grand' });
      });

      const db = getDb({ uid: 'owner1' });
      await assertFails(db.collection('hostels').doc('hostel1').update({ name: 'Grand II' }));
    });
  });

  // ── ROOMS ────────────────────────────────────────────────────────
  describe('rooms collection', () => {
    it('allows anyone to read rooms', async () => {
      const db = getDb(null);
      await assertSucceeds(db.collection('rooms').get());
    });

    it('allows hostel owner to create/update rooms', async () => {
      await seedUser('owner1', 'owner');
      const db = getDb({ uid: 'owner1' });
      await assertSucceeds(db.collection('rooms').doc('room1').set({
        roomNumber: '101',
        hostelId: 'hostel1',
      }));
    });

    it('denies student to write rooms', async () => {
      await seedUser('student1', 'student');
      const db = getDb({ uid: 'student1' });
      await assertFails(db.collection('rooms').doc('room1').set({
        roomNumber: '101',
      }));
    });
  });

  // ── BOOKINGS ─────────────────────────────────────────────────────
  describe('bookings collection', () => {
    it('allows student to read their own bookings', async () => {
      await runWithRulesDisabled(async (db) => {
        await db.collection('bookings').doc('b1').set({ studentId: 'student1', ownerId: 'owner1' });
      });

      const db = getDb({ uid: 'student1' });
      await assertSucceeds(db.collection('bookings').doc('b1').get());
    });

    it('denies student to read other students bookings', async () => {
      await runWithRulesDisabled(async (db) => {
        await db.collection('bookings').doc('b1').set({ studentId: 'student2', ownerId: 'owner1' });
      });

      const db = getDb({ uid: 'student1' });
      await assertFails(db.collection('bookings').doc('b1').get());
    });

    it('allows owner to read bookings for their hostels', async () => {
      await runWithRulesDisabled(async (db) => {
        await db.collection('bookings').doc('b1').set({ studentId: 'student1', ownerId: 'owner1' });
      });

      const db = getDb({ uid: 'owner1' });
      await assertSucceeds(db.collection('bookings').doc('b1').get());
    });
  });

  // ── COMPLAINTS ───────────────────────────────────────────────────
  describe('complaints collection', () => {
    it('allows student to create complaints if they are the studentId', async () => {
      const db = getDb({ uid: 'student1' });
      await assertSucceeds(db.collection('complaints').doc('c1').set({
        studentId: 'student1',
        title: 'Water leak',
      }));
    });

    it('denies student to create complaints for another studentId', async () => {
      const db = getDb({ uid: 'student1' });
      await assertFails(db.collection('complaints').doc('c1').set({
        studentId: 'student2',
        title: 'Water leak',
      }));
    });

    it('allows owner to read complaints assigned to them (hostelOwnerId)', async () => {
      await runWithRulesDisabled(async (db) => {
        await db.collection('complaints').doc('c1').set({ studentId: 'student1', hostelOwnerId: 'owner1' });
      });

      const db = getDb({ uid: 'owner1' });
      await assertSucceeds(db.collection('complaints').doc('c1').get());
    });
  });

  // ── USER PREFERENCES ──────────────────────────────────────────────
  describe('user_preferences collection', () => {
    it('allows student to read/write their own user_preferences', async () => {
      const db = getDb({ uid: 'student1' });
      await assertSucceeds(db.collection('user_preferences').doc('student1').set({ maxBudget: 15000 }));
      await assertSucceeds(db.collection('user_preferences').doc('student1').get());
    });

    it('denies student to access another user_preferences', async () => {
      const db = getDb({ uid: 'student1' });
      await assertFails(db.collection('user_preferences').doc('student2').get());
    });
  });

  // ── ROOMMATE MATCHING ──────────────────────────────────────────────
  describe('roommate_profiles & roommate_requests', () => {
    it('allows students to read roommate profiles', async () => {
      const db = getDb({ uid: 'student1' });
      await assertSucceeds(db.collection('roommate_profiles').get());
    });

    it('allows student to write their own profile', async () => {
      const db = getDb({ uid: 'student1' });
      await assertSucceeds(db.collection('roommate_profiles').doc('student1').set({ bio: 'Quiet student' }));
    });

    it('denies student to write another roommate profile', async () => {
      const db = getDb({ uid: 'student1' });
      await assertFails(db.collection('roommate_profiles').doc('student2').set({ bio: 'Quiet student' }));
    });
  });

  // ── CHATS & MESSAGES ─────────────────────────────────────────────
  describe('chats & messages collections', () => {
    it('allows student/owner to read chats they are part of', async () => {
      await runWithRulesDisabled(async (db) => {
        await db.collection('chats').doc('chat1').set({ studentId: 'student1', ownerId: 'owner1' });
      });

      const dbStudent = getDb({ uid: 'student1' });
      await assertSucceeds(dbStudent.collection('chats').doc('chat1').get());

      const dbOwner = getDb({ uid: 'owner1' });
      await assertSucceeds(dbOwner.collection('chats').doc('chat1').get());
    });

    it('denies third party to read chats', async () => {
      await runWithRulesDisabled(async (db) => {
        await db.collection('chats').doc('chat1').set({ studentId: 'student1', ownerId: 'owner1' });
      });

      const dbStranger = getDb({ uid: 'student2' });
      await assertFails(dbStranger.collection('chats').doc('chat1').get());
    });

    it('allows chat members to read/write messages', async () => {
      await runWithRulesDisabled(async (db) => {
        await db.collection('chats').doc('chat1').set({ studentId: 'student1', ownerId: 'owner1' });
      });

      const dbStudent = getDb({ uid: 'student1' });
      await assertSucceeds(dbStudent.collection('chats').doc('chat1').collection('messages').doc('msg1').set({
        senderId: 'student1',
        text: 'hello',
      }));
    });
  });

  // ── SYSTEM METADATA COLLECTIONS ──────────────────────────────────
  describe('system collections: cities, amenities, universities, knowledge', () => {
    it('allows authenticated users to read system collections', async () => {
      const db = getDb({ uid: 'student1' });
      await assertSucceeds(db.collection('cities').get());
      await assertSucceeds(db.collection('amenities').get());
      await assertSucceeds(db.collection('universities').get());
      await assertSucceeds(db.collection('knowledge').get());
    });

    it('denies non-authenticated to read system collections', async () => {
      const db = getDb(null);
      await assertFails(db.collection('cities').get());
    });

    it('denies regular users to write system collections', async () => {
      const db = getDb({ uid: 'student1' });
      await assertFails(db.collection('cities').doc('lahore').set({ name: 'Lahore' }));
    });

    it('allows admins to write system collections', async () => {
      await seedUser('admin1', 'admin');
      const db = getDb({ uid: 'admin1' });
      await assertSucceeds(db.collection('cities').doc('lahore').set({ name: 'Lahore' }));
    });
  });
});
