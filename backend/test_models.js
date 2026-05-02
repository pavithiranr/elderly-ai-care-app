require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const { GoogleGenerativeAI } = require('@google/generative-ai');

async function testModels() {
  const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
  const modelsToTest = ['gemini-1.5-flash', 'gemini-1.5-flash-001', 'gemini-1.5-flash-002', 'gemini-1.5-flash-latest', 'gemini-1.5-flash-8b', 'gemini-1.5-pro', 'gemini-1.0-pro'];
  
  for (const modelName of modelsToTest) {
    console.log(`Testing ${modelName}...`);
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent('Say exactly one word: test');
      console.log(`✅ Success for ${modelName}: ${result.response.text().trim()}`);
    } catch (err) {
      console.error(`❌ Failed for ${modelName}: ${err.message.substring(0, 150)}`);
    }
    console.log('---');
  }
}

testModels();
