# Player artwork

Original artwork: RetroLabStudioCo, Free 8-Direction Hero - Adventurer.
The original terms remain in LICENSE.txt.

The built-in image generation tool edited the character into a bookworm with
large black square glasses and a burgundy hardcover book instead of a spear.
The eight direction rows retain the south, southeast, east, northeast, north,
northwest, west, southwest order.

nerd_source.png preserves the generated source atlas. Its 16 columns contain
four idle, eight walk, and four dash frames. Each animation strip was extracted
and resized with nearest-neighbor sampling to 32 x 32 pixels per frame, with
binary alpha for the game.

Walk timing is 12 FPS in resources/player/player_sprite_frames.tres.

## Initial edit prompt

Edit this existing production pixel-art spritesheet in place. It is an EXACT 2048 x 1024 atlas with 16 columns and 8 rows, each cell EXACTLY 128 x 128 pixels; each original game pixel is enlarged to a hard 4 x 4 square. Preserve the exact image size, cell boundaries, frame count (128 sprites), sprite scale, positions, ground line, per-frame walking leg poses, dash poses/speed lines, all eight facing directions, empty margins, transparent alpha, and the existing limited-palette pixel-art style. Never merge, add, delete, rearrange or rescale frames. This is an edit target, NOT a style reference. Make just these character-design edits consistently in EVERY cell: turn this same brown-haired blue-clothed red-scarf backpack-wearing adventurer into a nerdy bookworm; REMOVE THE ENTIRE SPEAR (shaft and bright tip) from every frame and replace it with one chunky closed hardcover BOOK held at the hand, with a clearly visible burgundy cover and cream page edges; add LARGE BLACK SQUARE EYEGLASSES over the existing eyes. Spectacles should read as two big square outlined lenses connected by a bridge in front-facing cells, a foreshortened pair in diagonal front views, and a single visible lens and temple arm in side views. In back and back-diagonal views, only show the appropriate temple arm if visible, never draw a face or eyes on the back of the head. Keep the same body silhouette, hair, clothing palette, backpack, and original action poses. Book must follow the hand per frame and face the correct perspective consistently. No spear remnants anywhere. No text, labels, background, checkerboard, grid lines or extra props. Preserve transparent background. Rows top-to-bottom: south/front, southeast, east/right, northeast, north/back, northwest, west/left, southwest. Columns left-to-right: 4 idle frames, 8 walk frames, 4 dash frames. CRITICAL: exact 16x8 regular grid of 128-pixel cells, all 128 frames retained, only book and glasses design changes, true crisp 32px pixel character look enlarged 4x without antialiasing.

## Final cleanup prompt

Make ONE targeted cleanup to this exact transparent 16-column by 8-row pixel-art animation atlas, preserving every sprite frame in its exact same position, size, leg pose, eight facing directions and animation sequence. The character is now a nerdy bookworm with huge black square glasses and a burgundy book. HOWEVER THE OLD SPEAR WAS NOT FULLY REMOVED: in many cells there is still a WHITE/GRAY spear tip and a thin upright pole sticking up beside the head or behind the shoulder. Remove EVERY remnant of that long weapon from EVERY sprite: no white spearhead, no shaft, no pole, no staff behind the backpack, no long weapon anywhere. Preserve the existing brown backpack and skin-colored hands. The ONLY handheld object must be the burgundy hardcover BOOK with cream page edges, carried at the hand beside the torso, matching the current poses and facing direction. Keep the oversized glasses where the face is visible, including foreshortened glasses in side views and just temples in rear views. Preserve crisp low-resolution pixel art; eliminate stray colored fringe noise around sprites; fully transparent empty pixels. Preserve EXACTLY the input atlas dimensions, 16 columns, 8 rows, all 128 cells with consistent spacing. Do not crop edges, reposition, add or omit frames, paint background, add text, or change clothing or hair. Do not treat the atlas as an illustration; it must remain a usable animation spritesheet.
