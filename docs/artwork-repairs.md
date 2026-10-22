# Artwork repairs

## 2026-10-22 — duplicate forelegs

Reviewed all 96 source frames (8 monsters × 3 actions × 4 frames). Fixed duplicated grounded
forelegs in Mizutsune's four working frames and Velkhana's third waiting frame. The other
91 frames were retained after visual inspection.

The five edits used the built-in image generation tool with the existing frames as edit targets.
Outputs were resampled to 256 × 256 with alpha preserved, aligned to the original visible height
and ground baseline. Frame counts, timing, and character scale metadata remain unchanged.

### Prompts

#### `Resources/Characters/mizutsune/working/0.png`

```text
Use case: precise-object-edit
Asset type: a corrected single animation frame for an existing pixel-art desktop pet
Input image 1 is the EDIT TARGET: Mizutsune working frame 0. Input image 2 is an ANATOMY REFERENCE ONLY: the same character with the correct lifted-foreleg anatomy.
Task: Correct ONLY the duplicated front leg in image 1. The left foreleg is already raised beside the mouth. The erroneous extra grounded foreleg is still visible underneath the left side of the chest, with a small planted foot to the LEFT of the large nearer planted forepaw. Delete that obsolete lower leg and its three-clawed ground foot, exposing transparent background. In the 256 x 256 input this erroneous leg/foot is roughly x=46..79, y=188..234. Match the clean two-foreleg anatomy of image 2: ONE forepaw raised beside the face, ONE forepaw planted at the bottom center with the pink fin, and the hind legs remain at the rear.
Strict invariants: keep the exact target image's face, eyes, mouth, crest, whiskers, pink/cream/yellow colors, pixel-art texture, neck, back, curled tail, raised arm, existing planted nearer foreleg, rear haunch and rear foot, and BOTH bubbles completely unchanged. Keep the same pose, silhouette extent, scale, canvas position, and baseline. Do not import the different head pose or missing bubbles from image 2. Preserve transparency. Do not add a fourth visible paw or substitute a new foot in the deleted space. Only delete the duplicated foreleg and clean its junction to the chest. No text, no labels, no borders, no background, no ground shadow. Return exactly one square transparent sprite matching image 1's framing, ideally 256 x 256.
```

#### `Resources/Characters/mizutsune/working/1.png`

```text
Use case: precise-object-edit
Asset type: a corrected single animation frame for an existing pixel-art desktop pet
Input image 1 is the EDIT TARGET: Mizutsune working frame 1. Input image 2 is an ANATOMY REFERENCE ONLY: the same character with the correct lifted-foreleg anatomy.
Task: Correct ONLY the duplicated front leg in image 1. Preserve the distinctive bubble sizes and positions of this target frame exactly. The left foreleg is already raised beside the mouth. The erroneous extra grounded foreleg is still visible underneath the left side of the chest, with a small planted foot to the LEFT of the large nearer planted forepaw. Delete that obsolete lower leg and its three-clawed ground foot, exposing transparent background. In the 256 x 256 input this erroneous leg/foot is roughly x=46..79, y=188..234. Match the clean two-foreleg anatomy of image 2: ONE forepaw raised beside the face, ONE forepaw planted at the bottom center with the pink fin, and the hind legs remain at the rear.
Strict invariants: keep the exact target image's face, eyes, mouth, crest, whiskers, pink/cream/yellow colors, pixel-art texture, neck, back, curled tail, raised arm, existing planted nearer foreleg, rear haunch and rear foot, and ALL original bubbles or sparkles completely unchanged. Keep the same pose, silhouette extent, scale, canvas position, and baseline. Do not import the different head pose or missing bubbles from image 2. Preserve transparency. Do not add a fourth visible paw or substitute a new foot in the deleted space. Only delete the duplicated foreleg and clean its junction to the chest. No text, no labels, no borders, no background, no ground shadow. Return exactly one square transparent sprite matching image 1's framing, ideally 256 x 256.
```

#### `Resources/Characters/mizutsune/working/2.png`

