# AI Tools Definition (Swift / Apple Intelligence)

These are the specific functions the Foundation Model can "call" to interact with the app's data.

## 1. Data Recording Tools

### `log_workout_session`
- **Purpose:** Starts a new workout entry in the database.
- **Parameters:**
  - `focus_area` (String): e.g., "Push", "Legs", "Cardio".
  - `date` (Date): Current timestamp.
- **Return:** `session_ID` (to link subsequent exercises to this session).

### `log_set`
- **Purpose:** Records a specific set for an exercise.
- **Parameters:**
  - `exercise_name` (String): The name of the movement (e.g., "Lat Pulldown").
  - `weight_lbs` (Double): The weight lifted.
  - `reps` (Int): Number of repetitions.
  - `rpe` (Int, optional): Rate of Perceived Exertion (1-10).
- **Logic:**
  - If `exercise_name` does not strictly match a database entry, perform fuzzy matching (e.g., "MTS High Row" -> "Machine High Row").

## 2. Data Retrieval Tools (Context & Memory)

### `get_recent_history`
- **Purpose:** Fetches what the user did the last few times they were at the gym.
- **Parameters:**
  - `limit` (Int): Number of past sessions to retrieve (default 3).
- **Return:** A summary string: "Monday: Legs, Wednesday: Pull."
- **Use Case:** Helping the user decide what to train today.

### `get_last_exercise_stats`
- **Purpose:** Retrieves the weight/reps performed the *last time* a specific exercise was done.
- **Parameters:**
  - `exercise_name` (String)
- **Return:** "Last time: 135lbs x 8 reps on Oct 12."
- **Use Case:** Progressive overload validation.

### `get_personal_record`
- **Purpose:** checks the all-time max weight for an exercise.
- **Parameters:**
  - `exercise_name` (String)
- **Return:** "PR: 225lbs x 1 rep."

## 3. Utility Tools

### `calculate_plate_math`
- **Purpose:** Converts "gym slang" into total weight.
- **Parameters:**
  - `input_string` (String): e.g., "1 plate and a 25".
- **Logic:**
  - Bar = 45 lbs.
  - "Plate" = 45 lbs (per side).
  - Formula: (Plates * 2) + Bar + (Small_Weights * 2).
- **Return:** Total weight in lbs (Int).