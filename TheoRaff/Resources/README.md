# Resources

Shared by both.

Asset catalog, garment cutouts, USDZ models, catalog JSON and fonts. Crop every top cutout onto the same canvas with the shoulder seams at the same pixel positions.

## catalog.json

The garments and the try-on deck, loaded by `Catalog` in Services.

- `garments` lists every item once, with the fields of `Garment`: `id`, `name`, `category` (`eyewear`, `headwear`, `top`, `bottom` or `fullLook`), `imageName` (asset catalog name), `modelName` (USDZ file name, required for eyewear and headwear), `searchQuery` (the Find it search) and optional `tags`.
- `outfits` are the cards in the deck: `id`, `name` and `garmentIDs`, at most one garment per category. A garment can be in several outfits, or in none to show only in the closet.
- `BundledCatalogTests` check the file, so run the tests after editing it.
