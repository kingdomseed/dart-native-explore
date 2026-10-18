### unlit-linear

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.7 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.5 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| emissive.white1 | 255 255 255 | 249 247 248 | 6.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  64 | 247 124  63 | 2.8 |
| emissive.orange4 | 255 255 134 | 255 253 134 | 0.8 |
| emissive.blue2 | 141 232 255 | 141 232 255 | 0.2 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.2 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.2 |
| lit.red |   0   0   0 |   0   0   0 | 0.2 |
| lit.green |   0   0   0 |   0   0   0 | 0.2 |
| lit.blue |   0   0   0 |   0   0   0 | 0.2 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.2 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.2 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.2 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.2 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.2 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.2 |
| point.centre |   0   0   0 |   0   0   0 | 0.2 |
| point.edge |   0   0   0 |   0   0   0 | 0.2 |
| spot.centre |   0   0   0 |   0   0   0 | 0.2 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.2 |
| spot.outside |   0   0   0 |   0   0   0 | 0.2 |
| ibl.card |   0   0   0 |   0   0   0 | 0.2 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.2 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.2 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 5.0 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.9 | 6.9 (emissive.white1) | 8 | ok |
| lit | 13 | 0.2 | 0.2 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.2 | 0.2 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.2 | 0.2 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.2 | 0.2 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### unlit-neutral

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   8   8   8 |  10  10  10 | 1.9 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.9 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.4 |
| unlit.grey0.5 | 180 180 180 | 181 181 181 | 1.0 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.2 |
| unlit.indigo |   0  23  68 |   1  22  68 | 0.5 |
| unlit.red | 254   0   0 | 247   0   0 | 2.5 |
| unlit.green |   0 246   0 |   0 242   0 | 1.3 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.9 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.0 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 238 237   0 | 2.5 |
| emissive.grey0.18 | 105 105 105 | 105 105 105 | 0.4 |
| emissive.white1 | 240 240 240 | 234 234 234 | 6.2 |
| emissive.white4 | 253 253 253 | 249 249 249 | 3.8 |
| emissive.orange1 | 251 112  26 | 246 112  24 | 2.6 |
| emissive.orange4 | 255 173 137 | 255 173 137 | 0.2 |
| emissive.blue2 | 119 181 255 | 119 182 255 | 0.4 |
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
| sky |  68 112 162 |  69 112 162 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 2.5 | 6.9 (unlit.blue) | 8 | ok |
| emissive | 6 | 2.3 | 6.2 (emissive.white1) | 8 | ok |
| lit | 13 | 0.1 | 0.1 (lit.indigo) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.metal) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.outside) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### unlit-aces

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  20  20  20 |  23  23  24 | 3.5 |
| unlit.grey0.05 |  50  50  50 |  51  52  53 | 1.9 |
| unlit.grey0.18 | 127 127 127 | 128 128 129 | 1.6 |
| unlit.grey0.5 | 196 196 196 | 201 198 195 | 2.7 |
| unlit.grey1.0 | 226 226 226 | 230 225 219 | 3.6 |
| unlit.indigo |  19  32  69 |  22  34  74 | 3.3 |
| unlit.red | 250  17  21 | 244  29  17 | 7.0 |
| unlit.green | 148 228  89 | 150 228  87 | 1.7 |
| unlit.blue |   0   0 228 |   5   0 227 | 1.9 |
| unlit.cyan | 154 227 226 | 158 227 219 | 3.7 |
| unlit.magenta | 248  41 228 | 251  36 224 | 3.9 |
| unlit.yellow | 230 227 106 | 233 226 104 | 2.2 |
| emissive.grey0.18 | 127 127 127 | 128 128 129 | 1.6 |
| emissive.white1 | 226 226 226 | 230 225 219 | 3.6 |
| emissive.white4 | 250 250 250 | 249 244 236 | 7.1 |
| emissive.orange1 | 240 147  76 | 238 150  74 | 1.9 |
| emissive.orange4 | 255 226 178 | 255 225 176 | 1.1 |
| emissive.blue2 | 181 219 242 | 187 220 232 | 5.6 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.1 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.1 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.1 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.2 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.1 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.1 |
| lit.red |   0   0   0 |   0   0   0 | 0.1 |
| lit.green |   0   0   0 |   0   0   0 | 0.1 |
| lit.blue |   0   0   0 |   0   0   0 | 0.1 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.1 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.1 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.2 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.1 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.1 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.1 |
| point.centre |   0   0   0 |   0   0   0 | 0.1 |
| point.edge |   0   0   0 |   0   0   0 | 0.1 |
| spot.centre |   0   0   0 |   0   0   0 | 0.2 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.1 |
| spot.outside |   0   0   0 |   0   0   0 | 0.1 |
| ibl.card |   0   0   0 |   0   0   0 | 0.1 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.1 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.1 |
| sky |  92 136 181 |  94 137 182 | 1.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 3.1 | 7.0 (unlit.red) | 8 | ok |
| emissive | 6 | 3.5 | 7.1 (emissive.white4) | 8 | ok |
| lit | 13 | 0.1 | 0.2 (lit.yellow) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.glossy) | 16 | ok |
| light | 5 | 0.1 | 0.2 (spot.centre) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 1.2 | 1.2 (sky) | 8 | ok |

