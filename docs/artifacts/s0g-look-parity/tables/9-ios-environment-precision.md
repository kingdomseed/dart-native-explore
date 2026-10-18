### unlit-linear

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 179 200  94 | 181 199  94 | 1.0 |
| texture.unlit.pink | 253  96 166 | 244  96 166 | 3.1 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.3 |
| texture.emissive.lime | 205 223 107 | 203 224 107 | 0.9 |
| texture.emissive.pink | 255 109 187 | 255 109 187 | 0.2 |
| texture.unlit.factor |  92  92  92 |  93  92  93 | 0.5 |
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 253 253 253 | 249 247 248 | 4.9 |
| unlit.indigo |  39  49  80 |  39  48  80 | 0.3 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 253   0 |  23 247   6 | 11.5 |
| unlit.blue |   0   0 253 |   1   0 247 | 2.2 |
| unlit.cyan |   0 253 253 |  34 247 247 | 14.9 |
| unlit.magenta | 253   0 253 | 247   1 247 | 3.9 |
| unlit.yellow | 253 253   0 | 249 247  17 | 9.0 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| emissive.white1 | 253 253 253 | 249 247 248 | 4.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 253 124  63 | 247 124  63 | 2.0 |
| emissive.orange4 | 255 255 134 | 255 253 134 | 0.8 |
| emissive.blue2 | 139 230 255 | 141 232 255 | 1.3 |
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
| sky |  89 124 169 |  89 124 170 | 0.3 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 1.0 | 3.1 (texture.unlit.pink) | 8 | ok |
| unlit | 12 | 4.2 | 14.9 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.6 | 4.9 (emissive.white1) | 8 | ok |
| lit | 13 | 0.3 | 0.3 (lit.yellow) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.3 | 0.3 (spot.centre) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.3 | 0.3 (sky) | 8 | ok |

### unlit-neutral

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 172 194  76 | 174 193  76 | 1.1 |
| texture.unlit.pink | 249  79 158 | 242  78 158 | 2.7 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.1 |
| texture.emissive.lime | 199 217  92 | 197 219  91 | 1.3 |
| texture.emissive.pink | 255  95 178 | 255  94 178 | 0.5 |
| texture.unlit.factor |  73  73  73 |  74  74  74 | 0.6 |
| unlit.grey0.02 |   8   8   8 |  10  10  10 | 1.8 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.8 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| unlit.grey0.5 | 180 180 180 | 181 181 181 | 1.1 |
| unlit.grey1.0 | 239 239 239 | 234 234 234 | 5.3 |
| unlit.indigo |   0  23  68 |   1  22  68 | 0.5 |
| unlit.red | 252   0   0 | 247   0   0 | 1.8 |
| unlit.green |   0 245   0 |   0 242   0 | 1.0 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.8 |
| unlit.cyan |   0 240 240 |   0 237 236 | 2.4 |
| unlit.magenta | 245   0 245 | 241   0 243 | 2.0 |
| unlit.yellow | 240 240   0 | 237 237   0 | 1.9 |
| emissive.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| emissive.white1 | 239 239 239 | 234 234 234 | 5.3 |
| emissive.white4 | 253 253 253 | 249 249 249 | 3.7 |
| emissive.orange1 | 249 112  26 | 246 112  24 | 2.0 |
| emissive.orange4 | 255 172 139 | 255 173 137 | 1.2 |
| emissive.blue2 | 117 182 255 | 119 181 255 | 1.0 |
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
| sky |  69 112 161 |  69 111 162 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 1.1 | 2.7 (texture.unlit.pink) | 8 | ok |
| unlit | 12 | 2.1 | 6.8 (unlit.blue) | 8 | ok |
| emissive | 6 | 2.3 | 5.3 (emissive.white1) | 8 | ok |
| lit | 13 | 0.1 | 0.1 (lit.white.rough0.5) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.glossy) | 16 | ok |
| light | 5 | 0.1 | 0.1 (spot.outside) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### unlit-aces

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 194 204 121 | 199 205 120 | 2.1 |
| texture.unlit.pink | 241 118 180 | 241 118 181 | 0.4 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.1 |
| texture.emissive.lime | 210 215 141 | 213 216 141 | 1.4 |
| texture.emissive.pink | 250 140 196 | 250 140 195 | 0.5 |
| texture.unlit.factor |  91  91  91 |  92  93  94 | 1.7 |
| unlit.grey0.02 |  21  21  21 |  23  23  24 | 2.5 |
| unlit.grey0.05 |  50  50  50 |  51  52  53 | 1.9 |
| unlit.grey0.18 | 127 127 127 | 128 128 129 | 1.5 |
| unlit.grey0.5 | 196 196 196 | 201 198 195 | 2.7 |
| unlit.grey1.0 | 226 226 226 | 230 225 219 | 3.6 |
| unlit.indigo |  19  31  69 |  22  34  74 | 3.6 |
| unlit.red | 249  14  20 | 244  29  17 | 7.4 |
| unlit.green | 146 227  88 | 150 228  87 | 2.0 |
| unlit.blue |   0   0 227 |   5   0 227 | 1.8 |
| unlit.cyan | 152 227 225 | 158 227 219 | 4.0 |
| unlit.magenta | 247  39 227 | 251  36 224 | 3.2 |
| unlit.yellow | 229 226 104 | 233 226 104 | 1.6 |
| emissive.grey0.18 | 127 127 127 | 128 128 129 | 1.5 |
| emissive.white1 | 226 226 226 | 230 225 219 | 3.6 |
| emissive.white4 | 250 250 250 | 249 244 236 | 7.0 |
| emissive.orange1 | 239 147  75 | 238 150  74 | 1.3 |
| emissive.orange4 | 255 226 179 | 255 225 175 | 1.5 |
| emissive.blue2 | 179 219 241 | 187 220 231 | 5.9 |
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
| sky |  94 135 180 |  94 136 182 | 1.0 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 1.0 | 2.1 (texture.unlit.lime) | 8 | ok |
| unlit | 12 | 3.0 | 7.4 (unlit.red) | 8 | ok |
| emissive | 6 | 3.5 | 7.0 (emissive.white4) | 8 | ok |
| lit | 13 | 0.1 | 0.1 (lit.grey0.5) | 16 | ok |
| sphere | 3 | 0.1 | 0.1 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.1 | 0.1 (point.centre) | 16 | ok |
| shadow | 2 | 0.1 | 0.1 (shadow.lit) | 16 | ok |
| sky | 1 | 1.0 | 1.0 (sky) | 8 | ok |

