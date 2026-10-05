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
| unlit.grey0.02 |   9   9   9 |  10  10  10 | 0.8 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.8 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| unlit.grey0.5 | 181 181 181 | 181 181 181 | 0.1 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.3 |
| unlit.indigo |   0  22  68 |   1  22  68 | 0.4 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 245   0 |   0 242   0 | 1.0 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.8 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.1 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 237 237   0 | 2.6 |
| emissive.grey0.18 | 105 105 105 |   0   0   0 | 104.9 |
| emissive.white1 | 240 240 240 |   0   0   0 | 239.9 |
| emissive.white4 | 240 240 240 |   0   0   0 | 239.9 |
| emissive.orange1 | 250 112  25 |   0   0   0 | 128.9 |
| emissive.orange4 | 247 222 111 |   0   0   0 | 193.2 |
| emissive.blue2 | 110 218 242 |   0   0   0 | 189.9 |
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
| unlit | 12 | 2.2 | 6.8 (unlit.blue) | 8 | ok |
| emissive | 6 | 182.8 | 239.9 (emissive.white1) | 8 | over |
| lit | 13 | 0.1 | 0.1 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.metal) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.outside) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### unlit-aces

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  21  21  21 |  14  14  14 | 6.9 |
| unlit.grey0.05 |  50  50  50 |  33  34  34 | 16.2 |
| unlit.grey0.18 | 128 128 128 |  92  93  94 | 35.3 |
| unlit.grey0.5 | 197 197 197 | 167 166 166 | 30.7 |
| unlit.grey1.0 | 226 226 226 | 210 207 203 | 19.1 |
| unlit.indigo |  20  31  69 |  13  22  50 | 11.9 |
| unlit.red | 250  16  20 | 207   0   8 | 23.8 |
| unlit.green | 147 228  89 |  87 209  44 | 41.3 |
| unlit.blue |   0   0 228 |   0   0 207 | 7.1 |
| unlit.cyan | 153 227 226 |  99 208 203 | 32.0 |
| unlit.magenta | 247  40 228 | 221   0 205 | 29.6 |
| unlit.yellow | 230 226 106 | 213 207  61 | 27.1 |
| emissive.grey0.18 | 128 128 128 |   0   0   0 | 127.9 |
| emissive.white1 | 226 226 226 |   0   0   0 | 225.9 |
| emissive.white4 | 226 226 226 |   0   0   0 | 225.9 |
| emissive.orange1 | 240 147  75 |   0   0   0 | 153.9 |
| emissive.orange4 | 228 219 161 |   0   0   0 | 202.5 |
| emissive.blue2 | 173 219 225 |   0   0   0 | 205.5 |
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
| sky |  93 135 181 |  59 100 148 | 34.1 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 23.4 | 41.3 (unlit.green) | 8 | over |
| emissive | 6 | 190.3 | 225.9 (emissive.white1) | 8 | over |
| lit | 13 | 0.1 | 0.1 (lit.indigo) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.metal) | 16 | ok |
| light | 5 | 0.1 | 0.1 (point.centre) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 34.1 | 34.1 (sky) | 8 | over |

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
| unlit.grey0.02 |   9   9   9 |  10  10  10 | 0.8 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.8 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| unlit.grey0.5 | 181 181 181 | 181 181 181 | 0.1 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.3 |
| unlit.indigo |   0  22  68 |   1  22  68 | 0.4 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 245   0 |   0 242   0 | 1.0 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.8 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.1 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 237 237   0 | 2.6 |
| emissive.grey0.18 | 107 107 107 |   4   4   4 | 102.9 |
| emissive.white1 | 240 240 240 |   4   4   4 | 235.9 |
| emissive.white4 | 240 240 240 |   4   4   4 | 235.9 |
| emissive.orange1 | 250 114  38 |   4   4   4 | 129.9 |
| emissive.orange4 | 246 223 113 |   4   4   4 | 189.9 |
| emissive.blue2 | 112 219 242 |   4   4   4 | 186.9 |
| lit.grey0.04 |  30  30  30 |  39  40  39 | 9.5 |
| lit.grey0.18 | 104 104 104 | 113 112 112 | 8.3 |
| lit.grey0.5 | 182 182 182 | 188 188 188 | 5.6 |
| lit.grey1.0 | 240 240 240 | 238 238 239 | 1.5 |
| lit.white.rough0.5 | 240 240 240 | 240 240 240 | 0.1 |
| lit.indigo |   4  27  67 |  12  32  73 | 6.7 |
| lit.red | 253   0   0 | 251   0   0 | 0.7 |
| lit.green |   0 245   0 |   0 247   0 | 0.6 |
| lit.blue |   0   0 248 |  16  16 249 | 10.8 |
| lit.cyan |   0 241 241 |   0 241 241 | 0.5 |
| lit.magenta | 246   0 246 | 246   0 247 | 0.4 |
| lit.yellow | 241 241   0 | 241 241   2 | 0.7 |
| sphere.dielectric | 188 188 188 | 189 189 189 | 1.2 |
| sphere.metal | 196 177 121 | 204 181 121 | 3.8 |
| sphere.glossy | 202  54  54 | 202  54  54 | 0.3 |
| point.centre | 240 240 240 | 241 242 242 | 1.4 |
| point.edge | 240 240 240 | 242 242 242 | 1.8 |
| spot.centre | 240 240 240 | 241 241 242 | 1.4 |
| spot.penumbra | 240 240 240 | 239 239 239 | 1.3 |
| spot.outside | 240 240 240 | 240 240 240 | 0.4 |
| ibl.card | 240 240 240 | 238 238 239 | 1.5 |
| shadow.lit | 181 181 181 | 188 188 188 | 6.5 |
| shadow.umbra | 121 121 121 | 128 128 128 | 7.0 |
| sky |  68 112 162 |  69 112 162 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 2.2 | 6.8 (unlit.blue) | 8 | ok |
| emissive | 6 | 180.2 | 235.9 (emissive.white1) | 8 | over |
| lit | 13 | 3.6 | 10.8 (lit.blue) | 16 | ok |
| sphere | 3 | 1.8 | 3.8 (sphere.metal) | 16 | ok |
| light | 5 | 1.3 | 1.8 (point.edge) | 16 | ok |
| shadow | 2 | 6.7 | 7.0 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### all-bloom

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   9   9   9 |   9   9   9 | 0.1 |
| unlit.grey0.05 |  34  34  34 |  36  36  36 | 1.6 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.0 |
| unlit.grey0.5 | 181 181 181 | 181 181 181 | 0.2 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.3 |
| unlit.indigo |   0  22  68 |   1  23  68 | 0.7 |
| unlit.red | 253   0   0 | 247   0   0 | 2.2 |
| unlit.green |   0 245   0 |   0 242   0 | 1.0 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.9 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.0 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 237 237   0 | 2.6 |
| emissive.grey0.18 | 107 107 107 |   9   9   8 | 98.5 |
| emissive.white1 | 240 240 240 |   9   9   8 | 231.4 |
| emissive.white4 | 240 240 240 |   9   9   8 | 231.1 |
| emissive.orange1 | 250 114  38 |  10  10   9 | 124.4 |
| emissive.orange4 | 243 239 124 |  10  10   9 | 192.4 |
| emissive.blue2 | 112 219 242 |   9   9   8 | 182.2 |
| lit.grey0.04 |  30  30  30 |  42  42  41 | 11.5 |
| lit.grey0.18 | 104 104 104 | 113 113 113 | 9.2 |
| lit.grey0.5 | 182 182 182 | 188 188 188 | 6.4 |
| lit.grey1.0 | 240 240 240 | 240 240 240 | 0.1 |
| lit.white.rough0.5 | 240 240 240 | 242 242 242 | 2.0 |
| lit.indigo |   4  27  67 |  17  35  74 | 9.5 |
| lit.red | 253   0   0 | 252   0   0 | 0.3 |
| lit.green |   0 245   0 |   0 248   0 | 0.9 |
| lit.blue |   0   0 248 |  18  20 250 | 13.2 |
| lit.cyan |   0 241 241 |  12 242 242 | 4.6 |
| lit.magenta | 246   0 246 | 248   0 248 | 1.3 |
| lit.yellow | 241 241   0 | 242 242  10 | 3.8 |
| sphere.dielectric | 188 188 188 | 191 191 191 | 3.1 |
| sphere.metal | 199 180 124 | 208 184 124 | 4.5 |
| sphere.glossy | 202  55  55 | 203  59  58 | 2.2 |
| point.centre | 240 240 240 | 244 244 244 | 3.7 |
| point.edge | 240 240 240 | 246 246 246 | 6.1 |
| spot.centre | 240 240 240 | 245 245 245 | 5.0 |
| spot.penumbra | 240 240 240 | 240 240 240 | 0.4 |
| spot.outside | 240 240 240 | 243 243 243 | 2.7 |
| ibl.card | 240 240 240 | 241 240 240 | 0.5 |
| shadow.lit | 181 181 181 | 188 188 188 | 7.2 |
| shadow.umbra | 121 121 121 | 129 129 129 | 7.9 |
| sky |  68 112 162 |  71 113 162 | 1.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 2.3 | 6.9 (unlit.blue) | 8 | ok |
| emissive | 6 | 176.7 | 231.4 (emissive.white1) | 8 | over |
| lit | 13 | 4.9 | 13.2 (lit.blue) | 16 | ok |
| sphere | 3 | 3.3 | 4.5 (sphere.metal) | 16 | ok |
| light | 5 | 3.6 | 6.1 (point.edge) | 16 | ok |
| shadow | 2 | 7.6 | 7.9 (shadow.umbra) | 16 | ok |
| sky | 1 | 1.7 | 1.7 (sky) | 8 | ok |

