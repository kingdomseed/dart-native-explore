### all-bloom

| Patch | iOS | A142 | Diff |
|---|---|---|---|
| texture.unlit.lime | 175 194  76 | 175 193  77 | 0.7 |
| texture.unlit.pink | 246  79 158 | 242  80 159 | 1.8 |
| texture.lit.lime | 176 196  78 | 182 200  87 | 6.2 |
| texture.emissive.lime | 200 219  96 | 201 221  98 | 1.4 |
| texture.emissive.pink | 255  98 180 | 255 100 179 | 1.1 |
| texture.unlit.factor |  77  74  75 |  77  75  75 | 0.5 |
| unlit.grey0.02 |  13  10  11 |  18  15  15 | 4.6 |
| unlit.grey0.05 |  39  37  38 |  41  39  39 | 1.8 |
| unlit.grey0.18 | 107 107 107 | 108 107 107 | 0.3 |
| unlit.grey0.5 | 182 181 181 | 183 182 182 | 0.9 |
| unlit.grey1.0 | 240 240 240 | 235 234 234 | 5.8 |
| unlit.indigo |   7  20  69 |  12  21  69 | 2.1 |
| unlit.red | 254   0   0 | 247   0   0 | 2.4 |
| unlit.green |   0 246   0 |   0 243   0 | 1.1 |
| unlit.blue |  19   9 249 |  24  17 246 | 5.4 |
| unlit.cyan |   1 241 242 |  16 237 237 | 7.6 |
| unlit.magenta | 249   0 247 | 244   0 243 | 2.8 |
| unlit.yellow | 242 241   0 | 239 237   2 | 3.0 |
| emissive.grey0.18 | 110 110 110 | 113 112 112 | 2.1 |
| emissive.white1 | 241 241 241 | 237 237 237 | 3.9 |
| emissive.white4 | 253 253 253 | 248 248 248 | 5.2 |
| emissive.orange1 | 255 123  62 | 251 124  64 | 2.3 |
| emissive.orange4 | 255 174 146 | 255 174 145 | 0.7 |
| emissive.blue2 | 128 179 255 | 128 180 255 | 0.4 |
| lit.grey0.04 |  37  36  36 |  46  44  44 | 8.3 |
| lit.grey0.18 | 110 110 110 | 118 117 117 | 7.4 |
| lit.grey0.5 | 187 187 187 | 192 192 192 | 5.0 |
| lit.grey1.0 | 244 243 243 | 242 241 241 | 2.1 |
| lit.white.rough0.5 | 245 242 243 | 244 242 242 | 0.9 |
| lit.indigo |  31  27  73 |  36  35  78 | 6.3 |
| lit.red | 255   0   0 | 253   0   0 | 0.9 |
| lit.green |   0 251   0 |   8 248   3 | 4.6 |
| lit.blue |  28  27 253 |  25  23 250 | 3.3 |
| lit.cyan |  28 245 245 |  26 242 242 | 2.8 |
| lit.magenta | 252   0 251 | 249   1 249 | 2.4 |
| lit.yellow | 245 244  17 | 242 242  17 | 1.6 |
| sphere.dielectric | 189 188 188 | 190 189 189 | 0.9 |
| sphere.metal | 205 182 124 | 209 185 125 | 3.0 |
| sphere.glossy | 206  62  62 | 205  61  61 | 1.1 |
| point.centre | 250 250 250 | 244 244 244 | 6.3 |
| point.edge | 249 248 248 | 246 246 246 | 2.4 |
| spot.centre | 251 251 251 | 245 245 245 | 5.8 |
| spot.penumbra | 248 248 248 | 241 240 240 | 7.9 |
| spot.outside | 244 244 244 | 243 243 243 | 1.4 |
| ibl.card | 244 244 244 | 241 241 241 | 3.1 |
| shadow.lit | 183 182 182 | 189 188 188 | 6.0 |
| shadow.umbra | 122 122 122 | 129 129 129 | 7.0 |
| sky |  72 114 163 |  73 114 163 | 0.6 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| texture | 6 | 1.9 | 6.2 (texture.lit.lime) | 8 | ok |
| unlit | 12 | 3.2 | 7.6 (unlit.cyan) | 8 | ok |
| emissive | 6 | 2.4 | 5.2 (emissive.white4) | 8 | ok |
| lit | 13 | 3.8 | 8.3 (lit.grey0.04) | 16 | ok |
| sphere | 3 | 1.7 | 3.0 (sphere.metal) | 16 | ok |
| light | 5 | 4.7 | 7.9 (spot.penumbra) | 16 | ok |
| shadow | 2 | 6.5 | 7.0 (shadow.umbra) | 16 | ok |
| sky | 1 | 0.6 | 0.6 (sky) | 8 | ok |