### unlit-exposure2

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 255 255 135 | 247 255 134 | 3.3 |
| texture.unlit.pink | 255 142 230 | 255 143 227 | 1.2 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.3 |
| texture.emissive.lime | 255 255 158 | 255 255 158 | 0.1 |
| texture.emissive.pink | 255 170 255 | 255 168 247 | 3.1 |
| texture.unlit.factor | 127 127 127 | 128 128 128 | 1.2 |
| unlit.grey0.02 |  56  56  56 |  57  56  56 | 0.5 |
| unlit.grey0.05 |  89  89  89 |  89  89  89 | 0.2 |
| unlit.grey0.18 | 163 163 163 | 162 162 162 | 1.0 |
| unlit.grey0.5 | 253 253 253 | 249 247 248 | 4.9 |
| unlit.grey1.0 | 255 255 255 | 255 255 255 | 0.1 |
| unlit.indigo |  56  69 111 |  57  69 112 | 0.5 |
| unlit.red | 255  42  11 | 255  48  15 | 3.3 |
| unlit.green | 176 255  77 | 186 255  82 | 4.9 |
| unlit.blue |  63  18 255 |  68  19 255 | 1.9 |
| unlit.cyan | 189 255 255 | 199 255 255 | 3.5 |
| unlit.magenta | 255  56 255 | 255  62 255 | 2.0 |
| unlit.yellow | 255 255  90 | 255 255  95 | 1.8 |
| emissive.grey0.18 | 163 163 163 | 162 162 162 | 1.0 |
| emissive.white1 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 255 176  92 | 255 179  92 | 1.1 |
| emissive.orange4 | 255 255 205 | 255 255 202 | 1.0 |
| emissive.blue2 | 250 255 255 | 243 255 255 | 2.3 |
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
| spot.outside |   0   0   0 |   0   0   0 | 0.2 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky | 124 169 229 | 124 169 231 | 0.9 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 1.5 | 3.3 (texture.unlit.lime) | 8 | ok |
| unlit | 12 | 2.1 | 4.9 (unlit.green) | 8 | ok |
| emissive | 6 | 0.9 | 2.3 (emissive.blue2) | 8 | ok |
| lit | 13 | 0.3 | 0.3 (lit.magenta) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.metal) | 16 | ok |
| light | 5 | 0.3 | 0.3 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.lit) | 16 | ok |
| sky | 1 | 0.9 | 0.9 (sky) | 8 | ok |

