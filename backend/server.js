require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Firebase Admin.
admin.initializeApp();

const app = express();
app.use(express.json());
app.use(cors({
  origin: 'https://caresync-ai-kv7krtdwfa-ew.a.run.app',
}));

const PORT = process.env.PORT || 8080;

const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });

// Retry helper for 429 errors
const generateWithRetry = async (payload, maxRetries = 2) => {
  let lastError;
  for (let i = 0; i <= maxRetries; i++) {
    try {
      return await model.generateContent(payload);
    } catch (error) {
      lastError = error;
      if (error.message.includes('429') && i < maxRetries) {
        console.warn(`[gemini] 429 detected, retrying in ${2 * (i + 1)}s...`);
        await new Promise(resolve => setTimeout(resolve, 2000 * (i + 1)));
        continue;
      }
      throw error;
    }
  }
  throw lastError;
};

// ── Health check ─────────────────────────────────────────────────────────────
app.get('/health', (_, res) => res.json({ status: 'ok' }));
app.get('/health', (_, res) => res.json({ status: 'ok' }));

// ── Chat companion for elderly users ────────────────────────────────────────
// POST /gemini/chat
// Body: { message: string, history: Array<{role: 'user'|'model', text: string}> }
app.post('/gemini/chat', async (req, res) => {
  try {
    const { message, history = [] } = req.body;

    if (!message) {
      return res.status(400).json({ error: 'message is required' });
    }

    // Build conversation contents from history
    const contents = [];
    for (const turn of history) {
      contents.push({
        role: turn.role === 'model' ? 'model' : 'user',
        parts: [{ text: turn.text }],
      });
    }
    // Append the new user message
    contents.push({
      role: 'user',
      parts: [{ text: message }],
    });

    const systemPrompt = 'You are CareSync, a warm, patient, and friendly AI companion for elderly users. '
      + 'Keep responses concise (2-3 sentences max), use simple language, '
      + 'and be encouraging. Gently remind users about health habits when relevant. '
      + 'Never give medical diagnoses. If the user seems distressed, suggest contacting their caregiver.';

    const result = await generateWithRetry({
      contents,
      generationConfig: {
        temperature: 0.75,
        maxOutputTokens: 2048,
        topP: 0.9,
      },
    });

    const reply = result.response.text();
    console.log(`[gemini/chat] generated reply: ${reply.substring(0, 50)}...`);
    res.json({ reply });
  } catch (error) {
    console.error('[gemini/chat] error:', error.message);
    console.error('[gemini/chat] full error:', error);
    if (error.response) {
      console.error('[gemini/chat] response status:', error.response.status);
      console.error('[gemini/chat] response body:', error.response.data);
    }
    res.status(500).json({ error: error.message });
  }
});

// ── Health summary for elderly dashboard ─────────────────────────────────────
// POST /gemini/summary
// Body: { recentEvents: Array<string> }
app.post('/gemini/summary', async (req, res) => {
  try {
    const { recentEvents = [] } = req.body;

    if (!Array.isArray(recentEvents) || recentEvents.length === 0) {
      return res.status(400).json({ error: 'recentEvents array is required and must not be empty' });
    }

    const eventsList = recentEvents.join('\n• ');
    const prompt = `TASK: Write a warm 1-2 sentence health update addressed directly to the elderly person themselves.
STRICT RULES:
- Write in second person (e.g. "You're feeling..." or "Your pain level...")
- Do NOT begin with greetings like "Good morning", "Hello", "Hi", or any salutation
- Be warm, encouraging, and supportive in tone
- Use only the data listed below — do not invent or assume details
- End with a brief positive note or gentle reminder if relevant

PATIENT DATA:
• ${eventsList}

PERSONAL HEALTH UPDATE (start directly with "You", no greeting):`;

    const result = await generateWithRetry({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.5,
        maxOutputTokens: 500,
        topP: 0.9,
      },
    });

    const summary = result.response.text().trim();
    console.log(`[gemini/summary] generated: ${summary.substring(0, 50)}...`);
    res.json({ summary });
  } catch (error) {
    console.error('[gemini/summary] error:', error.message);
    console.error('[gemini/summary] full error:', error);
    if (error.response) {
      console.error('[gemini/summary] response status:', error.response.status);
      console.error('[gemini/summary] response body:', error.response.data);
    }
    res.status(500).json({ error: error.message });
  }
});

