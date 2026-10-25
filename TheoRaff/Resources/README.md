# Resources

Shared by both.

Asset catalog, garment cutouts, USDZ models, catalog JSON and fonts. Crop every top cutout onto the same canvas with the shoulder seams at the same pixel positions.

## catalog.json

The garments and the try-on deck, loaded by `Catalog` in Services.

- `garments` lists every item once, with the fields of `Garment`: `id`, `name`, `category` (`eyewear`, `headwear`, `top`, `bottom`, `fullLook` or `shoes`), `imageName` (asset catalog name), `modelName` (USDZ file name, required for eyewear and headwear), `searchQuery` (the Find it search) and optional `tags`.
- `outfits` are styled looks: `id`, `name` and `garmentIDs`, at most one garment per category. A garment can be in several outfits, or in none to show only in the closet.
- The Try On deck isn't read from `outfits`. It's `Catalog.liveLooks`, one card per eyewear or headwear garment, because only those can be shown live on the camera. Clothes are tried on with AI from the closet.
- `BundledCatalogTests` check the file, so run the tests after editing it.

## Garment photos

Every garment photo is a transparent PNG on the shared 768 x 960 canvas (`GarmentCanvas` in Shared). Tops have their shoulder seams at (234, 320) and (534, 320). Everything else is centred. `tools/prep-garment.swift` cuts a photo out of its background, places it and saves it as `<garment-id>.imageset`:

    xcrun swift tools/prep-garment.swift ~/Downloads/hoodie.jpg pink-velour-hoodie --top --preview /tmp/check.png

- Use `xcrun swift`, not a plain `swift` from swiftly, so the compiler matches Xcode's SDK.
- Photos on a plain background cut out best: flat lays or ghost mannequins, not worn.
- For tops, check the preview. If the red dots aren't on the shoulder seams, add `--grid /tmp/grid.png`, read the seam pixels off the grid, and pass them as `--shoulders leftX,leftY,rightX,rightY`.
- `--clear-above Y` erases a hanger hook above row Y.
- For eyewear and headwear that only exist as USDZ models, render a front view with `xcrun swift tools/render-usdz.swift <model.usdz> /tmp/front.png`, or a three-quarter shot in Blender with a transparent background, using copies of the `Cam`, `Key`, `Fill` and `Rim` objects from `art/y2k_hats.blend`. Then run `prep-garment.swift` on it with `--keep-background`.
- Then add the garment to `catalog.json` with the same id as its `imageName`. Every garment needs its own photo: `BundledCatalogTests` fails if two share one.

The first batch is real eBay listing photos (sellers' photos, demo use only). The Sport Shades and White Shades photos are front renders of their USDZ models. The studded glasses and the hats are three-quarter renders from Blender.

## Hat models

The four `Y2K_*` hats (leopard bucket hat, trucker cap, slouch beanie, striped pom beanie) were made in Blender. The source is `art/y2k_hats.blend`, which has a reference head (`RefHead`, not exported) and the leopard texture packed in.

Every hat is built around the same reference head so the AR view can wear it without per-model tweaks:

- Units are metres.
- The origin is halfway between the eyes.
- +y is up and +z points out of the face, matching ARKit's face anchor.

`ARViewContainer` moves the hat to the wearer's eye midpoint, scales it by their eye distance (`HatFit`), and puts an invisible head-shaped occluder inside it so the far side of the brim hides behind the head. `HatFitTests` loads every hat and checks it follows this layout.

To export from Blender: select one hat, then File → Export → USD with `.usdz` as the extension, Convert Orientation on (forward −Z, up Y), Triangulate on, and Export Lights and Cameras off. A new hat needs the same origin and scale: put it on `RefHead` and export it in place.

## Original Y2K eyewear

Ice Blue Rimless, Candy Pink Ovals and Amber Wrap Shades are original RetroFit models, made procedurally in Blender with no third-party geometry, textures or branding. Each has its own three-quarter product photo and a compact USDZ (under 100 KB). They appear in Closet and automatically join the live Try On deck through `Catalog.liveLooks`.

The source is `art/y2k_eyewear.blend`, with one scene per style. Rebuild it with Blender's `--python tools/build-eyewear.py` (or run that file in Blender's scripting workspace). The script uses copies of the hat product-shot rig, writes previews to `build/eyewear-previews`, exports selected meshes only, and restores the existing scene without saving it. Re-run `prep-garment.swift <preview> <id> --keep-background` for each preview.

