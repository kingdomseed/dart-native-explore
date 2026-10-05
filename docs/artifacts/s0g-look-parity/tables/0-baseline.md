### unlit-linear

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  39  39  39 | 33.7 |
| unlit.grey0.05 |  13  13  13 |  63  63  63 | 50.4 |
| unlit.grey0.18 |  46  46  46 | 118 118 118 | 71.8 |
| unlit.grey0.5 | 127 127 127 | 188 188 188 | 60.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |   5   8  20 |  39  48  80 | 44.7 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 |  46  46  46 |   0   0   0 | 45.7 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.orange1 | 255  51  13 |   0   0   0 | 106.1 |
| emissive.orange4 | 255 102  34 |   0   0   0 | 130.1 |
| emissive.blue2 |  39 141 255 |   0   0   0 | 144.7 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.3 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.3 |
| lit.red |   0   0   0 |   0   0   0 | 0.3 |
| lit.green |   0   0   0 |   0   0   0 | 0.3 |
| lit.blue |   0   0   0 |   0   0   0 | 0.3 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.3 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.3 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.3 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.3 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.3 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.3 |
| point.centre |   0   0   0 |   0   0   0 | 0.3 |
| point.edge |   0   0   0 |   0   0   0 | 0.3 |
| spot.centre |   0   0   0 |   0   0   0 | 0.3 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.3 |
| spot.outside |   0   0   0 |   0   0   0 | 0.3 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 26.5 | 71.8 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 156.0 | 254.7 (emissive.white4) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.3 | 0.3 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.lit) | 16 | ok |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

### unlit-neutral

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  10  10  10 | 4.8 |
| unlit.grey0.05 |  13  13  13 |  35  35  35 | 21.8 |
| unlit.grey0.18 |  46  46  46 | 105 105 105 | 58.7 |
| unlit.grey0.5 | 127 127 127 | 181 181 181 | 54.1 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |   5   8  20 |   1  22  68 | 22.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.1 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 |  46  46  46 |   0   0   0 | 45.9 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.9 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.9 |
| emissive.orange1 | 255  51  13 |   0   0   0 | 106.2 |
| emissive.orange4 | 255 102  34 |   0   0   0 | 130.2 |
| emissive.blue2 |  39 141 255 |   0   0   0 | 144.9 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.1 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.1 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.1 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.1 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.1 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.1 |
| lit.red |   0   0   0 |   0   0   0 | 0.1 |
| lit.green |   0   0   0 |   0   0   0 | 0.1 |
| lit.blue |   0   0   0 |   0   0   0 | 0.1 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.1 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.1 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.1 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.1 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.1 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.1 |
| point.centre |   0   0   0 |   0   0   0 | 0.1 |
| point.edge |   0   0   0 |   0   0   0 | 0.1 |
| spot.centre |   0   0   0 |   0   0   0 | 0.1 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.1 |
| spot.outside |   0   0   0 |   0   0   0 | 0.1 |
| ibl.card |   0   0   0 |   0   0   0 | 0.1 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.1 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.1 |
| sky |  88 124 170 |  54  96 142 | 29.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 19.4 | 58.7 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 156.2 | 254.9 (emissive.white1) | 8 | over |
| lit | 13 | 0.1 | 0.1 (lit.red) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.centre) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 29.7 | 29.7 (sky) | 8 | over |