// ── Daily health summary for caregiver report ────────────────────────────────
// POST /gemini/daily-summary
// Body: { patientName: string, events: Array<string> }
app.post('/gemini/daily-summary', async (req, res) => {
  try {
    const { patientName, events = [] } = req.body;

    if (!patientName || !Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ error: 'patientName and events array are required' });
    }

    const eventsList = events.join('\n• ');
    const prompt = `TASK: Write a 2-3 sentence daily health report for a caregiver about their elderly patient.
STRICT RULES:
- Start directly with the patient's health condition (e.g. "The patient..." or "${patientName} is...")
- Do NOT begin with greetings, salutations, or "Good morning/afternoon/evening"
- Mention mood, pain level, and medication adherence from the data provided
- Flag any SOS alerts if present
- Use only the data below — do not invent or assume anything

PATIENT DATA FOR TODAY:
• ${eventsList}

DAILY HEALTH REPORT (begin with patient status, no greeting):`;

    const result = await generateWithRetry({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.65,
        maxOutputTokens: 500,
        topP: 0.9,
      },
    });

    const summary = result.response.text().trim();
    console.log(`[gemini/daily-summary] generated: ${summary.substring(0, 50)}...`);
    res.json({ summary });
  } catch (error) {
    console.error('[gemini/daily-summary] error:', error.message);
    console.error('[gemini/daily-summary] full error:', error);
    if (error.response) {
      console.error('[gemini/daily-summary] response status:', error.response.status);
      console.error('[gemini/daily-summary] response body:', error.response.data);
    }
    res.status(500).json({ error: error.message });
  }
});

// ── Agentic 3-step care analysis ────────────────────────────────────────────
// POST /gemini/agentic-analysis
// Body: { events: Array<string> }
app.post('/gemini/agentic-analysis', async (req, res) => {
  try {
    const { events = [] } = req.body;

    if (!Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ error: 'events array is required and must not be empty' });
    }

    const eventsList = events.join('\n• ');
    const prompt = `You are a clinical AI assistant. Analyse the patient data below using a 3-step reasoning chain.
PATIENT DATA:
• ${eventsList}

Format your response exactly like this:
---SIGNALS---
(Summarize Mood, Pain, Medications, SOS alerts, and Key concern)

---RISK---
(State Risk Level, Flags, and Reasoning)

---PLAN---
(2-3 actionable steps starting with verbs)

RULES: Use ONLY the data provided. No markdown bolding. No greetings.`;

    const result = await generateWithRetry({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 4096,
      },
    });

    const raw = result.response.text();
    console.log(`[gemini/agentic-analysis] raw response length: ${raw.length}`);

    // Robust parsing using text markers
    const extractSection = (text, startMarker, endMarker) => {
      const start = text.indexOf(startMarker);
      if (start === -1) return "";
      const end = endMarker ? text.indexOf(endMarker, start + startMarker.length) : text.length;
      return text.substring(start + startMarker.length, end === -1 ? text.length : end).trim();
    };

    const signals = extractSection(raw, "---SIGNALS---", "---RISK---");
    const riskAssessment = extractSection(raw, "---RISK---", "---PLAN---");
    const carePlan = extractSection(raw, "---PLAN---", null);

    if (!signals || !riskAssessment || !carePlan) {
      console.warn(`[gemini/agentic-analysis] Warning: sections missing. Raw response: ${raw}`);
    }

    res.json({ signals, riskAssessment, carePlan });
  } catch (error) {
    console.error('[gemini/agentic-analysis] error:', error.message);
    console.error('[gemini/agentic-analysis] full error:', error);
    if (error.response) {
      console.error('[gemini/agentic-analysis] response status:', error.response.status);
      console.error('[gemini/agentic-analysis] response body:', error.response.data);
    }
    res.status(500).json({ error: error.message });
  }
});

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
