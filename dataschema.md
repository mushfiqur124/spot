# Data Schema: Spot (SwiftData)

## 1. High-Level Architecture
The database is normalized to separate **Definitions** (what an exercise is) from **Logs** (what you actually did). This ensures that naming variations (e.g., "Bench" vs. "Bench Press") are handled gracefully and history remains accurate.

**Core Models:**
1.  **`Exercise`**: The master definition (e.g., "Barbell Squat"). Holds global stats like PRs.
2.  **`WorkoutSession`**: A container for a single trip to the gym (e.g., "Monday Leg Day").
3.  **`WorkoutExercise`**: The specific instance of an exercise performed within a session.
4.  **`WorkoutSet`**: The granular data (Weight, Reps) for that instance.

---

## 2. Detailed Models

### Model A: `Exercise` (The Master Definition)
*Acts as the single source of truth for a movement.*

| Property | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | Unique identifier. |
| `name` | `String` | **Unique**. The standardized name (e.g., "Incline Bench"). |
| `muscleGroup` | `String` | e.g., "Chest", "Back", "Legs". |
| `allTimeMaxWeight` | `Double?` | Cached PR for quick lookup (e.g., 225.0). |
| `allTimeMaxVolume` | `Double?` | Cached Max Volume (Weight * Reps). |
| `history` | `[WorkoutExercise]` | **Relationship (Inverse).** All instances of this exercise ever performed. |

**Cursor Implementation Rules:**
* **Uniqueness:** Enforce uniqueness on `name`.
* **Search Logic:** When a user logs an exercise, search this table first. If found, link to it. If not, create a new entry.

### Model B: `WorkoutSession` (The Event)
*Represents one specific workout day.*

| Property | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | Unique identifier. |
| `startTime` | `Date` | When the session started. |
| `endTime` | `Date?` | When the session finished. |
| `label` | `String` | e.g., "Push Day", "Morning Cardio". |
| `summary` | `String?` | AI-generated summary of the workout. |
| `exercises` | `[WorkoutExercise]` | **Relationship (Cascade Delete).** The list of exercises done this day. |

### Model C: `WorkoutExercise` (The Instance)
*The intersection table connecting a Session to an Exercise Definition.*

| Property | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | Unique identifier. |
| `notes` | `String?` | User notes (e.g., "Shoulder felt tight"). |
| `orderIndex` | `Int` | To maintain the order of exercises (1st, 2nd, 3rd). |
| `session` | `WorkoutSession?` | **Relationship.** The parent session. |
| `exercise` | `Exercise?` | **Relationship.** The link to the master definition. |
| `sets` | `[WorkoutSet]` | **Relationship (Cascade Delete).** The actual sets performed. |

**Computed Properties:**
* **`totalVolume`**: Returns sum of `(set.weight * set.reps)` for all sets in this instance.
* **`maxWeight`**: Returns the highest weight lifted in this instance.

### Model D: `WorkoutSet` (The Data)
*The atomic unit of work.*

| Property | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` | Unique identifier. |
| `setNumber` | `Int` | 1, 2, 3... |
| `weight` | `Double` | Weight in Lbs (or Kg, handled by user pref later). |
| `reps` | `Int` | Number of repetitions. |
| `rpe` | `Int?` | Optional: Rate of Perceived Exertion (1-10). |
| `isPR` | `Bool` | **Flag.** True if this specific set broke a previous record. |
| `workoutExercise` | `WorkoutExercise?` | **Relationship.** Parent instance. |

---

## 3. Business Logic (Service Layer)

Cursor must implement the following logic in the `WorkoutService`.

### A. The "Smart Match" (Fuzzy Matching)
* **Trigger:** When user inputs an exercise name (e.g., "MTS Incline Press").
* **Logic:**
    1.  Normalize string (lowercase, remove punctuation).
    2.  Check `Exercise` table for exact match.
    3.  If no match, perform fuzzy search (e.g., Levenshtein distance) against existing names.
    4.  **Goal:** Map "MTS Incline" -> "Incline Machine Press" to keep stats clean.

### B. PR (Personal Record) Check
* **Trigger:** Whenever a `WorkoutSet` is saved.
* **Logic:**
    1.  Fetch the parent `Exercise.allTimeMaxWeight`.
    2.  If `newSet.weight` > `allTimeMaxWeight`:
        * Update `Exercise.allTimeMaxWeight` with the new value.
        * Set `newSet.isPR = true`.
        * Return "New PR!" flag to the Chat UI so the AI can celebrate.

### C. Context Retrieval
* **Trigger:** User asks "What did I do for legs last time?"
* **Logic:**
    1.  Fetch `WorkoutSession` where `label` contains "Legs" OR `exercises` contains "Squat/Leg Press".
    2.  Sort by `startTime` descending.
    3.  Return the most recent object.