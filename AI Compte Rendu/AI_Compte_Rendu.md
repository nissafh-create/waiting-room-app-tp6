# Workshop 6 Report: Building a Resilient Single-Room Waiting Queue with Flutter and Supabase

> **Simulation on Android Studio: Success**

---

## Part 1: AI Collaboration Log & Problem-Solving Journey

This section tracks the step-by-step collaboration between the student and the AI assistant inside Google Antigravity. It documents the natural, interactive prompts given during development, the real-world issues encountered, and the technical solutions applied to complete Workshop 6.

### Environment Details
- **AI Model:** Gemini 3.8 Flash (Medium)
- **Environment:** Google Antigravity Agentic IDE
- **Operating System:** Windows 10 (x64)
- **Frameworks & Packages:** Flutter SDK 3.38.5, `supabase_flutter: ^2.18.2`, `provider: ^6.1.5+1`, `geolocator: ^11.1.0`, `connectivity_plus: ^6.1.5`, `sqflite: ^2.4.2`, `uuid: ^4.0.0`, `mocktail: ^1.0.4`

---

### Step-by-Step Interactive Prompts & Fixes

#### Step 1: Upgrading Dependencies for TP6
- **Student Prompt:**  
  > *"tp6 pdf. The prof wants us to add connectivity monitoring, advanced pagination and clean up our architecture. What packages do we need to add to `pubspec.yaml`? i think we need `connectivity_plus` and maybe mocktail right?"*
- **Problem:**  
  The app had local SQLite and geolocation from TP5, but lacked network connectivity monitoring (`connectivity_plus`) to distinguish between device connection loss and Supabase backend downtime, as well as `mocktail` for modern mock-based testing.
- **Solution:**  
  Added `connectivity_plus: ^6.0.3` to `dependencies` and `mocktail: ^1.0.4` to `dev_dependencies` in `pubspec.yaml`, then executed `flutter pub get` cleanly.

---

#### Step 2: Structuring the Layered Architecture
- **Student Prompt:**  
  > *"look at page 3 of the pdf, the prof gave a specific folder structure with `models/`, `providers/`, `services/`, `repositories/`, `storage/`, `screens/`, and `widgets/`. Before we had everything loose inside `lib/`. How should we split this without breaking my previous working stuff?"*
- **Problem:**  
  Workshop 6 enforces a strict layered architecture:
  - **UI Layer:** `QueueScreen`, `ClientCard`, `OfflineBanner`, `LoadingWidget`, `QueueEmptyWidget`.
  - **Provider Layer:** `QueueProvider`, `ConnectivityProvider`.
  - **Services Layer:** `GeolocationService`, `ConnectivityService`, `SyncService`.
  - **Repository Layer:** `QueueRepository`.
  - **Storage Layer:** `LocalQueueStorage`.
  - **Models Layer:** `Client`, `SyncStatus`, `AppConnectivity`, `QueueState`.
- **Solution:**  
  Created the modular folder tree according to Section 2.3. Kept legacy root files (e.g. `lib/queue_provider.dart` and `lib/geolocation_service.dart`) exporting the new modular classes to ensure complete backwards compatibility with existing tests.

---

#### Step 3: Updating the `Client` Model & `SyncStatus`
- **Student Prompt:**  
  > *"In section 1.5, we have to create `sync_status.dart` enum and update `Client` model. The prof wants two different maps: one for supabase and one for sqlite. why do we need two different serialization methods?"*
- **Problem:**  
  Local SQLite needs to store local synchronization state (`sync_status: pending | syncing | synced | failed`), whereas Supabase should only receive clean business data without local client-side metadata.
- **Solution:**  
  1. Created `lib/models/sync_status.dart`:
     ```dart
     enum SyncStatus { pending, syncing, synced, failed }
     ```
  2. Implemented `toSupabaseMap()` (exports `id`, `name`, `lat`, `lng`, `location_accuracy_m`, `created_at`) and `toLocalMap()` (includes `sync_status.name`).
  3. Added `Client.fromSupabaseMap()` and `Client.fromLocalMap()` with fallback parsing.
  4. Added `operator [](String key)` to the `Client` class so legacy tests accessing client fields like `client['name']` or `client['lat']` continue to work without runtime errors.