### default-stage

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |   9   9   9 |   9   9   9 | 0.1 |
| unlit.grey0.05 |  34  34  34 |  36  36  36 | 1.6 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.0 |
| unlit.grey0.5 | 181 181 181 | 181 181 181 | 0.2 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.3 |
| unlit.indigo |   0  22  68 |   1  23  68 | 0.7 |
| unlit.red | 253   0   0 | 247   0   0 | 2.2 |
| unlit.green |   0 245   0 |   0 242   0 | 1.0 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.9 |
| unlit.cyan |   0 241 241 |   0 237 237 | 3.0 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 237 237   0 | 2.6 |
| emissive.grey0.18 | 107 107 107 |  10  10   9 | 97.3 |
| emissive.white1 | 240 240 240 |  10  10   9 | 230.1 |
| emissive.white4 | 240 240 240 |  10  11  10 | 229.5 |
| emissive.orange1 | 250 114  38 |  11  11  11 | 123.0 |
| emissive.orange4 | 243 239 124 |  11  11  11 | 190.9 |
| emissive.blue2 | 112 219 242 |  11  11  10 | 180.3 |
| lit.grey0.04 |  32  32  33 |  44  44  43 | 11.4 |
| lit.grey0.18 | 108 108 108 | 118 119 119 | 10.3 |
| lit.grey0.5 | 188 189 189 | 195 195 196 | 7.0 |
| lit.grey1.0 | 240 240 240 | 238 239 239 | 1.5 |
| lit.white.rough0.5 | 240 240 240 | 237 238 239 | 2.1 |
| lit.indigo |   6  28  70 |  22  39  78 | 11.9 |
| lit.red | 253   0   0 | 255   0   0 | 0.8 |
| lit.green |   0 245   0 |  11 251  11 | 9.5 |
| lit.blue |   0   0 248 |  28  32 253 | 21.5 |
| lit.cyan |   0 241 241 |  35 242 243 | 12.7 |
| lit.magenta | 246   0 246 | 247  15 251 | 7.0 |
| lit.yellow | 241 241   0 | 242 243  31 | 11.4 |
| sphere.dielectric | 192 193 193 | 194 195 195 | 2.0 |
| sphere.metal | 198 180 125 | 206 184 124 | 4.8 |
| sphere.glossy | 210  59  60 | 209  63  63 | 2.6 |
| point.centre | 240 240 240 | 238 238 239 | 1.8 |
| point.edge | 240 240 240 | 238 239 239 | 1.6 |
| spot.centre | 240 240 240 | 237 238 239 | 1.9 |
| spot.penumbra | 240 240 240 | 237 238 239 | 1.9 |
| spot.outside | 240 240 240 | 237 239 239 | 1.8 |
| ibl.card | 240 240 240 | 237 238 239 | 1.8 |
| shadow.lit | 187 188 188 | 195 195 196 | 7.7 |
| shadow.umbra | 131 132 132 | 139 140 141 | 8.3 |
| sky |   0   0   0 |  45  45  60 | 50.3 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 2.3 | 6.9 (unlit.blue) | 8 | ok |
| emissive | 6 | 175.2 | 230.1 (emissive.white1) | 8 | over |
| lit | 13 | 8.4 | 21.5 (lit.blue) | 16 | over |
| sphere | 3 | 3.1 | 4.8 (sphere.metal) | 16 | ok |
| light | 5 | 1.8 | 1.9 (spot.centre) | 16 | ok |
| shadow | 2 | 8.0 | 8.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 50.3 | 50.3 (sky) | 8 | over |

