require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const { GoogleGenerativeAI } = require('@google/generative-ai');

async function testTruncation() {
  const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

  const eventsList = "Patient reports feeling great.\\nPain level 7.\\nMedication taken: 0/8.\\nNo SOS alerts.";
  const prompt = `You are a clinical AI assistant. Analyse the patient data below using a 3-step reasoning chain.
PATIENT DATA:
• ${eventsList}

Analyze the data and return a JSON object with exactly three keys: "signals", "riskAssessment", and "carePlan".
- "signals" should be a multi-line string summarizing Mood, Pain, Medications, SOS alerts, and Key concern.
- "riskAssessment" should be a multi-line string stating Risk Level, Flags, and Reasoning.
- "carePlan" should be a 2-3 sentence string with actionable steps.`;

  try {
    const result = await model.generateContent({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.3,
        responseMimeType: "application/json",
      },
    });
    
    console.log("Finish Reason:", result.response.candidates[0].finishReason);
    console.log("Raw Response:");
    console.log(result.response.text());
  } catch (err) {
    console.error("Error:", err);
  }
}

testTruncation();
