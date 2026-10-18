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
| unlit.magenta | 255   0 255 | 247   0 247 | 5.3 |
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
| spot.penumbra |   0   0   0 |   0   0   0 | 0.3 |
| spot.outside |   0   0   0 |   0   0   0 | 0.3 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 196.7 | 254.7 (emissive.white4) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.3 | 0.3 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.lit) | 16 | ok |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

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
| sky |  88 124 170 |  54  96 142 | 29.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 14.5 | 29.2 (unlit.grey0.02) | 8 | over |
| emissive | 6 | 196.9 | 254.9 (emissive.white1) | 8 | over |
| lit | 13 | 0.1 | 0.1 (lit.red) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.centre) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 29.7 | 29.7 (sky) | 8 | over |

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
| sky |  88 124 170 |  47  84 129 | 40.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 34.6 | 65.9 (unlit.cyan) | 8 | over |
| emissive | 6 | 196.9 | 254.9 (emissive.white1) | 8 | over |
| lit | 13 | 0.1 | 0.1 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.outside) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 40.7 | 40.7 (sky) | 8 | over |

### unlit-exposure2

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  56  56  56 |  39  39  39 | 17.3 |
| unlit.grey0.05 |  89  89  89 |  63  63  63 | 25.6 |
| unlit.grey0.18 | 162 162 162 | 118 118 118 | 44.2 |
| unlit.grey0.5 | 255 255 255 | 188 188 188 | 67.1 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  56  69 111 |  39  48  80 | 22.9 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   0 247 | 5.3 |
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
| unlit | 12 | 19.5 | 67.1 (unlit.grey0.5) | 8 | over |
| emissive | 6 | 215.8 | 254.7 (emissive.white4) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.cyan) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.metal) | 16 | ok |
| light | 5 | 0.3 | 0.3 (spot.centre) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 18.0 | 18.0 (sky) | 8 | over |

### directional

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
| emissive.grey0.18 | 120 120 120 |   3   3   3 | 116.8 |
| emissive.white1 | 255 255 255 |   3   3   3 | 251.8 |
| emissive.white4 | 255 255 255 |   3   3   3 | 251.8 |
| emissive.orange1 | 255 126  69 |   3   3   3 | 146.8 |
| emissive.orange4 | 255 232 126 |   3   3   3 | 201.1 |
| emissive.blue2 | 126 232 255 |   3   3   3 | 201.2 |
| lit.grey0.04 |  59  59  59 |  12  12  12 | 46.9 |
| lit.grey0.18 | 113 113 113 |  31  31  31 | 81.6 |
| lit.grey0.5 | 177 177 177 |  54  54  54 | 122.9 |
| lit.grey1.0 | 240 240 240 |  77  77  77 | 163.3 |
| lit.white.rough0.5 | 244 244 244 |  78  78  78 | 165.6 |
| lit.indigo |  45  53  79 |   8  10  19 | 46.5 |
| lit.red | 240  24  24 |  77   3   3 | 68.3 |
| lit.green |  24 240  24 |   3  77   3 | 68.3 |
| lit.blue |  24  24 240 |   3   3  77 | 68.3 |
| lit.cyan |  24 240 240 |   3  77  77 | 115.7 |
| lit.magenta | 240  24 240 |  77   3  77 | 115.6 |
| lit.yellow | 239 239  24 |  77  77   3 | 115.4 |
| sphere.dielectric | 173 173 173 |  53  53  53 | 120.5 |
| sphere.metal | 108  98  73 |  40  35  23 | 60.5 |
| sphere.glossy | 185  63  63 |  58  14  14 | 75.3 |
| point.centre | 240 240 240 |  77  77  77 | 163.1 |
| point.edge | 240 240 240 |  77  77  77 | 163.3 |
| spot.centre | 239 239 239 |  77  77  77 | 162.6 |
| spot.penumbra | 239 239 239 |  77  77  77 | 162.3 |
| spot.outside | 239 239 239 |  77  77  77 | 162.3 |
| ibl.card | 238 238 238 |  77  77  77 | 161.9 |
| shadow.lit | 175 175 175 |  54  54  54 | 121.1 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 194.9 | 251.8 (emissive.white4) | 8 | over |
| lit | 13 | 103.1 | 165.6 (lit.white.rough0.5) | 16 | over |
| sphere | 3 | 85.4 | 120.5 (sphere.dielectric) | 16 | over |
| light | 5 | 162.7 | 163.3 (point.edge) | 16 | over |
| shadow | 2 | 60.7 | 121.1 (shadow.lit) | 16 | over |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

