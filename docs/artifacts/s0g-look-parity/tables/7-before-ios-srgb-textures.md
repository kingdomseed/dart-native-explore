### unlit-linear

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 220 229 164 | 181 199  94 | 46.3 |
| texture.unlit.pink | 253 165 212 | 244  96 166 | 41.1 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.3 |
| texture.emissive.lime | 245 255 183 | 203 224 107 | 49.7 |
| texture.emissive.pink | 255 185 238 | 255 109 187 | 42.2 |
| texture.unlit.factor | 162 162 162 |  93  92  93 | 69.5 |
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.6 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.8 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.4 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| emissive.white1 | 255 255 255 | 249 247 248 | 6.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  64 | 247 124  63 | 2.8 |
| emissive.orange4 | 255 255 134 | 255 253 134 | 0.8 |
| emissive.blue2 | 141 232 255 | 141 232 255 | 0.2 |
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
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 41.5 | 69.5 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 4.9 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.8 | 6.9 (emissive.white1) | 8 | ok |
| lit | 13 | 0.3 | 0.3 (lit.blue) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.metal) | 16 | ok |
| light | 5 | 0.3 | 0.3 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### unlit-neutral

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 214 223 156 | 174 193  76 | 50.3 |
| texture.unlit.pink | 248 157 206 | 242  78 158 | 44.2 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.1 |
| texture.emissive.lime | 231 241 170 | 197 219  91 | 44.8 |
| texture.emissive.pink | 255 171 223 | 255  94 178 | 40.8 |
| texture.unlit.factor | 154 154 154 |  74  74  74 | 80.4 |
| unlit.grey0.02 |   8   8   8 |  10  10  10 | 1.8 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.8 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| unlit.grey0.5 | 180 180 180 | 181 181 181 | 1.1 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.3 |
| unlit.indigo |   0  23  68 |   1  22  68 | 0.5 |
| unlit.red | 254   0   0 | 247   0   0 | 2.5 |
| unlit.green |   0 246   0 |   0 242   0 | 1.3 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.8 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.1 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 237 237   0 | 2.6 |
| emissive.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| emissive.white1 | 240 240 240 | 234 234 234 | 6.3 |
| emissive.white4 | 253 253 253 | 249 249 249 | 3.7 |
| emissive.orange1 | 251 112  26 | 246 112  24 | 2.6 |
| emissive.orange4 | 255 173 137 | 255 173 137 | 0.2 |
| emissive.blue2 | 119 181 255 | 119 181 255 | 0.3 |
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
| texture | 6 | 43.4 | 80.4 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 2.5 | 6.8 (unlit.blue) | 8 | ok |
| emissive | 6 | 2.3 | 6.3 (emissive.white1) | 8 | ok |
| lit | 13 | 0.1 | 0.1 (lit.blue) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.glossy) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.centre) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### unlit-aces

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 215 218 187 | 199 205 120 | 32.1 |
| texture.unlit.pink | 230 185 210 | 241 118 181 | 35.8 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.1 |
| texture.emissive.lime | 224 226 201 | 213 216 141 | 26.9 |
| texture.emissive.pink | 237 199 221 | 250 140 195 | 32.5 |
| texture.unlit.factor | 177 177 177 |  92  93  94 | 84.3 |
| unlit.grey0.02 |  20  20  20 |  23  23  24 | 3.5 |
| unlit.grey0.05 |  50  50  50 |  51  52  53 | 1.8 |
| unlit.grey0.18 | 127 127 127 | 128 128 129 | 1.5 |
| unlit.grey0.5 | 196 196 196 | 201 198 195 | 2.7 |
| unlit.grey1.0 | 226 226 226 | 230 225 219 | 3.6 |
| unlit.indigo |  19  32  69 |  22  34  74 | 3.3 |
| unlit.red | 250  17  21 | 244  29  17 | 7.0 |
| unlit.green | 148 228  89 | 150 228  87 | 1.7 |
| unlit.blue |   0   0 228 |   5   0 227 | 1.8 |
| unlit.cyan | 154 227 226 | 158 227 219 | 3.7 |
| unlit.magenta | 248  41 228 | 251  36 224 | 3.9 |
| unlit.yellow | 230 227 106 | 233 226 104 | 2.2 |
| emissive.grey0.18 | 127 127 127 | 128 128 129 | 1.5 |
| emissive.white1 | 226 226 226 | 230 225 219 | 3.6 |
| emissive.white4 | 250 250 250 | 249 244 236 | 7.0 |
| emissive.orange1 | 240 147  76 | 238 150  74 | 2.0 |
| emissive.orange4 | 255 226 178 | 255 225 175 | 1.1 |
| emissive.blue2 | 181 219 242 | 187 220 231 | 5.6 |
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
| sky |  92 136 181 |  94 137 182 | 1.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 35.3 | 84.3 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 3.1 | 7.0 (unlit.red) | 8 | ok |
| emissive | 6 | 3.5 | 7.0 (emissive.white4) | 8 | ok |
| lit | 13 | 0.1 | 0.1 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.metal) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 1.2 | 1.2 (sky) | 8 | ok |