### unlit-aces

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  14  14  14 | 9.1 |
| unlit.grey0.05 |  13  13  13 |  33  34  34 | 20.8 |
| unlit.grey0.18 |  46  46  46 |  92  93  94 | 46.7 |
| unlit.grey0.5 | 127 127 127 | 167 166 166 | 39.3 |
| unlit.grey1.0 | 255 255 255 | 210 207 203 | 48.1 |
| unlit.indigo |   5   8  20 |  13  22  50 | 17.1 |
| unlit.red | 255   0   0 | 207   0   8 | 18.7 |
| unlit.green |   0 255   0 |  87 209  44 | 59.2 |
| unlit.blue |   0   0 255 |   0   0 207 | 16.1 |
| unlit.cyan |   0 255 255 |  99 208 203 | 65.9 |
| unlit.magenta | 255   0 255 | 221   0 205 | 28.0 |
| unlit.yellow | 255 255   0 | 213 207  61 | 50.2 |
| emissive.grey0.18 |  46  46  46 |   0   0   0 | 45.9 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.9 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.9 |
| emissive.orange1 | 255  51  13 |   0   0   0 | 106.2 |
| emissive.orange4 | 255 102  34 |   0   0   0 | 130.2 |
| emissive.blue2 |  39 141 255 |   0   0   0 | 144.9 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.1 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.1 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.1 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.1 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.1 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.1 |
| lit.red |   0   0   0 |   0   0   0 | 0.1 |
| lit.green |   0   0   0 |   0   0   0 | 0.1 |
| lit.blue |   0   0   0 |   0   0   0 | 0.1 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.1 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.1 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.1 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.1 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.1 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.1 |
| point.centre |   0   0   0 |   0   0   0 | 0.1 |
| point.edge |   0   0   0 |   0   0   0 | 0.1 |
| spot.centre |   0   0   0 |   0   0   0 | 0.1 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.1 |
| spot.outside |   0   0   0 |   0   0   0 | 0.1 |
| ibl.card |   0   0   0 |   0   0   0 | 0.1 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.1 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.1 |
| sky |  88 124 170 |  47  84 129 | 40.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 34.9 | 65.9 (unlit.cyan) | 8 | over |
| emissive | 6 | 156.2 | 254.9 (emissive.white1) | 8 | over |
| lit | 13 | 0.1 | 0.1 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.outside) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 40.7 | 40.7 (sky) | 8 | over |

### unlit-exposure2

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  10  10  10 |  39  39  39 | 28.7 |
| unlit.grey0.05 |  22  22  22 |  63  63  63 | 41.4 |
| unlit.grey0.18 |  66  66  66 | 118 118 118 | 51.8 |
| unlit.grey0.5 | 175 175 175 | 188 188 188 | 12.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  10  15  32 |  39  48  80 | 36.7 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 |  66  66  66 |   0   0   0 | 65.7 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.orange1 | 255  73  22 |   0   0   0 | 116.4 |
| emissive.orange4 | 255 141  50 |   0   0   0 | 148.4 |
| emissive.blue2 |  56 193 255 |   0   0   0 | 167.7 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.3 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.3 |
| lit.red |   0   0   0 |   0   0   0 | 0.3 |
| lit.green |   0   0   0 |   0   0   0 | 0.3 |
| lit.blue |   0   0   0 |   0   0   0 | 0.3 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.3 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.3 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.3 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.3 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.3 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.3 |
| point.centre |   0   0   0 |   0   0   0 | 0.2 |
| point.edge |   0   0   0 |   0   0   0 | 0.3 |
| spot.centre |   0   0   0 |   0   0   0 | 0.3 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.3 |
| spot.outside |   0   0   0 |   0   0   0 | 0.2 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky | 122 170 231 | 110 152 207 | 18.0 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 19.0 | 51.8 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 168.0 | 254.7 (emissive.white4) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.cyan) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.metal) | 16 | ok |
| light | 5 | 0.3 | 0.3 (spot.centre) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 18.0 | 18.0 (sky) | 8 | over |

