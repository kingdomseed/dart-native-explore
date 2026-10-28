# Parent iOS runtime observations

The parent ran the real u3-outline fixture on the approved iPhone17 Pro simulator.

The initial run asserted that depth textures cannot use shared Metal storage. The parent changed the probe texture descriptor to private storage, matching existing render-target code. The next run completed without that assertion.

The skin off screenshot shows the blue selected quad. Outline and capture-only control show the selected quad magenta. Turning the mode off restores blue in skin-near-p05-off-return-3x.png. The unskinned payload shows the same failure: payload-off.png is yellow; payload-outline.png and payload-control.png are magenta. payload-mask.png contains the complete white sphere and bar silhouette. The main draw color-preservation gate therefore FAILS for both skinned and ordinary geometry. Capture-only control returns the main color unchanged in the compositor, so this observation does not depend on gold-outline blending. The first incorrect renderer state remains unproven.

The original same-scene probe temporarily replaces selected SCNGeometry materials and other node categories, renders through a separate SCNRenderer, waits for command-buffer completion, then restores them. The source restores the arrays; the pixels establish that this does not preserve the ordinary main draw in this experiment.

The parent also corrected selector updateNode to use encodeNodeCommandSpec and removed redundant generic animation controls only for this fixture. The source snapshot includes all three parent corrections.

The app and native log are stopped. The owned simulator was shut down through device_close. Android input is paused because the A142 foreground is an unrelated Google account dialog. The parent did not interact with it. Remaining animation, grid, width, sibling, and OpenGL verification is NOT_RUN. PR65 is unchanged and still draft with three passing checks, pending Fire and Wacom.