### point

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
| lit.red |  50   4   4 |   0   0   0 | 19.2 |
| lit.green |   4  50   4 |   0   0   0 | 19.4 |
| lit.blue |   0   0   0 |   0   0   0 | 0.3 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.3 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.3 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.3 |
| sphere.dielectric |  97  97  97 |   0   0   0 | 96.6 |
| sphere.metal |  65  60  46 |   0   0   0 | 56.7 |
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
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 196.7 | 254.7 (emissive.white1) | 8 | over |
| lit | 13 | 3.2 | 19.4 (lit.green) | 16 | over |
| sphere | 3 | 51.2 | 96.6 (sphere.dielectric) | 16 | over |
| light | 5 | 250.0 | 254.7 (spot.outside) | 16 | over |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

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
| spot.centre | 255 255 255 |   1   1   1 | 253.8 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.5 |
| spot.outside |   0   0   0 |   0   0   0 | 0.3 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 196.7 | 254.7 (emissive.white1) | 8 | over |
| lit | 13 | 0.3 | 0.3 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 51.0 | 253.8 (spot.centre) | 16 | over |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

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
| emissive.grey0.18 | 119 119 119 |  16  16  16 | 103.0 |
| emissive.white1 | 255 255 255 |  16  16  16 | 239.0 |
| emissive.white4 | 255 255 255 |  16  16  16 | 239.0 |
| emissive.orange1 | 255 124  65 |  16  16  16 | 132.0 |
| emissive.orange4 | 255 231 124 |  16  16  16 | 187.3 |
| emissive.blue2 | 124 231 255 |  16  16  16 | 187.3 |
| lit.grey0.04 |  36  36  36 |  40  40  40 | 3.5 |
| lit.grey0.18 |  77  77  77 |  78  78  78 | 0.7 |
| lit.grey0.5 | 132 132 132 | 124 124 124 | 8.3 |
| lit.grey1.0 | 195 195 195 | 169 169 169 | 26.4 |
| lit.white.rough0.5 | 192 192 192 | 168 168 168 | 23.7 |
| lit.indigo |  26  32  51 |  30  35  54 | 3.3 |
| lit.red | 195  10  10 | 169  16  16 | 12.8 |
| lit.green |  10 195  10 |  16 169  16 | 12.8 |
| lit.blue |  10  10 195 |  16  16 169 | 12.8 |
| lit.cyan |  10 195 195 |  16 169 169 | 19.6 |
| lit.magenta | 195  10 195 | 169  16 169 | 19.6 |
| lit.yellow | 195 195  10 | 169 169  16 | 19.6 |
| sphere.dielectric | 139 139 139 | 125 125 125 | 14.1 |
| sphere.metal | 182 162 111 | 168 149 102 | 11.9 |
| sphere.glossy | 153  59  59 | 135  52  52 | 10.6 |
| point.centre | 195 195 195 | 169 169 169 | 26.4 |
| point.edge | 195 195 195 | 169 169 169 | 26.4 |
| spot.centre | 195 195 195 | 169 169 169 | 26.4 |
| spot.penumbra | 195 195 195 | 169 169 169 | 26.5 |
| spot.outside | 195 195 195 | 169 169 169 | 26.5 |
| ibl.card | 195 195 195 | 169 169 169 | 26.4 |
| shadow.lit | 132 132 132 | 124 124 124 | 8.3 |
| shadow.umbra | 132 132 132 | 124 124 124 | 8.3 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 181.3 | 239.0 (emissive.white4) | 8 | over |
| lit | 13 | 14.6 | 26.4 (ibl.card) | 16 | over |
| sphere | 3 | 12.2 | 14.1 (sphere.dielectric) | 16 | ok |
| light | 5 | 26.4 | 26.5 (spot.penumbra) | 16 | over |
| shadow | 2 | 8.3 | 8.3 (shadow.lit) | 16 | ok |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