### directional

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  39  39  39 | 33.7 |
| unlit.grey0.05 |  13  13  13 |  63  63  63 | 50.4 |
| unlit.grey0.18 |  46  46  46 | 118 118 118 | 71.8 |
| unlit.grey0.5 | 127 127 127 | 188 188 188 | 60.8 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |   5   8  20 |  39  48  80 | 44.7 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 |  54  54  54 |   3   3   3 | 50.8 |
| emissive.white1 | 255 255 255 |   3   3   3 | 251.8 |
| emissive.white4 | 255 255 255 |   3   3   3 | 251.8 |
| emissive.orange1 | 255  58  30 |   3   3   3 | 111.2 |
| emissive.orange4 | 255 105  44 |   3   3   3 | 131.5 |
| emissive.blue2 |  48 143 255 |   3   3   3 | 145.5 |
| lit.grey0.04 |  29  29  29 |  12  12  12 | 16.8 |
| lit.grey0.18 |  51  51  51 |  31  31  31 | 19.5 |
| lit.grey0.5 | 122 122 122 |  54  54  54 | 67.6 |
| lit.grey1.0 | 240 240 240 |  77  77  77 | 163.3 |
| lit.white.rough0.5 | 244 244 244 |  78  78  78 | 165.6 |
| lit.indigo |  26  27  33 |   8  10  19 | 16.7 |
| lit.red | 240  24  24 |  77   3   3 | 68.3 |
| lit.green |  24 240  24 |   3  77   3 | 68.3 |
| lit.blue |  24  24 240 |   3   3  77 | 68.3 |
| lit.cyan |  24 240 240 |   3  77  77 | 115.7 |
| lit.magenta | 240  24 240 |  77   3  77 | 115.6 |
| lit.yellow | 239 239  24 |  77  77   3 | 115.4 |
| sphere.dielectric | 122 122 122 |  53  53  53 | 69.2 |
| sphere.metal | 108  88  42 |  40  35  23 | 46.5 |
| sphere.glossy | 141  23  23 |  58  14  14 | 33.9 |
| point.centre | 240 240 240 |  77  77  77 | 163.1 |
| point.edge | 240 240 240 |  77  77  77 | 163.3 |
| spot.centre | 239 239 239 |  77  77  77 | 162.6 |
| spot.penumbra | 239 239 239 |  77  77  77 | 162.3 |
| spot.outside | 239 239 239 |  77  77  77 | 162.3 |
| ibl.card | 238 238 238 |  77  77  77 | 161.9 |
| shadow.lit | 120 120 120 |  54  54  54 | 66.2 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 26.5 | 71.8 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 157.1 | 251.8 (emissive.white4) | 8 | over |
| lit | 13 | 89.5 | 165.6 (lit.white.rough0.5) | 16 | over |
| sphere | 3 | 49.9 | 69.2 (sphere.dielectric) | 16 | over |
| light | 5 | 162.7 | 163.3 (point.edge) | 16 | over |
| shadow | 2 | 33.3 | 66.2 (shadow.lit) | 16 | over |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

### point

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  39  39  39 | 33.7 |
| unlit.grey0.05 |  13  13  13 |  63  63  63 | 50.4 |
| unlit.grey0.18 |  46  46  46 | 118 118 118 | 71.8 |
| unlit.grey0.5 | 127 127 127 | 188 188 188 | 60.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |   5   8  20 |  39  48  80 | 44.7 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 |  46  46  46 |   0   0   0 | 45.7 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.orange1 | 255  51  13 |   0   0   0 | 106.1 |
| emissive.orange4 | 255 102  34 |   0   0   0 | 130.1 |
| emissive.blue2 |  39 141 255 |   0   0   0 | 144.7 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.3 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.3 |
| lit.red |  50   4   4 |   0   0   0 | 19.2 |
| lit.green |   4  50   4 |   0   0   0 | 19.4 |
| lit.blue |   0   0   0 |   0   0   0 | 0.3 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.3 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.3 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.3 |
| sphere.dielectric |  95  95  95 |   0   0   0 | 94.9 |
| sphere.metal |  65  54  29 |   0   0   0 | 49.0 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.3 |
| point.centre | 255 255 255 |   3   2   2 | 252.5 |
| point.edge | 255 255 255 |   1   1   1 | 253.6 |
| spot.centre | 255 255 255 |   0   0   0 | 254.7 |
| spot.penumbra | 235 235 235 |   0   0   0 | 234.5 |
| spot.outside | 255 255 255 |   0   0   0 | 254.7 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 26.5 | 71.8 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 156.0 | 254.7 (emissive.white1) | 8 | over |
| lit | 13 | 3.2 | 19.4 (lit.green) | 16 | over |
| sphere | 3 | 48.1 | 94.9 (sphere.dielectric) | 16 | over |
| light | 5 | 250.0 | 254.7 (spot.outside) | 16 | over |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

