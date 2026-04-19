================================================================================
                        CARESYNC AI - PROJECT README
================================================================================

AI-Powered Elderly Care Companion

Building peace of mind through real-time health monitoring, AI insights, and 
intelligent caregiving

Built for the Project 2030 - MyAI Future Hackathon - Track 3: Vital Signs 
(Healthcare & Wellbeing)
Organised by: GDG On Campus UTM

================================================================================
PROJECT OVERVIEW
================================================================================

CareSync AI is a two-sided mobile and web application that connects elderly users 
with their family caregivers through real-time health monitoring, AI-generated 
insights, and intelligent emergency response. The app uses Gemini 2.0 Flash to 
analyze health patterns and provide actionable recommendations to caregivers.

FOR THE ELDERLY:
- Role-Based Onboarding - Separate flows for elderly and caregivers
- Daily Health Check-ins - Track mood, pain level, and general wellness
- Smart Medication Tracking - Reminder system with FDA drug information via 
  openFDA API
- Emergency SOS Button - One-tap crisis alerts with pulsing heartbeat animation
- AI Companion Chat - Powered by Gemini 2.0 for health advice and emotional support
- Calendar Adherence Tracking - Visual medication history and completion calendar
- Secure Re-login - Access via Name + Date of Birth (alternative to password)
- Accessibility Settings - Large text (16px+), high contrast mode, colorblind-
  friendly palette

FOR CAREGIVERS:
- Real-time Health Dashboard - Multi-patient carousel view with live medication 
  adherence
- AI-Generated Health Summary - Gemini analyzes patient data and creates weekly 
  summaries
- 3-Step AI Deep Analysis:
  * Signal Extractor - Identifies health patterns and anomalies
  * Risk Assessor - Evaluates health risk levels
  * Care Planner - Recommends personalized interventions
- Intelligent Alerts - Severity-coded notifications (CRITICAL/WARNING/NORMAL/INFO)
- Push Notifications - Real-time alerts for SOS emergencies and critical health 
  changes
- Weekly Trend Reports - AI-generated insights with fl_chart bar charts
- Multi-Patient Management - Manage multiple elderly relatives via carousel
- Dark Mode Support - Accessible, eye-friendly interface

================================================================================
TECH STACK
================================================================================

Frontend:
  Flutter 3.29 + Dart 3.7
  Cross-platform mobile & web UI (Android, iOS, Web)

Database:
  Cloud Firestore
  Real-time data sync for health metrics, medications, alerts

Authentication:
  Firebase Auth
  Secure user login & session management

AI Core:
  Google Gemini 2.0 Flash
  Health analysis, summaries, chat companion, deep analysis

AI Workflows:
  Firebase Genkit
  Agentic AI pipelines for health analysis (planned)

Deployment:
  Google Cloud Run
  Backend service deployment (planned for AI pipelines)

Push Notifications:
  Firebase Cloud Messaging
  SOS alerts, emergency notifications

Local Notifications:
  flutter_local_notifications
  Local reminder alerts

Charts & Analytics:
  fl_chart
  Weekly health trend visualization

APIs:
  openFDA REST API
  Drug information, side effects, indications

Navigation:
  go_router
  Type-safe declarative routing + role-based redirects

State Management:
  Provider
  Reactive state management

PDF Generation:
  pdf
  Generate health reports as PDF

Localization:
  intl
  Date formatting, internationalization

Local Storage:
  shared_preferences
  Persistent user preferences

Fonts:
  google_fonts
  Inter typeface for UI consistency

SVG Support:
  flutter_svg
  Vector graphics rendering

Sharing:
  share_plus
  Native file sharing (Android, iOS)

Input:
  pinput
  OTP/PIN input UI component

Sensors:
  sensors_plus
  Accelerometer data (gesture detection)

================================================================================
HOW TO SETUP
================================================================================

PREREQUISITES:

