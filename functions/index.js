const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

// ── Shared helper ─────────────────────────────────────────────────────────────

async function sendFcmToCaregiver(caregiverId, title, body, data = {}) {
  const caregiverSnap = await db.collection('caregivers').doc(caregiverId).get();
  if (!caregiverSnap.exists) {
    console.warn(`[FCM] caregiver ${caregiverId} not found`);
    return;
  }

  const fcmToken = caregiverSnap.data().fcmToken;
  if (!fcmToken) {
    console.warn(`[FCM] caregiver ${caregiverId} has no FCM token`);
    return;
  }

  await admin.messaging().send({
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
    data,
  });

  console.log(`[FCM] sent "${title}" to caregiver ${caregiverId}`);
}

// ── Function 1: onSOSAlert ────────────────────────────────────────────────────
// Triggers when elderly taps SOS — elderly/{elderlyId}/sos_alerts/{alertId}

exports.onSOSAlert = functions.firestore
  .document('elderly/{elderlyId}/sos_alerts/{alertId}')
  .onCreate(async (snap, context) => {
    const { elderlyId } = context.params;

    const elderlySnap = await db.collection('elderly').doc(elderlyId).get();
    if (!elderlySnap.exists) {
      console.warn(`[onSOSAlert] elderly ${elderlyId} not found`);
      return;
    }

    const { name = 'Your patient', caregiverId } = elderlySnap.data();
    if (!caregiverId) {
      console.warn(`[onSOSAlert] elderly ${elderlyId} has no linked caregiver`);
      return;
    }

    await sendFcmToCaregiver(
      caregiverId,
      `🚨 SOS Alert — ${name}`,
      `${name} needs help immediately!`,
      { type: 'sos', elderlyId },
    );
  });

// ── Function 2: onConcerningCheckin ──────────────────────────────────────────
// Triggers on daily_checkins — fires if pain >= 7/10 OR moodScore >= 4 (Not Great)

exports.onConcerningCheckin = functions.firestore
  .document('elderly/{elderlyId}/daily_checkins/{checkinId}')
  .onCreate(async (snap, context) => {
    const { elderlyId } = context.params;
    const data = snap.data();

    const painScore = data.painScore ?? 0;
    const moodScore = data.moodScore ?? 0;

    const isConcerning = painScore >= 7 || moodScore >= 4;
    if (!isConcerning) return;

    const elderlySnap = await db.collection('elderly').doc(elderlyId).get();
    if (!elderlySnap.exists) return;

    const { name = 'Your patient', caregiverId } = elderlySnap.data();
    if (!caregiverId) return;

    let body;
    if (painScore >= 7 && moodScore >= 4) {
      body = `Pain level ${painScore}/10 and low mood detected. Please check in.`;
    } else if (painScore >= 7) {
      body = `Pain level ${painScore}/10 detected. Please check in.`;
    } else {
      body = `${name} is not feeling great. Please check in.`;
    }

    await sendFcmToCaregiver(
      caregiverId,
      `⚠️ Health Alert — ${name}`,
      body,
      { type: 'checkin', elderlyId },
    );
  });
