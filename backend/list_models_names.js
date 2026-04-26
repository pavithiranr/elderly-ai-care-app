async function fetchModels() {
  try {
    const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models?key=AIzaSyBcHymwEDSZ3lEp4LUdMGKQjkAxc8dwqNM&pageSize=100');
    const data = await response.json();
    const generateModels = data.models.filter(m => m.supportedGenerationMethods && m.supportedGenerationMethods.includes('generateContent'));
    console.log(generateModels.map(m => m.name).join('\\n'));
  } catch (err) {
    console.error(err);
  }
}
fetchModels();