The exports use metres, +y up and +z forward, with lenses in front and temples extending towards -z. They use the existing glasses bounds-based fit without model-specific offsets. `EyewearAssetTests` loads the actual bundled files through `FaceModelLibrary`, checks their dimensions, and verifies lens positions after the current AR fitting transform.

The lenses are tinted see-through plastic, like the accessories below. The script exports to a temporary `.usdc`, copies each material's Alpha into the USD opacity (Blender writes every material as opaque), then packages the USDZ. Each lens is one curved sheet stored once facing out and once facing the eyes. RealityKit culls the back faces of every USD material, and the export marks the see-through meshes `doubleSided = 0` so SceneKit does too. So only one copy draws: no streaks from two layers sorting, and no doubled tint. Cycles can't cull back faces, so the previews render only the outward copy. `EyewearAssetTests` checks every lens loads as a see-through tint and that each lens triangle has a twin facing the other way.

### Violet Butterfly Shades

`Y2K_Violet_Butterfly.usdz` adds an original swept butterfly frame with polished silver rims, ten small crystal accents and violet gradient lenses. Its gradient texture is embedded in the USDZ; the 161 KB file has 9,564 triangles. The editable source is `art/y2k_violet_butterfly.blend`, with the image packed in. Its own Blender render is `violet-butterfly-shades.imageset`, prepared on the shared 768 x 960 canvas.

It has no build script, so `tools/patch-violet-butterfly.py` makes the shipped USDZ's lenses see-through in place. It copies the source's Alpha values into the USD opacity and turns each lens's closed shell into a two-way sheet like the other eyewear. Run it again after any new export from the source:

    /Applications/Blender.app/Contents/MacOS/Blender -b art/y2k_violet_butterfly.blend --python tools/patch-violet-butterfly.py

The model uses the same coordinates and bounds-based glasses fit as the other eyewear. `EyewearAssetTests` checks its loading, dimensions, fitted lens positions, catalog/deck entry and embedded gradient material.

## Y2K accessories

Four original pieces, modelled in Blender with no third-party geometry, textures or branding:

| Garment | Model | Tris | Size |
| --- | --- | --- | --- |
| Pastel Butterfly Clips: six glitter-rimmed clips along the front hairline | `Y2K_Butterfly_Clips` | 20,376 | 893 KB |
| Rhinestone Tiara: silver crown with a faceted pink heart | `Y2K_Rhinestone_Tiara` | 9,042 | 389 KB |
| Aqua Tinted Visor: see-through brim, terry band, rhinestone heart | `Y2K_Tinted_Visor` | 8,956 | 385 KB |
| Gold Bamboo Hoops: segmented hoops hanging from the earlobes | `Y2K_Bamboo_Hoops` | 6,912 | 86 KB |

They're `headwear`, so they ride in the AR view's hat slot: built on `RefHead` with the hats' layout (metres, origin between the eyes, +y up, +z out of the face), moved to the eyes and scaled by `HatFit`, with the head occluder hiding whatever goes behind the head. They join the live Try On deck through `Catalog.liveLooks`. One headwear item is worn at a time, so the hoops can't be combined with a hat yet.

The source is `art/y2k_accessories.blend`: scene `Y2K_Accessories` has one collection per accessory on `RefHead`, and `Y2K_Accessory_Shots` has the product-photo layouts and a copy of the hat photo rig. Its Text Editor holds the scripts that built everything: one per accessory, `y2k_export_accessories.py` to write the USDZs into this folder, and `y2k_product_shots.py` to render the closet photos into `build/accessory-previews`. Run `prep-garment.swift <png> <garment-id> --keep-background` on each render.

Blender's USD export writes every material as opaque, so the export script copies each material's Alpha into the USD opacity before packaging. RealityKit reads that into the base colour's alpha. Translucent parts are single sheets stored once facing each way, not thin closed shells. RealityKit culls back faces (it ignores the meshes' `doubleSided` flag), so only one copy draws from any angle. That avoids the streaks of two see-through layers sorting against each other, and the tint never doubles.

`AccessoryAssetTests` loads the shipped files through `FaceModelLibrary` and checks each sits where it's worn, that no vertex sinks inside the head occluder, and that the wings and brim stay see-through. `HatFitTests` keeps checking the four hats.