### unlit-exposure2

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 255 255 230 | 247 255 134 | 35.0 |
| texture.unlit.pink | 255 233 255 | 255 143 227 | 39.3 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.3 |
| texture.emissive.lime | 255 255 255 | 255 255 158 | 32.3 |
| texture.emissive.pink | 255 255 255 | 255 168 247 | 31.4 |
| texture.unlit.factor | 220 220 220 | 128 128 128 | 91.8 |
| unlit.grey0.02 |  56  56  56 |  57  56  56 | 0.5 |
| unlit.grey0.05 |  89  89  89 |  89  89  89 | 0.2 |
| unlit.grey0.18 | 162 162 162 | 162 162 162 | 0.1 |
| unlit.grey0.5 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.grey1.0 | 255 255 255 | 255 255 255 | 0.1 |
| unlit.indigo |  56  69 112 |  57  69 112 | 0.4 |
| unlit.red | 255  50  15 | 255  48  15 | 0.7 |
| unlit.green | 187 255  82 | 186 255  82 | 0.5 |
| unlit.blue |  68  19 255 |  68  19 255 | 0.2 |
| unlit.cyan | 200 255 255 | 199 255 255 | 0.3 |
| unlit.magenta | 255  63 255 | 255  62 255 | 0.4 |
| unlit.yellow | 255 255  95 | 255 255  95 | 0.1 |
| emissive.grey0.18 | 162 162 162 | 162 162 162 | 0.1 |
| emissive.white1 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 179  92 | 255 179  92 | 0.1 |
| emissive.orange4 | 255 255 201 | 255 255 202 | 0.4 |
| emissive.blue2 | 246 255 255 | 243 255 255 | 1.0 |
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
| sky | 123 170 231 | 124 170 231 | 0.4 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 38.4 | 91.8 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 0.9 | 6.9 (unlit.grey0.5) | 8 | ok |
| emissive | 6 | 0.3 | 1.0 (emissive.blue2) | 8 | ok |
| lit | 13 | 0.3 | 0.3 (lit.red) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.3 | 0.3 (point.centre) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.4 | 0.4 (sky) | 8 | ok |

