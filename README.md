# Fluffy

<img src="docs/previews/fluffy/icon.png" width="140" align="right" alt="Fluffy">

A fluffy ginger cat who lives on your iPhone, sits under your Mac's screen, and helps you out (with some attitude).

Talk to him through the phone. He can see your Mac's screen, point at things with his own cursor, look things up on the web, take meeting notes, and, when you ask, click, type and open apps for you. He's aloof and a little sassy about it, but he gets it done.

> **Credit:** Fluffy is built on **Bluey** by Riley Brown, a blueberry character with the same brains.
> Original project: [github.com/rbrown101010/bluey-by-riley](https://github.com/rbrown101010/bluey-by-riley).
> Fluffy changes the character, colours and personality, and fixes a few issues on newer macOS. All the clever parts are Riley's.

| Listening | Unimpressed | Pleased with himself | Napping |
| --- | --- | --- | --- |
| ![](docs/previews/fluffy/listening.png) | ![](docs/previews/fluffy/pointing.png) | ![](docs/previews/fluffy/happy.png) | ![](docs/previews/fluffy/resting.png) |

## What's different from Bluey

- **A new character:** a fluffy ginger tabby with green slit-pupil eyes, half-closed lids, twitching ears, swaying whiskers and a flicking striped tail, in all seven moods.
- **Ginger everywhere:** the Mac cursor has cat ears, and the speech bubbles, report cards and menu bar icon are ginger.
- **A new personality:** dry, unimpressed and a bit smug. Never says "meow".
- **Paste works in the OpenAI key box.** Menu bar apps have no Edit menu, so ⌘V did nothing before.
- **He can see the screen on macOS 27.** Apple's "accurate" text recognition hangs and fails there, which made him wrongly say Screen Recording was off. Fluffy uses the fast mode, which works.
- **The Mac app runs on Intel and Apple Silicon Macs.**

## What you need

- A Mac with **macOS 14** or later, and **Xcode** (free from the App Store).
- An **iPhone** with iOS 17 or later, and a USB cable.
- A free **Apple ID** (to put the app on your own phone).
- An **OpenAI API key** from [platform.openai.com](https://platform.openai.com/api-keys). He runs on OpenAI's realtime and transcription models, which you pay for per use.

## Set it up

### 1. Download

```
git clone https://github.com/Shaidhms/fluffy.git
cd fluffy
```

Or use **Code → Download ZIP** on this page and unzip it.

### 2. The Mac app

```
./scripts/build-mac.sh
open build/Fluffy.app
```

A ginger cat face appears in your menu bar.

1. Click it, choose **OpenAI Key…**, paste your key, and click **Save**.
2. When macOS asks, allow **Screen Recording** and **Accessibility** for Fluffy (System Settings → Privacy & Security). Then quit Fluffy and open it again, so the Screen Recording permission takes effect.

### 3. The iPhone app

1. Open `GooglyEyes.xcodeproj` in Xcode. (To regenerate it, install XcodeGen with `brew install xcodegen` and run `xcodegen generate`.)
2. Click the project → **Signing & Capabilities**. Under **Team**, pick your Apple ID (add it in Xcode → Settings → Accounts if it isn't there).
3. Change the **Bundle Identifier** to something of your own, like `com.yourname.fluffy`.
4. Plug in your iPhone and unlock it. Turn on **Developer Mode** (Settings → Privacy & Security → Developer Mode), and let the phone restart.
5. Pick your iPhone at the top of Xcode and press **Run** (▶).
6. The first time, the phone will say "Untrusted Developer". Go to Settings → General → **VPN & Device Management**, tap your Apple ID, tap **Trust**, then press Run again.
7. On the phone, allow **Local Network** and **Microphone**.

Keep the phone and Mac on the **same Wi-Fi**. The Mac's menu changes to "Phone connected".

> With a free Apple ID, the app keeps working for 7 days; then plug the phone in and press Run again. A free Apple ID also allows only 3 of your own apps on a phone at once.

## Using Fluffy

- **Double-tap** him on the phone (or press **⌥Space** on the Mac) to wake him. He listens quietly the whole time.
- **Press and hold** the phone screen to ask something, then let go. His reply pops up as a speech bubble on the Mac.
- Try "what's this?" with your mouse over something, "open youtube.com", or "look up the weather in Chennai".
- **Double-tap** again and he goes back to idly watching your mouse.

| Keys | What it does |
| --- | --- |
| ⌥Space | Wake him up / back to idle |
| ⌃⌥S | Stop him using the computer |
| ⌃⌥P | Fly to the mouse and point |
| ⌃⌥F | Follow the mouse on/off |
| ⌃⌥D | Go home, above the phone |
| ⌃⌥H | Hide / show his cursor |

**Meeting notes:** while he's awake, the phone records in five-minute chunks and the Mac writes transcripts with speaker labels to `~/Documents/Fluffy Notes/`. **Open Meeting Notes** in the menu opens the folder.

**Using the computer:** he only clicks or types when you ask, confirms before anything hard to undo, refuses password fields, and stops on ⌃⌥S. Turn it off any time with **Let Him Use the Computer** in the menu.

## Privacy

Your OpenAI key stays on your Mac in `~/Library/Application Support/Fluffy/keys.json`, readable only by you. It's never in this repo. The phone only ever gets short-lived keys from the Mac. What you say and what's on screen when he looks are sent to OpenAI to answer you.

## Troubleshooting

- **"I can't see the screen":** allow Screen Recording for Fluffy, then quit and reopen him. Then double-tap him twice on the phone to start a fresh conversation.
- **He keeps asking for permissions after every rebuild:** the app has no stable signature. Sign in to Xcode with your Apple ID once; the build script then signs with your Apple Development certificate and macOS remembers your choices.
- **The phone can't find the Mac:** same Wi-Fi on both, Fluffy open on the Mac, Local Network allowed on the phone. Tap the faint speaker button at the top right of the phone to pick your Mac.

## How it's built

- `Mac/`: the menu bar app (Swift package target `GooglyMac`): his cursor, screen reading, computer control, meeting notes, and the OpenAI session setup.
- `iOS/`: the iPhone app (SwiftUI): his face, voice and the hold-to-ask controls.
- `Shared/`: pairing between the two (Bonjour `_fluffy._tcp`) and the colours.
- `scripts/preview/`: renders his moods to pictures (`docs/previews/fluffy/`).

Built on [Bluey by Riley Brown](https://github.com/rbrown101010/bluey-by-riley). Fluffy by [Shaid](https://www.shaid360.com).
