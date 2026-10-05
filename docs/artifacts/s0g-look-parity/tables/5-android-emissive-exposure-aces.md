### unlit-linear

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.3 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.2 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| emissive.white1 | 255 255 255 | 249 247 248 | 6.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  63 | 247 124  63 | 2.7 |
| emissive.orange4 | 255 231 124 | 255 253 134 | 10.6 |
| emissive.blue2 | 124 231 255 | 141 232 255 | 5.9 |
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
| unlit | 12 | 4.8 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 4.4 | 10.6 (emissive.orange4) | 8 | over |
| lit | 13 | 0.2 | 0.2 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.2 | 0.2 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.2 | 0.2 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.2 | 0.2 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### unlit-neutral

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   9   9   9 |  10  10  10 | 0.9 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.9 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.4 |
| unlit.grey0.5 | 181 181 181 | 181 181 181 | 0.1 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.2 |
| unlit.indigo |   0  22  68 |   1  22  68 | 0.4 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 245   0 |   0 242   0 | 1.0 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.9 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.0 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 238 237   0 | 2.5 |
| emissive.grey0.18 | 105 105 105 | 105 105 105 | 0.4 |
| emissive.white1 | 240 240 240 | 234 234 234 | 6.2 |
| emissive.white4 | 240 240 240 | 249 249 249 | 9.2 |
| emissive.orange1 | 250 112  25 | 246 112  24 | 1.9 |
| emissive.orange4 | 247 222 111 | 255 173 137 | 27.5 |
| emissive.blue2 | 110 218 242 | 119 182 255 | 19.6 |
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
| unlit | 12 | 2.3 | 6.9 (unlit.blue) | 8 | ok |
| emissive | 6 | 10.8 | 27.5 (emissive.orange4) | 8 | over |
| lit | 13 | 0.1 | 0.1 (lit.indigo) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.metal) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.outside) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### unlit-aces

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  21  21  21 |  23  23  24 | 2.5 |
| unlit.grey0.05 |  50  50  50 |  51  52  53 | 1.9 |
| unlit.grey0.18 | 128 128 128 | 128 128 129 | 0.6 |
| unlit.grey0.5 | 197 197 197 | 201 198 195 | 2.4 |
| unlit.grey1.0 | 226 226 226 | 230 225 219 | 3.6 |
| unlit.indigo |  20  31  69 |  22  34  74 | 3.3 |
| unlit.red | 250  16  20 | 244  29  17 | 7.0 |
| unlit.green | 147 228  89 | 150 228  87 | 2.0 |
| unlit.blue |   0   0 228 |   5   0 227 | 1.9 |
| unlit.cyan | 153 227 226 | 158 227 219 | 4.1 |
| unlit.magenta | 247  40 228 | 251  36 224 | 3.9 |
| unlit.yellow | 230 226 106 | 233 226 104 | 1.9 |
| emissive.grey0.18 | 128 128 128 | 128 128 129 | 0.6 |
| emissive.white1 | 226 226 226 | 230 225 219 | 3.6 |
| emissive.white4 | 226 226 226 | 249 244 236 | 16.9 |
| emissive.orange1 | 240 147  75 | 238 150  74 | 1.6 |
| emissive.orange4 | 228 219 161 | 255 225 176 | 15.9 |
| emissive.blue2 | 173 219 225 | 187 220 232 | 7.0 |
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
| sky |  93 135 181 |  94 137 182 | 1.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 2.9 | 7.0 (unlit.red) | 8 | ok |
| emissive | 6 | 7.6 | 16.9 (emissive.white4) | 8 | over |
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
| unlit.indigo |  56  69 111 |  57  69 112 | 0.4 |
| unlit.red | 255   0   0 | 255  48  15 | 21.1 |
| unlit.green |   0 255   0 | 186 255  82 | 89.3 |
| unlit.blue |   0   0 255 |  68  19 255 | 28.9 |
| unlit.cyan |   0 255 255 | 200 255 255 | 66.6 |
| unlit.magenta | 255   0 255 | 255  62 255 | 20.7 |
| unlit.yellow | 255 255   0 | 255 255  95 | 31.8 |
| emissive.grey0.18 | 162 162 162 | 162 162 162 | 0.1 |
| emissive.white1 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 170  89 | 255 179  92 | 4.1 |
| emissive.orange4 | 255 255 170 | 255 255 202 | 10.8 |
| emissive.blue2 | 170 255 255 | 243 255 255 | 24.5 |
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
| sky | 122 170 231 | 124 170 231 | 0.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 22.2 | 89.3 (unlit.green) | 8 | over |
| emissive | 6 | 6.6 | 24.5 (emissive.blue2) | 8 | over |
| lit | 13 | 0.2 | 0.2 (lit.yellow) | 16 | ok |
| sphere | 3 | 0.2 | 0.2 (sphere.glossy) | 16 | ok |
| light | 5 | 0.2 | 0.2 (point.edge) | 16 | ok |
| shadow | 2 | 0.2 | 0.2 (shadow.lit) | 16 | ok |
| sky | 1 | 0.7 | 0.7 (sky) | 8 | ok |

