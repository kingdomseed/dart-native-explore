### unlit-linear

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 |   0   0   0 | 117.7 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.orange1 | 255 124  63 |   0   0   0 | 147.1 |
| emissive.orange4 | 255 231 124 |   0   0   0 | 203.1 |
| emissive.blue2 | 124 231 255 |   0   0   0 | 203.1 |
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
| spot.penumbra |   0   0   0 |   0   0   0 | 0.2 |
| spot.outside |   0   0   0 |   0   0   0 | 0.3 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 196.7 | 254.7 (emissive.white1) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.red) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.metal) | 16 | ok |
| light | 5 | 0.3 | 0.3 (spot.centre) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### unlit-neutral

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  10  10  10 | 29.2 |
| unlit.grey0.05 |  63  63  63 |  35  35  35 | 28.2 |
| unlit.grey0.18 | 118 118 118 | 105 105 105 | 13.3 |
| unlit.grey0.5 | 188 188 188 | 181 181 181 | 6.9 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |  39  48  80 |   1  22  68 | 25.2 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.1 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 | 118 118 118 |   0   0   0 | 117.9 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.9 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.9 |
| emissive.orange1 | 255 124  63 |   0   0   0 | 147.2 |
| emissive.orange4 | 255 231 124 |   0   0   0 | 203.2 |
| emissive.blue2 | 124 231 255 |   0   0   0 | 203.2 |
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
| sky |  88 124 170 |  69 112 162 | 13.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 14.5 | 29.2 (unlit.grey0.02) | 8 | over |
| emissive | 6 | 196.9 | 254.9 (emissive.white1) | 8 | over |
| lit | 13 | 0.1 | 0.1 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.metal) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.outside) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 13.2 | 13.2 (sky) | 8 | over |

### unlit-aces

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  14  14  14 | 24.9 |
| unlit.grey0.05 |  63  63  63 |  33  34  34 | 29.2 |
| unlit.grey0.18 | 118 118 118 |  92  93  94 | 25.3 |
| unlit.grey0.5 | 188 188 188 | 167 166 166 | 21.7 |
| unlit.grey1.0 | 255 255 255 | 210 207 203 | 48.1 |
| unlit.indigo |  39  48  80 |  13  22  50 | 27.6 |
| unlit.red | 255   0   0 | 207   0   8 | 18.7 |
| unlit.green |   0 255   0 |  87 209  44 | 59.2 |
| unlit.blue |   0   0 255 |   0   0 207 | 16.1 |
| unlit.cyan |   0 255 255 |  99 208 203 | 65.9 |
| unlit.magenta | 255   0 255 | 221   0 205 | 28.0 |
| unlit.yellow | 255 255   0 | 213 207  61 | 50.2 |
| emissive.grey0.18 | 118 118 118 |   0   0   0 | 117.9 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.9 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.9 |
| emissive.orange1 | 255 124  63 |   0   0   0 | 147.2 |
| emissive.orange4 | 255 231 124 |   0   0   0 | 203.2 |
| emissive.blue2 | 124 231 255 |   0   0   0 | 203.2 |
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
| sky |  88 124 170 |  59 100 148 | 25.1 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 34.6 | 65.9 (unlit.cyan) | 8 | over |
| emissive | 6 | 196.9 | 254.9 (emissive.white1) | 8 | over |
| lit | 13 | 0.1 | 0.1 (lit.indigo) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.metal) | 16 | ok |
| light | 5 | 0.1 | 0.1 (point.centre) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 25.1 | 25.1 (sky) | 8 | over |