### directional

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 179 200  94 | 181 199  94 | 1.0 |
| texture.unlit.pink | 253  96 166 | 244  96 166 | 3.1 |
| texture.lit.lime | 140 154  74 | 140 154  74 | 0.2 |
| texture.emissive.lime | 205 223 108 | 205 224 109 | 0.9 |
| texture.emissive.pink | 255 111 187 | 255 111 188 | 0.6 |
| texture.unlit.factor |  92  92  92 |  93  92  93 | 0.5 |
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.8 |
| unlit.grey1.0 | 253 253 253 | 249 247 248 | 4.9 |
| unlit.indigo |  39  49  80 |  39  48  80 | 0.3 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 253   0 |  23 247   6 | 11.5 |
| unlit.blue |   0   0 253 |   1   0 247 | 2.2 |
| unlit.cyan |   0 253 253 |  34 247 247 | 14.9 |
| unlit.magenta | 253   0 253 | 247   0 247 | 3.9 |
| unlit.yellow | 253 253   0 | 249 247  17 | 8.9 |
| emissive.grey0.18 | 119 119 119 | 120 120 120 | 0.8 |
| emissive.white1 | 253 253 253 | 250 248 248 | 4.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 253 126  67 | 248 126  67 | 2.0 |
| emissive.orange4 | 255 255 135 | 255 253 135 | 0.7 |
| emissive.blue2 | 140 230 255 | 142 233 255 | 1.7 |
| lit.grey0.04 |  47  47  47 |  47  47  47 | 0.7 |
| lit.grey0.18 |  91  91  91 |  92  92  92 | 1.0 |
| lit.grey0.5 | 145 145 145 | 146 146 146 | 0.6 |
| lit.grey1.0 | 196 196 196 | 198 198 198 | 1.7 |
| lit.white.rough0.5 | 200 200 200 | 201 201 201 | 0.6 |
| lit.indigo |  35  41  63 |  36  42  64 | 1.0 |
| lit.red | 196  18  18 | 198  19  19 | 1.1 |
| lit.green |  18 196  18 |  19 198  19 | 1.1 |
| lit.blue |  18  18 196 |  19  19 198 | 1.1 |
| lit.cyan |  18 196 196 |  19 198 198 | 1.4 |
| lit.magenta | 196  18 196 | 198  19 198 | 1.4 |
| lit.yellow | 196 196  18 | 198 198  19 | 1.5 |
| sphere.dielectric | 139 139 139 | 141 141 141 | 1.3 |
| sphere.metal |  96  87  64 |  96  87  63 | 0.3 |
| sphere.glossy | 155  52  52 | 156  52  52 | 0.2 |
| point.centre | 196 196 196 | 198 198 198 | 1.7 |
| point.edge | 196 196 196 | 198 198 198 | 1.6 |
| spot.centre | 196 196 196 | 198 198 198 | 1.6 |
| spot.penumbra | 196 196 196 | 198 198 198 | 1.6 |
| spot.outside | 196 196 196 | 198 198 198 | 1.7 |
| ibl.card | 196 196 196 | 198 198 198 | 1.6 |
| shadow.lit | 144 144 144 | 146 146 146 | 2.0 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  89 124 169 |  89 124 170 | 0.3 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 1.0 | 3.1 (texture.unlit.pink) | 8 | ok |
| unlit | 12 | 4.2 | 14.9 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.6 | 4.5 (emissive.white1) | 8 | ok |
| lit | 13 | 1.1 | 1.7 (lit.grey1.0) | 16 | ok |
| sphere | 3 | 0.6 | 1.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 1.6 | 1.7 (point.centre) | 16 | ok |
| shadow | 2 | 1.1 | 2.0 (shadow.lit) | 16 | ok |
| sky | 1 | 0.3 | 0.3 (sky) | 8 | ok |

### point

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 179 200  94 | 181 199  94 | 1.0 |
| texture.unlit.pink | 253  96 166 | 244  96 166 | 3.1 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.3 |
| texture.emissive.lime | 205 223 107 | 203 224 107 | 0.9 |
| texture.emissive.pink | 255 109 187 | 255 109 187 | 0.2 |
| texture.unlit.factor |  92  92  92 |  93  92  93 | 0.5 |
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 253 253 253 | 249 247 248 | 4.9 |
| unlit.indigo |  39  49  80 |  39  48  80 | 0.3 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 253   0 |  23 247   6 | 11.5 |
| unlit.blue |   0   0 253 |   1   0 247 | 2.2 |
| unlit.cyan |   0 253 253 |  34 247 247 | 14.9 |
| unlit.magenta | 253   0 253 | 247   1 247 | 3.9 |
| unlit.yellow | 253 253   0 | 249 247  17 | 8.9 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| emissive.white1 | 253 253 253 | 249 247 248 | 4.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 253 124  63 | 247 124  63 | 2.0 |
| emissive.orange4 | 255 255 134 | 255 253 134 | 0.8 |
| emissive.blue2 | 139 230 255 | 141 232 255 | 1.3 |
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
| sphere.dielectric |  14  14  14 |  14  14  14 | 0.7 |
| sphere.metal |   3   2   1 |   3   2   1 | 0.3 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.3 |
| point.centre | 208 208 208 | 208 208 208 | 0.2 |
| point.edge | 157 157 157 | 157 157 157 | 0.3 |
| spot.centre |  46  46  46 |  47  47  47 | 0.3 |
| spot.penumbra |   7   7   7 |   7   7   7 | 0.4 |
| spot.outside |  31  31  31 |  31  31  31 | 0.1 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  89 124 169 |  89 124 170 | 0.3 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 1.0 | 3.1 (texture.unlit.pink) | 8 | ok |
| unlit | 12 | 4.2 | 14.9 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.6 | 4.9 (emissive.white1) | 8 | ok |
| lit | 13 | 0.3 | 0.3 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 0.4 | 0.7 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.3 | 0.4 (spot.penumbra) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.lit) | 16 | ok |
| sky | 1 | 0.3 | 0.3 (sky) | 8 | ok |

