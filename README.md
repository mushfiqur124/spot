# Spot

A chat-based fitness tracking app for iOS that removes the friction from logging workouts. Instead of filling out forms and tapping buttons, you simply talk to Spot like a gym buddy—it understands natural language, logs your sets, tracks your progress, and remembers everything for next time.

## Features

- **Natural Language Interface**: Log workouts through simple conversation ("Incline bench 135 for 8" → automatically logged)
- **Intelligent Context**: AI checks your workout history before replying, warns about recovery, and tracks PRs
- **Plate Math**: Automatically converts gym slang ("1 plate and a 25") into total weight ("135 lbs")
- **Privacy-First**: All data stays on your device using SwiftData—no cloud database, no tracking
- **Modern Design**: Beautiful "liquid glass" aesthetic with translucency, blur, and depth

## Technical Details

- **Platform**: iOS 18+ (Swift 6)
- **Framework**: SwiftUI
- **AI Engine**: Apple Foundation Model (on-device via Apple Intelligence)
- **Storage**: SwiftData for local persistence
- **Architecture**: MVVM with SwiftData models

## Requirements

- iOS 26.0+
- Device with Apple Intelligence support
- Xcode 16+

## Getting Started

1. Open `Spot.xcodeproj` in Xcode
2. Build and run on a compatible device or simulator
3. Complete onboarding to set up your profile
4. Start chatting with Spot to log your workouts!

## License

[Add your license here]