### unlit-exposure2

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  56  56  56 |  39  39  39 | 17.3 |
| unlit.grey0.05 |  89  89  89 |  63  63  63 | 25.6 |
| unlit.grey0.18 | 162 162 162 | 118 118 118 | 44.2 |
| unlit.grey0.5 | 255 255 255 | 188 188 188 | 67.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  56  69 111 |  39  48  80 | 23.0 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 162 162 162 |   0   0   0 | 161.7 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.orange1 | 255 170  89 |   0   0   0 | 171.1 |
| emissive.orange4 | 255 255 170 |   0   0   0 | 226.4 |
| emissive.blue2 | 170 255 255 |   0   0   0 | 226.4 |
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
| sky | 122 170 231 | 124 170 231 | 0.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 19.5 | 67.1 (unlit.grey0.5) | 8 | over |
| emissive | 6 | 215.8 | 254.7 (emissive.white1) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.grey0.5) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.glossy) | 16 | ok |
| light | 5 | 0.3 | 0.3 (point.edge) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.lit) | 16 | ok |
| sky | 1 | 0.7 | 0.7 (sky) | 8 | ok |

### directional

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 |  19  19  19 | 100.2 |
| emissive.white1 | 255 255 255 |  19  19  19 | 236.2 |
| emissive.white4 | 255 255 255 |  19  19  19 | 236.2 |
| emissive.orange1 | 255 125  67 |  19  19  19 | 130.2 |
| emissive.orange4 | 255 232 125 |  19  19  19 | 185.2 |
| emissive.blue2 | 125 232 255 |  19  19  19 | 185.2 |
| lit.grey0.04 |  46  46  46 |  47  47  47 | 1.1 |
| lit.grey0.18 |  91  91  91 |  92  92  92 | 1.0 |
| lit.grey0.5 | 144 144 144 | 146 146 146 | 1.2 |
| lit.grey1.0 | 196 196 196 | 198 198 198 | 1.3 |
| lit.white.rough0.5 | 199 199 199 | 201 200 201 | 1.3 |
| lit.indigo |  35  41  63 |  36  42  64 | 1.0 |
| lit.red | 196  18  18 | 198  19  19 | 1.0 |
| lit.green |  18 196  18 |  19 198  19 | 1.0 |
| lit.blue |  18  18 196 |  19  19 198 | 0.9 |
| lit.cyan |  18 196 196 |  19 198 198 | 1.3 |
| lit.magenta | 196  18 196 | 198  19 198 | 1.3 |
| lit.yellow | 196 196  18 | 198 198  19 | 1.5 |
| sphere.dielectric | 141 141 141 | 143 143 143 | 1.3 |
| sphere.metal |  92  84  61 |  94  85  62 | 1.3 |
| sphere.glossy | 151  50  50 | 153  50  50 | 0.7 |
| point.centre | 196 196 196 | 198 198 198 | 1.5 |
| point.edge | 196 196 196 | 198 198 198 | 1.4 |
| spot.centre | 196 196 196 | 198 198 198 | 1.9 |
| spot.penumbra | 195 195 195 | 198 198 198 | 2.2 |
| spot.outside | 196 196 196 | 198 198 198 | 2.1 |
| ibl.card | 195 195 195 | 198 198 198 | 2.5 |
| shadow.lit | 143 143 143 | 146 146 146 | 2.7 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 178.8 | 236.2 (emissive.white1) | 8 | over |
| lit | 13 | 1.3 | 2.5 (ibl.card) | 16 | ok |
| sphere | 3 | 1.1 | 1.3 (sphere.metal) | 16 | ok |
| light | 5 | 1.8 | 2.2 (spot.penumbra) | 16 | ok |
| shadow | 2 | 1.5 | 2.7 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### point

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.2 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 |   0   0   0 | 117.7 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.orange1 | 255 124  63 |   0   0   0 | 147.0 |
| emissive.orange4 | 255 231 124 |   0   0   0 | 203.1 |
| emissive.blue2 | 124 231 255 |   0   0   0 | 203.1 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.3 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.3 |
| lit.red |   1   0   0 |   1   0   0 | 0.3 |
| lit.green |   0   1   0 |   0   1   0 | 0.3 |
| lit.blue |   0   0   0 |   0   0   0 | 0.3 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.3 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.3 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.3 |
| sphere.dielectric |  16  16  16 |  17  17  17 | 0.6 |
| sphere.metal |   3   3   2 |   3   3   2 | 0.1 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.3 |
| point.centre | 208 208 208 | 208 208 208 | 0.2 |
| point.edge | 157 157 157 | 157 157 157 | 0.2 |
| spot.centre |  46  46  46 |  47  47  47 | 0.3 |
| spot.penumbra |   7   7   7 |   7   7   7 | 0.5 |
| spot.outside |  31  31  31 |  31  31  31 | 0.2 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 196.7 | 254.7 (emissive.white4) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.cyan) | 16 | ok |
| sphere | 3 | 0.3 | 0.6 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.3 | 0.5 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### spot

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 |   0   0   0 | 117.7 |
| emissive.white1 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.white4 | 255 255 255 |   0   0   0 | 254.7 |
| emissive.orange1 | 255 124  63 |   0   0   0 | 147.0 |
| emissive.orange4 | 255 231 124 |   0   0   0 | 203.1 |
| emissive.blue2 | 124 231 255 |   0   0   0 | 203.1 |
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
| spot.centre | 210 210 210 | 210 210 210 | 0.3 |
| spot.penumbra | 151 151 151 | 121 121 121 | 30.1 |
| spot.outside |   0   0   0 |   0   0   0 | 0.3 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 196.7 | 254.7 (emissive.white1) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 6.3 | 30.1 (spot.penumbra) | 16 | over |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### ibl-constant

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 |  20  20  19 | 99.5 |
| emissive.white1 | 255 255 255 |  19  19  19 | 235.5 |
| emissive.white4 | 255 255 255 |  20  20  19 | 235.5 |
| emissive.orange1 | 255 124  65 |  19  19  19 | 128.5 |
| emissive.orange4 | 255 231 124 |  20  20  19 | 183.8 |
| emissive.blue2 | 124 231 255 |  20  20  19 | 183.8 |
| lit.grey0.04 |  36  36  36 |  45  45  45 | 9.4 |
| lit.grey0.18 |  77  77  77 |  88  87  88 | 10.5 |
| lit.grey0.5 | 132 132 132 | 139 138 138 | 6.5 |
| lit.grey1.0 | 195 195 195 | 188 188 188 | 6.6 |
| lit.white.rough0.5 | 192 192 192 | 188 188 188 | 3.6 |
| lit.indigo |  26  32  51 |  35  41  61 | 9.1 |
| lit.red | 195  10  10 | 188  20  19 | 8.5 |
| lit.green |  10 195  10 |  20 188  19 | 8.5 |
| lit.blue |  10  10 195 |  20  19 188 | 8.5 |
| lit.cyan |  10 195 195 |  19 189 188 | 7.5 |
| lit.magenta | 195  10 195 | 189  19 188 | 7.5 |
| lit.yellow | 195 195  10 | 188 188  19 | 7.5 |
| sphere.dielectric | 139 139 139 | 140 140 140 | 0.8 |
| sphere.metal | 182 162 111 | 188 167 114 | 4.8 |
| sphere.glossy | 153  59  59 | 151  59  59 | 0.8 |
| point.centre | 195 195 195 | 188 188 188 | 6.5 |
| point.edge | 195 195 195 | 188 188 188 | 6.6 |
| spot.centre | 195 195 195 | 188 188 188 | 6.6 |
| spot.penumbra | 195 195 195 | 188 188 188 | 6.6 |
| spot.outside | 195 195 195 | 188 188 188 | 6.6 |
| ibl.card | 195 195 195 | 188 188 188 | 6.6 |
| shadow.lit | 132 132 132 | 139 138 138 | 6.5 |
| shadow.umbra | 132 132 132 | 139 138 138 | 6.5 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 177.8 | 235.5 (emissive.white1) | 8 | over |
| lit | 13 | 7.7 | 10.5 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 2.1 | 4.8 (sphere.metal) | 16 | ok |
| light | 5 | 6.6 | 6.6 (spot.penumbra) | 16 | ok |
| shadow | 2 | 6.5 | 6.5 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### ibl-studio

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 |  22  22  21 | 97.4 |
| emissive.white1 | 255 255 255 |  22  22  21 | 233.4 |
| emissive.white4 | 255 255 255 |  22  22  21 | 233.4 |
| emissive.orange1 | 255 125  66 |  22  22  21 | 127.1 |
| emissive.orange4 | 255 232 125 |  22  22  21 | 182.4 |
| emissive.blue2 | 125 232 255 |  22  22  21 | 182.4 |
| lit.grey0.04 |  40  40  40 |  49  49  50 | 9.3 |
| lit.grey0.18 |  83  83  83 |  94  94  95 | 11.4 |
| lit.grey0.5 | 141 142 142 | 148 149 150 | 7.3 |
| lit.grey1.0 | 209 209 210 | 201 202 203 | 7.5 |
| lit.white.rough0.5 | 205 206 207 | 201 202 202 | 4.4 |
| lit.indigo |  29  35  56 |  38  44  66 | 9.5 |
| lit.red | 209  12  12 | 201  22  21 | 9.1 |
| lit.green |  12 209  12 |  22 202  21 | 8.7 |
| lit.blue |  12  12 210 |  22  22 203 | 8.8 |
| lit.cyan |  12 209 210 |  22 202 203 | 8.0 |
| lit.magenta | 209  12 210 | 201  22 203 | 8.3 |
| lit.yellow | 209 209  12 | 201 202  21 | 8.2 |
| sphere.dielectric | 149 150 150 | 149 150 150 | 0.2 |
| sphere.metal | 191 170 117 | 194 174 119 | 3.1 |
| sphere.glossy | 164  64  64 | 161  64  64 | 1.1 |
| point.centre | 209 209 210 | 201 202 203 | 7.5 |
| point.edge | 209 209 210 | 201 202 203 | 7.6 |
| spot.centre | 209 209 210 | 201 202 203 | 7.5 |
| spot.penumbra | 209 209 210 | 201 202 203 | 7.5 |
| spot.outside | 209 209 210 | 201 202 203 | 7.5 |
| ibl.card | 209 209 210 | 201 202 203 | 7.5 |
| shadow.lit | 141 142 142 | 148 149 150 | 7.3 |
| shadow.umbra | 141 142 142 | 148 149 150 | 7.3 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 176.0 | 233.4 (emissive.white1) | 8 | over |
| lit | 13 | 8.3 | 11.4 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 1.5 | 3.1 (sphere.metal) | 16 | ok |
| light | 5 | 7.5 | 7.6 (point.edge) | 16 | ok |
| shadow | 2 | 7.3 | 7.3 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### all

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  10  10  10 | 29.2 |
| unlit.grey0.05 |  63  63  63 |  35  35  35 | 28.2 |
| unlit.grey0.18 | 118 118 118 | 105 105 105 | 13.3 |
| unlit.grey0.5 | 188 188 188 | 181 181 181 | 6.9 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |  39  48  80 |   1  22  68 | 25.2 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.1 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 | 120 120 120 |   4   4   4 | 115.9 |
| emissive.white1 | 255 255 255 |   4   4   4 | 250.9 |
| emissive.white4 | 255 255 255 |   4   4   4 | 250.9 |
| emissive.orange1 | 255 126  69 |   4   4   4 | 145.9 |
| emissive.orange4 | 255 232 126 |   4   4   4 | 200.3 |
| emissive.blue2 | 126 232 255 |   4   4   4 | 200.2 |
| lit.grey0.04 |  60  60  60 |  39  40  39 | 20.5 |
| lit.grey0.18 | 117 117 117 | 113 112 112 | 4.7 |
| lit.grey0.5 | 189 189 189 | 188 188 188 | 1.4 |
| lit.grey1.0 | 255 255 255 | 238 238 239 | 16.5 |
| lit.white.rough0.5 | 255 255 255 | 240 240 240 | 15.0 |
| lit.indigo |  46  54  81 |  12  32  73 | 21.0 |
| lit.red | 255  24  24 | 251   0   0 | 17.2 |
| lit.green |  24 255  24 |   0 247   0 | 18.7 |
| lit.blue |  24  24 255 |  16  16 249 | 7.5 |
| lit.cyan |  24 255 255 |   0 241 241 | 17.4 |
| lit.magenta | 255  24 255 | 246   0 247 | 13.5 |
| lit.yellow | 255 255  24 | 241 241   2 | 16.9 |
| sphere.dielectric | 194 194 194 | 189 189 189 | 5.4 |
| sphere.metal | 204 185 134 | 204 181 121 | 6.0 |
| sphere.glossy | 208  79  79 | 202  54  54 | 19.3 |
| point.centre | 255 255 255 | 241 242 242 | 13.6 |
| point.edge | 255 255 255 | 242 242 242 | 13.2 |
| spot.centre | 255 255 255 | 241 241 242 | 13.6 |
| spot.penumbra | 255 255 255 | 239 239 239 | 16.3 |
| spot.outside | 255 255 255 | 240 240 240 | 15.4 |
| ibl.card | 255 255 255 | 238 238 239 | 16.5 |
| shadow.lit | 188 188 188 | 188 188 188 | 0.5 |
| shadow.umbra | 132 132 132 | 128 128 128 | 4.0 |
| sky |  88 124 170 |  69 112 162 | 13.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 14.5 | 29.2 (unlit.grey0.02) | 8 | over |
| emissive | 6 | 194.0 | 250.9 (emissive.white1) | 8 | over |
| lit | 13 | 14.4 | 21.0 (lit.indigo) | 16 | over |
| sphere | 3 | 10.2 | 19.3 (sphere.glossy) | 16 | over |
| light | 5 | 14.4 | 16.3 (spot.penumbra) | 16 | over |
| shadow | 2 | 2.3 | 4.0 (shadow.umbra) | 16 | ok |
| sky | 1 | 13.2 | 13.2 (sky) | 8 | over |