### spot

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 179 200  94 | 181 199  94 | 1.0 |
| texture.unlit.pink | 253  96 166 | 244  96 166 | 3.1 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.3 |
| texture.emissive.lime | 205 223 107 | 203 224 107 | 0.9 |
| texture.emissive.pink | 255 109 187 | 255 109 187 | 0.2 |
| texture.unlit.factor |  92  92  92 |  93  92  93 | 0.5 |
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.8 |
| unlit.grey1.0 | 253 253 253 | 249 247 248 | 4.9 |
| unlit.indigo |  39  49  80 |  39  48  80 | 0.3 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 253   0 |  23 247   6 | 11.5 |
| unlit.blue |   0   0 253 |   1   0 247 | 2.2 |
| unlit.cyan |   0 253 253 |  34 247 247 | 14.9 |
| unlit.magenta | 253   0 253 | 247   0 247 | 3.9 |
| unlit.yellow | 253 253   0 | 249 247  17 | 9.0 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| emissive.white1 | 253 253 253 | 249 247 248 | 4.9 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 253 124  63 | 247 124  63 | 2.0 |
| emissive.orange4 | 255 255 134 | 255 253 134 | 0.8 |
| emissive.blue2 | 139 230 255 | 141 232 255 | 1.3 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.3 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.3 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.3 |
| lit.red |   0   0   0 |   0   0   0 | 0.3 |
| lit.green |   0   0   0 |   0   0   0 | 0.3 |
| lit.blue |   0   0   0 |   0   0   0 | 0.2 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.3 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.3 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.3 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.3 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.3 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.3 |
| point.centre |   0   0   0 |   0   0   0 | 0.3 |
| point.edge |   0   0   0 |   0   0   0 | 0.3 |
| spot.centre | 211 211 211 | 210 210 210 | 1.1 |
| spot.penumbra | 151 151 151 | 121 121 121 | 30.2 |
| spot.outside |   0   0   0 |   0   0   0 | 0.3 |
| ibl.card |   0   0   0 |   0   0   0 | 0.3 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.3 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.3 |
| sky |  89 124 169 |  89 124 170 | 0.3 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 1.0 | 3.1 (texture.unlit.pink) | 8 | ok |
| unlit | 12 | 4.2 | 14.9 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.6 | 4.9 (emissive.white1) | 8 | ok |
| lit | 13 | 0.3 | 0.3 (lit.grey0.5) | 16 | ok |
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 6.4 | 30.2 (spot.penumbra) | 16 | over |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.3 | 0.3 (sky) | 8 | ok |

