# Resources

Shared by both.

Asset catalog, garment cutouts, USDZ models, catalog JSON and fonts. Crop every top cutout onto the same canvas with the shoulder seams at the same pixel positions.

## catalog.json

The garments and the try-on deck, loaded by `Catalog` in Services.

- `garments` lists every item once, with the fields of `Garment`: `id`, `name`, `category` (`eyewear`, `headwear`, `top`, `bottom` or `fullLook`), `imageName` (asset catalog name), `modelName` (USDZ file name, required for eyewear and headwear), `searchQuery` (the Find it search) and optional `tags`.
- `outfits` are the cards in the deck: `id`, `name` and `garmentIDs`, at most one garment per category. A garment can be in several outfits, or in none to show only in the closet.
- `BundledCatalogTests` check the file, so run the tests after editing it.

## Garment photos

Every garment photo is a transparent PNG on the shared 768 x 960 canvas (`GarmentCanvas` in Shared). Tops have their shoulder seams at (234, 320) and (534, 320). Everything else is centred. `tools/prep-garment.swift` cuts a photo out of its background, places it and saves it as `<garment-id>.imageset`:

    xcrun swift tools/prep-garment.swift ~/Downloads/hoodie.jpg pink-velour-hoodie --top --preview /tmp/check.png

- Use `xcrun swift`, not a plain `swift` from swiftly, so the compiler matches Xcode's SDK.
- Photos on a plain background cut out best: flat lays or ghost mannequins, not worn.
- For tops, check the preview. If the red dots aren't on the shoulder seams, add `--grid /tmp/grid.png`, read the seam pixels off the grid, and pass them as `--shoulders leftX,leftY,rightX,rightY`.
- `--clear-above Y` erases a hanger hook above row Y.
- For eyewear and headwear that only exist as USDZ models, render a front view with `xcrun swift tools/render-usdz.swift <model.usdz> /tmp/front.png`, then run `prep-garment.swift` on it with `--keep-background`.
- Then add the garment to `catalog.json` with the same id as its `imageName`.

The first batch is real eBay listing photos (sellers' photos, demo use only). The sunglasses photos are renders of their USDZ models, and the hat photos are three-quarter renders from Blender.

## Hat models

The four `Y2K_*` hats (leopard bucket hat, trucker cap, slouch beanie, striped pom beanie) were made in Blender. The source is `art/y2k_hats.blend`, which has a reference head (`RefHead`, not exported) and the leopard texture packed in.

Every hat is built around the same reference head so the AR view can wear it without per-model tweaks:

- Units are metres.
- The origin is halfway between the eyes.
- +y is up and +z points out of the face, matching ARKit's face anchor.

`ARViewContainer` moves the hat to the wearer's eye midpoint, scales it by their eye distance (`HatFit`), and puts an invisible head-shaped occluder inside it so the far side of the brim hides behind the head. `HatFitTests` loads every headwear model and checks it follows this layout.

To export from Blender: select one hat, then File → Export → USD with `.usdz` as the extension, Convert Orientation on (forward −Z, up Y), Triangulate on, and Export Lights and Cameras off. A new hat needs the same origin and scale: put it on `RefHead` and export it in place.