### all-bloom

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |   9   9   9 | 29.9 |
| unlit.grey0.05 |  63  63  63 |  36  36  36 | 27.4 |
| unlit.grey0.18 | 118 118 118 | 105 105 105 | 13.0 |
| unlit.grey0.5 | 188 188 188 | 181 181 181 | 6.8 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |  39  48  80 |   1  23  68 | 25.0 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.2 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 | 120 120 120 |   9   9   8 | 111.5 |
| emissive.white1 | 255 255 255 |   9   9   8 | 246.4 |
| emissive.white4 | 255 255 255 |   9   9   8 | 246.1 |
| emissive.orange1 | 255 126  69 |  10  10   9 | 140.4 |
| emissive.orange4 | 255 251 137 |  10  10   9 | 204.7 |
| emissive.blue2 | 126 232 255 |   9   9   8 | 195.6 |
| lit.grey0.04 |  60  60  60 |  42  42  41 | 18.5 |
| lit.grey0.18 | 117 117 117 | 113 113 113 | 3.8 |
| lit.grey0.5 | 189 189 189 | 188 188 188 | 0.6 |
| lit.grey1.0 | 255 255 255 | 240 240 240 | 15.1 |
| lit.white.rough0.5 | 255 255 255 | 242 242 242 | 13.0 |
| lit.indigo |  46  54  81 |  17  35  74 | 18.2 |
| lit.red | 255  24  24 | 252   0   0 | 16.8 |
| lit.green |  24 255  24 |   0 248   0 | 18.4 |
| lit.blue |  24  24 255 |  18  20 250 | 5.0 |
| lit.cyan |  24 255 255 |  12 242 242 | 12.7 |
| lit.magenta | 255  24 255 | 248   0 248 | 12.6 |
| lit.yellow | 255 255  24 | 242 242  10 | 13.5 |
| sphere.dielectric | 194 194 194 | 191 191 191 | 3.6 |
| sphere.metal | 207 188 137 | 208 184 124 | 5.6 |
| sphere.glossy | 208  80  80 | 203  59  58 | 16.5 |
| point.centre | 255 255 255 | 244 244 244 | 11.3 |
| point.edge | 255 255 255 | 246 246 246 | 8.9 |
| spot.centre | 255 255 255 | 245 245 245 | 10.0 |
| spot.penumbra | 255 255 255 | 240 240 240 | 14.6 |
| spot.outside | 255 255 255 | 243 243 243 | 12.3 |
| ibl.card | 255 255 255 | 241 240 240 | 14.5 |
| shadow.lit | 188 188 188 | 188 188 188 | 0.2 |
| shadow.umbra | 132 132 132 | 129 129 129 | 3.1 |
| sky |  88 124 170 |  71 113 162 | 11.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 14.4 | 29.9 (unlit.grey0.02) | 8 | over |
| emissive | 6 | 190.8 | 246.4 (emissive.white1) | 8 | over |
| lit | 13 | 12.5 | 18.5 (lit.grey0.04) | 16 | over |
| sphere | 3 | 8.6 | 16.5 (sphere.glossy) | 16 | over |
| light | 5 | 11.4 | 14.6 (spot.penumbra) | 16 | ok |
| shadow | 2 | 1.7 | 3.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 11.6 | 11.6 (sky) | 8 | over |

