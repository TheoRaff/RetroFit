# RetroFit Pitch Deck Brief

Use this brief to build, or rebuild, the RetroFit judging deck. It's written so you can paste it into any slide tool or AI and get the same deck.

## Context

- **Event:** HackNotts '26, a 24-hour hackathon at the University of Nottingham (Sat 24 Oct 12:00 to Sun 25 Oct 12:00, judging Sun 13:15).
- **Team:** Theo Rook (AR tracking and UI design) and Rafferty "Raff" Carter-Lazenbury (services, AI rendering, backend and catalog).
- **Product:** RetroFit, an iPhone app for trying on Y2K fashion before you buy it, then finding it second-hand.
- **Audience:** hackathon judges. They are technical, short on time, and seeing many teams. They reward a clear problem, a working demo and honest engineering.
- **Talk length:** 2 to 3 minutes, then a live demo on the phone. The slides set up the demo; they don't replace it.

## What RetroFit does

1. **Live AR try-on:** the front camera tracks your face (ARKit) and puts 3D Y2K glasses and hats on you in real time. You swipe through a deck of 11 looks, and tap Like to save the pieces you love.
2. **AI try-on:** pick any garment, or build an outfit of several pieces. After a countdown, RetroFit takes a photo and an AI model renders you wearing it, one garment after another.
3. **The closet:** 26 garments with search, category filters (Tops, Bottoms, Head) and a Saved view. Add pieces to "Your outfit" to try them on together.
4. **Find it second-hand:** one tap searches Depop, Vinted or eBay for the piece. That keeps it sustainable and affordable.
5. **Two looks:** a Classic Windows 2000 theme and a pink iridescent Y2K Chrome theme. Switch between them on the Profile tab and the whole app restyles instantly.

## How it's built

- **App:** native SwiftUI for iOS 18+, built in Xcode. The design system is our own: a Win95 component kit (bevels, title bars and dialogs) that also renders the Y2K Chrome theme. Theme tokens use Swift Observation, so changing the theme updates every screen live.
- **AR:** ARKit face tracking (ARFaceAnchor) with RealityKit. The glasses and hats are USDZ models, and we modelled the hats in Blender. Each model is fitted to your eye positions and head pose every frame.
- **AI try-on:** fal.ai's virtual try-on model (image-apps-v2). The app never holds the AI key. It calls our Vercel serverless function (TypeScript), which checks an app token and queues the job on fal.ai. The app then polls the same function for progress ("2 ahead of you") and shows a buffering bar until the image is ready.
- **Data:** a bundled JSON catalog of 26 garments and 11 looks, with trimmed product photos.
- **Quality:** 168 unit tests (Swift Testing). Each of us owned folders, and every change went through branches and PRs.

## Deck: 5 slides, 16:9

**Slide 1: What it is.** Show the RetroFit wordmark in liquid chrome and the one-line promise: "Try on Y2K fashion with AR and AI, then find it second-hand." Add three feature pills: Live AR try-on, AI try-on, Find it second-hand. Add one hero phone screenshot of the closet.

**Slide 2: Inside the app.** Show four phone screenshots in the Y2K Chrome theme, each with a short caption:
1. The closet grid.
2. The "Try this on with AI?" prompt.
3. The Find it second-hand picker (Depop, Vinted, eBay).
4. The Profile theme switch.

**Slide 3: Prefer it Classic?** The same four screens in the Classic Windows 2000 theme, laid out exactly like slide 2, to show the app has two complete looks:
1. The Classic closet.
2. The "Try this on with AI?" prompt as a Windows message box.
3. The Find it picker, same shops.
4. The Profile theme switch with Classic selected.

**Slide 4: How we built it.** Draw a simple flow: iPhone (SwiftUI + ARKit + RealityKit), then Vercel function (TypeScript), then fal.ai virtual try-on, then the result back on the phone. Under each step, add a card: Live AR try-on, Our own design system, and Second-hand search. No stat callouts.

**Slide 5: Finish.** A big "Let's try it on" demo cue, the team names, HackNotts '26, and a thank-you.

## Visual system: Y2K pink iridescent

- **Background:** a holographic pastel mesh of pink (#FFD3EC), lilac (#EEDCFF), sky blue (#CFE6FF), mint (#CFF5E7) and pearl white. Scatter white four-point sparkles with a soft pink glow.
- **Text:** deep indigo (#2B1F5C) for titles and body, and raspberry pink (#B0126A) as the accent. Never put light text on the pastel background.
- **Lettering:** the wordmark and the big closing line are liquid chrome: a silver gradient with a dark horizon band and an ink edge, like the app's own titles.
- **Cards:** frosted pearl glass with a soft lilac shadow and rounded corners.
- **Phones:** screenshots sit in rounded phone frames with a chrome rim.
- **Fonts:** Arial Black for titles, Arial for body text, with the chrome lettering as images.
- **Avoid:** accent bars, underlines under titles, and walls of bullets. Keep each slide to one idea.

## Speaker notes: split between Theo and Raff (about 2:35)

- **Slide 1, Theo (~30 s):** the problem (you can't try Y2K pieces on before buying second-hand) and what RetroFit is.
- **Slide 2, Theo (~40 s):** a walk through the screens, ending on the Profile tab.
- **Slide 3, Theo (~15 s):** one switch turns the whole app Classic; same features, same components. Hand over to Raff.
- **Slide 4, Raff (~50 s):** the architecture, why the AI key lives on the server, the AR fitting, the design system and second-hand search.
- **Slide 5, Raff (~20 s):** thanks, then hand over to the live demo.
