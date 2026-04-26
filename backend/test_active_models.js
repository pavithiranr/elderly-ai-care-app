const { GoogleGenerativeAI } = require('@google/generative-ai');

async function testModels() {
  const genAI = new GoogleGenerativeAI('AIzaSyBcHymwEDSZ3lEp4LUdMGKQjkAxc8dwqNM');
  const modelsToTest = ['gemini-2.5-flash', 'gemini-2.0-flash-lite', 'gemini-flash-latest', 'gemma-3-1b-it'];
  
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