---

#### Step 4: TDD Client Model Test
- **Student Prompt:**  
  > *"Okay, we need to do the TDD exercise from section 1.6 in `test/models/client_test.dart`. can u write it exactly like the pdf and run it to make sure it passes?"*
- **Problem:**  
  Verifying that clients without GPS report `hasLocation == false`, that `toLocalMap()` preserves accuracy and syncStatus, and that `toSupabaseMap()` excludes local sync metadata.
- **Solution:**  
  Created `test/models/client_test.dart` and ran `flutter test test/models/client_test.dart`. All 3 unit tests passed on the first run.

---

#### Step 5: Network Connectivity Monitoring & Debouncing
- **Student Prompt:**  
  > *"In part 2, the prof says we have to distinguish between wifi/data connection and backend reachability. And in `ConnectivityProvider` there is a 700ms debounce. why do we need a debounce here?"*
- **Problem:**  
  Mobile network radios often toggle states rapidly when switching cells or reconnecting to Wi-Fi. Pinging Supabase on every single flicker creates unnecessary HTTP traffic and race conditions.
- **Solution:**  
  1. Created `lib/models/app_connectivity.dart` with states: `checking`, `online`, `offline`, `backendUnavailable`.
  2. Implemented `ConnectivityService`:
     - Checks device connection using `Connectivity().checkConnectivity()`.
     - Pings backend using `_supabase.from('clients').select('id').limit(1).timeout(Duration(seconds: 5))` inside `isSupabaseAvailable()`.
  3. Built `ConnectivityProvider` with a 700ms `Timer` (`_debounceTimer`) and a re-entrant `do...while` guard (`_checkingBackend`, `_checkAgain`) before determining final backend availability.

---

#### Step 6: Implementing `OfflineBanner` & Widget Test
- **Student Prompt:**  
  > *"Now for the UI, we need the `OfflineBanner` widget and its test from section 2.5 and 7.1. It should show red for no network, orange for server down, and blue when checking. How do we test this widget?"*
- **Problem:**  
  Users need clear visual feedback when disconnected or when the backend server is unreachable.
- **Solution:**  
  1. Created `lib/widgets/offline_banner.dart` using Dart pattern matching `switch (status)`:
     - `offline`: "No network connection" (Red)
     - `backendUnavailable`: "Waiting-room server unavailable" (Orange)
     - `checking`: "Checking connection..." (Blue)
     - `online`: `SizedBox.shrink()` (Hidden)
  2. Created `test/widgets/offline_banner_test.dart` testing that offline state renders `"No network connection"`. Test passed successfully.

---

#### Step 7: Local SQLite Storage & SyncService
- **Student Prompt:**  
  > *"In part 3 and 4, we have `LocalQueueStorage` and `SyncService`. The pdf says to fetch both pending and failed records for retry logic. Can you write both files and make sure the sync doesn't crash if supabase schema has differences?"*
- **Problem:**  
  Unsent registrations must be persisted in SQLite table `clients` with `ConflictAlgorithm.replace`. If a sync fails, records must remain marked as `failed` so they can be retried on the next sync pass.
- **Solution:**  
  1. Implemented `lib/storage/local_queue_storage.dart` with table schema:
     ```sql
     CREATE TABLE clients (
       id TEXT PRIMARY KEY,
       name TEXT NOT NULL,
       lat REAL,
       lng REAL,
       location_accuracy_m REAL,
       created_at TEXT NOT NULL,
       sync_status TEXT NOT NULL
     )
     ```
     Included `getPendingClients()` querying `WHERE sync_status = 'pending' OR sync_status = 'failed'`. Added web in-memory fallback for browser testing.
  2. Implemented `lib/services/sync_service.dart`: iterates over pending/failed records, marks them `syncing`, calls `registerOnServer()`, and updates to `synced` (or `failed` upon exception).
  3. Implemented `lib/repositories/queue_repository.dart` which calls the Postgres function `register_queue_client` and falls back gracefully to `upsert()`.

---