### ibl-studio

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
| unlit.magenta | 255   0 255 | 247   0 247 | 5.2 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 |  18  18  18 | 101.0 |
| emissive.white1 | 255 255 255 |  18  18  18 | 237.0 |
| emissive.white4 | 255 255 255 |  18  18  18 | 237.0 |
| emissive.orange1 | 255 125  66 |  18  18  18 | 130.7 |
| emissive.orange4 | 255 232 125 |  18  18  18 | 186.0 |
| emissive.blue2 | 125 232 255 |  18  18  18 | 186.0 |
| lit.grey0.04 |  40  40  40 |  43  43  43 | 3.2 |
| lit.grey0.18 |  83  83  83 |  83  84  84 | 0.8 |
| lit.grey0.5 | 141 142 142 | 132 133 133 | 9.0 |
| lit.grey1.0 | 209 209 210 | 180 181 182 | 28.5 |
| lit.white.rough0.5 | 205 206 207 | 180 181 181 | 25.5 |
| lit.indigo |  29  35  56 |  33  38  58 | 3.2 |
| lit.red | 209  12  12 | 180  18  18 | 13.7 |
| lit.green |  12 209  12 |  18 181  18 | 13.3 |
| lit.blue |  12  12 210 |  18  18 182 | 13.4 |
| lit.cyan |  12 209 210 |  18 181 182 | 20.7 |
| lit.magenta | 209  12 210 | 180  18 182 | 21.1 |
| lit.yellow | 209 209  12 | 180 181  18 | 20.9 |
| sphere.dielectric | 149 150 150 | 133 134 134 | 15.8 |
| sphere.metal | 191 170 117 | 175 156 106 | 13.9 |
| sphere.glossy | 164  64  64 | 144  56  56 | 11.9 |
| point.centre | 209 209 210 | 180 181 182 | 28.5 |
| point.edge | 209 209 210 | 180 181 182 | 28.5 |
| spot.centre | 209 209 210 | 180 181 182 | 28.5 |
| spot.penumbra | 209 209 210 | 180 181 182 | 28.4 |
| spot.outside | 209 209 210 | 180 181 182 | 28.5 |
| ibl.card | 209 209 210 | 180 181 182 | 28.5 |
| shadow.lit | 141 142 142 | 132 133 133 | 9.0 |
| shadow.umbra | 141 142 142 | 132 133 133 | 9.0 |
| sky |  88 124 170 |  79 111 152 | 13.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.8 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 179.6 | 237.0 (emissive.white1) | 8 | over |
| lit | 13 | 15.5 | 28.5 (ibl.card) | 16 | over |
| sphere | 3 | 13.9 | 15.8 (sphere.dielectric) | 16 | ok |
| light | 5 | 28.5 | 28.5 (point.edge) | 16 | over |
| shadow | 2 | 9.0 | 9.0 (shadow.umbra) | 16 | ok |
| sky | 1 | 13.6 | 13.6 (sky) | 8 | over |

