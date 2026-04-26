async function fetchModels() {
  try {
    const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models?key=AIzaSyBcHymwEDSZ3lEp4LUdMGKQjkAxc8dwqNM&pageToken=CiRtb2RlbHMvdmVvLTMuMS1mYXN0LWdlbmVyYXRlLXByZXZpZXc=');
    const data = await response.json();
    console.log(JSON.stringify(data, null, 2));
  } catch (err) {
    console.error(err);
  }
}
fetchModels();