#### Step 8: State Management, Pagination & Realtime Reconciliation
- **Student Prompt:**  
  > *"In part 5 and 6, we need pagination with `fetchInitialQueue()` and `loadMore()` with 20 items per page, and handling realtime inserts without duplicate items. Can we make sure the list stays in correct order when users add clients?"*
- **Problem:**  
  1. Loading all items at once overtaxes slow mobile connections; pagination (`offset`, `limit: 20`) is required.
  2. Supabase Realtime inserts can fire for records the local user just added, causing duplicate entries in the UI.
  3. FIFO waiting room logic requires the first person in line to be served first.
- **Solution:**  
  1. Created `lib/models/queue_state.dart` (`initial`, `loading`, `loaded`, `empty`, `refreshing`, `loadingMore`, `error`).
  2. Implemented `QueueProvider`:
     - `fetchInitialQueue()`: loads page 0 with limit 20 and sets state to `empty` or `loaded`.
     - `loadMore()`: queries the next page and filters out duplicates using a Set of existing IDs (`existingIds.contains(c.id)`).
     - `handleRealtimeInsert(Client client)`: checks if `_clients.any((c) => c.id == client.id)` before appending.
     - Preserved FIFO queue ordering (`_clients.add(client)`) so `nextClient()` serves the earliest registered client first.
  3. Created reusable widgets: `LoadingWidget` and `QueueEmptyWidget`.
  4. Built `lib/screens/queue_screen.dart` featuring `OfflineBanner`, an input bar, pull-to-refresh (`RefreshIndicator`), infinite scroll detection (`ScrollController`), swipe-to-delete dismissibles, and the "Next Client" button.

---

#### Step 9: Fixing Missing Provider in Isolated Widget Tests
- **Student Prompt:**  
  > *"When running `flutter test`, my older widget test gave: `ProviderNotFoundException: Could not find the correct Provider<ConnectivityProvider> above this QueueScreen Widget`. How do we make `QueueScreen` work even when a test doesn't provide `ConnectivityProvider`?"*
- **Problem:**  
  `QueueScreen` used `context.select<ConnectivityProvider, AppConnectivity>()`. In isolated widget tests where only `QueueProvider` was injected into the test tree, Provider threw an unhandled exception.
- **Solution:**  
  Updated `QueueScreen` to safely lookup `Provider.of<ConnectivityProvider?>(context, listen: true)`. If null (isolated test environment), it smoothly defaults to `AppConnectivity.online` without crashing.

---

#### Step 10: Fixing Geolocation 11.1.0 vs 12+ API Incompatibility
- **Student Prompt:**  
  > *"I got a compilation error in `geolocation_service.dart`: `Error: No named parameter with the name 'locationSettings'`. What is going on here?"*
- **Problem:**  
  The professor's code snippet used `locationSettings: const LocationSettings(...)`, which was introduced in newer versions of the geolocator library. In `geolocator: ^11.0.0` (as specified in Section 3.3 Dependencies), `getCurrentPosition` takes `desiredAccuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)`. Upgrading geolocator to 13 caused `dart:js_interop` incompatibilities on the VM test runner.
- **Solution:**  
  Maintained strict compliance with `geolocator: ^11.0.0` and updated `GeolocationService.getCurrentPosition()` to use `desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 10)`. The compiler error was resolved and all test suites ran smoothly.

---

## Part 2: Architecture & Component Overview

The application implements a clean **5-Layer Architecture** designed for high resilience against network drops and server downtime:

```
┌──────────────────────────────────────────────────────────┐
│                        UI LAYER                          │
│  QueueScreen │ ClientCard │ OfflineBanner │ LoadingWidget│
└────────────────────────────┬─────────────────────────────┘
                             │ Consumer / Provider
                             ▼
┌──────────────────────────────────────────────────────────┐
│                     PROVIDER LAYER                       │
│    QueueProvider (Pagination, State, Realtime)           │
│    ConnectivityProvider (700ms Debounced Network Guard)  │
└──────────────┬────────────────────────────┬──────────────┘
               │                            │
               ▼                            ▼
┌───────────────────────────────┐ ┌────────────────────────┐
│        SERVICES LAYER         │ │    REPOSITORY LAYER    │
│  GeolocationService (GPS)     │ │    QueueRepository     │
│  ConnectivityService (Health) │ │ (RPC / Supabase Client)│
│  SyncService (Offline Sync)   │ └───────────┬────────────┘
└──────────────┬────────────────┘             │
               │                              │
               ▼                              ▼
┌───────────────────────────────┐ ┌────────────────────────┐
│         STORAGE LAYER         │ │     BACKEND LAYER      │
│     LocalQueueStorage         │ │    Supabase Postgres   │
│  (SQLite waiting_queue.db)    │ │   (Realtime WebSocket) │
└───────────────────────────────┘ └────────────────────────┘
```