### spot

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  39  39  39 | 33.7 |
| unlit.grey0.05 |  13  13  13 |  63  63  63 | 50.4 |
| unlit.grey0.18 |  46  46  46 | 118 118 118 | 71.8 |
| unlit.grey0.5 | 127 127 127 | 188 188 188 | 60.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |   5   8  20 |  39  48  80 | 44.7 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 |  46  46  46 |   0   0   0 | 45.7 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.orange1 | 255  51  13 |   0   0   0 | 106.0 |
| emissive.orange4 | 255 102  34 |   0   0   0 | 130.1 |
| emissive.blue2 |  39 141 255 |   0   0   0 | 144.7 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.3 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.3 |
| lit.red |   0   0   0 |   0   0   0 | 0.3 |
| lit.green |   0   0   0 |   0   0   0 | 0.3 |
| lit.blue |   0   0   0 |   0   0   0 | 0.3 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.3 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.3 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.3 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.3 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.3 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.3 |
| point.centre |   0   0   0 |   0   0   0 | 0.3 |
| point.edge |   0   0   0 |   0   0   0 | 0.3 |
| spot.centre | 255 255 255 |   1   1   1 | 253.8 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.5 |
| spot.outside |   0   0   0 |   0   0   0 | 0.3 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 26.5 | 71.8 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 156.0 | 254.7 (emissive.white1) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 51.0 | 253.8 (spot.centre) | 16 | over |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

### ibl-constant

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  39  39  39 | 33.7 |
| unlit.grey0.05 |  13  13  13 |  63  63  63 | 50.4 |
| unlit.grey0.18 |  46  46  46 | 118 118 118 | 71.8 |
| unlit.grey0.5 | 127 127 127 | 188 188 188 | 60.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |   5   8  20 |  39  48  80 | 44.7 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 |  49  49  49 |  16  16  16 | 33.0 |
| emissive.white1 | 255 255 255 |  16  16  16 | 239.0 |
| emissive.white4 | 255 255 255 |  16  16  16 | 239.0 |
| emissive.orange1 | 255  53  20 |  16  16  16 | 93.4 |
| emissive.orange4 | 255 103  37 |  16  16  16 | 115.7 |
| emissive.blue2 |  42 142 255 |  16  16  16 | 130.3 |
| lit.grey0.04 |  13  13  13 |  40  40  40 | 26.5 |
| lit.grey0.18 |  30  30  30 |  78  78  78 | 47.7 |
| lit.grey0.5 |  84  84  84 | 124 124 124 | 39.7 |
| lit.grey1.0 | 195 195 195 | 169 169 169 | 26.4 |
| lit.white.rough0.5 | 192 192 192 | 168 168 168 | 23.7 |
| lit.indigo |  12  13  17 |  30  35  54 | 25.6 |
| lit.red | 195  10  10 | 169  16  16 | 12.8 |
| lit.green |  10 195  10 |  16 169  16 | 12.8 |
| lit.blue |  10  10 195 |  16  16 169 | 12.8 |
| lit.cyan |  10 195 195 |  16 169 169 | 19.6 |
| lit.magenta | 195  10 195 | 169  16 169 | 19.6 |
| lit.yellow | 195 195  10 | 169 169  16 | 19.6 |
| sphere.dielectric |  96  96  96 | 125 125 125 | 28.9 |
| sphere.metal | 182 139  59 | 168 149 102 | 22.2 |
| sphere.glossy | 117  40  40 | 135  52  52 | 14.1 |
| point.centre | 195 195 195 | 169 169 169 | 26.4 |
| point.edge | 195 195 195 | 169 169 169 | 26.4 |
| spot.centre | 195 195 195 | 169 169 169 | 26.4 |
| spot.penumbra | 195 195 195 | 169 169 169 | 26.5 |
| spot.outside | 195 195 195 | 169 169 169 | 26.5 |
| ibl.card | 195 195 195 | 169 169 169 | 26.4 |
| shadow.lit |  84  84  84 | 124 124 124 | 39.7 |
| shadow.umbra |  84  84  84 | 124 124 124 | 39.7 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 26.5 | 71.8 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 141.7 | 239.0 (emissive.white4) | 8 | over |
| lit | 13 | 24.1 | 47.7 (lit.grey0.18) | 16 | over |
| sphere | 3 | 21.7 | 28.9 (sphere.dielectric) | 16 | over |
| light | 5 | 26.4 | 26.5 (spot.penumbra) | 16 | over |
| shadow | 2 | 39.7 | 39.7 (shadow.umbra) | 16 | over |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

