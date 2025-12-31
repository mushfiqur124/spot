Product Requirement Document: Spot (MVP)
1. The Core Idea
Fitness tracking has too much friction. If tracking a workout takes more effort than the workout itself, you won't do it.

Spot removes that friction. It replaces forms, buttons, and spreadsheets with a simple conversation. You talk to the app like a gym buddy ("I'll spot you"), and it handles the boring part—writing it down, doing the math, and remembering it for next time.

2. The Solution
We are building a Native iOS App that functions as an intelligent wrapper around an on-device LLM (Apple Foundation Model).

The "Vibe"
Name: Spot.

Visual Style: "Liquid Glass". Modern iOS/visionOS aesthetic. heavily relying on translucency, blur, and depth rather than flat colors.

Interaction: Natural language texting. You say "Hit push day, 80lbs on incline." The AI understands, logs it, and replies with context ("That's 5lbs more than last week, nice.").

Privacy: Local-first. No cloud database. All data stays on the user's device.

3. Key Features (MVP)
A. The Chat Interface
Home Screen: A clean, glass-morphism chat window. No complex dashboards yet.

Input: A floating "capsule" text field.

Quick Actions: "Pills" (glassy chips) above the input for quick starts (e.g., "Start Workout", "What did I do last time?").

Streaming: Responses typ out in real-time to feel alive.

B. Intelligent Context (The "Brain")
The AI acts as a Fitness Trainer Persona. It isn't just a chatbot; it has access to specific Tools to read and write data.

Tool 1: Log Workout. Extracts structured data (Exercise Name, Weight, Reps, Muscle Group) from natural text and saves it to SwiftData.

Tool 2: Fetch History. Checks previous sessions before replying. If you say "Chest day," it checks if you hit chest yesterday and warns you about recovery.

Tool 3: Plate Calculator. Automatically converts gym slang ("1 plate and a 25") into total weight ("135 lbs") so the user doesn't have to do math.

Tool 4: PR Manager. Checks the user's all-time bests and reminds them of their PR before a heavy set.

C. Data Management
Storage: SwiftData. Modern, robust local persistence.

Fuzzy Matching: The system handles naming variations. "MTS Incline" and "Incline Machine" map to the same ExerciseID so history remains accurate.

4. Technical Stack
Platform: iOS 18+ (Swift 6).

Framework: SwiftUI (Declarative UI).

AI Engine: Apple Foundation Model (via Apple Intelligence or on-device CoreML equivalent).

IDE: Xcode (Build/Test) + Cursor (Code Generation).

Project Management: Linear (Ticket tracking).

5. User Stories (MVP)
The "Start" Flow: User opens app -> Taps "Start Workout" pill -> AI asks "What are we hitting today?" -> User replies "Push day".

The "Log" Flow: User types "Incline bench 135 for 8" -> AI confirms "Logged. That's a solid set. You did 145 last time, feeling tired?"

The "Recall" Flow: User asks "What did I do for legs last time?" -> AI queries database -> AI responds "Last leg day was Tuesday. You did Squats (225x5) and Leg Press."