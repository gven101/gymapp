# 🏋️ GymApp — Gym Progress & Trainer Allocation System

> **Final Year University Project**
> A mobile application built with Flutter and Firebase that digitises gym management: trainer allocation, workout plans, daily workout logging, session booking and progress tracking.

---

## 📋 Table of Contents

1. [Project Overview](#-project-overview)
2. [Problem Statement](#-problem-statement)
3. [Technical Stack](#-technical-stack)
4. [Features by Role](#-features-by-role)
5. [Screens](#-screens)
6. [Project Architecture](#-project-architecture)
7. [Database Structure](#-database-structure)
8. [Calorie Calculation](#-calorie-calculation)
9. [Offline-First Logging](#-offline-first-logging)
10. [Prerequisites](#-prerequisites)
11. [Setup & Installation](#-setup--installation)
12. [Firebase Configuration](#-firebase-configuration)
13. [Launching the App](#-launching-the-app)
14. [First-Time Setup (Creating the Admin)](#-first-time-setup-creating-the-admin)
15. [Challenges Faced & How They Were Solved](#-challenges-faced--how-they-were-solved)
16. [Key Design Decisions](#-key-design-decisions)
17. [Build Journey](#-build-journey)
18. [Known Limitations & Future Work](#-known-limitations--future-work)
19. [Dependencies](#-dependencies)
20. [Author](#-author)

---

## 📖 Project Overview

GymApp replaces paper registers and spreadsheets with a single digital system. It supports three user roles — **Admin**, **Trainer** and **Member** — each with its own dashboard.

- **Admins** manage users and assign trainers to members.
- **Trainers** build workout plans, track their members' progress and manage session requests.
- **Members** follow their plan, log workouts, book sessions and watch their progress on charts.

All data syncs in real time through Firebase Firestore, and workout logs keep working without an internet connection.

---

## ❓ Problem Statement

Many gyms still track members manually:

- Trainer allocation is done verbally or on paper, so assignments get lost.
- Members have no clear record of what they did last session.
- Trainers can't see a member's progress without asking them.
- Session booking happens over phone calls or messages.
- Gyms are often in basements with poor network coverage, so cloud-only apps lose data.

GymApp addresses each of these with role-based dashboards, a structured workout log, live progress charts, an appointment workflow, and an offline queue for workout logs.

---

## 🛠 Technical Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter 3.x (Dart) |
| State Management | Provider |
| Database | Firebase Cloud Firestore (NoSQL) |
| Authentication | Firebase Authentication (Email/Password) |
| Offline Queue | SQLite via `sqflite` |
| Charts | `fl_chart` |
| Date Formatting | `intl` |
| Network Detection | `connectivity_plus` |
| Fonts | `google_fonts` |

---

## ✨ Features by Role

### 🔴 Admin
- Live dashboard: total members, trainers and pending appointments
- Create trainer accounts **without being logged out** (uses a secondary Firebase app instance)
- Assign trainers to members, with a **reassignment guard** that warns if the member already has a trainer
- Full assignment history (old assignments are closed with an `endedAt` date, not deleted)
- User management: search, filter by role, activate/deactivate accounts

### 🔵 Trainer
- Real-time list of assigned members
- Create custom workout plans:
  - Pick exercises from the master catalogue (tap to select/deselect)
  - Set target sets, reps and weight per exercise
  - Choose a goal: strength, hypertrophy, fat loss or endurance
- View each member's progress: workout history, weight trend chart, calories burned
- Appointment queue: approve, reject or mark complete, with optional notes

### 🟢 Member
- See assigned trainer, assignment date and status badge
- View the assigned workout plan with expandable exercise details
- Daily workout logger with input fields that adapt to the exercise type:
  - **Strength / Compound** → Sets, Reps, Weight (kg)
  - **Cardio** → Duration (mins), Distance (km)
  - **Timed (e.g. Plank)** → Sets, Hold time (secs)
- Calorie estimate shown after every log
- Progress dashboard with line charts and total calories burned
- Per-exercise calorie breakdown
- Book training sessions with a date/time picker and track their status (pending / approved / rejected / completed)

---

## 📱 Screens

| # | Screen | Role | Description |
|---|---|---|---|
| 1 | Login | All | Firebase Auth sign-in |
| 2 | Register | Public | Self-register as a member |
| 3 | Member Dashboard | Member | Live stats, trainer status, quick actions |
| 4 | Workout Log | Member | Adaptive fields per exercise type, calorie estimate |
| 5 | My Workout Plan | Member | Trainer-assigned plan, start workout |
| 6 | Progress Dashboard | Member | Weight trend chart, calories burned |
| 7 | Book Appointment | Member | Date/time picker, booking history |
| 8 | Trainer Dashboard | Trainer | Live member count, quick actions |
| 9 | Member List | Trainer | All assigned members |
| 10 | Member Progress | Trainer | Member stats, chart, recent activity |
| 11 | Create Workout Plan | Trainer | Exercise picker and target setter |
| 12 | Appointments Queue | Trainer | Approve/reject with notes |
| 13 | Admin Dashboard | Admin | Live user counts, recent assignments |
| 14 | Assign Trainer | Admin | Link trainer to member with reassignment guard |
| 15 | Create Trainer | Admin | Create trainer accounts without logging out |
| 16 | User Management | Admin | Search, filter, activate/deactivate users |

**Total: 16 screens across 3 roles.**

---

## 🏗 Project Architecture

```
lib/
├── main.dart                    ← Entry point, Firebase init, exercise seeding
├── app.dart                     ← MaterialApp, theme, role-based routing
├── firebase_options.dart        ← Generated by `flutterfire configure`
│
├── core/
│   ├── constants/
│   │   └── app_colors.dart      ← Design tokens (lime = member, cyan = trainer, red = admin)
│   ├── services/
│   │   └── firebase_service.dart
│   └── storage/
│       └── local_db.dart        ← SQLite offline queue
│
├── providers/
│   └── auth_provider.dart       ← Auth state, login, logout, role
│
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── member/
    │   ├── member_home_screen.dart
    │   ├── workout_log_screen.dart
    │   ├── my_plan_screen.dart
    │   ├── progress_screen.dart
    │   └── book_appointment_screen.dart
    ├── trainer/
    │   ├── trainer_home_screen.dart
    │   ├── member_list_screen.dart
    │   ├── member_progress_screen.dart
    │   ├── create_plan_screen.dart
    │   └── appointments_screen.dart
    └── admin/
        ├── admin_home_screen.dart
        ├── assign_trainer_screen.dart
        ├── create_trainer_screen.dart
        └── user_management_screen.dart
```

**Routing flow:** `AuthProvider` listens to Firebase Auth. When a user signs in, it reads their `role` from Firestore and `app.dart` rebuilds to show the matching home screen (Admin, Trainer or Member). Deactivated users are blocked at this step.

---

## 🗄 Database Structure

Firestore with 6 collections:

```
users/{uid}
    name, email, role, phone, isActive, createdAt
    assignedTrainerId, assignedTrainerName        (members only)

exercises/{id}
    name, muscleGroup, category, metValue

workoutPlans/{id}
    trainerId, trainerName, memberId, memberName
    planName, goal, isActive, items[], createdAt

workoutLogs/{id}
    memberId, memberName, exerciseId, exerciseName
    muscleGroup, category, inputType
    setsCompleted, repsCompleted, weightKg        (strength)
    durationMins, distanceKm                      (cardio)
    durationSecs                                  (timed)
    caloriesBurnt, loggedDate, createdAt

trainerAssignments/{id}
    memberId, memberName, memberEmail
    trainerId, trainerName
    assignedBy, isActive, assignedAt, endedAt

appointments/{id}
    memberId, memberName, trainerId, trainerName
    sessionDatetime, durationMins, status
    memberNotes, trainerNotes, requestedAt
```

Names (e.g. `trainerName`, `memberName`) are intentionally duplicated into related documents. This is normal in NoSQL design: it lets a screen load in one query instead of several lookups.

---

## 🔥 Calorie Calculation

Calories are estimated with the **MET (Metabolic Equivalent of Task)** formula:

```
Calories = MET × Body Weight (kg) × Duration (hours)
```

Default body weight: **70 kg**.

### Duration estimate per exercise type

| Type | Duration formula |
|---|---|
| Strength | `(sets × reps × 3 s) + (sets × 90 s rest)` |
| Cardio | user-entered minutes ÷ 60 |
| Timed (Plank) | `(sets × hold secs) + (sets × 30 s rest)` |

**Worked example:** Back Squat, 4 sets × 10 reps
Duration = (4 × 10 × 3) + (4 × 90) = 120 + 360 = 480 s = 0.133 h
Calories = 5.0 × 70 × 0.133 ≈ **47 kcal**

### MET values (15 seeded exercises)

| Exercise | MET |
|---|---|
| Treadmill Run | 9.0 |
| Back Squat | 5.0 |
| Romanian Deadlift | 4.5 |
| Pull-Up, Barbell Row, Leg Press, Hip Thrust | 4.0 |
| Bench Press, Overhead Press, Incline Press, Plank | 3.5 |
| Lateral Raise, Barbell Curl, Tricep Pushdown, Calf Raise | 3.0 |

---

## 📶 Offline-First Logging

```
Member logs a workout
        ↓
Try Firestore write
        ↓
Success? ── Yes ──→ Saved to Firestore ✓
        │
        No (no network)
        ↓
Save to SQLite `pending_logs` table
Show amber "N offline" badge
        ↓
Connection restored
        ↓
Tap badge → bulk upload to Firestore
        ↓
Clear SQLite queue → badge disappears ✓
```

Members training in basement gyms with no signal never lose a log, and they can always see how many logs are waiting to sync.

---

## ✅ Prerequisites

- [Flutter SDK 3.x](https://docs.flutter.dev/get-started/install)
- [Android Studio](https://developer.android.com/studio) with the Flutter and Dart plugins
- An Android emulator (AVD) or a physical Android phone with USB debugging enabled
- [Node.js](https://nodejs.org) (needed for the Firebase CLI)
- A [Firebase account](https://firebase.google.com) (free Spark plan is enough)
- Git

Check your setup:

```bash
flutter doctor
```

Everything except Xcode (iOS-only) should show ✓.

---

## ⚙️ Setup & Installation

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/<repo-name>.git
cd <repo-name>
```

### 2. Install Flutter packages

```bash
flutter pub get
```

### 3. Install the Firebase tools

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
```

Add the Dart pub cache to your PATH so the `flutterfire` command works:

- **macOS / Linux:** add this line to `~/.zshrc` or `~/.bashrc`, then restart the terminal
  ```bash
  export PATH="$PATH":"$HOME/.pub-cache/bin"
  ```
- **Windows:** add `%LOCALAPPDATA%\Pub\Cache\bin` to your PATH in *Environment Variables*.

---

## 🔥 Firebase Configuration

### 1. Create the Firebase project

1. Open the [Firebase Console](https://console.firebase.google.com) and create a project (e.g. `gymapp`).
2. **Authentication** → Sign-in method → enable **Email/Password**.
3. **Firestore Database** → Create database → choose a region (e.g. `asia-south1`, Mumbai).

### 2. Connect the Flutter app

From the project folder:

```bash
flutterfire configure
```

Select your project and the **android** platform. This generates `lib/firebase_options.dart` and `android/app/google-services.json`.

### 3. Android settings

In `android/app/build.gradle` (or `build.gradle.kts` in newer Flutter versions), set the minimum SDK:

```gradle
defaultConfig {
    minSdk = 23   // Firebase plugins need at least 21; 23 avoids build errors on newer plugin versions
}
```

In `android/app/src/main/AndroidManifest.xml`, make sure internet access is allowed (above the `<application>` tag):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### 4. Firestore security rules

Firebase Console → Firestore → **Rules**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

> ⚠️ These rules allow any signed-in user to read and write everything. They are fine for development and demos, but a production release should use role-based rules (e.g. only admins can write to `trainerAssignments`).

### 5. Firestore indexes

Some screens filter and sort at the same time (e.g. logs for one member ordered by date). The first time such a query runs, Firestore shows an error in the debug console containing a **link to create the required index**. Click the link, wait 1–2 minutes for the index to build, then restart the app.

---

## 🚀 Launching the App

1. **Start a device**
   - Emulator: Android Studio → **Device Manager** → ▶ next to your virtual device
   - Physical phone: connect via USB with **USB debugging** enabled

2. **Confirm Flutter sees it**
   ```bash
   flutter devices
   ```

3. **Run the app**
   ```bash
   flutter run
   ```
   Or open the project in Android Studio and press **▶ Run**.

4. While it's running, press `r` in the terminal for hot reload or `R` for hot restart.

### Building an APK (to install on a phone or submit)

```bash
flutter build apk --release
```

The APK is created at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 👤 First-Time Setup (Creating the Admin)

The app has no built-in admin account, so the first admin is created manually:

1. Launch the app and **register** a normal account.
2. Firebase Console → Firestore → `users` → open your user document.
3. Change `role` from `member` to `admin`.
4. Log out and log back in — the **Admin Dashboard** appears.
5. The 15 exercises are seeded into Firestore automatically on first launch.

From the admin account you can now create trainers, register test members, and assign trainers to them.

### Suggested demo flow
1. Admin creates a trainer → assigns them to a member.
2. Trainer logs in → creates a workout plan for that member.
3. Member logs in → views the plan → logs a workout → checks progress.
4. Member books a session → trainer approves it → member sees the status change live.
5. Turn on airplane mode → log a workout → see the offline badge → reconnect and sync.

---

## 🧗 Challenges Faced & How They Were Solved

### 1. `flutterfire: command not found`
**Problem:** After installing `flutterfire_cli`, the terminal couldn't find the command.
**Cause:** Dart installs global tools into `~/.pub-cache/bin`, which isn't on the PATH by default.
**Solution:** Added the folder to PATH (see Setup step 3) and restarted the terminal.

### 2. Android build failing because of the minimum SDK
**Problem:** The first build after adding Firebase failed with a `minSdkVersion` error.
**Cause:** The default Flutter template targets an SDK version lower than the Firebase plugins support.
**Solution:** Raised `minSdk` in `android/app/build.gradle`.

### 3. Admin got logged out when creating a trainer
**Problem:** Firebase's `createUserWithEmailAndPassword` automatically signs in as the new user, so the admin was kicked out every time they created a trainer account.
**Solution:** Created a **secondary Firebase app instance** used only for account creation. The new trainer is created and signed out on the secondary instance, while the admin's session on the main instance stays untouched.

### 4. No way to create the first admin
**Problem:** Only admins can create privileged accounts, but there's no admin to begin with.
**Solution:** Everyone registers as a `member`; the first admin is promoted by editing the `role` field directly in Firestore (see *First-Time Setup*). A production version would use a Cloud Function or the Admin SDK.

### 5. Keeping trainer assignments consistent
**Problem:** Assigning a trainer updates several documents (the member's user doc, a new assignment, and closing the old one). If one write failed, the data would disagree.
**Solution:** Used a **Firestore batch write** so all changes succeed or fail together. A reassignment guard also warns the admin before replacing an existing trainer.

### 6. One workout form didn't fit every exercise
**Problem:** Sets/reps/weight make no sense for a treadmill run or a plank.
**Solution:** Each exercise has an `inputType` (strength, cardio, timed). The logger reads it and shows only the relevant fields, and the calorie formula uses a different duration estimate for each type.

### 7. Exercises seeded more than once
**Problem:** Seeding exercises in `main.dart` created duplicates on every app launch.
**Solution:** The seed function first checks whether the `exercises` collection is empty and only writes if it is.

### 8. Firestore "requires an index" errors
**Problem:** Queries combining `where` and `orderBy` failed with a `FAILED_PRECONDITION` error.
**Solution:** Created the composite indexes using the link Firestore prints in the error message.

### 9. Losing workout logs with no network
**Problem:** Gyms often have weak signal, and members couldn't tell whether a log had saved.
**Solution:** Built the SQLite offline queue with a visible "N offline" badge and a one-tap bulk sync (see *Offline-First Logging*).

### 10. Charts breaking with little or no data
**Problem:** `fl_chart` threw errors or drew odd graphs for new members with zero or one log.
**Solution:** Added empty-state messages and only draw the chart once there are enough data points.

### 11. Dates and timestamps
**Problem:** Firestore returns `Timestamp` objects, not Dart `DateTime`, which caused type errors and awkward formatting.
**Solution:** Converted with `.toDate()` and formatted with the `intl` package (e.g. `DateFormat('d MMM yyyy')`).

### 12. Slow emulator and long first builds
**Problem:** The first Gradle build took several minutes and the emulator was sluggish.
**Solution:** Enabled hardware acceleration for the emulator, used a lighter system image, and relied on hot reload instead of full rebuilds during development.

---

## 🧠 Key Design Decisions

**Firebase instead of MySQL + Node.js**
Firebase removes the need to build and host a backend server. Firestore's real-time listeners (`snapshots()`) update screens the moment data changes — for example, a member's dashboard shows their new trainer immediately after the admin assigns one, with no refresh or polling.

**Provider for state management**
Provider is lightweight and well-documented, which suits a project of this size. `AuthProvider` drives role-based routing: when login succeeds, the app rebuilds straight to the correct home screen.

**SQLite for the offline queue**
Firestore does cache writes offline on its own, but those pending writes are invisible to the user and are lost if app data is cleared before reconnecting. The SQLite `pending_logs` table makes unsynced logs visible (the amber badge), persistent, and under the member's control.

**MET formula for calories**
MET values come from the widely used *Compendium of Physical Activities* and are a standard way to estimate energy expenditure from activity type and duration. It gives reasonable estimates without needing heart-rate hardware.

---

## 🗺 Build Journey

| Phase | What was built |
|---|---|
| 1 | Environment setup — Flutter, Android Studio, emulator |
| 2 | Firebase project — Auth, Firestore, `flutterfire configure` |
| 3 | Project structure — `pubspec.yaml`, folders, theme |
| 4 | First run — Login and Register screens connected to Firebase |
| 5 | Three role dashboards with live Firestore data |
| 6 | Assign Trainer — batch write and reassignment guard |
| 7 | Workout Log — adaptive fields per exercise type |
| 8 | Exercise seeding — 15 exercises with MET values |
| 9 | Calorie calculation per exercise type |
| 10 | Progress screen — `fl_chart` line chart, calories burned |
| 11 | Book Appointment — date/time picker, status tracking |
| 12 | Trainer Appointments — approve/reject dialog |
| 13 | Create Workout Plan — exercise picker, targets |
| 14 | My Plan — expandable plan view, start workout |
| 15 | Member Progress (trainer view) — chart, recent activity |
| 16 | Create Trainer — secondary Firebase app, no logout |
| 17 | User Management — search, filter, activate/deactivate |
| 18 | Member Dashboard improvements — live stats, trainer badge |

---

## 🚧 Known Limitations & Future Work

- **Security rules** are development-level; role-based rules are needed for production.
- **Body weight** is fixed at 70 kg for calorie estimates; it should come from each member's profile.
- **Admin bootstrap** is manual; could be replaced with a Cloud Function.
- **Android only** — iOS needs Xcode setup and testing.
- **Planned features:** push notifications for appointment updates, personal records (PRs), plan templates, member weight entry, and export of progress reports to PDF.

---

## 📦 Dependencies

```yaml
firebase_core: ^3.3.0
firebase_auth: ^5.1.2
cloud_firestore: ^5.2.1
provider: ^6.1.2
sqflite: ^2.3.3+1
path: ^1.9.0
fl_chart: ^0.68.0
intl: ^0.19.0
connectivity_plus: ^6.0.3
google_fonts: ^6.2.1
```

---

## 👨‍💻 Author

**Gaurav**
MIT — Semester 6
Final Year University Project
Academic Year 2025–26

---

*Built with Flutter and Firebase — 16 screens, 3 roles, real-time data, offline-first workout logging.*