### all

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  10  10  10 | 29.2 |
| unlit.grey0.05 |  63  63  63 |  35  35  35 | 28.2 |
| unlit.grey0.18 | 118 118 118 | 105 105 105 | 13.3 |
| unlit.grey0.5 | 188 188 188 | 181 181 181 | 6.9 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |  39  48  80 |   1  22  68 | 25.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.1 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 | 121 121 121 |   5   4   4 | 116.7 |
| emissive.white1 | 255 255 255 |   5   4   4 | 250.7 |
| emissive.white4 | 255 255 255 |   5   4   4 | 250.7 |
| emissive.orange1 | 255 127  71 |   5   4   4 | 146.7 |
| emissive.orange4 | 255 233 127 |   5   4   4 | 200.7 |
| emissive.blue2 | 127 233 255 |   5   4   4 | 200.7 |
| lit.grey0.04 |  70  70  70 |  15  16  16 | 54.5 |
| lit.grey0.18 | 134 134 134 |  63  62  63 | 71.4 |
| lit.grey0.5 | 214 214 214 | 122 122 122 | 91.2 |
| lit.grey1.0 | 255 255 255 | 175 175 175 | 80.3 |
| lit.white.rough0.5 | 255 255 255 | 175 175 175 | 79.7 |
| lit.indigo |  54  63  94 |   3  13  46 | 49.5 |
| lit.red | 255  31  31 | 180   0   0 | 45.7 |
| lit.green |  31 255  31 |   0 176   0 | 46.9 |
| lit.blue |  29  29 255 |   0   0 180 | 44.3 |
| lit.cyan |  29 255 255 |   0 175 175 | 63.2 |
| lit.magenta | 255  29 255 | 176   0 176 | 62.2 |
| lit.yellow | 255 255  29 | 175 175   0 | 62.7 |
| sphere.dielectric | 235 235 235 | 123 123 123 | 111.7 |
| sphere.metal | 222 207 159 | 169 148  92 | 59.5 |
| sphere.glossy | 231  88  88 | 138  21  21 | 75.4 |
| point.centre | 255 255 255 | 175 175 175 | 80.1 |
| point.edge | 255 255 255 | 175 175 175 | 80.2 |
| spot.centre | 255 255 255 | 175 175 175 | 80.3 |
| spot.penumbra | 255 255 255 | 175 175 175 | 80.3 |
| spot.outside | 255 255 255 | 175 175 175 | 80.4 |
| ibl.card | 255 255 255 | 175 175 175 | 80.3 |
| shadow.lit | 212 212 212 | 122 122 122 | 89.8 |
| shadow.umbra | 132 132 132 | 111 111 111 | 20.7 |
| sky |  88 124 170 |  54  96 142 | 29.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 14.5 | 29.2 (unlit.grey0.02) | 8 | over |
| emissive | 6 | 194.4 | 250.7 (emissive.white1) | 8 | over |
| lit | 13 | 64.0 | 91.2 (lit.grey0.5) | 16 | over |
| sphere | 3 | 82.2 | 111.7 (sphere.dielectric) | 16 | over |
| light | 5 | 80.2 | 80.4 (spot.outside) | 16 | over |
| shadow | 2 | 55.2 | 89.8 (shadow.lit) | 16 | over |
| sky | 1 | 29.7 | 29.7 (sky) | 8 | over |

### all-bloom

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
| unlit.blue |   0   0 255 |   9   9 245 | 9.2 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 | 121 121 121 |   5   4   4 | 116.7 |
| emissive.white1 | 255 255 255 |   5   4   4 | 250.7 |
| emissive.white4 | 255 255 255 |   5   4   4 | 250.7 |
| emissive.orange1 | 255 127  71 |   5   4   4 | 146.7 |
| emissive.orange4 | 255 252 138 |   5   4   4 | 210.7 |
| emissive.blue2 | 127 233 255 |   5   4   4 | 200.7 |
| lit.grey0.04 |  70  70  70 |  15  16  16 | 54.5 |
| lit.grey0.18 | 134 134 134 |  63  62  63 | 71.4 |
| lit.grey0.5 | 214 214 214 | 122 122 122 | 91.2 |
| lit.grey1.0 | 255 255 255 | 175 175 175 | 80.3 |
| lit.white.rough0.5 | 255 255 255 | 175 175 175 | 79.7 |
| lit.indigo |  54  63  94 |   3  13  46 | 49.5 |
| lit.red | 255  31  31 | 180   0   0 | 45.7 |
| lit.green |  32 255  32 |   0 176   0 | 47.9 |
| lit.blue |  29  29 255 |   0   0 180 | 44.3 |
| lit.cyan |  31 255 255 |   0 175 175 | 63.8 |
| lit.magenta | 255  29 255 | 176   0 176 | 62.2 |
| lit.yellow | 255 255  32 | 175 175   0 | 63.7 |
| sphere.dielectric | 238 238 238 | 123 123 123 | 115.0 |
| sphere.metal | 225 211 164 | 170 148  92 | 63.1 |
| sphere.glossy | 232  89  89 | 138  21  21 | 76.4 |
| point.centre | 255 255 255 | 175 175 175 | 80.1 |
| point.edge | 255 255 255 | 175 175 175 | 80.2 |
| spot.centre | 255 255 255 | 175 175 175 | 80.3 |
| spot.penumbra | 255 255 255 | 175 175 175 | 80.3 |
| spot.outside | 255 255 255 | 175 175 175 | 80.3 |
| ibl.card | 255 255 255 | 175 175 175 | 80.3 |
| shadow.lit | 212 212 212 | 122 122 122 | 89.8 |
| shadow.umbra | 132 132 132 | 111 111 111 | 20.7 |
| sky |  88 124 170 |  54  96 142 | 29.7 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 14.5 | 29.2 (unlit.grey0.02) | 8 | over |
| emissive | 6 | 196.1 | 250.7 (emissive.white4) | 8 | over |
| lit | 13 | 64.2 | 91.2 (lit.grey0.5) | 16 | over |
| sphere | 3 | 84.8 | 115.0 (sphere.dielectric) | 16 | over |
| light | 5 | 80.2 | 80.3 (spot.penumbra) | 16 | over |
| shadow | 2 | 55.2 | 89.8 (shadow.lit) | 16 | over |
| sky | 1 | 29.7 | 29.7 (sky) | 8 | over |

