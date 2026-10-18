### default-stage

| Patch | iOS, adaptation left on | iOS, adaptation off | Diff |
|---|---|---|---|
| unlit.grey0.02 |   6   6   6 |   9   9   9 | 3.0 |
| unlit.grey0.05 |  30  30  30 |  34  34  34 | 4.0 |
| unlit.grey0.18 |  98  98  98 | 105 105 105 | 7.0 |
| unlit.grey0.5 | 171 171 171 | 181 181 181 | 10.0 |
| unlit.grey1.0 | 235 235 235 | 240 240 240 | 5.0 |
| unlit.indigo |   0  21  65 |   0  22  68 | 1.3 |
| unlit.red | 241   0   0 | 253   0   0 | 4.0 |
| unlit.green |   0 238   0 |   0 245   0 | 2.3 |
| unlit.blue |   0   0 241 |   0   0 248 | 2.3 |
| unlit.cyan |   0 236 236 |   0 241 241 | 3.3 |
| unlit.magenta | 238   0 238 | 246   0 246 | 5.3 |
| unlit.yellow | 235 235   0 | 241 241   0 | 4.0 |
| emissive.grey0.18 | 100 100 100 | 107 107 107 | 7.0 |
| emissive.white1 | 235 235 235 | 240 240 240 | 5.0 |
| emissive.white4 | 240 240 240 | 240 240 240 | 0.0 |
| emissive.orange1 | 239 107  30 | 250 114  38 | 8.7 |
| emissive.orange4 | 248 214 107 | 246 223 113 | 5.7 |
| emissive.blue2 | 106 209 242 | 112 219 242 | 5.3 |
| lit.grey0.04 |  29  29  29 |  32  32  33 | 3.5 |
| lit.grey0.18 | 101 101 101 | 108 108 108 | 7.1 |
| lit.grey0.5 | 179 179 179 | 188 189 189 | 9.5 |
| lit.grey1.0 | 240 240 240 | 240 240 240 | 0.0 |
| lit.white.rough0.5 | 240 240 240 | 240 240 240 | 0.0 |
| lit.indigo |   3  24  66 |   6  28  70 | 3.6 |
| lit.red | 253   0   0 | 253   0   0 | 0.0 |
| lit.green |   0 245   0 |   0 245   0 | 0.0 |
| lit.blue |   0   0 248 |   0   0 248 | 0.0 |
| lit.cyan |   0 241 241 |   0 241 241 | 0.0 |
| lit.magenta | 246   0 246 | 246   0 246 | 0.0 |
| lit.yellow | 241 241   0 | 241 241   0 | 0.0 |
| sphere.dielectric | 182 183 183 | 192 193 193 | 10.0 |
| sphere.metal | 189 170 116 | 196 178 122 | 7.2 |
| sphere.glossy | 199  52  52 | 209  58  58 | 7.6 |
| point.centre | 240 240 240 | 240 240 240 | 0.0 |
| point.edge | 240 240 240 | 240 240 240 | 0.0 |
| spot.centre | 240 240 240 | 240 240 240 | 0.0 |
| spot.penumbra | 240 240 240 | 240 240 240 | 0.0 |
| spot.outside | 240 240 240 | 240 240 240 | 0.0 |
| ibl.card | 240 240 240 | 240 240 240 | 0.0 |
| shadow.lit | 178 178 178 | 187 188 188 | 9.3 |
| shadow.umbra | 123 124 124 | 131 132 132 | 8.0 |
| sky |   0   0   0 |   0   0   0 | 0.0 |

| Kind | Patches | Mean diff | Worst | Tolerance | |
|---|---|---|---|---|---|
| unlit | 12 | 4.3 | 10.0 (unlit.grey0.5) | 8 | over |
| emissive | 6 | 5.3 | 8.7 (emissive.orange1) | 8 | over |
| lit | 13 | 1.8 | 9.5 (lit.grey0.5) | 16 | ok |
| sphere | 3 | 8.2 | 10.0 (sphere.dielectric) | 16 | ok |
| light | 5 | 0.0 | 0.0 (spot.penumbra) | 16 | ok |
| shadow | 2 | 8.7 | 9.3 (shadow.lit) | 16 | ok |
| sky | 1 | 0.0 | 0.0 (sky) | 8 | ok |