### ibl-constant

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 179 200  94 | 181 199  94 | 1.0 |
| texture.unlit.pink | 253  96 166 | 244  96 166 | 3.1 |
| texture.lit.lime | 126 143  61 | 133 147  71 | 7.0 |
| texture.emissive.lime | 205 223 108 | 205 225 109 | 1.1 |
| texture.emissive.pink | 255 109 187 | 255 111 188 | 1.3 |
| texture.unlit.factor |  92  92  92 |  93  92  93 | 0.5 |
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.9 |
| unlit.grey1.0 | 253 253 253 | 249 247 248 | 4.9 |
| unlit.indigo |  39  49  80 |  39  48  80 | 0.3 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 253   0 |  23 247   6 | 11.5 |
| unlit.blue |   0   0 253 |   1   0 247 | 2.2 |
| unlit.cyan |   0 253 253 |  34 247 247 | 14.9 |
| unlit.magenta | 253   0 253 | 247   1 247 | 3.9 |
| unlit.yellow | 253 253   0 | 249 247  17 | 8.9 |
| emissive.grey0.18 | 118 118 118 | 120 120 120 | 1.9 |
| emissive.white1 | 253 253 253 | 250 248 248 | 4.5 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 253 124  65 | 248 126  68 | 3.2 |
| emissive.orange4 | 255 255 134 | 255 253 135 | 1.0 |
| emissive.blue2 | 139 230 255 | 142 233 255 | 2.0 |
| lit.grey0.04 |  36  36  36 |  45  45  45 | 9.4 |
| lit.grey0.18 |  77  77  77 |  88  87  88 | 10.5 |
| lit.grey0.5 | 131 131 131 | 139 138 138 | 7.5 |
| lit.grey1.0 | 196 196 196 | 188 188 188 | 7.6 |
| lit.white.rough0.5 | 191 191 191 | 188 188 188 | 2.6 |
| lit.indigo |  26  32  51 |  35  41  61 | 9.1 |
| lit.red | 196  10  10 | 188  20  19 | 8.9 |
| lit.green |  10 196  10 |  20 188  19 | 8.9 |
| lit.blue |  10  10 196 |  20  19 188 | 8.9 |
| lit.cyan |  10 196 196 |  20 189 188 | 8.2 |
| lit.magenta | 196  10 196 | 189  19 188 | 8.2 |
| lit.yellow | 196 196  10 | 188 188  19 | 8.2 |
| sphere.dielectric | 139 139 139 | 140 140 140 | 0.8 |
| sphere.metal | 183 162 111 | 188 167 114 | 4.2 |
| sphere.glossy | 152  59  59 | 151  59  59 | 0.5 |
| point.centre | 196 196 196 | 188 188 188 | 7.6 |
| point.edge | 196 196 196 | 188 188 188 | 7.5 |
| spot.centre | 196 196 196 | 188 188 188 | 7.5 |
| spot.penumbra | 196 196 196 | 188 188 188 | 7.6 |
| spot.outside | 196 196 196 | 188 188 188 | 7.5 |
| ibl.card | 196 196 196 | 188 188 188 | 7.6 |
| shadow.lit | 131 131 131 | 139 138 138 | 7.5 |
| shadow.umbra | 131 131 131 | 139 138 138 | 7.5 |
| sky |  89 124 169 |  89 124 170 | 0.3 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 2.3 | 7.0 (texture.lit.lime) | 8 | ok |
| unlit | 12 | 4.2 | 14.9 (unlit.cyan) | 8 | over |
| emissive | 6 | 2.1 | 4.5 (emissive.white1) | 8 | ok |
| lit | 13 | 8.1 | 10.5 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 1.8 | 4.2 (sphere.metal) | 16 | ok |
| light | 5 | 7.6 | 7.6 (point.centre) | 16 | ok |
| shadow | 2 | 7.5 | 7.5 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.3 | 0.3 (sky) | 8 | ok |

### ibl-studio

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 179 200  94 | 181 199  94 | 1.0 |
| texture.unlit.pink | 253  96 166 | 244  96 166 | 3.1 |
| texture.lit.lime |  97 111  46 | 104 115  54 | 6.1 |
| texture.emissive.lime | 205 223 107 | 204 224 108 | 1.1 |
| texture.emissive.pink | 255 109 187 | 255 111 188 | 0.9 |
| texture.unlit.factor |  92  92  92 |  93  92  93 | 0.5 |
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.4 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.2 |
| unlit.grey0.5 | 187 187 187 | 188 188 188 | 0.8 |
| unlit.grey1.0 | 253 253 253 | 249 247 248 | 4.9 |
| unlit.indigo |  39  49  80 |  39  48  80 | 0.3 |
| unlit.red | 253   0   0 | 247   0   0 | 2.1 |
| unlit.green |   0 253   0 |  23 247   6 | 11.5 |
| unlit.blue |   0   0 253 |   1   0 247 | 2.2 |
| unlit.cyan |   0 253 253 |  34 247 247 | 14.9 |
| unlit.magenta | 253   0 253 | 247   0 247 | 3.9 |
| unlit.yellow | 253 253   0 | 249 247  17 | 8.9 |
| emissive.grey0.18 | 118 118 118 | 119 119 119 | 1.2 |
| emissive.white1 | 253 253 253 | 250 248 248 | 4.6 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 253 124  64 | 248 125  66 | 2.7 |
| emissive.orange4 | 255 255 134 | 255 253 135 | 0.8 |
| emissive.blue2 | 139 230 255 | 142 233 255 | 1.8 |
| lit.grey0.04 |  26  26  26 |  33  33  34 | 7.4 |
| lit.grey0.18 |  59  59  59 |  67  67  68 | 8.3 |
| lit.grey0.5 | 102 103 103 | 108 108 109 | 5.4 |
| lit.grey1.0 | 152 155 155 | 147 148 149 | 6.0 |
| lit.white.rough0.5 | 150 150 152 | 147 148 149 | 2.9 |
| lit.indigo |  18  22  38 |  25  29  46 | 7.5 |
| lit.red | 152   6   6 | 147  13  12 | 5.9 |
| lit.green |   6 155   6 |  12 148  12 | 6.5 |
| lit.blue |   6   6 155 |  12  12 149 | 6.4 |
| lit.cyan |   6 155 155 |  12 148 149 | 6.5 |
| lit.magenta | 152   6 155 | 147  13 149 | 5.9 |
| lit.yellow | 152 155   6 | 147 148  12 | 6.0 |
| sphere.dielectric | 109 109 110 | 109 109 110 | 0.1 |
| sphere.metal | 142 126  86 | 145 129  87 | 2.1 |
| sphere.glossy | 120  45  45 | 118  45  45 | 1.0 |
| point.centre | 152 155 155 | 147 148 149 | 6.0 |
| point.edge | 152 155 155 | 147 148 149 | 6.0 |
| spot.centre | 152 155 155 | 147 148 149 | 6.0 |
| spot.penumbra | 152 155 155 | 147 148 149 | 6.0 |
| spot.outside | 152 155 155 | 147 148 149 | 6.0 |
| ibl.card | 152 155 155 | 147 148 149 | 6.0 |
| shadow.lit | 102 103 103 | 108 108 109 | 5.4 |
| shadow.umbra | 102 103 103 | 108 108 109 | 5.4 |
| sky |  89 124 169 |  89 124 170 | 0.3 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 2.1 | 6.1 (texture.lit.lime) | 8 | ok |
| unlit | 12 | 4.2 | 14.9 (unlit.cyan) | 8 | over |
| emissive | 6 | 1.9 | 4.6 (emissive.white1) | 8 | ok |
| lit | 13 | 6.2 | 8.3 (lit.grey0.18) | 16 | ok |
| sphere | 3 | 1.1 | 2.1 (sphere.metal) | 16 | ok |
| light | 5 | 6.0 | 6.0 (spot.outside) | 16 | ok |
| shadow | 2 | 5.4 | 5.4 (shadow.lit) | 16 | ok |
| sky | 1 | 0.3 | 0.3 (sky) | 8 | ok |