### ibl-studio

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  39  39  39 | 33.7 |
| unlit.grey0.05 |  13  13  13 |  63  63  63 | 50.4 |
| unlit.grey0.18 |  46  46  46 | 118 118 118 | 71.8 |
| unlit.grey0.5 | 127 127 127 | 188 188 188 | 60.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |   5   8  20 |  39  48  80 | 44.7 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 |  49  49  49 |  18  18  18 | 31.0 |
| emissive.white1 | 255 255 255 |  18  18  18 | 237.0 |
| emissive.white4 | 255 255 255 |  18  18  18 | 237.0 |
| emissive.orange1 | 255  54  21 |  18  18  18 | 92.0 |
| emissive.orange4 | 255 103  38 |  18  18  18 | 114.0 |
| emissive.blue2 |  43 142 255 |  18  18  18 | 128.7 |
| lit.grey0.04 |  15  15  16 |  43  43  43 | 27.8 |
| lit.grey0.18 |  33  33  33 |  83  84  84 | 50.8 |
| lit.grey0.5 |  90  91  91 | 132 133 133 | 42.0 |
| lit.grey1.0 | 209 209 210 | 180 181 182 | 28.5 |
| lit.white.rough0.5 | 205 206 207 | 180 181 181 | 25.5 |
| lit.indigo |  14  15  20 |  33  38  58 | 26.9 |
| lit.red | 209  12  12 | 180  18  18 | 13.7 |
| lit.green |  12 209  12 |  18 181  18 | 13.3 |
| lit.blue |  12  12 210 |  18  18 182 | 13.4 |
| lit.cyan |  12 209 210 |  18 181 182 | 20.7 |
| lit.magenta | 209  12 210 | 180  18 182 | 21.1 |
| lit.yellow | 209 209  12 | 180 181  18 | 20.9 |
| sphere.dielectric | 103 103 103 | 133 134 134 | 30.5 |
| sphere.metal | 191 147  63 | 175 156 106 | 22.8 |
| sphere.glossy | 125  43  43 | 144  56  56 | 14.9 |
| point.centre | 209 209 210 | 180 181 182 | 28.5 |
| point.edge | 209 209 210 | 180 181 182 | 28.5 |
| spot.centre | 209 209 210 | 180 181 182 | 28.5 |
| spot.penumbra | 209 209 210 | 180 181 182 | 28.4 |
| spot.outside | 209 209 210 | 180 181 182 | 28.5 |
| ibl.card | 209 209 210 | 180 181 182 | 28.5 |
| shadow.lit |  90  91  91 | 132 133 133 | 42.0 |
| shadow.umbra |  90  91  91 | 132 133 133 | 42.0 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 26.5 | 71.8 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 140.0 | 237.0 (emissive.white1) | 8 | over |
| lit | 13 | 25.6 | 50.8 (lit.grey0.18) | 16 | over |
| sphere | 3 | 22.7 | 30.5 (sphere.dielectric) | 16 | over |
| light | 5 | 28.5 | 28.5 (point.edge) | 16 | over |
| shadow | 2 | 42.0 | 42.0 (shadow.lit) | 16 | over |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