### unlit-exposure2

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  56  56  56 |  56  56  56 | 0.4 |
| unlit.grey0.05 |  89  89  89 |  89  89  89 | 0.2 |
| unlit.grey0.18 | 162 162 162 | 162 162 162 | 0.1 |
| unlit.grey0.5 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.grey1.0 | 255 255 255 | 255 255 255 | 0.1 |
| unlit.indigo |  56  69 112 |  57  69 112 | 0.4 |
| unlit.red | 255  50  15 | 255  48  15 | 0.7 |
| unlit.green | 187 255  82 | 186 255  82 | 0.4 |
| unlit.blue |  68  19 255 |  68  19 255 | 0.2 |
| unlit.cyan | 200 255 255 | 200 255 255 | 0.2 |
| unlit.magenta | 255  63 255 | 255  62 255 | 0.5 |
| unlit.yellow | 255 255  95 | 255 255  95 | 0.1 |
| emissive.grey0.18 | 162 162 162 | 162 162 162 | 0.1 |
| emissive.white1 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 179  92 | 255 179  92 | 0.1 |
| emissive.orange4 | 255 255 201 | 255 255 202 | 0.5 |
| emissive.blue2 | 246 255 255 | 243 255 255 | 1.0 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.2 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.2 |
| lit.red |   0   0   0 |   0   0   0 | 0.2 |
| lit.green |   0   0   0 |   0   0   0 | 0.2 |
| lit.blue |   0   0   0 |   0   0   0 | 0.2 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.2 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.2 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.2 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.2 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.2 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.2 |
| point.centre |   0   0   0 |   0   0   0 | 0.2 |
| point.edge |   0   0   0 |   0   0   0 | 0.2 |
| spot.centre |   0   0   0 |   0   0   0 | 0.2 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.2 |
| spot.outside |   0   0   0 |   0   0   0 | 0.2 |
| ibl.card |   0   0   0 |   0   0   0 | 0.2 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.2 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.2 |
| sky | 123 170 231 | 124 170 231 | 0.3 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 0.8 | 6.9 (unlit.grey0.5) | 8 | ok |
| emissive | 6 | 0.3 | 1.0 (emissive.blue2) | 8 | ok |
| lit | 13 | 0.2 | 0.2 (lit.yellow) | 16 | ok |
| sphere | 3 | 0.2 | 0.2 (sphere.glossy) | 16 | ok |
| light | 5 | 0.2 | 0.2 (point.edge) | 16 | ok |
| shadow | 2 | 0.2 | 0.2 (shadow.lit) | 16 | ok |
| sky | 1 | 0.3 | 0.3 (sky) | 8 | ok |

