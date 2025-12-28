const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// =========================================================
// 1. API: Send Custom Notification (For your Admin App)
// =========================================================
exports.sendCustomNotification = functions.https.onRequest(async (req, res) => {
  // CORS support so your Flutter app can talk to this function
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }

  try {
    // Get data sent from Flutter
    const { title, body, image, universityId } = req.body;

    // Construct the Notification Payload
    const message = {
      notification: {
        title: title || "New Announcement",
        body: body || "Check the app for details.",
      },
      android: {
        notification: {
          image: image || null, // Handles the Base64/URL image
        },
      },
      apns: {
        payload: {
          aps: {
            "mutable-content": 1, // Required for images on iOS
          },
        },
        fcm_options: {
          image: image || null,
        },
      },
      // This sends to the topic "university_123" (everyone in that univ)
      topic: `university_${universityId}`, 
    };

    // 1. Send the Push Notification
    await admin.messaging().send(message);

    // 2. Save to Firestore Database (So it shows in the "Notification Page" history)
    await admin.firestore().collection("notifications").add({
      title: title,
      body: body,
      type: "custom",
      universityId: universityId,
      imageUrl: image || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });

    res.status(200).json({ success: true, message: "Sent successfully!" });
  } catch (error) {
    console.error("Error sending notification:", error);
    res.status(500).json({ error: error.message });
  }
});

// =========================================================
// 2. TRIGGER: Timetable Updates (Automated)
// =========================================================
// This watches the "timetables" collection. If a doc is updated, it notifies students.
exports.onTimetableUpdate = functions.firestore
  .document("timetables/{timetableId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const universityId = newData.universityId;
    const courseName = newData.courseName || "Class";

    const payload = {
      notification: {
        title: "Timetable Updated 📅",
        body: `The schedule for ${courseName} has changed.`,
      },
      topic: `university_${universityId}`,
    };

    // Send Push
    await admin.messaging().send(payload);

    // Save to History
    return admin.firestore().collection("notifications").add({
      title: "Timetable Updated",
      body: `The schedule for ${courseName} has changed.`,
      type: "timetable",
      universityId: universityId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });
  });

// =========================================================
// 3. TRIGGER: Lost & Found Posts (Automated)
// =========================================================
// This watches the "lost_found" collection. If a new post is added, it notifies everyone.
exports.onLostAndFoundPost = functions.firestore
  .document("lost_found/{postId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    // Assuming your data has fields: itemName, type ('lost' or 'found'), universityId
    const isLost = data.type === "lost"; 

    const payload = {
      notification: {
        title: isLost ? "Lost Item Reported 🔍" : "Item Found! 🎉",
        body: `Someone posted about: ${data.itemName || "an item"}.`,
      },
      topic: `university_${data.universityId}`,
    };

    await admin.messaging().send(payload);

    return admin.firestore().collection("notifications").add({
      title: payload.notification.title,
      body: payload.notification.body,
      type: "lostAndFound",
      universityId: data.universityId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });
  });

// =========================================================
// TRIGGER: Marketplace Item Created (Automated)
// Notify all students in the university via topic and save history
// =========================================================
exports.onMarketplaceItemCreate = functions.firestore
  .document('universities/{uniId}/marketplace_items/{itemId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const uniId = context.params.uniId;
    const title = data.title || 'New Item Listed';
    const price = data.price != null ? String(data.price) : '';

    const payload = {
      notification: {
        title: 'New Marketplace Item 🛍️',
        body: `${title}${price ? ' for ' + price : ''}`,
      },
      topic: `university_${uniId}`,
    };

    // Send push to the university topic
    try {
      await admin.messaging().send(payload);
    } catch (err) {
      console.error('Failed to send marketplace topic message', err);
    }

    // Save notification to Firestore history
    try {
      return admin.firestore().collection('notifications').add({
        title: 'New Item Listed',
        body: `${title}${price ? ' for ' + price : ''}`,
        type: 'marketplace',
        universityId: uniId,
        data: { postId: context.params.itemId },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      });
    } catch (err) {
      console.error('Failed to write marketplace notification doc', err);
      return null;
    }
  });

// =========================================================
// TRIGGER: Subscribe FCM Token to University Topic
// When a token document is created under `users/{userId}/fcmTokens/{token}`
// subscribe that token to `university_{uniId}` topic so topic pushes reach devices.
// =========================================================
exports.onFcmTokenCreate = functions.firestore
  .document('users/{userId}/fcmTokens/{tokenId}')
  .onCreate(async (snap, context) => {
    const tokenId = context.params.tokenId; // tokenId is the token string (we store token as doc ID)
    const userId = context.params.userId;

    try {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.warn('User doc not found for token subscription', userId);
        return null;
      }
      const uniId = userDoc.data().universityId || userDoc.data().uniId || null;
      if (!uniId) {
        console.warn('No university id found for user', userId);
        return null;
      }

      const topic = `university_${uniId}`;
      try {
        await admin.messaging().subscribeToTopic([tokenId], topic);
        console.log(`Subscribed token to topic ${topic}`);
      } catch (err) {
        console.error('Failed to subscribe token to topic', err);
      }
    } catch (err) {
      console.error('Error in onFcmTokenCreate', err);
    }

    return null;
  });