### all

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  10  10  10 | 4.8 |
| unlit.grey0.05 |  13  13  13 |  35  35  35 | 21.8 |
| unlit.grey0.18 |  46  46  46 | 105 105 105 | 58.7 |
| unlit.grey0.5 | 127 127 127 | 181 181 181 | 54.1 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |   5   8  20 |   1  22  68 | 22.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.1 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 |  56  56  56 |   5   4   4 | 51.7 |
| emissive.white1 | 255 255 255 |   5   4   4 | 250.7 |
| emissive.white4 | 255 255 255 |   5   4   4 | 250.7 |
| emissive.orange1 | 255  60  34 |   5   4   4 | 112.1 |
| emissive.orange4 | 255 106  47 |   5   4   4 | 131.7 |
| emissive.blue2 |  50 144 255 |   5   4   4 | 145.4 |
| lit.grey0.04 |  34  34  34 |  15  16  16 | 18.5 |
| lit.grey0.18 |  60  60  60 |  63  62  63 | 2.4 |
| lit.grey0.5 | 145 145 145 | 122 122 122 | 22.5 |
| lit.grey1.0 | 255 255 255 | 175 175 175 | 80.3 |
| lit.white.rough0.5 | 255 255 255 | 175 175 175 | 79.7 |
| lit.indigo |  32  33  40 |   3  13  46 | 18.1 |
| lit.red | 255  31  31 | 180   0   0 | 45.7 |
| lit.green |  31 255  31 |   0 176   0 | 46.9 |
| lit.blue |  29  29 255 |   0   0 180 | 44.3 |
| lit.cyan |  29 255 255 |   0 175 175 | 63.2 |
| lit.magenta | 255  29 255 | 176   0 176 | 62.2 |
| lit.yellow | 255 255  29 | 175 175   0 | 62.7 |
| sphere.dielectric | 195 195 195 | 123 123 123 | 71.2 |
| sphere.metal | 222 187  96 | 169 148  92 | 32.1 |
| sphere.glossy | 178  52  52 | 138  21  21 | 33.8 |
| point.centre | 255 255 255 | 175 175 175 | 80.1 |
| point.edge | 255 255 255 | 175 175 175 | 80.2 |
| spot.centre | 255 255 255 | 175 175 175 | 80.3 |
| spot.penumbra | 255 255 255 | 175 175 175 | 80.3 |
| spot.outside | 255 255 255 | 175 175 175 | 80.4 |
| ibl.card | 255 255 255 | 175 175 175 | 80.3 |
| shadow.lit | 144 144 144 | 122 122 122 | 21.5 |
| shadow.umbra |  84  84  84 | 111 111 111 | 27.3 |
| sky |  88 124 170 |  54  96 142 | 29.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 19.4 | 58.7 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 157.1 | 250.7 (emissive.white1) | 8 | over |
| lit | 13 | 48.2 | 80.3 (lit.grey1.0) | 16 | over |
| sphere | 3 | 45.7 | 71.2 (sphere.dielectric) | 16 | over |
| light | 5 | 80.2 | 80.4 (spot.outside) | 16 | over |
| shadow | 2 | 24.4 | 27.3 (shadow.umbra) | 16 | over |
| sky | 1 | 29.7 | 29.7 (sky) | 8 | over |

### all-bloom

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  10  10  10 | 4.8 |
| unlit.grey0.05 |  13  13  13 |  35  35  35 | 21.8 |
| unlit.grey0.18 |  46  46  46 | 105 105 105 | 58.7 |
| unlit.grey0.5 | 127 127 127 | 181 181 181 | 54.1 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |   5   8  20 |   1  22  68 | 22.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.2 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 |  56  56  56 |   5   4   4 | 51.7 |
| emissive.white1 | 255 255 255 |   5   4   4 | 250.7 |
| emissive.white4 | 255 255 255 |   5   4   4 | 250.7 |
| emissive.orange1 | 255  60  34 |   5   4   4 | 112.1 |
| emissive.orange4 | 255 106  47 |   5   4   4 | 131.7 |
| emissive.blue2 |  50 144 255 |   5   4   4 | 145.4 |
| lit.grey0.04 |  34  34  34 |  15  16  16 | 18.5 |
| lit.grey0.18 |  60  60  60 |  63  62  63 | 2.4 |
| lit.grey0.5 | 145 145 145 | 122 122 122 | 22.5 |
| lit.grey1.0 | 255 255 255 | 175 175 175 | 80.3 |
| lit.white.rough0.5 | 255 255 255 | 175 175 175 | 79.7 |
| lit.indigo |  32  33  40 |   3  13  46 | 18.1 |
| lit.red | 255  31  31 | 180   0   0 | 45.7 |
| lit.green |  32 255  32 |   0 176   0 | 47.9 |
| lit.blue |  29  29 255 |   0   0 180 | 44.3 |
| lit.cyan |  31 255 255 |   0 175 175 | 63.8 |
| lit.magenta | 255  29 255 | 176   0 176 | 62.2 |
| lit.yellow | 255 255  32 | 175 175   0 | 63.7 |
| sphere.dielectric | 199 199 199 | 123 123 123 | 75.4 |
| sphere.metal | 225 192 100 | 170 148  92 | 35.4 |
| sphere.glossy | 179  54  54 | 138  21  21 | 35.4 |
| point.centre | 255 255 255 | 175 175 175 | 80.1 |
| point.edge | 255 255 255 | 175 175 175 | 80.2 |
| spot.centre | 255 255 255 | 175 175 175 | 80.3 |
| spot.penumbra | 255 255 255 | 175 175 175 | 80.3 |
| spot.outside | 255 255 255 | 175 175 175 | 80.3 |
| ibl.card | 255 255 255 | 175 175 175 | 80.3 |
| shadow.lit | 144 144 144 | 122 122 122 | 21.5 |
| shadow.umbra |  84  84  84 | 111 111 111 | 27.3 |
| sky |  88 124 170 |  54  96 142 | 29.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 19.4 | 58.7 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 157.1 | 250.7 (emissive.white4) | 8 | over |
| lit | 13 | 48.4 | 80.3 (ibl.card) | 16 | over |
| sphere | 3 | 48.7 | 75.4 (sphere.dielectric) | 16 | over |
| light | 5 | 80.2 | 80.3 (spot.penumbra) | 16 | over |
| shadow | 2 | 24.4 | 27.3 (shadow.umbra) | 16 | over |
| sky | 1 | 29.7 | 29.7 (sky) | 8 | over |