### directional

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.6 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.5 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 | 120 120 120 | 0.8 |
| emissive.white1 | 255 255 255 | 250 248 248 | 6.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 125  67 | 248 126  67 | 2.8 |
| emissive.orange4 | 255 255 135 | 255 253 135 | 0.7 |
| emissive.blue2 | 142 232 255 | 142 233 255 | 0.3 |
| lit.grey0.04 |  47  47  47 |  47  47  47 | 0.5 |
| lit.grey0.18 |  91  91  91 |  92  92  92 | 1.1 |
| lit.grey0.5 | 144 144 144 | 145 145 145 | 1.5 |
| lit.grey1.0 | 196 196 196 | 198 198 198 | 1.7 |
| lit.white.rough0.5 | 200 200 200 | 201 200 201 | 1.1 |
| lit.indigo |  35  42  63 |  36  42  64 | 0.9 |
| lit.red | 196  18  18 | 198  19  19 | 1.1 |
| lit.green |  18 196  18 |  19 198  19 | 1.3 |
| lit.blue |  18  18 196 |  19  19 198 | 1.1 |
| lit.cyan |  18 196 196 |  19 198 198 | 1.7 |
| lit.magenta | 196  18 196 | 198  19 198 | 1.5 |
| lit.yellow | 196 196  18 | 198 198  19 | 1.7 |
| sphere.dielectric | 141 141 141 | 143 143 143 | 1.3 |
| sphere.metal |  92  84  61 |  94  85  62 | 1.3 |
| sphere.glossy | 151  50  50 | 153  50  50 | 0.6 |
| point.centre | 196 196 196 | 198 198 198 | 1.8 |
| point.edge | 196 196 196 | 198 198 198 | 1.7 |
| spot.centre | 196 196 196 | 198 198 198 | 2.1 |
| spot.penumbra | 195 195 195 | 198 198 198 | 2.4 |
| spot.outside | 195 195 195 | 198 198 198 | 2.3 |
| ibl.card | 195 195 195 | 198 198 198 | 2.8 |
| shadow.lit | 143 143 143 | 145 145 145 | 2.5 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.2 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 5.0 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.9 | 6.5 (emissive.white1) | 8 | ok |
| lit | 13 | 1.4 | 2.8 (ibl.card) | 16 | ok |
| sphere | 3 | 1.1 | 1.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 2.1 | 2.4 (spot.penumbra) | 16 | ok |
| shadow | 2 | 1.4 | 2.5 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### point

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.7 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.5 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| emissive.white1 | 255 255 255 | 249 247 248 | 6.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  64 | 247 124  63 | 2.8 |
| emissive.orange4 | 255 255 134 | 255 253 134 | 0.8 |
| emissive.blue2 | 141 232 255 | 141 232 255 | 0.2 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.2 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.2 |
| lit.red |   1   0   0 |   1   0   0 | 0.2 |
| lit.green |   0   1   0 |   0   1   0 | 0.2 |
| lit.blue |   0   0   0 |   0   0   0 | 0.2 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.2 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.2 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.2 |
| sphere.dielectric |  16  16  16 |  17  17  17 | 0.5 |
| sphere.metal |   3   3   2 |   3   3   2 | 0.0 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.2 |
| point.centre | 208 208 208 | 208 208 208 | 0.6 |
| point.edge | 157 157 157 | 157 157 157 | 0.2 |
| spot.centre |  46  46  46 |  47  47  47 | 0.1 |
| spot.penumbra |   7   7   7 |   7   7   7 | 0.5 |
| spot.outside |  31  31  31 |  31  31  31 | 0.4 |
| ibl.card |   0   0   0 |   0   0   0 | 0.2 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.2 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.2 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 5.0 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.9 | 6.9 (emissive.white1) | 8 | ok |
| lit | 13 | 0.2 | 0.2 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 0.2 | 0.5 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.4 | 0.6 (point.centre) | 16 | ok |
| shadow | 2 | 0.2 | 0.2 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### spot

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.7 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.5 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| emissive.white1 | 255 255 255 | 249 247 248 | 6.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  64 | 247 124  63 | 2.8 |
| emissive.orange4 | 255 255 134 | 255 253 134 | 0.8 |
| emissive.blue2 | 141 232 255 | 141 232 255 | 0.2 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.2 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.2 |
| lit.red |   0   0   0 |   0   0   0 | 0.2 |
| lit.green |   0   0   0 |   0   0   0 | 0.2 |
| lit.blue |   0   0   0 |   0   0   0 | 0.2 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.2 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.2 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.2 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.2 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.2 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.2 |
| point.centre |   0   0   0 |   0   0   0 | 0.2 |
| point.edge |   0   0   0 |   0   0   0 | 0.2 |
| spot.centre | 209 209 209 | 210 210 210 | 1.1 |
| spot.penumbra | 151 151 151 | 121 121 121 | 30.1 |
| spot.outside |   0   0   0 |   0   0   0 | 0.2 |
| ibl.card |   0   0   0 |   0   0   0 | 0.2 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.2 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.2 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 5.0 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.9 | 6.9 (emissive.white1) | 8 | ok |
| lit | 13 | 0.2 | 0.2 (lit.indigo) | 16 | ok |
| sphere | 3 | 0.2 | 0.2 (sphere.dielectric) | 16 | ok |
| light | 5 | 6.4 | 30.1 (spot.penumbra) | 16 | over |
| shadow | 2 | 0.2 | 0.2 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### ibl-constant

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.6 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.5 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 | 120 120 120 | 0.8 |
| emissive.white1 | 255 255 255 | 250 248 248 | 6.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  66 | 248 126  68 | 3.5 |
| emissive.orange4 | 255 255 134 | 255 253 136 | 1.1 |
| emissive.blue2 | 141 232 255 | 142 233 255 | 0.7 |
| lit.grey0.04 |  36  36  36 |  45  45  45 | 9.4 |
| lit.grey0.18 |  77  77  77 |  88  87  88 | 10.5 |
| lit.grey0.5 | 132 132 132 | 139 138 138 | 6.5 |
| lit.grey1.0 | 196 196 196 | 189 188 189 | 7.5 |
| lit.white.rough0.5 | 192 192 192 | 189 188 188 | 3.5 |
| lit.indigo |  26  31  51 |  35  41  61 | 9.4 |
| lit.red | 196  10  10 | 188  19  19 | 8.8 |
| lit.green |  10 196  10 |  20 188  19 | 9.0 |
| lit.blue |  10  10 196 |  20  19 189 | 8.8 |
| lit.cyan |  10 196 196 |  20 189 189 | 8.3 |
| lit.magenta | 196  10 196 | 189  19 189 | 8.1 |
| lit.yellow | 196 196  10 | 189 188  20 | 8.2 |
| sphere.dielectric | 139 139 139 | 140 140 140 | 0.8 |
| sphere.metal | 182 162 110 | 188 167 114 | 5.0 |
| sphere.glossy | 153  59  59 | 151  59  59 | 0.8 |
| point.centre | 196 196 196 | 189 188 189 | 7.5 |
| point.edge | 196 196 196 | 189 188 189 | 7.5 |
| spot.centre | 196 196 196 | 189 188 189 | 7.5 |
| spot.penumbra | 196 196 196 | 189 188 189 | 7.5 |
| spot.outside | 196 196 196 | 189 188 189 | 7.5 |
| ibl.card | 196 196 196 | 189 188 189 | 7.5 |
| shadow.lit | 132 132 132 | 139 138 138 | 6.5 |
| shadow.umbra | 132 132 132 | 139 138 138 | 6.5 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 5.0 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 2.1 | 6.5 (emissive.white1) | 8 | ok |
| lit | 13 | 8.1 | 10.5 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 2.2 | 5.0 (sphere.metal) | 16 | ok |
| light | 5 | 7.5 | 7.5 (spot.penumbra) | 16 | ok |
| shadow | 2 | 6.5 | 6.5 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### ibl-studio

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.7 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.5 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 | 120 120 120 | 1.2 |
| emissive.white1 | 255 255 255 | 250 248 248 | 6.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  66 | 248 126  68 | 3.7 |
| emissive.orange4 | 255 255 134 | 255 254 136 | 1.1 |
| emissive.blue2 | 141 232 255 | 143 233 255 | 1.0 |
| lit.grey0.04 |  40  40  41 |  49  49  49 | 9.0 |
| lit.grey0.18 |  83  83  83 |  94  95  95 | 11.5 |
| lit.grey0.5 | 142 142 142 | 148 149 150 | 7.0 |
| lit.grey1.0 | 209 209 209 | 201 202 203 | 7.1 |
| lit.white.rough0.5 | 206 206 207 | 201 202 203 | 4.5 |
| lit.indigo |  29  34  56 |  38  44  66 | 9.9 |
| lit.red | 209  12  12 | 201  22  21 | 9.0 |
| lit.green |  12 209  12 |  22 202  22 | 8.9 |
| lit.blue |  12  12 209 |  22  22 203 | 8.4 |
| lit.cyan |  12 209 209 |  22 202 203 | 7.7 |
| lit.magenta | 209  12 209 | 201  22 203 | 7.9 |
| lit.yellow | 209 209  12 | 201 202  22 | 8.2 |
| sphere.dielectric | 149 149 150 | 149 150 150 | 0.2 |
| sphere.metal | 191 170 117 | 194 174 119 | 3.1 |
| sphere.glossy | 164  64  64 | 161  64  64 | 1.1 |
| point.centre | 209 209 209 | 201 202 203 | 7.1 |
| point.edge | 209 209 209 | 201 202 203 | 7.1 |
| spot.centre | 209 209 209 | 201 202 203 | 7.1 |
| spot.penumbra | 209 209 209 | 201 202 203 | 7.1 |
| spot.outside | 209 209 209 | 201 202 203 | 7.1 |
| ibl.card | 209 209 209 | 201 202 203 | 7.1 |
| shadow.lit | 142 142 142 | 148 149 150 | 6.9 |
| shadow.umbra | 142 142 142 | 148 149 150 | 6.9 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 5.0 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 2.3 | 6.5 (emissive.white1) | 8 | ok |
| lit | 13 | 8.2 | 11.5 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 1.5 | 3.1 (sphere.metal) | 16 | ok |
| light | 5 | 7.1 | 7.1 (spot.penumbra) | 16 | ok |
| shadow | 2 | 6.9 | 6.9 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### all

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   8   8   8 |  10  10  10 | 1.9 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.9 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.4 |
| unlit.grey0.5 | 180 180 180 | 181 181 181 | 1.0 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.2 |
| unlit.indigo |   0  23  68 |   1  22  68 | 0.5 |
| unlit.red | 254   0   0 | 247   0   0 | 2.5 |
| unlit.green |   0 246   0 |   0 242   0 | 1.3 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.9 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.0 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 238 237   0 | 2.5 |
| emissive.grey0.18 | 108 108 108 | 109 109 109 | 1.3 |
| emissive.white1 | 240 240 240 | 235 235 235 | 5.3 |
| emissive.white4 | 253 253 253 | 249 249 249 | 4.0 |
| emissive.orange1 | 251 115  38 | 247 116  42 | 3.0 |
| emissive.orange4 | 255 174 138 | 255 174 138 | 0.1 |
| emissive.blue2 | 121 182 255 | 121 182 255 | 0.3 |
| lit.grey0.04 |  30  30  30 |  39  40  40 | 9.5 |
| lit.grey0.18 | 104 104 104 | 113 112 112 | 8.0 |
| lit.grey0.5 | 182 182 182 | 188 188 188 | 5.7 |
| lit.grey1.0 | 243 243 243 | 239 238 239 | 4.4 |
| lit.white.rough0.5 | 243 243 243 | 240 240 240 | 2.8 |
| lit.indigo |   3  26  67 |  12  32  73 | 7.1 |
| lit.red | 255   0   0 | 251   0   0 | 1.4 |
| lit.green |   0 250   0 |   0 246   0 | 1.3 |
| lit.blue |  14  14 252 |  16  16 249 | 2.3 |
| lit.cyan |   0 244 244 |   1 240 241 | 2.6 |
| lit.magenta | 250   0 250 | 246   0 247 | 2.2 |
| lit.yellow | 244 244   0 | 241 241   2 | 2.5 |
| sphere.dielectric | 188 188 188 | 189 189 189 | 1.1 |
| sphere.metal | 198 176 117 | 204 181 121 | 4.4 |
| sphere.glossy | 202  54  54 | 201  54  54 | 0.3 |
| point.centre | 249 249 249 | 241 241 242 | 7.6 |
| point.edge | 247 247 247 | 242 242 242 | 5.7 |
| spot.centre | 250 250 250 | 241 241 242 | 8.6 |
| spot.penumbra | 247 247 247 | 239 239 239 | 8.5 |
| spot.outside | 243 243 243 | 240 240 240 | 3.3 |
| ibl.card | 243 243 243 | 239 238 239 | 4.0 |
| shadow.lit | 181 181 181 | 188 188 188 | 6.2 |
| shadow.umbra | 121 121 121 | 128 128 128 | 7.0 |
| sky |  68 112 162 |  69 112 162 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 2.5 | 6.9 (unlit.blue) | 8 | ok |
| emissive | 6 | 2.3 | 5.3 (emissive.white1) | 8 | ok |
| lit | 13 | 4.1 | 9.5 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 2.0 | 4.4 (sphere.metal) | 16 | ok |
| light | 5 | 6.8 | 8.6 (spot.centre) | 16 | ok |
| shadow | 2 | 6.6 | 7.0 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### default-stage

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   8   8   8 |  18  15  15 | 7.9 |
| unlit.grey0.05 |  34  34  34 |  41  39  39 | 5.9 |
| unlit.grey0.18 | 105 105 105 | 108 107 107 | 2.0 |
| unlit.grey0.5 | 180 180 180 | 183 182 182 | 2.2 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 5.9 |
| unlit.indigo |   0  23  68 |  11  22  69 | 4.4 |
| unlit.red | 254   0   0 | 247   0   0 | 2.4 |
| unlit.green |   0 246   0 |   0 243   0 | 1.1 |
| unlit.blue |   0   0 248 |  24  17 246 | 14.3 |
| unlit.cyan |   0 241 241 |  16 237 237 | 7.8 |
| unlit.magenta | 246   0 246 | 244   0 243 | 1.7 |
| unlit.yellow | 241 241   0 | 239 237   2 | 2.6 |
| emissive.grey0.18 | 108 108 108 | 113 112 112 | 4.4 |
| emissive.white1 | 241 241 241 | 237 237 237 | 4.0 |
| emissive.white4 | 255 255 255 | 248 248 248 | 7.2 |
| emissive.orange1 | 251 115  38 | 251 124  65 | 12.0 |
| emissive.orange4 | 255 209 202 | 255 175 145 | 30.5 |
| emissive.blue2 | 121 182 255 | 128 180 255 | 3.2 |
| lit.grey0.04 |  33  33  33 |  49  47  47 | 14.9 |
| lit.grey0.18 | 108 109 109 | 122 122 122 | 13.3 |
| lit.grey0.5 | 189 189 189 | 199 199 199 | 10.0 |
| lit.grey1.0 | 251 251 251 | 238 238 239 | 12.8 |
| lit.white.rough0.5 | 249 250 251 | 238 237 238 | 12.1 |
| lit.indigo |   6  28  71 |  39  39  82 | 18.6 |
| lit.red | 255   0   0 | 255   1   0 | 0.3 |
| lit.green |   0 252   0 |  20 251  17 | 12.5 |
| lit.blue |  29  29 254 |  35  35 253 | 3.9 |
| lit.cyan |  18 246 246 |  45 242 243 | 11.1 |
| lit.magenta | 252   0 252 | 247  20 251 | 8.4 |
| lit.yellow | 250 250  79 | 242 243  37 | 18.8 |
| sphere.dielectric | 192 193 193 | 195 195 195 | 2.3 |
| sphere.metal | 204 180 121 | 207 185 124 | 3.6 |
| sphere.glossy | 211  59  60 | 210  64  65 | 3.6 |
| point.centre | 251 251 251 | 237 238 239 | 12.7 |
| point.edge | 250 251 251 | 238 238 239 | 12.2 |
| spot.centre | 249 250 251 | 237 238 239 | 12.1 |
| spot.penumbra | 249 250 251 | 237 238 239 | 11.9 |
| spot.outside | 249 250 251 | 237 238 239 | 12.0 |
| ibl.card | 250 250 251 | 238 238 239 | 12.0 |
| shadow.lit | 188 188 188 | 195 195 196 | 7.1 |
| shadow.umbra | 132 132 132 | 139 140 141 | 8.1 |
| sky |   0   0   0 |  48  46  62 | 52.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.9 | 14.3 (unlit.blue) | 8 | over |
| emissive | 6 | 10.2 | 30.5 (emissive.orange4) | 8 | over |
| lit | 13 | 11.4 | 18.8 (lit.yellow) | 16 | over |
| sphere | 3 | 3.1 | 3.6 (sphere.metal) | 16 | ok |
| light | 5 | 12.2 | 12.7 (point.centre) | 16 | ok |
| shadow | 2 | 7.6 | 8.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 52.2 | 52.2 (sky) | 8 | over |

