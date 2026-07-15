# CLAUDE.md - Solid Hackathon App

## Project Overview

**Name**: Solid Hackathon App - Health Records & Prediction Platform

**Purpose**: A SOLID POD-based health data management application that enables users to:
- Record personal health metrics (age, weight, height, BP, sleep, exercise, etc.)
- Automatically calculate health indicators (BMI)
- Predict health risks using machine learning models
- Visualize health trends over time

**Status**: Active Development | MVP Phase

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | Flutter (Web/Chrome) | UI/UX and form handling |
| Data Storage | SOLID POD | Encrypted health record storage (.ttl format) |
| Encryption | AES-256 | Data-at-rest encryption for sensitive records |
| ML Pipeline | scikit-learn, Python | Health risk prediction (logistic regression) |
| Visualization | Flutter Charts / Plotly | Trend dashboard and metrics display |
| Authentication | SOLID WebID | POD access and user identity |

---

## Key Directories

```
lib/
├── models/              # Data models (HealthRecord, PredictionResult)
├── screens/             # UI screens (Add, View, Predict, Dashboard)
├── services/            # Business logic (POD, encryption, ML, auth)
├── widgets/             # Reusable UI components
└── main.dart            # Entry point

.claude/docs/            # Progressive disclosure documentation
├── FEATURES.md          # Detailed feature specifications
├── DATA_MODEL.md        # Health record schema and encryption strategy
├── ML_PIPELINE.md       # Model training and prediction workflow
├── STORAGE.md           # SOLID POD integration guide
└── DEVELOPMENT.md       # Build/test/deployment procedures
```

---

## Core Features

### 1. Add Health Record
**Files**: `lib/screens/add_health_record_screen.dart` | `lib/models/health_record.dart`

Form inputs: age, weight (kg), height (cm), BP (systolic/diastolic), resting HR, sleep hours, exercise minutes/week, smoking status, family history

Auto-calculation: BMI = weight / (height/100)²

Saves as encrypted JSON to POD: `note_<timestamp>.json.enc.ttl`

→ See `.claude/docs/DATA_MODEL.md` for schema details

### 2. View Health History
**Files**: `lib/screens/view_history_screen.dart` | `lib/widgets/record_card.dart`

Lists past entries (reverse chronological order), tap for full details, supports date range filtering

→ See `.claude/docs/FEATURES.md` for UI/UX requirements

### 3. Health Risk Prediction
**Files**: `lib/services/ml_service.dart` | `assets/models/`

Takes latest health record → extracts features → runs scikit-learn model → outputs risk score (0-1) and level (Low/Medium/High) → saves result to POD

**Time intensive** - prioritize after MVP core features

→ See `.claude/docs/ML_PIPELINE.md` for model training, feature engineering, and deployment

### 4. Trends Dashboard
**Files**: `lib/screens/trends_dashboard_screen.dart`

Visualizes: weight, BP, sleep, exercise, BMI, and risk score trends over time

→ See `.claude/docs/FEATURES.md` for chart specifications

---

## Quick Start

```bash
# Install Flutter and dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome

# Run tests
flutter test

# Build for production
flutter build web
```

For Python ML environment setup, see `.claude/docs/DEVELOPMENT.md`

---

## Data Security & Privacy

- All health records encrypted before saving to POD
- SOLID POD provides user data ownership and access control
- No central server; data stored in user's personal POD
- Encryption key management: See `.claude/docs/DATA_MODEL.md`

---

## Development Priorities

| Phase | Features | Timeline |
|-------|----------|----------|
| **MVP** | Add Record, View History, BMI calculation | 40-50h |
| **Enhancement** | Prediction Feature, Trends Dashboard | 30-40h |
| **Polish** | Data export, advanced analytics, UI refinement | As time allows |

---

## Important Files to Know

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Flutter dependencies and project config |
| `lib/main.dart` | App initialization and routing |
| `lib/services/solid_pod_service.dart` | POD read/write operations |
| `lib/services/encryption_service.dart` | Data encryption/decryption |
| `lib/services/ml_service.dart` | ML model integration and predictions |
| `assets/models/` | Pre-trained scikit-learn model files |

---

## When You Need More Details

- **Feature specifications & UI requirements** → `.claude/docs/FEATURES.md`
- **Health record schema, encryption strategy** → `.claude/docs/DATA_MODEL.md`
- **ML model training, feature extraction, evaluation** → `.claude/docs/ML_PIPELINE.md`
- **SOLID POD integration, authentication, storage** → `.claude/docs/STORAGE.md`
- **Build, test, deployment, troubleshooting** → `.claude/docs/DEVELOPMENT.md`

---

## Key Decisions

- **Data Format**: Encrypted JSON stored in SOLID POD with `.ttl` extension
- **ML Approach**: Pre-trained scikit-learn model called via Python service (Flask API or FFI)
- **Frontend**: Flutter Web for cross-platform Chrome app deployment
- **Auth**: SOLID WebID protocol for POD access

---

## Questions Before Coding?

- What is the preferred way to deploy the Python ML model? (Flask API, embedded, serverless?)
- Do you have a health dataset for model training, or should we source publicly available data?
- Are there specific health prediction targets beyond "general health score"?
- What is the POD provider/environment for testing? (e.g., Solid Test Suite, self-hosted?)

---

**Last Updated**: 2026-07-15 | **Version**: 1.0 | **Status**: Active Development