### default-stage

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |   9   9   9 | 30.0 |
| unlit.grey0.05 |  63  63  63 |  36  36  36 | 27.4 |
| unlit.grey0.18 | 118 118 118 | 105 105 105 | 13.0 |
| unlit.grey0.5 | 188 188 188 | 181 181 181 | 6.8 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |  39  48  80 |   1  23  68 | 25.0 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.2 |
| unlit.cyan |   0 255 255 |   0 237 237 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 | 120 120 120 |  10  10   9 | 110.3 |
| emissive.white1 | 255 255 255 |  10  10   9 | 245.1 |
| emissive.white4 | 255 255 255 |  10  11  10 | 244.5 |
| emissive.orange1 | 255 126  69 |  11  11  11 | 139.0 |
| emissive.orange4 | 255 251 137 |  11  11  11 | 203.3 |
| emissive.blue2 | 126 232 255 |  11  11  10 | 193.6 |
| lit.grey0.04 |  62  62  62 |  44  44  43 | 18.4 |
| lit.grey0.18 | 121 121 121 | 118 119 119 | 2.6 |
| lit.grey0.5 | 195 196 196 | 195 195 196 | 0.1 |
| lit.grey1.0 | 255 255 255 | 238 239 239 | 16.5 |
| lit.white.rough0.5 | 255 255 255 | 237 238 239 | 17.1 |
| lit.indigo |  48  55  84 |  22  39  78 | 15.9 |
| lit.red | 255  25  25 | 255   0   0 | 16.6 |
| lit.green |  25 255  25 |  11 251  11 | 10.5 |
| lit.blue |  25  25 255 |  28  32 253 | 3.9 |
| lit.cyan |  25 255 255 |  35 242 243 | 11.6 |
| lit.magenta | 255  25 255 | 247  15 251 | 7.3 |
| lit.yellow | 255 255  26 | 242 243  31 | 9.9 |
| sphere.dielectric | 199 199 199 | 194 195 195 | 4.5 |
| sphere.metal | 207 190 140 | 206 184 124 | 7.3 |
| sphere.glossy | 215  83  83 | 209  63  63 | 15.5 |
| point.centre | 255 255 255 | 238 238 239 | 16.8 |
| point.edge | 255 255 255 | 238 239 239 | 16.6 |
| spot.centre | 255 255 255 | 237 238 239 | 16.9 |
| spot.penumbra | 255 255 255 | 237 238 239 | 16.9 |
| spot.outside | 255 255 255 | 237 239 239 | 16.8 |
| ibl.card | 255 255 255 | 237 238 239 | 16.8 |
| shadow.lit | 194 195 195 | 195 195 196 | 0.7 |
| shadow.umbra | 141 142 142 | 139 140 141 | 1.7 |
| sky |   0   0   0 |  45  45  60 | 50.3 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 14.4 | 30.0 (unlit.grey0.02) | 8 | over |
| emissive | 6 | 189.3 | 245.1 (emissive.white1) | 8 | over |
| lit | 13 | 11.3 | 18.4 (lit.grey0.04) | 16 | over |
| sphere | 3 | 9.1 | 15.5 (sphere.glossy) | 16 | ok |
| light | 5 | 16.8 | 16.9 (spot.centre) | 16 | over |
| shadow | 2 | 1.2 | 1.7 (shadow.umbra) | 16 | ok |
| sky | 1 | 50.3 | 50.3 (sky) | 8 | over |