### all

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 172 194  76 | 174 193  76 | 1.1 |
| texture.unlit.pink | 249  79 158 | 242  78 158 | 2.7 |
| texture.lit.lime | 176 194  76 | 181 199  85 | 6.4 |
| texture.emissive.lime | 199 217  95 | 200 220  97 | 1.8 |
| texture.emissive.pink | 255  98 178 | 255  99 179 | 0.9 |
| texture.unlit.factor |  73  73  73 |  74  74  74 | 0.6 |
| unlit.grey0.02 |   8   8   8 |  10  10  10 | 1.8 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.8 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| unlit.grey0.5 | 180 180 180 | 181 181 181 | 1.0 |
| unlit.grey1.0 | 239 239 239 | 234 234 234 | 5.3 |
| unlit.indigo |   0  23  68 |   1  22  68 | 0.5 |
| unlit.red | 252   0   0 | 247   0   0 | 1.8 |
| unlit.green |   0 245   0 |   0 242   0 | 1.0 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.8 |
| unlit.cyan |   0 240 240 |   0 237 236 | 2.4 |
| unlit.magenta | 245   0 245 | 241   0 243 | 2.0 |
| unlit.yellow | 240 240   0 | 237 237   0 | 1.9 |
| emissive.grey0.18 | 108 108 108 | 109 109 109 | 1.3 |
| emissive.white1 | 239 239 239 | 235 235 235 | 4.3 |
| emissive.white4 | 253 253 253 | 249 249 249 | 3.9 |
| emissive.orange1 | 249 114  37 | 247 116  42 | 2.9 |
| emissive.orange4 | 255 172 140 | 255 174 138 | 1.3 |
| emissive.blue2 | 118 182 255 | 121 182 255 | 1.2 |
| lit.grey0.04 |  30  30  30 |  39  40  39 | 9.0 |
| lit.grey0.18 | 105 105 105 | 113 112 112 | 7.4 |
| lit.grey0.5 | 184 184 184 | 188 188 188 | 4.1 |
| lit.grey1.0 | 242 242 242 | 238 238 239 | 3.5 |
| lit.white.rough0.5 | 242 242 242 | 240 240 240 | 2.0 |
| lit.indigo |   4  26  68 |  12  32  73 | 6.7 |
| lit.red | 255   0   0 | 251   0   0 | 1.4 |
| lit.green |   0 248   0 |   0 247   0 | 0.5 |
| lit.blue |   6   6 251 |  16  16 249 | 7.1 |
| lit.cyan |   0 243 243 |   0 241 241 | 1.8 |
| lit.magenta | 249   0 249 | 246   0 247 | 1.7 |
| lit.yellow | 243 243   0 | 241 241   2 | 2.0 |
| sphere.dielectric | 186 186 186 | 187 187 187 | 1.4 |
| sphere.metal | 199 177 118 | 204 181 121 | 3.9 |
| sphere.glossy | 205  55  55 | 204  55  55 | 0.5 |
| point.centre | 249 249 249 | 241 242 242 | 7.6 |
| point.edge | 248 248 248 | 242 242 242 | 6.2 |
| spot.centre | 250 250 250 | 241 242 242 | 8.6 |
| spot.penumbra | 247 247 247 | 239 239 239 | 8.7 |
| spot.outside | 242 242 242 | 240 240 240 | 2.6 |
| ibl.card | 242 242 242 | 238 238 239 | 3.5 |
| shadow.lit | 181 181 181 | 188 188 188 | 6.8 |
| shadow.umbra | 120 120 120 | 128 128 128 | 8.0 |
| sky |  69 112 161 |  69 111 162 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 2.3 | 6.4 (texture.lit.lime) | 8 | ok |
| unlit | 12 | 2.1 | 6.8 (unlit.blue) | 8 | ok |
| emissive | 6 | 2.5 | 4.3 (emissive.white1) | 8 | ok |
| lit | 13 | 3.9 | 9.0 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 2.0 | 3.9 (sphere.metal) | 16 | ok |
| light | 5 | 6.7 | 8.7 (spot.penumbra) | 16 | ok |
| shadow | 2 | 7.4 | 8.0 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