### default-stage

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   5   5   5 |  10  10  10 | 4.8 |
| unlit.grey0.05 |  13  13  13 |  35  35  35 | 21.8 |
| unlit.grey0.18 |  46  46  46 | 105 105 105 | 58.7 |
| unlit.grey0.5 | 127 127 127 | 181 181 181 | 54.1 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |   5   8  20 |   1  22  68 | 22.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.1 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 |  56  56  56 |   2   2   2 | 54.0 |
| emissive.white1 | 255 255 255 |   2   2   2 | 252.7 |
| emissive.white4 | 255 255 255 |   2   2   2 | 252.6 |
| emissive.orange1 | 255  61  35 |   2   2   2 | 114.5 |
| emissive.orange4 | 255 106  47 |   2   2   2 | 133.7 |
| emissive.blue2 |  51 144 255 |   2   2   2 | 147.6 |
| lit.grey0.04 |  35  35  35 |  17  19  19 | 16.8 |
| lit.grey0.18 |  62  62  62 |  70  70  71 | 8.3 |
| lit.grey0.5 | 148 148 149 | 131 132 133 | 16.4 |
| lit.grey1.0 | 255 255 255 | 186 187 188 | 68.1 |
| lit.white.rough0.5 | 255 255 255 | 186 187 188 | 67.9 |
| lit.indigo |  33  34  41 |   4  15  50 | 18.9 |
| lit.red | 255  30  30 | 190   0   0 | 41.4 |
| lit.green |  31 255  31 |   0 188   0 | 43.1 |
| lit.blue |  30  30 255 |   0   0 192 | 40.9 |
| lit.cyan |  32 255 255 |   0 187 188 | 55.8 |
| lit.magenta | 255  30 255 | 187   0 189 | 54.7 |
| lit.yellow | 255 255  33 | 186 187   0 | 56.4 |
| sphere.dielectric | 156 156 156 | 132 132 133 | 23.7 |
| sphere.metal | 210 174  85 | 175 154  95 | 21.9 |
| sphere.glossy | 183  56  56 | 146  26  27 | 31.7 |
| point.centre | 255 255 255 | 186 187 188 | 68.1 |
| point.edge | 255 255 255 | 186 187 188 | 68.2 |
| spot.centre | 255 255 255 | 186 187 188 | 68.2 |
| spot.penumbra | 255 255 255 | 186 187 188 | 68.2 |
| spot.outside | 255 255 255 | 186 187 188 | 68.2 |
| ibl.card | 255 255 255 | 186 187 188 | 68.2 |
| shadow.lit | 147 147 148 | 131 132 133 | 15.4 |
| shadow.umbra |  90  91  91 | 121 122 122 | 30.9 |
| sky |   0   0   0 |  42  42  58 | 47.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 19.4 | 58.7 (unlit.grey0.18) | 8 | over |
| emissive | 6 | 159.2 | 252.7 (emissive.white1) | 8 | over |
| lit | 13 | 42.8 | 68.2 (ibl.card) | 16 | over |
| sphere | 3 | 25.8 | 31.7 (sphere.glossy) | 16 | over |
| light | 5 | 68.2 | 68.2 (spot.outside) | 16 | over |
| shadow | 2 | 23.2 | 30.9 (shadow.umbra) | 16 | over |
| sky | 1 | 47.2 | 47.2 (sky) | 8 | over |

