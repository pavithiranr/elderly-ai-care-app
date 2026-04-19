# Web Platform Setup Guide for CareSync AI

## Files Created/Updated

### 1. **firebase-config.js**
- Loads Firebase SDK scripts for web platform
- Must be available before Flutter initialization

### 2. **firebase-messaging-sw.js** 
- Service Worker for push notifications
- Registered in `index.html`
- Handles background messages when app is not active

### 3. **index.html** (Updated)
- Added Firebase SDK script tags
- Added Service Worker registration
- Must load BEFORE `flutter_bootstrap.js`

### 4. **main.dart** (Updated)
- Added error handling for Firebase initialization
- App won't crash if Firebase fails to initialize
- Better logging for debugging

### 5. **debug.html**
- Diagnostic page to check if web setup is correct
- Visit `http://localhost:8888/debug.html` after running app

## Running Flutter Web App

### Development
```bash
# Using Edge browser
flutter run -d edge

# Using Chrome browser (faster for web)
flutter run -d chrome

# On specific port (default: 8080)
flutter run -d web --web-port=8888
```

### Troubleshooting

#### Blank Screen
1. Open DevTools: **F12**
2. Check **Console** tab for errors
3. Check **Network** tab for failed resources
4. Visit `http://localhost:YOUR_PORT/debug.html` to verify setup

#### Firebase Not Initializing
- Verify `firebase_options.dart` has correct credentials
- Check that web app ID is set (currently placeholder)
- Firebase must be configured in Google Cloud Console

#### Service Worker Issues
- Clear browser cache: `Ctrl+Shift+Del`
- Service Worker shows in DevTools > Application > Service Workers
- Check `firebase-messaging-sw.js` exists in web/ folder

## Important Notes

⚠️ **Update Firebase Web App ID**
- In `lib/firebase_options.dart`, update the web appId:
  ```dart
  appId: '1:631057330468:web:YOUR_WEB_APP_ID_HERE'
  ```
- Get this from Firebase Console > Project Settings > Your Apps

⚠️ **CORS Configuration**
- If Firebase calls fail with CORS errors, check Firebase console settings
- Ensure web domain is added to authorized domains

⚠️ **Development vs Production**
- Hot reload may not work perfectly with Service Workers
- Full rebuild recommended: `flutter clean && flutter run`

## File Structure
```
web/
├── index.html                    (main entry point)
├── firebase-config.js            (Firebase SDK loader)
├── firebase-messaging-sw.js      (Service Worker)
├── debug.html                    (diagnostic page)
├── manifest.json
├── favicon.png
└── icons/
    └── Icon-192.png
```

## Next Steps

1. ✅ Firebase SDKs are now loaded
2. ✅ Service Worker is registered
3. ✅ Error handling is improved in main.dart
4. ⚠️ **TODO**: Update Firebase web app ID in `firebase_options.dart`
5. ⚠️ **TODO**: Test on Edge browser and check console for errors