### default-stage

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 172 194  76 | 174 193  76 | 1.1 |
| texture.unlit.pink | 249  79 158 | 242  78 158 | 2.7 |
| texture.lit.lime | 180 205  80 | 187 208  90 | 6.6 |
| texture.emissive.lime | 199 217  95 | 200 221  97 | 2.1 |
| texture.emissive.pink | 255  98 178 | 255  99 180 | 1.0 |
| texture.unlit.factor |  73  73  73 |  74  74  74 | 0.6 |
| unlit.grey0.02 |   8   8   8 |  10  10  10 | 1.8 |
| unlit.grey0.05 |  34  34  34 |  35  35  35 | 0.8 |
| unlit.grey0.18 | 105 105 105 | 105 105 105 | 0.3 |
| unlit.grey0.5 | 180 180 180 | 181 181 181 | 1.0 |
| unlit.grey1.0 | 239 239 239 | 234 234 234 | 5.3 |
| unlit.indigo |   0  23  68 |   1  22  68 | 0.5 |
| unlit.red | 252   0   0 | 247   0   0 | 1.8 |
| unlit.green |   0 245   0 |   0 242   0 | 1.0 |
| unlit.blue |   0   0 248 |   9   9 245 | 6.8 |
| unlit.cyan |   0 240 240 |   0 237 236 | 2.4 |
| unlit.magenta | 245   0 245 | 241   0 243 | 2.0 |
| unlit.yellow | 240 240   0 | 237 237   0 | 1.9 |
| emissive.grey0.18 | 108 108 108 | 110 110 110 | 1.6 |
| emissive.white1 | 239 239 239 | 235 235 235 | 4.3 |
| emissive.white4 | 253 253 253 | 249 249 249 | 4.0 |
| emissive.orange1 | 249 114  38 | 247 116  43 | 3.1 |
| emissive.orange4 | 255 172 140 | 255 174 138 | 1.3 |
| emissive.blue2 | 118 182 255 | 122 182 255 | 1.3 |
| lit.grey0.04 |  32  33  33 |  42  43  43 | 9.7 |
| lit.grey0.18 | 108 108 108 | 117 117 118 | 9.5 |
| lit.grey0.5 | 189 189 189 | 194 195 195 | 5.8 |
| lit.grey1.0 | 244 244 244 | 240 240 241 | 3.6 |
| lit.white.rough0.5 | 244 244 244 | 239 239 240 | 4.5 |
| lit.indigo |   6  28  71 |  15  35  77 | 7.5 |
| lit.red | 255   0   0 | 255   0   0 | 0.1 |
| lit.green |   0 251   0 |   5 250   5 | 3.5 |
| lit.blue |  27  27 254 |  23  24 253 | 2.7 |
| lit.cyan |  15 246 246 |  14 243 244 | 2.0 |
| lit.magenta | 252   0 252 | 248   6 251 | 3.5 |
| lit.yellow | 245 245  16 | 243 244  13 | 2.2 |
| sphere.dielectric | 192 192 192 | 193 193 193 | 0.8 |
| sphere.metal | 203 181 121 | 206 184 123 | 2.7 |
| sphere.glossy | 213  61  61 | 211  60  60 | 1.1 |
| point.centre | 244 244 244 | 240 240 241 | 3.6 |
| point.edge | 244 244 244 | 240 240 241 | 3.6 |
| spot.centre | 244 244 244 | 240 240 241 | 3.6 |
| spot.penumbra | 244 244 244 | 240 240 241 | 3.6 |
| spot.outside | 244 244 244 | 240 240 241 | 3.6 |
| ibl.card | 244 244 244 | 240 240 241 | 3.6 |
| shadow.lit | 189 189 189 | 194 195 195 | 5.8 |
| shadow.umbra | 131 131 133 | 139 140 140 | 7.8 |
| sky |   0   0   0 |  42  42  58 | 47.2 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 2.4 | 6.6 (texture.lit.lime) | 8 | ok |
| unlit | 12 | 2.1 | 6.8 (unlit.blue) | 8 | ok |
| emissive | 6 | 2.6 | 4.3 (emissive.white1) | 8 | ok |
| lit | 13 | 4.5 | 9.7 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 1.6 | 2.7 (sphere.metal) | 16 | ok |
| light | 5 | 3.6 | 3.6 (point.centre) | 16 | ok |
| shadow | 2 | 6.8 | 7.8 (shadow.umbra) | 16 | ok |
| sky | 1 | 47.2 | 47.2 (sky) | 8 | over |

