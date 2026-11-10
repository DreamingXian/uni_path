# UniPath: Your Campus Companion

**UniPath** is a comprehensive mobile application designed specifically for the **TARUMT** student community. It integrates campus navigation, event management, social interaction, and personal academic organization into a single, seamless platform.

---

## 📂 Project File Structure

To maintain a clean architecture and prevent merge conflicts, we follow a **Feature-Service-Model** pattern. Please ensure you place your files in the correct directories:

```text
lib/
├── main.dart             # App entry point & Provider setup
├── models/               # Data blueprints (JSON Serialization)
│   ├── user_model.dart
│   ├── event_model.dart
│   ├── post_model.dart
│   └── schedule_model.dart
├── services/             # Direct Supabase API logic
│   ├── auth_service.dart
│   ├── user_service.dart
│   ├── event_service.dart
│   └── community_service.dart
├── providers/            # Global State Management
│   └── user_provider.dart
├── screens/              # UI / Folders per module
│   ├── auth/             # Login & Sign-up
│   ├── events/           # Member 1's Work
│   ├── community/        # Member 2's Work
│   └── schedule/         # Member 3's Work
└── widgets/              # Reusable UI components (Buttons, Cards)
```

---

## 🗄️ Database Structure (Supabase)

Our backend uses a relational PostgreSQL database. Most tables are linked via **Foreign Keys** and use `CASCADE` deletes to maintain data integrity.

| Table | Purpose | Key Relationships |
| :--- | :--- | :--- |
| **users** | Student profiles | Linked to Supabase Auth UUID |
| **events** | Campus events/workshops | Created by 'society' users |
| **event_times** | Multiple slots for one event | Linked to `events.id` |
| **tickets** | Student event bookings | Linked to `users.id` & `events.id` |
| **posts** | Community feed / Lost & Found | Linked to `users.id` |
| **post_images** | Multiple images per post | Linked to `posts.id` |
| **comments** | Text comments & Reactions | Linked to `posts.id` |
| **schedules** | Personal student timetable | Linked to `users.id` |
| **reminders** | Notification alerts | Linked to `schedules.id` |

---

## 🛠️ Module Breakdown

### 📅 1. Event & Ticketing (Lead: Shou Xian)
*Focus: Role-Based Access Control (RBAC) and Digital Asset Management.*

* **Basic Requirements (CRUD & Logic):**
    * **Society Features:** Exclusive permissions to Create, Update, and Delete events and time slots. Manage event "Dashboard" to view total tickets issued and attendee lists.
    * **Student Features:** Discovery-driven UI to browse and filter campus events. Ability to "Join" (free) or "Purchase" (paid) tickets. 
    * **Digital Wallet:** A "My Tickets" section in the student profile to retrieve active passes and view event history.
* **Extra Effort (Advanced Tech):**
    * **📍 Spatial Awareness:** Integration of GPS for precise event venue pinning on a map.
    * **💳 Payment Integration:** Implementation of a sandbox Payment API for simulated ticket transactions.
    * **🎫 Smart Ticketing (NFC/QR):** * **Generator:** Students' tickets are converted into unique QR codes or written to NFC tags.
        * **Scanner:** Society accounts access a camera-based scanner to verify tickets and mark them as "Used" in real-time.
    * **🔗 Physical-to-Digital Bridge:** App-level deep linking where scanning a physical poster (QR/NFC) redirects the student directly to that specific event’s detail page.

---

### 👥 2. Community Hub (Lead: Jason)
*Focus: Multimodal Content & Social Interaction.*

* **Basic Requirements (CRUD & Logic):**
    * **Unified Posting:** Both Student and Society accounts can create media-rich posts including titles, descriptions, and category tags.
    * **Engagement Engine:** Nested comment sections for every post and a reaction system (Likes/Hearts) with live counters.
    * **Feed Optimization:** Implementation of sorting (Recent vs. Popular) and filtering (Category: "Lost & Found", "Study Buddies"). Includes **Lazy Loading/Pagination** to ensure app performance.
* **Extra Effort (Advanced Tech):**
    * **📸 Native Camera:** Direct integration with the device camera for instant photo uploads.
    * **📍 Geo-Tagging:** Specifically for "Lost & Found," allowing users to mark the exact GPS coordinates where an item was found.
    * **💬 Real-time P2P Messaging:** A contact/friend system with private chatrooms to allow users to inquire about posts (e.g., "Is the study group still open?") without public comments.

---

### ⏰ 3. Schedules & Reminders (Lead: Pei Tung)
*Focus: Personal Productivity & Hardware Sensor Integration.*

* **Basic Requirements (CRUD & Logic):**
    * **Student Timetable:** A dedicated student-only feature to manage custom schedules for classes, exams, or personal tasks. Includes custom labeling for easy filtering.
    * **Dynamic Reminder Logic:** In-app logic to calculate reminder triggers based on schedule start times (e.g., "Remind me 30 mins before"). Data is stored as absolute timestamps in the database.
    * **Alert System:** Execution of local notifications and haptic feedback (vibration) when a reminder is triggered.
* **Extra Effort (Advanced Tech):**
    * **📍 Venue Pinning:** Linking specific campus locations (DKB, Arena, etc.) to schedule items using GPS coordinates.
    * **📳 Haptic & Notification Engine:** Utilizing the phone's vibration motor for distinct alert patterns.
    * **🌙 Intelligent "Study Mode":** A hardware-aware feature that utilizes the **Ambient Light Sensor** and **Gyroscope**. When activated, the app automatically mutes the device if it detects the phone is placed "Face Down" on a surface.

---


## 🚀 Getting Started for Teammates

1. **Clone the Repo:**
   `git clone [your-repo-url]`
2. **Setup Flutter:**
   Run `flutter pub get` in the terminal to install dependencies.
3. **Environment:**
   Ensure you have the `SUPABASE_URL` and `ANON_KEY` in your local configuration.
   **Modify the ".env.example" file based on the instruction inside**
5. **Git Workflow:**
   * **PULL** every morning before starting.
   * **BRANCH** out for your features (`git checkout -b feat-[yourname]`).
   * **COMMIT** small, meaningful changes.
   * **PUSH** only when your code is tested and building.
VIDEO reference: https://drive.google.com/file/d/1faOWc4cJFclxo5OIh-CPH6P0DQbIsiDo/view?usp=sharing


---