---

### Core Components & Responsibilities

#### 1. Models (`lib/models/`)
- `client.dart`: Business model storing client data and GPS metadata. Provides clean dual serialization (`toSupabaseMap()` without sync metadata, `toLocalMap()` with sync metadata).
- `sync_status.dart`: Tracks local sync progression (`pending`, `syncing`, `synced`, `failed`).
- `app_connectivity.dart`: Distinguishes between physical device offline state and backend server unreachable state.
- `queue_state.dart`: Drives explicit UI state rendering (`loading`, `empty`, `loaded`, `error`, etc.).

#### 2. Services (`lib/services/`)
- `geolocation_service.dart`: Handles device location permissions and coordinates retrieval with a 10s timeout, gracefully returning `null` if permission is denied.
- `connectivity_service.dart`: Monitors connectivity changes and validates Supabase reachability using a lightweight query.
- `sync_service.dart`: Synchronizes local pending and failed records with Supabase in the background, updating their state sequentially.

#### 3. Storage & Repository (`lib/storage/` & `lib/repositories/`)
- `local_queue_storage.dart`: Manages SQLite database `waiting_queue.db` table `clients` with conflict replacement and pending queries.
- `queue_repository.dart`: Handles server operations including `fetchPage()` for pagination, `deleteOnServer()`, and `registerOnServer()` using the PostgreSQL RPC function `register_queue_client`.

#### 4. Providers (`lib/providers/`)
- `connectivity_provider.dart`: Listens to network streams and applies a 700ms debounce before testing backend availability.
- `queue_provider.dart`: Manages queue pagination (20 items/page), realtime event reconciliation, and FIFO queue progression.

#### 5. Presentation (`lib/screens/` & `lib/widgets/`)
- `offline_banner.dart`: Dynamic color-coded status banner.
- `client_card.dart`: Shows client identity, formatted GPS coordinates, and location status icons.
- `queue_screen.dart`: Complete screen providing pull-to-refresh, infinite scroll pagination, and dismissible deletions.

---

## Part 3: Verification & Automated Test Suite

All 11 unit, integration, and widget tests pass with **0 errors and 0 warnings**:

| Test File | Layer / Component | Verified Behaviors | Status |
| :--- | :--- | :--- | :---: |
| `test/models/client_test.dart` | Model (TDD) | Evaluates `hasLocation`, `toLocalMap()`, and `toSupabaseMap()` | **PASSED** |
| `test/widgets/offline_banner_test.dart` | Widget (TDD) | Confirms `OfflineBanner` renders "No network connection" when offline | **PASSED** |
| `test/local_queue_service_test.dart` | Storage | SQLite table creation, record insertion, and unsynced query filtering | **PASSED** |
| `test/queue_provider_geolocation_test.dart` | Provider / Service | Verifies `addClient()` captures and persists mock GPS coordinates | **PASSED** |
| `test/queue_provider_test.dart` | Provider / Repository | Ensures local save triggers background remote sync | **PASSED** |
| `test/waiting_room_manager_test.dart` | Provider | Tests queue FIFO ordering, client removal, and `nextClient()` | **PASSED** |
| `test/waiting_room_widget_test.dart` | UI / Widget | Verifies client list rendering and formatted coordinate display | **PASSED** |

### Execution Commands:
- **Test Suite:** `flutter test`  
  `00:05 +11: All tests passed!`
- **Static Code Analysis:** `dart analyze`  
  `Analyzing waiting-room-app-tp4-main... No issues found!`