### all-bloom

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   8   8   8 |  18  15  15 | 7.9 |
| unlit.grey0.05 |  34  34  34 |  41  39  39 | 5.9 |
| unlit.grey0.18 | 105 105 105 | 108 107 107 | 2.0 |
| unlit.grey0.5 | 180 180 180 | 183 182 182 | 2.2 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 5.9 |
| unlit.indigo |   0  23  68 |  11  22  69 | 4.4 |
| unlit.red | 254   0   0 | 247   0   0 | 2.4 |
| unlit.green |   0 246   0 |   0 243   0 | 1.1 |
| unlit.blue |   0   0 248 |  23  17 246 | 14.3 |
| unlit.cyan |   0 241 241 |  16 237 237 | 7.8 |
| unlit.magenta | 246   0 246 | 244   0 243 | 1.7 |
| unlit.yellow | 241 241   0 | 239 237   1 | 2.6 |
| emissive.grey0.18 | 108 108 108 | 113 112 112 | 4.1 |
| emissive.white1 | 241 241 241 | 237 237 237 | 4.1 |
| emissive.white4 | 255 255 255 | 248 248 248 | 7.2 |
| emissive.orange1 | 251 115  38 | 251 123  63 | 11.4 |
| emissive.orange4 | 255 209 202 | 255 175 145 | 30.6 |
| emissive.blue2 | 121 182 255 | 128 180 255 | 3.3 |
| lit.grey0.04 |  30  30  30 |  46  44  44 | 14.7 |
| lit.grey0.18 | 104 104 104 | 118 117 117 | 12.8 |
| lit.grey0.5 | 182 182 182 | 192 192 192 | 9.9 |
| lit.grey1.0 | 248 248 248 | 242 241 241 | 6.6 |
| lit.white.rough0.5 | 248 248 248 | 244 242 242 | 5.5 |
| lit.indigo |   3  26  67 |  36  35  79 | 17.5 |
| lit.red | 255   0   0 | 253   0   0 | 0.9 |
| lit.green |   0 250   0 |   7 248   3 | 4.1 |
| lit.blue |  14  14 252 |  25  23 250 | 7.3 |
| lit.cyan |   0 244 244 |  26 242 242 | 9.9 |
| lit.magenta | 250   0 250 | 248   1 249 | 1.3 |
| lit.yellow | 245 245  19 | 243 242  18 | 2.2 |
| sphere.dielectric | 188 188 188 | 191 191 191 | 3.3 |
| sphere.metal | 205 181 121 | 208 185 125 | 3.5 |
| sphere.glossy | 203  55  55 | 203  60  60 | 3.1 |
| point.centre | 254 254 254 | 244 244 244 | 10.2 |
| point.edge | 253 253 253 | 246 246 246 | 7.1 |
| spot.centre | 254 254 254 | 245 245 245 | 8.9 |
| spot.penumbra | 253 253 253 | 240 240 240 | 12.7 |
| spot.outside | 249 249 249 | 243 243 243 | 6.2 |
| ibl.card | 248 248 248 | 241 241 241 | 7.2 |
| shadow.lit | 181 181 181 | 189 188 188 | 7.0 |
| shadow.umbra | 121 121 121 | 129 129 129 | 8.1 |
| sky |  68 112 162 |  74 114 163 | 2.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 14.3 (unlit.blue) | 8 | over |
| emissive | 6 | 10.1 | 30.6 (emissive.orange4) | 8 | over |
| lit | 13 | 7.7 | 17.5 (lit.indigo) | 16 | over |
| sphere | 3 | 3.3 | 3.5 (sphere.metal) | 16 | ok |
| light | 5 | 9.0 | 12.7 (spot.penumbra) | 16 | ok |
| shadow | 2 | 7.6 | 8.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 2.7 | 2.7 (sky) | 8 | ok |