### directional

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 220 229 164 | 181 199  94 | 46.4 |
| texture.unlit.pink | 253 165 212 | 244  96 166 | 41.1 |
| texture.lit.lime | 169 177 126 | 140 154  74 | 34.5 |
| texture.emissive.lime | 249 255 185 | 205 224 109 | 50.4 |
| texture.emissive.pink | 255 187 238 | 255 111 188 | 41.8 |
| texture.unlit.factor | 162 162 162 |  93  92  93 | 69.5 |
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.6 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.8 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.4 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 | 120 120 120 | 0.8 |
| emissive.white1 | 255 255 255 | 250 248 248 | 6.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 125  67 | 248 126  67 | 2.8 |
| emissive.orange4 | 255 255 135 | 255 253 135 | 0.7 |
| emissive.blue2 | 142 232 255 | 142 233 255 | 0.3 |
| lit.grey0.04 |  47  47  47 |  47  47  47 | 0.3 |
| lit.grey0.18 |  91  91  91 |  92  92  92 | 0.9 |
| lit.grey0.5 | 144 144 144 | 146 146 146 | 1.6 |
| lit.grey1.0 | 197 197 197 | 198 198 198 | 1.0 |
| lit.white.rough0.5 | 200 200 200 | 201 200 201 | 0.9 |
| lit.indigo |  35  42  63 |  36  42  64 | 0.7 |
| lit.red | 197  18  18 | 198  19  19 | 0.8 |
| lit.green |  18 197  18 |  19 198  19 | 0.8 |
| lit.blue |  18  18 197 |  19  19 198 | 0.8 |
| lit.cyan |  18 197 197 |  19 198 198 | 1.0 |
| lit.magenta | 197  18 197 | 198  19 198 | 1.0 |
| lit.yellow | 196 196  18 | 198 198  19 | 1.2 |
| sphere.dielectric | 141 141 141 | 143 143 143 | 1.5 |
| sphere.metal |  91  82  60 |  94  85  62 | 2.7 |
| sphere.glossy | 151  50  50 | 153  51  51 | 0.8 |
| point.centre | 197 197 197 | 198 198 198 | 1.0 |
| point.edge | 197 197 197 | 198 198 198 | 1.0 |
| spot.centre | 196 196 196 | 198 198 198 | 1.4 |
| spot.penumbra | 196 196 196 | 198 198 198 | 1.7 |
| spot.outside | 196 196 196 | 198 198 198 | 1.6 |
| ibl.card | 196 196 196 | 198 198 198 | 1.9 |
| shadow.lit | 143 143 143 | 146 146 146 | 2.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 47.3 | 69.5 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 4.9 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.9 | 6.5 (emissive.white1) | 8 | ok |
| lit | 13 | 1.0 | 1.9 (ibl.card) | 16 | ok |
| sphere | 3 | 1.7 | 2.7 (sphere.metal) | 16 | ok |
| light | 5 | 1.3 | 1.7 (spot.penumbra) | 16 | ok |
| shadow | 2 | 1.3 | 2.3 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### point

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 220 229 164 | 181 199  94 | 46.4 |
| texture.unlit.pink | 253 165 212 | 244  96 166 | 41.1 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.3 |
| texture.emissive.lime | 245 255 183 | 203 224 107 | 49.7 |
| texture.emissive.pink | 255 185 238 | 255 109 187 | 42.2 |
| texture.unlit.factor | 162 162 162 |  93  92  93 | 69.5 |
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.6 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.8 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.4 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| emissive.white1 | 255 255 255 | 249 247 248 | 6.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  64 | 247 124  63 | 2.8 |
| emissive.orange4 | 255 255 134 | 255 253 134 | 0.8 |
| emissive.blue2 | 141 232 255 | 141 232 255 | 0.2 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.3 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.3 |
| lit.red |   1   0   0 |   0   0   0 | 0.3 |
| lit.green |   0   1   0 |   0   1   0 | 0.2 |
| lit.blue |   0   0   0 |   0   0   0 | 0.3 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.3 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.3 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.3 |
| sphere.dielectric |  17  17  17 |  12  12  12 | 4.3 |
| sphere.metal |   4   3   2 |   0   0   0 | 2.5 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.3 |
| point.centre | 208 208 208 | 206 206 206 | 2.0 |
| point.edge | 157 157 157 |  90  90  90 | 66.9 |
| spot.centre |  46  46  46 |  26  26  26 | 20.3 |
| spot.penumbra |   7   7   7 |   4   4   4 | 2.3 |
| spot.outside |  31  31  31 |   0   0   0 | 30.4 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 41.5 | 69.5 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 4.9 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.9 | 6.9 (emissive.white1) | 8 | ok |
| lit | 13 | 0.3 | 0.3 (lit.red) | 16 | ok |
| sphere | 3 | 2.4 | 4.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 24.4 | 66.9 (point.edge) | 16 | over |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### spot

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 220 229 164 | 181 199  94 | 46.4 |
| texture.unlit.pink | 253 165 212 | 244  96 166 | 41.1 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.3 |
| texture.emissive.lime | 245 255 183 | 203 224 107 | 49.6 |
| texture.emissive.pink | 255 185 238 | 255 109 187 | 42.2 |
| texture.unlit.factor | 162 162 162 |  93  92  93 | 69.5 |
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.6 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.4 |
| unlit.red | 255   0   0 | 247   0   0 | 2.7 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| emissive.white1 | 255 255 255 | 249 247 248 | 6.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  64 | 247 124  63 | 2.8 |
| emissive.orange4 | 255 255 134 | 255 253 134 | 0.8 |
| emissive.blue2 | 141 232 255 | 141 232 255 | 0.2 |
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
| spot.centre | 209 209 209 | 210 210 210 | 0.9 |
| spot.penumbra | 151 151 151 | 121 121 121 | 29.9 |
| spot.outside |   0   0   0 |   0   0   0 | 0.3 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 41.5 | 69.5 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 4.9 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.8 | 6.9 (emissive.white1) | 8 | ok |
| lit | 13 | 0.3 | 0.3 (lit.blue) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 6.3 | 29.9 (spot.penumbra) | 16 | over |
| shadow | 2 | 0.3 | 0.3 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### ibl-constant

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 220 229 164 | 181 199  94 | 46.4 |
| texture.unlit.pink | 253 165 212 | 244  96 166 | 41.1 |
| texture.lit.lime | 161 168 112 | 133 147  71 | 29.9 |
| texture.emissive.lime | 249 255 185 | 205 225 109 | 50.2 |
| texture.emissive.pink | 255 187 238 | 255 111 188 | 41.8 |
| texture.unlit.factor | 162 162 162 |  93  92  93 | 69.5 |
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.6 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.4 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 | 120 120 120 | 0.9 |
| emissive.white1 | 255 255 255 | 250 248 248 | 6.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  66 | 248 126  68 | 3.5 |
| emissive.orange4 | 255 255 134 | 255 253 135 | 1.0 |
| emissive.blue2 | 141 232 255 | 142 233 255 | 0.7 |
| lit.grey0.04 |  36  36  36 |  45  45  45 | 9.4 |
| lit.grey0.18 |  77  77  77 |  88  87  88 | 10.5 |
| lit.grey0.5 | 132 132 132 | 139 138 138 | 6.5 |
| lit.grey1.0 | 196 196 196 | 188 188 188 | 7.6 |
| lit.white.rough0.5 | 192 192 192 | 188 188 188 | 3.6 |
| lit.indigo |  26  31  51 |  35  41  61 | 9.4 |
| lit.red | 196  10  10 | 188  20  19 | 8.9 |
| lit.green |  10 196  10 |  20 188  19 | 8.9 |
| lit.blue |  10  10 196 |  20  19 188 | 8.9 |
| lit.cyan |  10 196 196 |  19 189 188 | 8.2 |
| lit.magenta | 196  10 196 | 189  20 188 | 8.2 |
| lit.yellow | 196 196  10 | 188 188  19 | 8.2 |
| sphere.dielectric | 139 139 139 | 140 140 140 | 0.8 |
| sphere.metal | 182 162 110 | 188 167 114 | 5.0 |
| sphere.glossy | 153  59  59 | 151  59  59 | 0.8 |
| point.centre | 196 196 196 | 188 188 188 | 7.6 |
| point.edge | 196 196 196 | 188 188 188 | 7.5 |
| spot.centre | 196 196 196 | 188 188 188 | 7.6 |
| spot.penumbra | 196 196 196 | 188 188 188 | 7.6 |
| spot.outside | 196 196 196 | 188 188 188 | 7.6 |
| ibl.card | 196 196 196 | 188 188 188 | 7.6 |
| shadow.lit | 132 132 132 | 139 138 138 | 6.5 |
| shadow.umbra | 132 132 132 | 139 138 138 | 6.5 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 46.5 | 69.5 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 4.9 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 2.1 | 6.5 (emissive.white1) | 8 | ok |
| lit | 13 | 8.1 | 10.5 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 2.2 | 5.0 (sphere.metal) | 16 | ok |
| light | 5 | 7.6 | 7.6 (spot.centre) | 16 | ok |
| shadow | 2 | 6.5 | 6.5 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### ibl-studio

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 220 229 164 | 181 199  94 | 46.3 |
| texture.unlit.pink | 253 165 212 | 244  96 166 | 41.1 |
| texture.lit.lime | 172 182 120 | 143 158  77 | 32.0 |
| texture.emissive.lime | 249 255 185 | 205 225 109 | 50.0 |
| texture.emissive.pink | 255 187 238 | 255 112 188 | 41.6 |
| texture.unlit.factor | 162 162 162 |  93  92  93 | 69.5 |
| unlit.grey0.02 |  38  38  38 |  39  39  39 | 0.7 |
| unlit.grey0.05 |  64  64  64 |  63  63  63 | 0.6 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 255 255 255 | 249 247 248 | 6.9 |
| unlit.indigo |  38  49  80 |  39  48  80 | 0.4 |
| unlit.red | 255   0   0 | 247   0   0 | 2.8 |
| unlit.green |   0 255   0 |  23 247   6 | 12.2 |
| unlit.blue |   0   0 255 |   1   0 247 | 2.8 |
| unlit.cyan |   0 255 255 |  34 247 247 | 16.3 |
| unlit.magenta | 255   0 255 | 247   1 247 | 5.3 |
| unlit.yellow | 255 255   0 | 249 247  17 | 10.3 |
| emissive.grey0.18 | 119 119 119 | 120 120 120 | 1.3 |
| emissive.white1 | 255 255 255 | 250 248 248 | 6.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 124  66 | 248 126  68 | 3.8 |
| emissive.orange4 | 255 255 134 | 255 254 136 | 1.1 |
| emissive.blue2 | 141 232 255 | 143 233 255 | 1.0 |
| lit.grey0.04 |  40  40  41 |  49  49  50 | 9.0 |
| lit.grey0.18 |  83  83  83 |  94  94  95 | 11.4 |
| lit.grey0.5 | 142 142 142 | 148 149 150 | 7.0 |
| lit.grey1.0 | 209 209 209 | 201 202 203 | 7.2 |
| lit.white.rough0.5 | 206 206 206 | 201 202 202 | 4.4 |
| lit.indigo |  29  34  56 |  38  44  66 | 9.9 |
| lit.red | 209  12  12 | 201  22  21 | 9.1 |
| lit.green |  12 209  12 |  22 202  21 | 8.7 |
| lit.blue |  12  12 209 |  22  22 203 | 8.5 |
| lit.cyan |  12 209 209 |  22 202 203 | 7.6 |
| lit.magenta | 209  12 209 | 201  22 203 | 8.0 |
| lit.yellow | 209 209  12 | 201 202  21 | 8.2 |
| sphere.dielectric | 149 149 150 | 149 150 150 | 0.5 |
| sphere.metal | 189 169 116 | 195 175 120 | 5.1 |
| sphere.glossy | 164  64  64 | 161  64  64 | 0.9 |
| point.centre | 209 209 209 | 201 202 203 | 7.2 |
| point.edge | 209 209 209 | 201 202 203 | 7.1 |
| spot.centre | 209 209 209 | 201 202 203 | 7.2 |
| spot.penumbra | 209 209 209 | 201 202 203 | 7.2 |
| spot.outside | 209 209 209 | 201 202 203 | 7.2 |
| ibl.card | 209 209 209 | 201 202 203 | 7.2 |
| shadow.lit | 142 142 142 | 148 149 150 | 7.0 |
| shadow.umbra | 142 142 142 | 148 149 150 | 7.0 |
| sky |  88 124 170 |  89 124 170 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 46.8 | 69.5 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 4.9 | 16.3 (unlit.cyan) | 8 | over |
| emissive | 6 | 2.3 | 6.5 (emissive.white1) | 8 | ok |
| lit | 13 | 8.2 | 11.4 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 2.2 | 5.1 (sphere.metal) | 16 | ok |
| light | 5 | 7.2 | 7.2 (spot.centre) | 16 | ok |
| shadow | 2 | 7.0 | 7.0 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### all

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 214 223 156 | 174 193  76 | 50.3 |
| texture.unlit.pink | 248 157 206 | 242  78 158 | 44.2 |
| texture.lit.lime | 218 230 155 | 181 199  85 | 45.9 |
| texture.emissive.lime | 232 242 171 | 200 220  97 | 42.9 |
| texture.emissive.pink | 255 173 223 | 255  99 179 | 39.2 |
| texture.unlit.factor | 154 154 154 |  74  74  74 | 80.4 |
| unlit.grey0.02 |   8   8   8 |  10  10  10 | 1.8 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.8 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| unlit.grey0.5 | 180 180 180 | 181 181 181 | 1.1 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.3 |
| unlit.indigo |   0  23  68 |   1  22  68 | 0.5 |
| unlit.red | 254   0   0 | 247   0   0 | 2.5 |
| unlit.green |   0 246   0 |   0 242   0 | 1.3 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.8 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.1 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 237 237   0 | 2.6 |
| emissive.grey0.18 | 108 108 108 | 109 109 109 | 1.4 |
| emissive.white1 | 240 240 240 | 235 235 235 | 5.3 |
| emissive.white4 | 253 253 253 | 249 249 249 | 3.9 |
| emissive.orange1 | 251 115  38 | 247 116  42 | 2.9 |
| emissive.orange4 | 255 174 138 | 255 174 138 | 0.1 |
| emissive.blue2 | 121 182 255 | 121 182 255 | 0.2 |
| lit.grey0.04 |  30  30  30 |  39  40  39 | 9.5 |
| lit.grey0.18 | 105 105 105 | 113 112 112 | 7.5 |
| lit.grey0.5 | 182 182 182 | 188 188 188 | 5.6 |
| lit.grey1.0 | 243 243 243 | 238 238 239 | 4.5 |
| lit.white.rough0.5 | 243 243 243 | 240 240 240 | 3.0 |
| lit.indigo |   3  27  67 |  12  32  73 | 7.0 |
| lit.red | 255   0   0 | 251   0   0 | 1.4 |
| lit.green |   0 250   0 |   0 246   0 | 1.3 |
| lit.blue |  14  14 252 |  16  16 249 | 2.1 |
| lit.cyan |   0 244 244 |   0 241 241 | 2.4 |
| lit.magenta | 250   0 250 | 246   0 247 | 2.3 |
| lit.yellow | 244 244   0 | 241 241   1 | 2.6 |
| sphere.dielectric | 188 188 188 | 188 188 188 | 0.8 |
| sphere.metal | 198 176 117 | 203 181 121 | 4.6 |
| sphere.glossy | 202  54  54 | 202  54  54 | 0.2 |
| point.centre | 249 249 249 | 241 242 242 | 7.6 |
| point.edge | 247 247 247 | 240 240 240 | 7.1 |
| spot.centre | 250 250 250 | 241 242 242 | 8.6 |
| spot.penumbra | 247 247 247 | 239 239 239 | 8.6 |
| spot.outside | 243 243 243 | 238 238 239 | 4.5 |
| ibl.card | 243 243 243 | 238 238 239 | 4.3 |
| shadow.lit | 182 182 182 | 188 188 188 | 5.9 |
| shadow.umbra | 121 121 121 | 128 128 128 | 7.0 |
| sky |  68 112 162 |  69 112 162 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 50.5 | 80.4 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 2.5 | 6.8 (unlit.blue) | 8 | ok |
| emissive | 6 | 2.3 | 5.3 (emissive.white1) | 8 | ok |
| lit | 13 | 4.1 | 9.5 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 1.9 | 4.6 (sphere.metal) | 16 | ok |
| light | 5 | 7.3 | 8.6 (spot.penumbra) | 16 | ok |
| shadow | 2 | 6.4 | 7.0 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### default-stage

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 214 223 156 | 174 193  76 | 50.3 |
| texture.unlit.pink | 248 157 206 | 242  78 158 | 44.2 |
| texture.lit.lime | 224 235 161 | 187 208  90 | 44.9 |
| texture.emissive.lime | 232 242 171 | 199 221  97 | 42.6 |
| texture.emissive.pink | 255 173 223 | 255  99 180 | 39.0 |
| texture.unlit.factor | 154 154 154 |  74  74  74 | 80.4 |
| unlit.grey0.02 |   8   8   8 |  10  10  10 | 1.8 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.8 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| unlit.grey0.5 | 180 180 180 | 181 181 181 | 1.1 |
| unlit.grey1.0 | 240 240 240 | 234 234 234 | 6.3 |
| unlit.indigo |   0  23  68 |   1  22  68 | 0.5 |
| unlit.red | 254   0   0 | 247   0   0 | 2.5 |
| unlit.green |   0 246   0 |   0 242   0 | 1.3 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.8 |
| unlit.cyan |   0 241 241 |   0 237 236 | 3.1 |
| unlit.magenta | 246   0 246 | 241   0 243 | 2.7 |
| unlit.yellow | 241 241   0 | 237 237   0 | 2.6 |
| emissive.grey0.18 | 108 108 108 | 110 110 110 | 1.7 |
| emissive.white1 | 240 240 240 | 235 235 235 | 5.3 |
| emissive.white4 | 253 253 253 | 249 249 249 | 4.0 |
| emissive.orange1 | 251 115  38 | 247 116  43 | 3.4 |
| emissive.orange4 | 255 174 138 | 255 174 138 | 0.1 |
| emissive.blue2 | 121 182 255 | 122 182 255 | 0.3 |
| lit.grey0.04 |  33  33  33 |  42  43  43 | 9.4 |
| lit.grey0.18 | 109 109 109 | 117 118 118 | 8.6 |
| lit.grey0.5 | 189 189 189 | 194 195 195 | 5.9 |
| lit.grey1.0 | 244 244 244 | 240 240 241 | 3.5 |
| lit.white.rough0.5 | 244 244 244 | 239 239 240 | 4.5 |
| lit.indigo |   6  28  71 |  15  35  77 | 7.4 |
| lit.red | 255   0   0 | 255   0   0 | 0.1 |
| lit.green |   0 252   0 |   5 250   5 | 3.9 |
| lit.blue |  30  30 254 |  23  24 253 | 5.1 |
| lit.cyan |  20 245 246 |  14 243 244 | 3.6 |
| lit.magenta | 251   0 252 | 248   6 251 | 3.4 |
| lit.yellow | 245 245  20 | 243 244  13 | 3.5 |
| sphere.dielectric | 192 192 193 | 193 194 194 | 1.4 |
| sphere.metal | 196 175 116 | 204 182 121 | 6.3 |
| sphere.glossy | 209  58  58 | 208  58  58 | 0.6 |
| point.centre | 244 244 244 | 240 240 241 | 3.5 |
| point.edge | 244 244 244 | 240 240 241 | 3.5 |
| spot.centre | 244 244 244 | 240 240 241 | 3.5 |
| spot.penumbra | 244 244 244 | 240 240 241 | 3.5 |
| spot.outside | 244 244 244 | 240 240 241 | 3.5 |
| ibl.card | 244 244 244 | 240 240 241 | 3.6 |
| shadow.lit | 188 188 189 | 194 195 195 | 6.4 |
| shadow.umbra | 132 132 132 | 139 140 140 | 7.4 |
| sky |   0   0   0 |  42  42  58 | 47.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 50.2 | 80.4 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 2.5 | 6.8 (unlit.blue) | 8 | ok |
| emissive | 6 | 2.4 | 5.3 (emissive.white1) | 8 | ok |
| lit | 13 | 4.8 | 9.4 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 2.8 | 6.3 (sphere.metal) | 16 | ok |
| light | 5 | 3.5 | 3.5 (spot.penumbra) | 16 | ok |
| shadow | 2 | 6.9 | 7.4 (shadow.umbra) | 16 | ok |
| sky | 1 | 47.2 | 47.2 (sky) | 8 | over |