```text
Use case: precise-object-edit
Asset type: a corrected single animation frame for an existing pixel-art desktop pet
Input image 1 is the EDIT TARGET: Mizutsune working frame 2. Input image 2 is an ANATOMY REFERENCE ONLY: the same character with the correct lifted-foreleg anatomy.
Task: Correct ONLY the duplicated front leg in image 1. Preserve the distinctive bubble sizes and positions of this target frame exactly. The left foreleg is already raised beside the mouth. The erroneous extra grounded foreleg is still visible underneath the left side of the chest, with a small planted foot to the LEFT of the large nearer planted forepaw. Delete that obsolete lower leg and its three-clawed ground foot, exposing transparent background. In the 256 x 256 input this erroneous leg/foot is roughly x=46..79, y=188..234. Match the clean two-foreleg anatomy of image 2: ONE forepaw raised beside the face, ONE forepaw planted at the bottom center with the pink fin, and the hind legs remain at the rear.
Strict invariants: keep the exact target image's face, eyes, mouth, crest, whiskers, pink/cream/yellow colors, pixel-art texture, neck, back, curled tail, raised arm, existing planted nearer foreleg, rear haunch and rear foot, and ALL original bubbles or sparkles completely unchanged. Keep the same pose, silhouette extent, scale, canvas position, and baseline. Do not import the different head pose or missing bubbles from image 2. Preserve transparency. Do not add a fourth visible paw or substitute a new foot in the deleted space. Only delete the duplicated foreleg and clean its junction to the chest. No text, no labels, no borders, no background, no ground shadow. Return exactly one square transparent sprite matching image 1's framing, ideally 256 x 256.
```

#### `Resources/Characters/mizutsune/working/3.png`

```text
Use case: precise-object-edit
Asset type: a corrected single animation frame for an existing pixel-art desktop pet
Input image 1 is the EDIT TARGET: Mizutsune working frame 3. Input image 2 is an ANATOMY REFERENCE ONLY: the same character with the correct lifted-foreleg anatomy.
Task: Correct ONLY the duplicated front leg in image 1. Preserve the distinctive bubble sizes and positions of this target frame exactly. The left foreleg is already raised beside the mouth. The erroneous extra grounded foreleg is still visible underneath the left side of the chest, with a small planted foot to the LEFT of the large nearer planted forepaw. Delete that obsolete lower leg and its three-clawed ground foot, exposing transparent background. In the 256 x 256 input this erroneous leg/foot is roughly x=46..79, y=188..234. Match the clean two-foreleg anatomy of image 2: ONE forepaw raised beside the face, ONE forepaw planted at the bottom center with the pink fin, and the hind legs remain at the rear.
Strict invariants: keep the exact target image's face, eyes, mouth, crest, whiskers, pink/cream/yellow colors, pixel-art texture, neck, back, curled tail, raised arm, existing planted nearer foreleg, rear haunch and rear foot, and ALL original bubbles or sparkles completely unchanged. Keep the same pose, silhouette extent, scale, canvas position, and baseline. Do not import the different head pose or missing bubbles from image 2. Preserve transparency. Do not add a fourth visible paw or substitute a new foot in the deleted space. Only delete the duplicated foreleg and clean its junction to the chest. No text, no labels, no borders, no background, no ground shadow. Return exactly one square transparent sprite matching image 1's framing, ideally 256 x 256.
```

#### `Resources/Characters/velkhana/waiting/2.png`

```text
Use case: precise-object-edit
Asset type: a single repaired transparent pixel-art animation frame
Input image is the EDIT TARGET, a chibi Velkhana from Monster Hunter, waiting frame 2. Correct ONLY the duplicate front leg. The forepaw on the left side of the chest is already raised beside the face, but the old lower foreleg and its foot are still planted below it at the far left of the ground. There are five visible legs as a result. DELETE that obsolete dark blue diagonal leg and planted paw at approximately x=39..69, y=198..237 of the original 256x256 image, exposing transparent background. Retain the raised forepaw at x=38..60,y=173..198; retain the nearer planted foreleg with ice plates at x=72..101,y=185..238; retain BOTH hind legs underneath the hips at x=110..157,y=218..239. The result has exactly two forelegs (one raised, one planted), two hind legs and the two existing wings. Do not create any replacement paw or shadow inside the cleared gap.
Strict invariants: preserve the exact face, head, icy crest, wing shapes, blue-white palette, pixel-art texture, posture, tail, all non-erroneous legs, image framing, silhouette extent, scale, ground baseline and position. Only remove the duplicate lower foreleg and clean the small chest junction. No restyling or new animation pose. No text, border, ground, labels, or backdrop. Preserve genuine alpha transparency. Return exactly one square sprite with the same framing, ideally 256x256.
```
