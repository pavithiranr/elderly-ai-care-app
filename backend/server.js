const express = require('express');
const admin = require('firebase-admin');

// Initialize Firebase Admin using Application Default Credentials.
// On Cloud Run the compute service account is used automatically — no key file needed.
admin.initializeApp();

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 8081;

// ── Health check ─────────────────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({ status: 'ok' }));

// ── Send FCM push to a caregiver ─────────────────────────────────────────────
// POST /notify
// Body: { fcmToken: string, title: string, body: string, type?: string }
app.post('/notify', async (req, res) => {
  const { fcmToken, title, body, type = 'alert' } = req.body;

  if (!fcmToken || !title || !body) {
    return res.status(400).json({ error: 'fcmToken, title and body are required' });
  }

  try {
    const messageId = await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: {
        priority: 'high',
        ttl: 0,
        notification: {
          channelId: 'caresync_alerts',
          notificationPriority: 'PRIORITY_MAX',
          defaultSound: true,
          defaultVibrateTimings: true,
          visibility: 'PUBLIC',
        },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: 'default', badge: 1 } },
      },
      data: { type },
    });

    console.log(`[notify] sent ${type} → ${fcmToken.substring(0, 20)}… messageId=${messageId}`);
    res.json({ success: true, messageId });
  } catch (err) {
    console.error('[notify] FCM error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => console.log(`CareSync backend listening on :${PORT}`));
