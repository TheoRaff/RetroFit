# RetroFit

The app is called RetroFit. The Xcode project, target and folders are still named TheoRaff.

Our hackathon project.

## Open in Xcode

1. Clone the repo, then open `TheoRaff.xcodeproj` (Xcode 16 or newer).
2. Pick an iPhone simulator and press Run (⌘R).
3. Add new Swift files inside the `TheoRaff` folder. Xcode picks them up automatically, so the project file rarely changes.

### Folders

Each folder has one owner, which keeps project-file conflicts away.

- `TheoRaff/Tracking`: Person A. ARKit, Vision body pose, overlays.
- `TheoRaff/UI`: Person B. Screens and the chrome design system.
- `TheoRaff/Services`: Person B. Catalog and AI render calls.
- `TheoRaff/Resources`: shared. Assets, cutouts, models, fonts.
- `TheoRaff/Shared`: both. `Garment`, `Outfit` and `TryOnSession`, the contract between tracking and the app. Agree changes together.
- `TheoRaffTests`: unit tests. Run them with ⌘U.

### How the try-on screen works

- The deck is a list of outfits. Each outfit holds one garment per category, such as shades plus a hoodie.
- Swiping calls `showNext()` or `showPrevious()` to move between outfits.
- The Like button calls `likeCurrentOutfit()`, which saves the outfit's garments to the closet. `like(_:)` saves a single garment.
- Tracking reads `currentOutfit` and draws its garments on the camera view.

### Run on your iPhone

Two free Apple IDs can't share one bundle ID, so each person signs with their own settings.

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`. Git ignores this file.
2. Set `DEVELOPMENT_TEAM` to your Personal Team ID from Xcode > Settings > Accounts.
3. Set `BUNDLE_ID_SUFFIX` to something unique, such as `.raff` or `.theo`.
4. Don't pick a team in Xcode's Signing & Capabilities tab. That writes your team into the shared project file.

## Project notes

Add the project idea, setup instructions, and demo link here as the build takes shape.

Keep passwords and API keys out of the repository. Use local environment files and share an `.env.example` containing placeholder values when needed.

