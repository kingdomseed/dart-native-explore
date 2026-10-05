### unlit-linear

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 179 200  94 | 181 199  94 | 1.1 |
| texture.unlit.pink | 253  96 166 | 249  96 166 | 1.5 |
| texture.lit.lime |   0   0   0 |   0   0   0 | 0.3 |
| texture.emissive.lime | 205 223 107 | 203 224 107 | 0.9 |
| texture.emissive.pink | 255 109 187 | 255 109 187 | 0.2 |
| texture.unlit.factor |  92  92  92 |  92  92  92 | 0.4 |
| unlit.grey0.02 |  39  39  39 |  39  39  39 | 0.3 |
| unlit.grey0.05 |  63  63  63 |  63  63  63 | 0.3 |
| unlit.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| unlit.grey0.5 | 187 187 187 | 188 187 188 | 0.5 |
| unlit.grey1.0 | 253 253 253 | 253 253 253 | 0.1 |
| unlit.indigo |  39  49  80 |  39  48  80 | 0.3 |
| unlit.red | 253   0   0 | 253   0   0 | 0.2 |
| unlit.green |   0 253   0 |   1 253   0 | 0.7 |
| unlit.blue |   0   0 253 |   0   0 253 | 0.3 |
| unlit.cyan |   0 253 253 |   3 253 253 | 1.2 |
| unlit.magenta | 253   0 253 | 253   0 253 | 0.3 |
| unlit.yellow | 253 253   0 | 253 253   4 | 1.4 |
| emissive.grey0.18 | 118 118 118 | 118 118 118 | 0.3 |
| emissive.white1 | 253 253 253 | 253 253 253 | 0.2 |
| emissive.white4 | 255 255 255 | 255 255 255 | 0.1 |
| emissive.orange1 | 253 124  63 | 253 124  63 | 0.3 |
| emissive.orange4 | 255 255 134 | 255 253 133 | 0.8 |
| emissive.blue2 | 139 230 255 | 140 232 255 | 1.2 |
| lit.grey0.04 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.18 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.grey1.0 |   0   0   0 |   0   0   0 | 0.3 |
| lit.white.rough0.5 |   0   0   0 |   0   0   0 | 0.2 |
| lit.indigo |   0   0   0 |   0   0   0 | 0.3 |
| lit.red |   0   0   0 |   0   0   0 | 0.2 |
| lit.green |   0   0   0 |   0   0   0 | 0.2 |
| lit.blue |   0   0   0 |   0   0   0 | 0.2 |
| lit.cyan |   0   0   0 |   0   0   0 | 0.3 |
| lit.magenta |   0   0   0 |   0   0   0 | 0.2 |
| lit.yellow |   0   0   0 |   0   0   0 | 0.2 |
| sphere.dielectric |   0   0   0 |   0   0   0 | 0.2 |
| sphere.metal |   0   0   0 |   0   0   0 | 0.2 |
| sphere.glossy |   0   0   0 |   0   0   0 | 0.2 |
| point.centre |   0   0   0 |   0   0   0 | 0.2 |
| point.edge |   0   0   0 |   0   0   0 | 0.3 |
| spot.centre |   0   0   0 |   0   0   0 | 0.2 |
| spot.penumbra |   0   0   0 |   0   0   0 | 0.2 |
| spot.outside |   0   0   0 |   0   0   0 | 0.2 |
| ibl.card |   0   0   0 |   0   0   0 | 0.2 |
| shadow.lit |   0   0   0 |   0   0   0 | 0.2 |
| shadow.umbra |   0   0   0 |   0   0   0 | 0.2 |
| sky |  89 124 169 |  89 123 169 | 0.4 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 0.7 | 1.5 (texture.unlit.pink) | 8 | ok |
| unlit | 12 | 0.5 | 1.4 (unlit.yellow) | 8 | ok |
| emissive | 6 | 0.5 | 1.2 (emissive.blue2) | 8 | ok |
| lit | 13 | 0.2 | 0.3 (lit.grey1.0) | 16 | ok |
| sphere | 3 | 0.2 | 0.2 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.2 | 0.3 (point.edge) | 16 | ok |
| shadow | 2 | 0.2 | 0.2 (shadow.lit) | 16 | ok |
| sky | 1 | 0.4 | 0.4 (sky) | 8 | ok |

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
| spot.centre | 211 211 211 | 210 210 210 | 1.1 |
| spot.penumbra | 120 120 120 | 121 121 121 | 0.7 |
| spot.outside |   0   0   0 |   0   0   0 | 0.2 |
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
| sphere | 3 | 0.3 | 0.3 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.5 | 1.1 (spot.centre) | 16 | ok |
| shadow | 2 | 0.3 | 0.3 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.3 | 0.3 (sky) | 8 | ok |

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
| unlit.grey0.5 | 180 180 180 | 181 181 181 | 1.1 |
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
| sky |   0   0   0 |   0   0   0 | 0.1 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 2.4 | 6.6 (texture.lit.lime) | 8 | ok |
| unlit | 12 | 2.1 | 6.8 (unlit.blue) | 8 | ok |
| emissive | 6 | 2.6 | 4.3 (emissive.white1) | 8 | ok |
| lit | 13 | 4.5 | 9.7 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 1.6 | 2.7 (sphere.metal) | 16 | ok |
| light | 5 | 3.6 | 3.6 (spot.penumbra) | 16 | ok |
| shadow | 2 | 6.8 | 7.8 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.1 | 0.1 (sky) | 8 | ok |

