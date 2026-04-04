# CareSync AI

> AI-powered elderly home care companion — built for the **Project 2030: MyAI Future Hackathon** (Track 3: Healthcare & Wellbeing)

---

## What it does

CareSync AI is a two-sided mobile and web app that connects elderly users with their family caregivers through AI-powered health monitoring.

| Side | Features |
|---|---|
| **Elderly** | Daily health check-ins, medication reminders, SOS emergency button, AI chat companion |
| **Caregiver / Family** | Real-time health dashboard, AI-generated alerts, weekly trend reports with charts |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter 3.29 (Android · iOS · Web) |
| Backend | Firebase Genkit + Cloud Run |
| AI | Gemini 2.0 API |
| Database | Cloud Firestore |
| Hosting | Firebase Hosting |
| Charts | fl_chart |

---

## Team

| Role | Responsibility |
|---|---|
| Frontend / UI | Flutter screens, navigation, UI/UX |
| Backend | Firebase Genkit, Cloud Run, Firestore |
| AI Integration | Gemini 2.0 prompts, analysis pipeline |

---

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── constants/app_constants.dart   # Route names, prefs keys, roles
│   ├── theme/app_theme.dart           # Colors, typography, button styles
│   └── utils/router.dart             # go_router config + role-based redirect
├── features/
│   ├── onboarding/
│   │   ├── onboarding_screen.dart     # Splash / landing
│   │   └── role_selection_screen.dart # Elderly vs Caregiver picker
│   ├── elderly/
│   │   ├── home/                      # Home screen — large-text, accessible
│   │   ├── checkin/                   # Daily mood + pain check-in form
│   │   ├── medication/                # Medication reminder list
│   │   ├── sos/                       # SOS button with confirmation dialog
│   │   └── chat/                      # Gemini AI chat companion
│   └── caregiver/
│       ├── dashboard/                 # Health stats, AI summary, activity log
│       ├── alerts/                    # Severity-coded alert list
│       └── reports/                  # Weekly report with fl_chart bar charts
└── shared/
    ├── models/user_model.dart
    └── services/user_session_service.dart
```

---

## Branching Strategy

```
main   ← stable releases only — do not push directly
  └── dev  ← everyone pushes daily work here
```

**Workflow:**
1. All daily commits go to `dev`
2. When a feature is stable and tested, open a PR from `dev` → `main`
3. Coordinate with the team before merging to `main`

---

## Getting Started

### Prerequisites

- Flutter 3.29+ — [install guide](https://docs.flutter.dev/get-started/install)
- Dart 3.7+
- Android Studio or VS Code with Flutter extension

### Run locally

```bash
# Clone
git clone https://github.com/pavithiranr/elderly-ai-care-app.git
cd elderly-ai-care-app

# Switch to the work branch
git checkout dev

# Install dependencies
flutter pub get

# Run (connect a device or start an emulator first)
flutter run

# Run on web
flutter run -d chrome
```

### Key packages

| Package | Purpose |
|---|---|
| `go_router` | Declarative routing + role-based redirects |
| `google_fonts` | Inter typeface |
| `fl_chart` | Bar charts in the weekly report |
| `shared_preferences` | Local role persistence |
| `provider` | State management (ready for Firestore data) |
| `intl` | Date formatting |

---

## Integration Points

All screens contain `// TODO:` comments marking where Firestore reads/writes and Gemini API calls are wired in by the backend and AI team members.

---

## License

MIT