### directional

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.2 |
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
| emissive.orange4 | 255 232 125 | 255 253 135 | 10.7 |
| emissive.blue2 | 125 232 255 | 142 233 255 | 6.0 |
| lit.grey0.04 |  46  46  46 |  47  47  47 | 1.1 |
| lit.grey0.18 |  91  91  91 |  92  92  92 | 1.0 |
| lit.grey0.5 | 144 144 144 | 145 145 145 | 1.1 |
| lit.grey1.0 | 196 196 196 | 198 198 198 | 1.5 |
| lit.white.rough0.5 | 199 199 199 | 201 200 201 | 1.4 |
| lit.indigo |  35  41  63 |  36  42  64 | 1.0 |
| lit.red | 196  18  18 | 198  19  19 | 1.0 |
| lit.green |  18 196  18 |  19 198  19 | 1.2 |
| lit.blue |  18  18 196 |  19  19 198 | 1.0 |
| lit.cyan |  18 196 196 |  19 198 198 | 1.5 |
| lit.magenta | 196  18 196 | 198  19 198 | 1.4 |
| lit.yellow | 196 196  18 | 198 198  19 | 1.6 |
| sphere.dielectric | 141 141 141 | 143 143 143 | 1.3 |
| sphere.metal |  92  84  61 |  94  85  62 | 1.3 |
| sphere.glossy | 151  50  50 | 153  50  50 | 0.6 |
| point.centre | 196 196 196 | 198 198 198 | 1.6 |
| point.edge | 196 196 196 | 198 198 198 | 1.5 |
| spot.centre | 196 196 196 | 198 198 198 | 2.0 |
| spot.penumbra | 195 195 195 | 198 198 198 | 2.3 |
| spot.outside | 196 196 196 | 198 198 198 | 2.2 |
| ibl.card | 195 195 195 | 198 198 198 | 2.6 |
| shadow.lit | 143 143 143 | 145 145 145 | 2.6 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.2 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 4.5 | 10.7 (emissive.orange4) | 8 | over |
| lit | 13 | 1.3 | 2.6 (ibl.card) | 16 | ok |
| sphere | 3 | 1.1 | 1.3 (sphere.metal) | 16 | ok |
| light | 5 | 2.0 | 2.3 (spot.penumbra) | 16 | ok |
| shadow | 2 | 1.4 | 2.6 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### point

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.3 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.2 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| emissive.white1 | 255 255 255 | 249 247 248 | 6.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  63 | 247 124  63 | 2.7 |
| emissive.orange4 | 255 231 124 | 255 253 134 | 10.6 |
| emissive.blue2 | 124 231 255 | 141 232 255 | 5.9 |
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
| point.centre | 208 208 208 | 208 208 208 | 0.3 |
| point.edge | 157 157 157 | 157 157 157 | 0.2 |
| spot.centre |  46  46  46 |  47  47  47 | 0.3 |
| spot.penumbra |   7   7   7 |   7   7   7 | 0.5 |
| spot.outside |  31  31  31 |  31  31  31 | 0.2 |
| ibl.card |   0   0   0 |   0   0   0 | 0.2 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.2 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.2 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 4.4 | 10.6 (emissive.orange4) | 8 | over |
| lit | 13 | 0.2 | 0.2 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 0.2 | 0.5 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.3 | 0.5 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.2 | 0.2 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### spot

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.3 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.2 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| emissive.white1 | 255 255 255 | 249 247 248 | 6.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  63 | 247 124  63 | 2.7 |
| emissive.orange4 | 255 231 124 | 255 253 134 | 10.6 |
| emissive.blue2 | 124 231 255 | 141 232 255 | 5.9 |
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
| spot.centre | 210 210 210 | 210 210 210 | 0.4 |
| spot.penumbra | 151 151 151 | 121 121 121 | 30.2 |
| spot.outside |   0   0   0 |   0   0   0 | 0.2 |
| ibl.card |   0   0   0 |   0   0   0 | 0.2 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.2 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.2 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 4.4 | 10.6 (emissive.orange4) | 8 | over |
| lit | 13 | 0.2 | 0.2 (lit.indigo) | 16 | ok |
| sphere | 3 | 0.2 | 0.2 (sphere.dielectric) | 16 | ok |
| light | 5 | 6.2 | 30.2 (spot.penumbra) | 16 | over |
| shadow | 2 | 0.2 | 0.2 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### ibl-constant

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.2 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 | 120 120 120 | 0.8 |
| emissive.white1 | 255 255 255 | 250 248 248 | 6.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  65 | 248 126  68 | 3.9 |
| emissive.orange4 | 255 231 124 | 255 253 136 | 11.4 |
| emissive.blue2 | 124 231 255 | 142 233 255 | 6.7 |
| lit.grey0.04 |  36  36  36 |  45  45  45 | 9.4 |
| lit.grey0.18 |  77  77  77 |  88  87  88 | 10.5 |
| lit.grey0.5 | 132 132 132 | 139 138 138 | 6.5 |
| lit.grey1.0 | 195 195 195 | 189 188 189 | 6.5 |
| lit.white.rough0.5 | 192 192 192 | 189 188 188 | 3.5 |
| lit.indigo |  26  32  51 |  35  41  61 | 9.1 |
| lit.red | 195  10  10 | 188  19  19 | 8.5 |
| lit.green |  10 195  10 |  20 188  19 | 8.7 |
| lit.blue |  10  10 195 |  20  19 189 | 8.4 |
| lit.cyan |  10 195 195 |  20 189 189 | 7.6 |
| lit.magenta | 195  10 195 | 189  19 189 | 7.4 |
| lit.yellow | 195 195  10 | 189 188  20 | 7.5 |
| sphere.dielectric | 139 139 139 | 140 140 140 | 0.8 |
| sphere.metal | 182 162 111 | 188 167 114 | 4.8 |
| sphere.glossy | 153  59  59 | 151  59  59 | 0.8 |
| point.centre | 195 195 195 | 189 188 189 | 6.5 |
| point.edge | 195 195 195 | 189 188 189 | 6.5 |
| spot.centre | 195 195 195 | 189 188 189 | 6.5 |
| spot.penumbra | 195 195 195 | 189 188 189 | 6.5 |
| spot.outside | 195 195 195 | 189 188 189 | 6.5 |
| ibl.card | 195 195 195 | 189 188 189 | 6.5 |
| shadow.lit | 132 132 132 | 139 138 138 | 6.5 |
| shadow.umbra | 132 132 132 | 139 138 138 | 6.5 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 4.9 | 11.4 (emissive.orange4) | 8 | over |
| lit | 13 | 7.7 | 10.5 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 2.1 | 4.8 (sphere.metal) | 16 | ok |
| light | 5 | 6.5 | 6.5 (spot.penumbra) | 16 | ok |
| shadow | 2 | 6.5 | 6.5 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### ibl-studio

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.3 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 188 188 188 | 188 188 188 | 0.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  39  48  80 |  39  48  80 | 0.2 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   7 | 12.5 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.4 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 | 120 120 120 | 1.2 |
| emissive.white1 | 255 255 255 | 250 248 248 | 6.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 125  66 | 248 126  68 | 3.4 |
| emissive.orange4 | 255 232 125 | 255 254 136 | 10.9 |
| emissive.blue2 | 125 232 255 | 143 233 255 | 6.4 |
| lit.grey0.04 |  40  40  40 |  49  49  49 | 9.3 |
| lit.grey0.18 |  83  83  83 |  94  95  95 | 11.5 |
| lit.grey0.5 | 141 142 142 | 148 149 150 | 7.3 |
| lit.grey1.0 | 209 209 210 | 201 202 203 | 7.4 |
| lit.white.rough0.5 | 205 206 207 | 201 202 203 | 4.3 |
| lit.indigo |  29  35  56 |  38  44  66 | 9.5 |
| lit.red | 209  12  12 | 201  22  21 | 9.0 |
| lit.green |  12 209  12 |  22 202  22 | 8.9 |
| lit.blue |  12  12 210 |  22  22 203 | 8.7 |
| lit.cyan |  12 209 210 |  22 202 203 | 8.1 |
| lit.magenta | 209  12 210 | 201  22 203 | 8.2 |
| lit.yellow | 209 209  12 | 201 202  22 | 8.2 |
| sphere.dielectric | 149 150 150 | 149 150 150 | 0.2 |
| sphere.metal | 191 170 117 | 194 174 119 | 3.1 |
| sphere.glossy | 164  64  64 | 161  64  64 | 1.2 |
| point.centre | 209 209 210 | 201 202 203 | 7.5 |
| point.edge | 209 209 210 | 201 202 203 | 7.5 |
| spot.centre | 209 209 210 | 201 202 203 | 7.4 |
| spot.penumbra | 209 209 210 | 201 202 203 | 7.5 |
| spot.outside | 209 209 210 | 201 202 203 | 7.5 |
| ibl.card | 209 209 210 | 201 202 203 | 7.4 |
| shadow.lit | 141 142 142 | 148 149 150 | 7.3 |
| shadow.umbra | 141 142 142 | 148 149 150 | 7.3 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.4 (unlit.cyan) | 8 | over |
| emissive | 6 | 4.7 | 10.9 (emissive.orange4) | 8 | over |
| lit | 13 | 8.3 | 11.5 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 1.5 | 3.1 (sphere.metal) | 16 | ok |
| light | 5 | 7.5 | 7.5 (spot.penumbra) | 16 | ok |
| shadow | 2 | 7.3 | 7.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### all

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   9   9   9 |  10  10  10 | 0.9 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.9 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.4 |
| unlit.grey0.5 | 181 181 181 | 181 181 181 | 0.1 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.2 |
| unlit.indigo |   0  22  68 |   1  22  68 | 0.4 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 245   0 |   0 242   0 | 1.0 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.9 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.0 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 238 237   0 | 2.5 |
| emissive.grey0.18 | 107 107 107 | 109 109 109 | 2.3 |
| emissive.white1 | 240 240 240 | 235 235 235 | 5.3 |
| emissive.white4 | 240 240 240 | 249 249 249 | 9.0 |
| emissive.orange1 | 250 114  38 | 247 116  42 | 3.0 |
| emissive.orange4 | 246 223 113 | 255 174 138 | 27.7 |
| emissive.blue2 | 112 219 242 | 121 182 255 | 19.7 |
| lit.grey0.04 |  30  30  30 |  39  40  40 | 9.5 |
| lit.grey0.18 | 104 104 104 | 113 112 112 | 8.3 |
| lit.grey0.5 | 182 182 182 | 188 188 188 | 5.6 |
| lit.grey1.0 | 240 240 240 | 239 238 239 | 1.4 |
| lit.white.rough0.5 | 240 240 240 | 240 240 240 | 0.1 |
| lit.indigo |   4  27  67 |  12  32  73 | 6.7 |
| lit.red | 253   0   0 | 251   0   0 | 0.7 |
| lit.green |   0 245   0 |   0 246   0 | 0.5 |
| lit.blue |   0   0 248 |  16  16 249 | 10.9 |
| lit.cyan |   0 241 241 |   1 240 241 | 0.6 |
| lit.magenta | 246   0 246 | 246   0 247 | 0.4 |
| lit.yellow | 241 241   0 | 241 241   2 | 0.7 |
| sphere.dielectric | 188 188 188 | 189 189 189 | 1.2 |
| sphere.metal | 196 177 121 | 204 181 121 | 3.8 |
| sphere.glossy | 202  54  54 | 201  54  54 | 0.3 |
| point.centre | 240 240 240 | 241 241 242 | 1.4 |
| point.edge | 240 240 240 | 242 242 242 | 1.7 |
| spot.centre | 240 240 240 | 241 241 242 | 1.3 |
| spot.penumbra | 240 240 240 | 239 239 239 | 1.3 |
| spot.outside | 240 240 240 | 240 240 240 | 0.3 |
| ibl.card | 240 240 240 | 239 238 239 | 1.4 |
| shadow.lit | 181 181 181 | 188 188 188 | 6.5 |
| shadow.umbra | 121 121 121 | 128 128 128 | 7.0 |
| sky |  68 112 162 |  69 112 162 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 2.3 | 6.9 (unlit.blue) | 8 | ok |
| emissive | 6 | 11.2 | 27.7 (emissive.orange4) | 8 | over |
| lit | 13 | 3.6 | 10.9 (lit.blue) | 16 | ok |
| sphere | 3 | 1.7 | 3.8 (sphere.metal) | 16 | ok |
| light | 5 | 1.2 | 1.7 (point.edge) | 16 | ok |
| shadow | 2 | 6.8 | 7.0 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### default-stage

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   9   9   9 |  18  15  15 | 6.9 |
| unlit.grey0.05 |  34  34  34 |  41  39  39 | 5.9 |
| unlit.grey0.18 | 105 105 105 | 108 107 107 | 2.0 |
| unlit.grey0.5 | 181 181 181 | 183 182 182 | 1.2 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 5.9 |
| unlit.indigo |   0  22  68 |  11  22  69 | 4.1 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 245   0 |   0 243   0 | 0.7 |
| unlit.blue |   0   0 248 |  24  17 246 | 14.3 |
| unlit.cyan |   0 241 241 |  16 237 237 | 7.8 |
| unlit.magenta | 246   0 246 | 244   0 243 | 1.7 |
| unlit.yellow | 241 241   0 | 239 237   2 | 2.6 |
| emissive.grey0.18 | 107 107 107 | 113 112 112 | 5.4 |
| emissive.white1 | 240 240 240 | 237 237 237 | 3.0 |
| emissive.white4 | 240 240 240 | 248 248 248 | 7.8 |
| emissive.orange1 | 250 114  38 | 251 124  65 | 12.7 |
| emissive.orange4 | 243 239 124 | 255 175 145 | 32.4 |
| emissive.blue2 | 112 219 242 | 128 180 255 | 22.8 |
| lit.grey0.04 |  32  32  33 |  49  47  47 | 15.3 |
| lit.grey0.18 | 108 108 108 | 122 122 122 | 13.9 |
| lit.grey0.5 | 188 189 189 | 199 199 199 | 10.3 |
| lit.grey1.0 | 240 240 240 | 238 238 239 | 1.8 |
| lit.white.rough0.5 | 240 240 240 | 238 237 238 | 2.2 |
| lit.indigo |   6  28  70 |  39  39  82 | 18.9 |
| lit.red | 253   0   0 | 255   1   0 | 0.9 |
| lit.green |   0 245   0 |  20 251  17 | 14.1 |
| lit.blue |   0   0 248 |  35  35 253 | 24.7 |
| lit.cyan |   0 241 241 |  45 242 243 | 15.8 |
| lit.magenta | 246   0 246 | 247  20 251 | 8.7 |
| lit.yellow | 241 241   0 | 242 243  37 | 13.3 |
| sphere.dielectric | 192 193 193 | 195 195 195 | 2.3 |
| sphere.metal | 198 180 125 | 207 185 124 | 4.8 |
| sphere.glossy | 210  59  60 | 210  64  65 | 3.3 |
| point.centre | 240 240 240 | 237 238 239 | 1.8 |
| point.edge | 240 240 240 | 238 238 239 | 1.6 |
| spot.centre | 240 240 240 | 237 238 239 | 1.9 |
| spot.penumbra | 240 240 240 | 237 238 239 | 1.9 |
| spot.outside | 240 240 240 | 237 238 239 | 1.8 |
| ibl.card | 240 240 240 | 238 238 239 | 1.8 |
| shadow.lit | 187 188 188 | 195 195 196 | 7.7 |
| shadow.umbra | 131 132 132 | 139 140 141 | 8.4 |
| sky |   0   0   0 |  48  46  62 | 52.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.6 | 14.3 (unlit.blue) | 8 | over |
| emissive | 6 | 14.0 | 32.4 (emissive.orange4) | 8 | over |
| lit | 13 | 10.9 | 24.7 (lit.blue) | 16 | over |
| sphere | 3 | 3.4 | 4.8 (sphere.metal) | 16 | ok |
| light | 5 | 1.8 | 1.9 (spot.penumbra) | 16 | ok |
| shadow | 2 | 8.0 | 8.4 (shadow.umbra) | 16 | ok |
| sky | 1 | 52.2 | 52.2 (sky) | 8 | over |

