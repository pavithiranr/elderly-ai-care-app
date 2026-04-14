// Firebase Messaging Service Worker for CareSync AI
// Handles background push notifications

importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// Initialize Firebase in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyAE3hE0pcYq3iLKbI4xaquQxyHzyOcMsY4",
  authDomain: "caresync-vertex.firebaseapp.com",
  projectId: "caresync-vertex",
  storageBucket: "caresync-vertex.firebasestorage.app",
  messagingSenderId: "631057330468",
  appId: "1:631057330468:web:62aa3e016e18b0833a83b1"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('Received background message:', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
  };
  
  self.registration.showNotification(notificationTitle, notificationOptions);
});