### default-stage

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| unlit.grey0.02 |  39  39  39 |  10  10  10 | 29.2 |
| unlit.grey0.05 |  63  63  63 |  35  35  35 | 28.2 |
| unlit.grey0.18 | 118 118 118 | 105 105 105 | 13.3 |
| unlit.grey0.5 | 188 188 188 | 181 181 181 | 6.9 |
| unlit.grey1.0 | 255 255 255 | 234 234 234 | 21.3 |
| unlit.indigo |  39  48  80 |   1  22  68 | 25.3 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |   0 242   0 | 4.3 |
| unlit.blue |   0   0 255 |   9   9 245 | 9.1 |
| unlit.cyan |   0 255 255 |   0 237 236 | 12.4 |
| unlit.magenta | 255   0 255 | 241   0 243 | 8.7 |
| unlit.yellow | 255 255   0 | 237 237   0 | 11.9 |
| emissive.grey0.18 | 122 122 122 |   2   2   2 | 119.4 |
| emissive.white1 | 255 255 255 |   2   2   2 | 252.7 |
| emissive.white4 | 255 255 255 |   2   2   2 | 252.6 |
| emissive.orange1 | 255 127  71 |   2   2   2 | 148.7 |
| emissive.orange4 | 255 252 138 |   2   2   2 | 212.7 |
| emissive.blue2 | 127 233 255 |   2   2   2 | 202.6 |
| lit.grey0.04 |  72  72  72 |  17  19  19 | 53.7 |
| lit.grey0.18 | 137 137 137 |  70  70  71 | 66.9 |
| lit.grey0.5 | 219 219 219 | 131 132 133 | 87.0 |
| lit.grey1.0 | 255 255 255 | 186 187 188 | 68.1 |
| lit.white.rough0.5 | 255 255 255 | 186 187 188 | 67.9 |
| lit.indigo |  55  64  96 |   4  15  50 | 48.8 |
| lit.red | 255  30  30 | 190   0   0 | 41.4 |
| lit.green |  31 255  31 |   0 188   0 | 43.1 |
| lit.blue |  30  30 255 |   0   0 192 | 40.9 |
| lit.cyan |  32 255 255 |   0 187 188 | 55.8 |
| lit.magenta | 255  30 255 | 187   0 189 | 54.7 |
| lit.yellow | 255 255  33 | 186 187   0 | 56.4 |
| sphere.dielectric | 221 221 222 | 132 132 133 | 88.9 |
| sphere.metal | 210 195 145 | 175 154  95 | 42.0 |
| sphere.glossy | 236  92  92 | 146  26  27 | 73.4 |
| point.centre | 255 255 255 | 186 187 188 | 68.1 |
| point.edge | 255 255 255 | 186 187 188 | 68.2 |
| spot.centre | 255 255 255 | 186 187 188 | 68.2 |
| spot.penumbra | 255 255 255 | 186 187 188 | 68.2 |
| spot.outside | 255 255 255 | 186 187 188 | 68.2 |
| ibl.card | 255 255 255 | 186 187 188 | 68.2 |
| shadow.lit | 217 218 218 | 131 132 133 | 85.7 |
| shadow.umbra | 141 142 142 | 121 122 122 | 20.1 |
| sky |   0   0   0 |  42  42  58 | 47.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 14.5 | 29.2 (unlit.grey0.02) | 8 | over |
| emissive | 6 | 198.1 | 252.7 (emissive.white1) | 8 | over |
| lit | 13 | 57.9 | 87.0 (lit.grey0.5) | 16 | over |
| sphere | 3 | 68.1 | 88.9 (sphere.dielectric) | 16 | over |
| light | 5 | 68.2 | 68.2 (spot.outside) | 16 | over |
| shadow | 2 | 52.9 | 85.7 (shadow.lit) | 16 | over |
| sky | 1 | 47.2 | 47.2 (sky) | 8 | over |