Before you start, make sure you have:
- Flutter 3.29+ (Install Guide: https://docs.flutter.dev/get-started/install)
- Dart 3.7+ (comes with Flutter)
- Git - For version control
- Android Studio or VS Code with Flutter extension
- Android Emulator or Physical Device (or use Chrome for web)
- Firebase CLI - npm install -g firebase-tools (optional, for Firebase setup)
- Google Gemini API Key - From https://aistudio.google.com/app/apikey

STEP 1: CLONE THE REPOSITORY

  git clone https://github.com/pavithiranr/elderly-ai-care-app.git
  cd elderly-ai-care-app

STEP 2: INSTALL DEPENDENCIES

  flutter pub get

STEP 3: CREATE .ENV FILE

Create a .env file in the project root with your Gemini API key:

  # .env
  GEMINI_API_KEY=your_actual_gemini_api_key_here

Get your API key:
1. Visit https://aistudio.google.com/app/apikey
2. Click "Create API Key"
3. Select your Google project or create a new one
4. Copy the API key and paste it in .env

STEP 4: FIREBASE SETUP

Option A: Use Existing Firebase Configuration (Recommended for Testing)
  The app includes pre-configured Firebase credentials. Skip to Step 5.

Option B: Setup Your Own Firebase Project

  # Install Firebase CLI
  npm install -g firebase-tools

  # Login to Firebase
  firebase login

  # Configure Flutter for your Firebase project
  flutterfire configure

This will:
- Create Firebase project in your Google Cloud Console
- Generate google-services.json (Android) → android/app/
- Generate GoogleService-Info.plist (iOS) → ios/Runner/
- Create .firebaserc configuration

STEP 5: ADD GOOGLE-SERVICES.JSON (if using your own Firebase)

  # For Android, copy google-services.json to:
  cp google-services.json android/app/

Verify the file exists at: android/app/google-services.json

STEP 6: RUN THE APP

On Android Emulator:
  # Start emulator
  flutter emulators --launch <emulator-name>

  # Run app
  flutter run

On Physical Device:
  # Enable USB Debugging on your device
  flutter run -d <device-id>

  # Find device ID:
  flutter devices

On Web (Chrome):
  flutter run -d chrome

Run with Specific Device:
  # List available devices
  flutter devices

  # Run on specific device
  flutter run -d <device-id>

STEP 7: TEST LOGIN CREDENTIALS

Role       | Email                   | Password
-----------|-------------------------|----------
Elderly    | elderly@test.com        | password123
Caregiver  | caregiver@test.com      | password123

================================================================================
PACKAGES USED
================================================================================

Package                      | Version      | Purpose
------------------------------|--------------|---------------------------
flutter                       | sdk          | Flutter framework & widgets
go_router                      | 14.6.2       | Type-safe routing + role-
                               |              | based redirects
provider                       | 6.1.2        | Reactive state management
firebase_core                  | 3.12.0       | Firebase initialization
firebase_auth                  | 5.2.0        | User authentication
cloud_firestore                | 5.6.0        | Real-time database
firebase_messaging             | 15.2.5       | Push notifications (FCM)
flutter_local_notifications    | 18.0.1       | Local reminder notifications
google_fonts                   | 6.2.1        | Inter font family
fl_chart                       | 0.70.0       | Bar charts for health trends
http                           | 1.2.2        | HTTP client for openFDA API
flutter_dotenv                 | 5.2.1        | Load .env file variables
shared_preferences             | 2.3.3        | Local persistent storage
pdf                            | 3.11.0       | PDF generation for reports
share_plus                     | 12.0.2       | Native file sharing
pinput                         | 4.0.0        | OTP/PIN input widget
flutter_svg                    | 2.0.10+1     | SVG rendering
intl                           | 0.20.2       | Date formatting, localization
timezone                       | 0.9.4        | Timezone handling
sensors_plus                   | 7.0.0        | Accelerometer, gesture 
                               |              | detection
cupertino_icons                | 1.0.8        | iOS-style icons

================================================================================
PROJECT STRUCTURE
================================================================================

elderly-ai-care-app/

lib/
  main.dart                           # App entry point + Firebase init

  core/
    constants/
      app_constants.dart              # Route names, roles, theme keys
      app_theme.dart                  # Colors, fonts, button styles
    theme/
      theme_provider.dart             # Dark/light mode toggle
    utils/
      router.dart                     # GoRouter config + redirects

  features/
    onboarding/
      onboarding_screen.dart          # Splash/landing page
      role_selection_screen.dart      # Elderly vs Caregiver

    auth/
      elderly_setup_screen.dart       # Profile creation
      caregiver_login_screen.dart     # Caregiver auth

    elderly/
      home/
        elderly_home_screen.dart
      checkin/
        checkin_screen.dart           # Daily mood/pain check-in
      medication/
        medication_screen.dart        # Reminder list + FDA info
      sos/
        sos_screen.dart               # Emergency button
      chat/
        elderly_chat_screen.dart

    caregiver/
      dashboard/
        caregiver_dashboard_screen.dart  # Main dashboard
      reports/
        reports_screen.dart             # Weekly reports + charts
      alerts/
        alerts_screen.dart              # Alert feed
      elderly/
        patient_detail_screen.dart      # Patient info

  shared/
    models/
      user_model.dart
      patient_model.dart
      medication_model.dart
    services/
      patient_service.dart            # Firestore + FDA API
      caregiver_service.dart          # Caregiver data
      notification_service.dart       # Push notifications
      gemini_service.dart             # AI integration
      user_session_service.dart       # Auth state

android/
  app/
    build.gradle.kts
    src/main/AndroidManifest.xml
  build.gradle.kts

ios/
  Runner.xcodeproj
  Podfile

pubspec.yaml                    # Dependencies
pubspec.lock                    # Locked versions
analysis_options.yaml           # Dart linting
README.md                       # Markdown readme
README.txt                      # This file

================================================================================
TESTING MEDICATIONS
================================================================================

You can add these drugs for testing (they have FDA data):

OTC PAIN RELIEVERS:
- Aspirin
- Ibuprofen (Advil)
- Naproxen (Aleve)
- Acetaminophen (Tylenol)

OTC ALLERGY/COLD:
- Diphenhydramine (Benadryl)
- Cetirizine (Zyrtec)
- Loratadine (Claritin)

COMMON PRESCRIPTIONS:
- Lisinopril
- Metformin
- Amoxicillin
- Propranolol

HOW TO TEST:
1. Login as Elderly
2. Go to Medications
3. Tap + Add Medication
4. Enter drug name (e.g., "Aspirin")
5. Tap the medication card
6. Tap Info - See FDA purpose

================================================================================
DATABASE SCHEMA (FIRESTORE)
================================================================================

ELDERLY PROFILE:
  elderly/{userId}/
    profile                     # Personal info
    medications                 # List of prescribed meds
      {medId}/
        name, dosage, times, frequency
        logs/                   # Medication history
    daily_checkins/             # Mood & pain scores
    sos_alerts/                 # Emergency events

CAREGIVER PROFILE:
  caregivers/{caregiverId}/
    profile                     # Personal info
    linkedElderlyIds[]          # Array of elderly IDs

================================================================================
FEATURES IN ACTION
================================================================================

MEDICATION REMINDER FLOW:
1. Elderly user opens app - Sees medication list
2. Swipes down to refresh from Firestore (pull-to-refresh)
3. Taps medication - See details + FDA info
4. Checks box when taken - Logged to medications/{medId}/logs
5. Caregiver sees update in real-time on dashboard

AI HEALTH ANALYSIS:
1. Elderly completes daily check-in (mood + pain)
2. Gemini API analyzes data + generates summary
3. Caregiver receives alert if anomalies detected
4. Weekly report shows trends with charts

================================================================================
CONTRIBUTING
================================================================================

BRANCHING STRATEGY:

  main                ← Stable, demo-ready code only - Never push directly
    └── dev           ← Active development - All PRs go here
        └── feature/* ← Individual feature branches

KEY RULES:
- DO push daily work to dev
- DO create feature branches from dev for major features
- NEVER push directly to main (code review required)
- DO merge to main only for stable, tested releases

WORKFLOW:

1. Create feature branch from dev:
   git checkout dev
   git pull origin dev
   git checkout -b feature/your-feature

2. Make changes and commit:
   git commit -m "Add feature: describe what you added"

3. Push to your branch:
   git push origin feature/your-feature

4. Open PR to dev (NOT main)

5. After peer review and testing, merge to dev

6. When stable, open PR from dev → main for releases

================================================================================
LICENSE
================================================================================

MIT License - See LICENSE file for details

This project is open-source and free to use, modify, and distribute under the 
MIT License terms.

================================================================================
AI TOOLS USED
================================================================================

This project leverages multiple AI tools to accelerate development and deliver 
intelligent features:

TOOL                        | PROVIDER           | USAGE
----------------------------|--------------------|---------------------------------
Gemini 2.0 Flash           | Google DeepMind    | Core AI features within the app:
                           |                    | health chat companion, weekly 
                           |                    | summaries, 3-step deep analysis
Claude                     | Anthropic          | UI scaffolding, screen 
                           |                    | development, bug fixes, Git 
                           |                    | workflow setup, code reviews
Claude Code                | Anthropic          | Automated code fixes, feature 
                           |                    | implementation, refactoring

================================================================================
TEAM & ROLES
================================================================================

ROLE               | RESPONSIBILITY                          | EXPERTISE
-------------------|----------------------------------------|-------------------
Frontend           | Flutter UI, screens, navigation,        | Mobile development,
Developer          | accessibility, responsive design       | UI/UX
                   |                                        |
Backend            | Firebase setup, Firestore              | Cloud infrastructure,
Developer          | architecture, authentication,          | databases
                   | API integration                        |
                   |                                        |
AI Developer       | Gemini integration, AI prompt          | Machine learning,
                   | engineering, Genkit workflows,        | AI/ML
                   | health analysis logic                 |
                   |                                        |
QA & Testing       | Device testing, bug verification,     | Quality assurance
                   | accessibility compliance, performance |

================================================================================
SUBMISSION INFORMATION
================================================================================

Hackathon:    Project 2030 - MyAI Future Hackathon
Track:        Track 3 - Vital Signs (Healthcare & Wellbeing)
Organization: GDG On Campus UTM
Repository:   https://github.com/pavithiranr/elderly-ai-care-app
License:      MIT

================================================================================
FUTURE ROADMAP
================================================================================

- [ ] Video Telehealth Consultations - Real-time video calls between elderly 
      and healthcare providers
- [ ] Wearable Device Integration - Apple Watch, Fitbit, Garmin smartwatch syncing
- [ ] Offline Mode with Sync - App functionality without internet, auto-sync 
      when online
- [ ] Multi-Language Support - Localization for elderly-friendly interfaces
- [ ] Advanced ML Predictions - Predictive health risk assessments using Gemini's 
      extended analysis
- [ ] EHR Integration - Connect with hospital/clinic electronic health records
- [ ] Voice Commands - Hands-free interaction for accessibility
- [ ] Medication Photo Recognition - AI identifies pills by image
- [ ] Family Video Calls - Direct messaging and video between elderly and caregivers
- [ ] Therapist Integration - Mental health support through licensed professionals

================================================================================

Made with love for Project 2030 - MyAI Future Hackathon

================================================================================