### all-bloom

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 172 194  77 | 175 193  77 | 1.2 |
| texture.unlit.pink | 249  80 158 | 242  80 159 | 2.7 |
| texture.lit.lime | 177 194  78 | 182 200  87 | 6.6 |
| texture.emissive.lime | 200 217  96 | 201 221  98 | 2.1 |
| texture.emissive.pink | 255  98 176 | 255 100 179 | 1.5 |
| texture.unlit.factor |  77  74  75 |  77  75  75 | 0.7 |
| unlit.grey0.02 |  13  11  11 |  18  15  15 | 4.2 |
| unlit.grey0.05 |  39  37  38 |  41  39  39 | 1.8 |
| unlit.grey0.18 | 108 107 107 | 108 107 107 | 0.2 |
| unlit.grey0.5 | 182 181 181 | 183 182 182 | 0.9 |
| unlit.grey1.0 | 240 239 239 | 235 234 234 | 5.2 |
| unlit.indigo |   9  19  69 |  12  21  69 | 1.8 |
| unlit.red | 252   0   0 | 247   0   0 | 1.8 |
| unlit.green |   0 245   0 |   0 243   0 | 0.7 |
| unlit.blue |  18   8 248 |  24  17 246 | 6.0 |
| unlit.cyan |   0 241 241 |  16 237 237 | 7.6 |
| unlit.magenta | 248   0 246 | 244   0 243 | 2.3 |
| unlit.yellow | 241 240   0 | 239 237   2 | 2.4 |
| emissive.grey0.18 | 111 110 111 | 113 112 112 | 1.5 |
| emissive.white1 | 240 240 240 | 237 237 237 | 3.2 |
| emissive.white4 | 254 253 253 | 248 248 248 | 5.5 |
| emissive.orange1 | 255 122  61 | 251 124  64 | 2.8 |
| emissive.orange4 | 255 173 148 | 255 175 145 | 1.7 |
| emissive.blue2 | 126 178 255 | 128 180 255 | 1.4 |
| lit.grey0.04 |  37  36  36 |  46  44  44 | 8.3 |
| lit.grey0.18 | 110 110 110 | 118 117 117 | 7.3 |
| lit.grey0.5 | 189 189 189 | 192 192 192 | 3.1 |
| lit.grey1.0 | 243 242 243 | 242 241 241 | 1.3 |
| lit.white.rough0.5 | 244 242 242 | 244 242 242 | 0.3 |
| lit.indigo |  32  26  72 |  36  35  78 | 6.5 |
| lit.red | 255   0   0 | 253   0   0 | 0.9 |
| lit.green |   0 249   0 |   8 248   3 | 4.0 |
| lit.blue |  23  20 252 |  25  23 250 | 2.0 |
| lit.cyan |  19 244 244 |  26 242 242 | 3.2 |
| lit.magenta | 250   0 250 | 249   1 248 | 1.6 |
| lit.yellow | 244 244   2 | 242 242  17 | 6.6 |
| sphere.dielectric | 188 188 188 | 190 189 189 | 1.1 |
| sphere.metal | 204 182 123 | 209 185 125 | 3.1 |
| sphere.glossy | 206  61  62 | 205  61  61 | 0.6 |
| point.centre | 250 250 250 | 244 244 244 | 6.3 |
| point.edge | 249 249 249 | 246 246 246 | 2.9 |
| spot.centre | 251 251 251 | 245 245 245 | 5.9 |
| spot.penumbra | 248 248 248 | 240 240 240 | 8.0 |
| spot.outside | 243 243 243 | 243 243 243 | 0.5 |
| ibl.card | 243 243 243 | 241 241 241 | 2.3 |
| shadow.lit | 182 182 182 | 189 188 188 | 6.8 |
| shadow.umbra | 121 121 121 | 129 129 129 | 8.1 |
| sky |  73 113 162 |  73 113 163 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 2.5 | 6.6 (texture.lit.lime) | 8 | ok |
| unlit | 12 | 2.9 | 7.6 (unlit.cyan) | 8 | ok |
| emissive | 6 | 2.7 | 5.5 (emissive.white4) | 8 | ok |
| lit | 13 | 3.6 | 8.3 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 1.6 | 3.1 (sphere.metal) | 16 | ok |
| light | 5 | 4.7 | 8.0 (spot.penumbra) | 16 | ok |
| shadow | 2 | 7.4 | 8.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