### all-bloom

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 172 194  77 | 175 193  77 | 1.2 |
| texture.unlit.pink | 249  80 158 | 242  80 159 | 2.7 |
| texture.lit.lime | 177 194  77 | 182 200  87 | 6.6 |
| texture.emissive.lime | 200 217  96 | 201 221  98 | 2.1 |
| texture.emissive.pink | 255  98 176 | 255 100 179 | 1.5 |
| texture.unlit.factor |  77  74  75 |  77  75  75 | 0.7 |
| unlit.grey0.02 |  13  11  11 |  18  15  15 | 4.2 |
| unlit.grey0.05 |  39  37  38 |  41  39  39 | 1.8 |
| unlit.grey0.18 | 108 107 107 | 108 107 107 | 0.2 |
| unlit.grey0.5 | 182 181 181 | 183 182 182 | 0.9 |
| unlit.grey1.0 | 240 239 239 | 235 234 234 | 5.1 |
| unlit.indigo |   9  19  69 |  12  21  69 | 1.8 |
| unlit.red | 252   0   0 | 247   0   0 | 1.8 |
| unlit.green |   0 245   0 |   0 243   0 | 0.7 |
| unlit.blue |  18   8 248 |  24  17 246 | 6.0 |
| unlit.cyan |   0 241 241 |  16 237 237 | 7.6 |
| unlit.magenta | 248   0 246 | 244   0 243 | 2.3 |
| unlit.yellow | 241 240   0 | 239 237   2 | 2.4 |
| emissive.grey0.18 | 111 110 110 | 113 112 112 | 1.6 |
| emissive.white1 | 240 240 240 | 237 237 237 | 3.2 |
| emissive.white4 | 254 253 253 | 248 248 248 | 5.5 |
| emissive.orange1 | 255 122  61 | 251 124  64 | 2.8 |
| emissive.orange4 | 255 173 148 | 255 174 145 | 1.7 |
| emissive.blue2 | 126 178 255 | 128 180 255 | 1.4 |
| lit.grey0.04 |  37  36  36 |  46  44  44 | 8.3 |
| lit.grey0.18 | 110 110 110 | 118 117 117 | 7.3 |
| lit.grey0.5 | 189 189 189 | 192 192 192 | 3.1 |
| lit.grey1.0 | 243 242 243 | 242 241 241 | 1.3 |
| lit.white.rough0.5 | 244 242 242 | 244 242 242 | 0.3 |
| lit.indigo |  31  26  72 |  36  35  78 | 6.5 |
| lit.red | 255   0   0 | 253   0   0 | 0.9 |
| lit.green |   0 249   0 |   8 248   3 | 4.1 |
| lit.blue |  23  20 252 |  25  23 250 | 2.1 |
| lit.cyan |  19 244 244 |  26 242 242 | 3.4 |
| lit.magenta | 250   0 250 | 249   1 249 | 1.6 |
| lit.yellow | 244 244   1 | 242 242  17 | 6.7 |
| sphere.dielectric | 188 188 188 | 190 189 189 | 1.2 |
| sphere.metal | 204 182 123 | 209 185 125 | 3.3 |
| sphere.glossy | 206  61  61 | 205  61  61 | 0.4 |
| point.centre | 250 250 250 | 244 244 244 | 6.2 |
| point.edge | 249 249 249 | 246 246 246 | 2.9 |
| spot.centre | 251 251 251 | 245 245 245 | 5.9 |
| spot.penumbra | 247 247 247 | 241 240 240 | 6.7 |
| spot.outside | 243 243 243 | 243 243 243 | 0.4 |
| ibl.card | 243 243 243 | 241 241 241 | 2.3 |
| shadow.lit | 182 182 182 | 189 188 188 | 6.9 |
| shadow.umbra | 121 121 121 | 129 129 129 | 8.1 |
| sky |  73 113 162 |  74 113 163 | 0.5 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 2.5 | 6.6 (texture.lit.lime) | 8 | ok |
| unlit | 12 | 2.9 | 7.6 (unlit.cyan) | 8 | ok |
| emissive | 6 | 2.7 | 5.5 (emissive.white4) | 8 | ok |
| lit | 13 | 3.7 | 8.3 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 1.6 | 3.3 (sphere.metal) | 16 | ok |
| light | 5 | 4.4 | 6.7 (spot.penumbra) | 16 | ok |
| shadow | 2 | 7.5 | 8.1 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.5 | 0.5 (sky) | 8 | ok |