### all-bloom

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 214 223 156 | 175 193  77 | 49.3 |
| texture.unlit.pink | 248 157 206 | 242  80 159 | 43.5 |
| texture.lit.lime | 218 230 155 | 182 200  86 | 44.9 |
| texture.emissive.lime | 232 242 171 | 201 221  98 | 41.9 |
| texture.emissive.pink | 255 173 223 | 255 100 179 | 39.3 |
| texture.unlit.factor | 154 154 154 |  77  75  75 | 78.2 |
| unlit.grey0.02 |   8   8   8 |  18  15  15 | 7.8 |
| unlit.grey0.05 |  34  34  34 |  41  39  39 | 5.9 |
| unlit.grey0.18 | 105 105 105 | 108 107 107 | 2.2 |
| unlit.grey0.5 | 180 180 180 | 183 182 182 | 2.2 |
| unlit.grey1.0 | 240 240 240 | 235 234 234 | 5.8 |
| unlit.indigo |   0  23  68 |  12  21  69 | 5.2 |
| unlit.red | 254   0   0 | 247   0   0 | 2.4 |
| unlit.green |   0 246   0 |   0 243   0 | 1.1 |
| unlit.blue |   0   0 248 |  24  17 246 | 14.4 |
| unlit.cyan |   0 241 241 |  15 237 237 | 7.6 |
| unlit.magenta | 246   0 246 | 244   0 243 | 1.7 |
| unlit.yellow | 241 241   0 | 239 237   1 | 2.6 |
| emissive.grey0.18 | 108 108 108 | 112 112 112 | 4.0 |
| emissive.white1 | 241 241 241 | 237 237 237 | 4.1 |
| emissive.white4 | 255 255 255 | 248 248 248 | 7.2 |
| emissive.orange1 | 251 115  38 | 251 123  63 | 11.3 |
| emissive.orange4 | 255 209 202 | 255 174 145 | 30.7 |
| emissive.blue2 | 121 182 255 | 128 180 255 | 3.3 |
| lit.grey0.04 |  30  30  30 |  46  44  44 | 14.4 |
| lit.grey0.18 | 105 105 105 | 117 117 117 | 12.0 |
| lit.grey0.5 | 182 182 182 | 192 192 192 | 9.9 |
| lit.grey1.0 | 248 248 248 | 242 241 241 | 6.7 |
| lit.white.rough0.5 | 248 248 248 | 244 242 242 | 5.6 |
| lit.indigo |   3  27  67 |  35  35  78 | 17.1 |
| lit.red | 255   0   0 | 253   0   0 | 0.8 |
| lit.green |   0 250   0 |   6 248   1 | 3.0 |
| lit.blue |  14  14 252 |  25  22 250 | 6.9 |
| lit.cyan |   0 244 244 |  25 242 242 | 9.4 |
| lit.magenta | 250   0 250 | 248   1 248 | 1.2 |
| lit.yellow | 246 246  23 | 242 242  17 | 4.5 |
| sphere.dielectric | 188 188 188 | 190 190 190 | 2.4 |
| sphere.metal | 205 181 120 | 207 184 124 | 3.3 |
| sphere.glossy | 203  55  55 | 203  59  59 | 3.0 |
| point.centre | 254 254 254 | 243 243 243 | 10.8 |
| point.edge | 253 253 253 | 244 244 244 | 8.8 |
| spot.centre | 254 254 254 | 245 245 244 | 9.5 |
| spot.penumbra | 253 253 253 | 240 240 240 | 12.7 |
| spot.outside | 249 249 249 | 241 241 241 | 7.7 |
| ibl.card | 248 248 248 | 241 241 241 | 7.4 |
| shadow.lit | 182 182 182 | 188 188 188 | 6.6 |
| shadow.umbra | 121 121 121 | 129 129 129 | 7.8 |
| sky |  68 112 162 |  73 113 163 | 2.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 49.5 | 78.2 (texture.unlit.factor) | 8 | over |
| unlit | 12 | 4.9 | 14.4 (unlit.blue) | 8 | over |
| emissive | 6 | 10.1 | 30.7 (emissive.orange4) | 8 | over |
| lit | 13 | 7.6 | 17.1 (lit.indigo) | 16 | over |
| sphere | 3 | 2.9 | 3.3 (sphere.metal) | 16 | ok |
| light | 5 | 9.9 | 12.7 (spot.penumbra) | 16 | ok |
| shadow | 2 | 7.2 | 7.8 (shadow.umbra) | 16 | ok |
| sky | 1 | 2.5 | 2.5 (sky) | 8 | ok |

