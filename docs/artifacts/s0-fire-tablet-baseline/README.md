# Fire tablet baseline (2026-10-01)

Device: Amazon Fire KFTUWI, Android 11 (API 30), Mali-G52 MC2, Vulkan 1.1,
1920×1200 landscape. Build: `dn run -d GN434J02409203LD --release`.

| Check | Result | Evidence |
|---|---|---|
| Scene view starts | **Failed** before the fix: `NoClassDefFoundError: java/lang/ref/Cleaner` from `JoltPhysicsObject.startCleaner()` (API 33+). Passes with the API guard. | `before-cleaner-crash.png`, `hero.png` |
| Backend | Filament resolves Vulkan (feature level 3). | logcat |
| Cold material compile | 5.4 s + 5.7 s + 4.4 s for the three lit packages, then 0.17 s. About 15 s before the first frame. | logcat |
| Dice screen | Renders and rolls; readout `d4 3 · d6 5 · d8 3 · d12 4 · d20 15 · d% 30+1 = 61`. | `dice.png`, `roll.png` |
| Tray rim | **Wrong in landscape.** The walls fit the screen (play x −68.6…51.4, z −35.6…35.8) but the rim stays a narrow portrait shape, so dice rest outside it. | `dice.png`, `roll.png` |
| Frame rate | About 15–20 fps on the dice screen (hwcomposer `fps:` lines while rolling). Measured by the system compositor, not by an in-app counter. | logcat |

Open: the rim bug, the frame rate, and whether natives leak on API 26–32
now that the automatic cleaner is off there (only the explicit `close()`
calls free them).