### all-bloom

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   9   9   9 |  18  15  15 | 6.9 |
| unlit.grey0.05 |  34  34  34 |  41  39  39 | 5.9 |
| unlit.grey0.18 | 105 105 105 | 108 107 107 | 2.0 |
| unlit.grey0.5 | 181 181 181 | 183 182 182 | 1.2 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 5.9 |
| unlit.indigo |   0  22  68 |  11  22  69 | 4.1 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 245   0 |   0 243   0 | 0.7 |
| unlit.blue |   0   0 248 |  23  17 246 | 14.3 |
| unlit.cyan |   0 241 241 |  16 237 237 | 7.8 |
| unlit.magenta | 246   0 246 | 244   0 243 | 1.7 |
| unlit.yellow | 241 241   0 | 239 237   1 | 2.6 |
| emissive.grey0.18 | 107 107 107 | 113 112 112 | 5.1 |
| emissive.white1 | 240 240 240 | 237 237 237 | 3.1 |
| emissive.white4 | 240 240 240 | 248 248 248 | 7.8 |
| emissive.orange1 | 250 114  38 | 251 123  63 | 12.0 |
| emissive.orange4 | 243 239 124 | 255 175 145 | 32.4 |
| emissive.blue2 | 112 219 242 | 128 180 255 | 22.8 |
| lit.grey0.04 |  30  30  30 |  46  44  44 | 14.7 |
| lit.grey0.18 | 104 104 104 | 118 117 117 | 13.0 |
| lit.grey0.5 | 182 182 182 | 192 192 192 | 9.9 |
| lit.grey1.0 | 240 240 240 | 242 241 241 | 1.4 |
| lit.white.rough0.5 | 240 240 240 | 244 242 242 | 2.5 |
| lit.indigo |   4  27  67 |  36  35  79 | 17.1 |
| lit.red | 253   0   0 | 253   0   0 | 0.2 |
| lit.green |   0 245   0 |   7 248   3 | 4.4 |
| lit.blue |   0   0 248 |  25  23 250 | 16.7 |
| lit.cyan |   0 241 241 |  26 242 242 | 9.4 |
| lit.magenta | 246   0 246 | 248   1 249 | 2.1 |
| lit.yellow | 241 241   0 | 243 242  18 | 6.7 |
| sphere.dielectric | 188 188 188 | 191 191 191 | 3.4 |
| sphere.metal | 199 180 124 | 208 185 125 | 5.0 |
| sphere.glossy | 202  55  55 | 203  60  60 | 3.2 |
| point.centre | 240 240 240 | 244 244 244 | 3.7 |
| point.edge | 240 240 240 | 246 246 246 | 6.0 |
| spot.centre | 240 240 240 | 245 245 245 | 5.1 |
| spot.penumbra | 240 240 240 | 240 240 240 | 0.4 |
| spot.outside | 240 240 240 | 243 243 243 | 2.8 |
| ibl.card | 240 240 240 | 241 241 241 | 0.8 |
| shadow.lit | 181 181 181 | 189 188 188 | 7.3 |
| shadow.umbra | 121 121 121 | 129 129 129 | 8.1 |
| sky |  68 112 162 |  74 114 163 | 2.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.6 | 14.3 (unlit.blue) | 8 | over |
| emissive | 6 | 13.9 | 32.4 (emissive.orange4) | 8 | over |
| lit | 13 | 7.6 | 17.1 (lit.indigo) | 16 | over |
| sphere | 3 | 3.9 | 5.0 (sphere.metal) | 16 | ok |
| light | 5 | 3.6 | 6.0 (point.edge) | 16 | ok |
| shadow | 2 | 7.7 | 8.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 2.7 | 2.7 (sky) | 8 | ok |

