# Independently inspected source excerpts

Line numbers are one-based in the exact hashed local inputs. Vendor source is pinned v1.77.3; cached web line numbers may differ.

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNSkinner.h:23-81

```text
23: /*!
24:  @property skeleton
25:  @abstract Specifies the skeleton of the receiver.
26:  @discussion When setting a new skeleton, the new skeleton must have the same hierarchy of joints.
27:  */
28: @property(nonatomic, weak, nullable) SCNNode *skeleton;
29: 
30: /*!
31:  @method skinnerWithBaseGeometry:bones:boneInverseBindTransforms:boneWeights:boneIndices:
32:  @abstract Creates and initialize a skinner instance with the specified parameters.
33:  @param baseGeometry Specifies the base geometry used by the skinner
34:  @param bones Specifies the array of bones.
35:  @param boneInverseBindTransforms The inverse of the bone’s bind-space transformation matrix at the time the bind shape was bound to this bone.
36:  @param boneWeights A buffer of weights. This contains the weights of every influence of every vertex. The number of influence per vertex is controlled by the number of component in the geometry source.
37:  @param boneIndices A buffer of bone indexes. This buffer contains the corresponding index in the bones array for every weight in the weights buffer.
38:  */
39: + (instancetype)skinnerWithBaseGeometry:(nullable SCNGeometry *)baseGeometry bones:(NSArray<SCNNode *> *)bones boneInverseBindTransforms:(nullable NSArray<NSValue *> *)boneInverseBindTransforms boneWeights:(SCNGeometrySource *)boneWeights boneIndices:(SCNGeometrySource *)boneIndices API_AVAILABLE(macos(10.10));
40: 
41: /*!
42:  @property baseGeometry
43:  @abstract Specifies the base geometry of the receiver.
44:  @discussion Updating this will change the geometry of all the nodes sharing the skinner.
45:  Access the node's geometry if you want to update this specific skinner properties (materials for example).
46:  Access this property if you want a whole new geometry (which will necessarily be shared among the skinner instances), with
47:  different sources, for instance.
48:  */
49: @property(retain, nonatomic, nullable) SCNGeometry *baseGeometry API_AVAILABLE(macos(10.9));
50: 
51: /*!
52:  @property baseGeometryBindTransform
53:  @abstract Specifies the transform of the baseGeometry at the time when the mesh was bound to a skeleton. This transforms the baseGeometry from object space to a space on which the skinning then applies.
54:  */
55: @property(nonatomic) SCNMatrix4 baseGeometryBindTransform API_AVAILABLE(macos(10.10));
56: 
57: /*!
58:  @property boneInverseBindTransforms
59:  @abstract The inverse of the bone’s bind-space transformation matrix at the time the bind shape was bound to this bone.
60:  @discussion boneInverseBindTransforms is an array of SCNMatrix4 wrapped into instances of NSValue.
61:  */
62: @property(readonly, nonatomic, nullable) NSArray<NSValue *> *boneInverseBindTransforms API_AVAILABLE(macos(10.10));
63: 
64: /*!
65:  @property bones
66:  @abstract The bones of the skinner.
67:  */
68: @property(readonly, nonatomic) NSArray<SCNNode *> *bones API_AVAILABLE(macos(10.10));
69: 
70: /*!
71:  @property boneWeights
72:  @abstract The bone weights of the receiver.
73:  */
74: @property(readonly, nonatomic) SCNGeometrySource *boneWeights API_AVAILABLE(macos(10.10));
75: 
76: /*!
77:  @property boneIndices
78:  @abstract The bone indices of the receiver.
79:  */
80: @property(readonly, nonatomic) SCNGeometrySource *boneIndices API_AVAILABLE(macos(10.10));
81: 
```

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNParticleSystem.h:17-36

```text
17: typedef NSString * SCNParticleProperty NS_STRING_ENUM;
18: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyPosition API_AVAILABLE(macos(10.10));        // float3 : {x,y,z}     controller animation type : {NSValue(SCNVector3)}
19: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyAngle API_AVAILABLE(macos(10.10));           // float                controller animation type : {NSNumber}
20: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyRotationAxis API_AVAILABLE(macos(10.10));    // float3 : {x,y,z}     controller animation type : {NSValue(SCNVector3)}
21: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyVelocity API_AVAILABLE(macos(10.10));        // float3 : {x,y,z}     controller animation type : {NSValue(SCNVector3)}
22: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyAngularVelocity API_AVAILABLE(macos(10.10)); // float                controller animation type : {NSNumber}
23: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyLife API_AVAILABLE(macos(10.10));            // float                not controllable
24: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyColor API_AVAILABLE(macos(10.10));           // float4 : {r,g,b,a}   controller animation type : {UIColor}
25: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyOpacity API_AVAILABLE(macos(10.10));         // float                controller animation type : {NSNumber}
26: SCN_EXPORT SCNParticleProperty const SCNParticlePropertySize API_AVAILABLE(macos(10.10));            // float                controller animation type : {NSNumber}
27: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyFrame API_AVAILABLE(macos(10.10));           // float                controller animation type : {NSNumber}
28: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyFrameRate API_AVAILABLE(macos(10.10));       // float                controller animation type : {NSNumber}
29: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyBounce API_AVAILABLE(macos(10.10));          // float                controller animation type : {NSNumber}
30: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyCharge API_AVAILABLE(macos(10.10));          // float                controller animation type : {NSNumber}
31: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyFriction API_AVAILABLE(macos(10.10));        // float                controller animation type : {NSNumber}
32: 
33: // These two properties are only available when handling the events of type SCNParticleEventCollision.
34: // They are read-only values.
35: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyContactPoint API_AVAILABLE(macos(10.10));    // float3               not controllable
36: SCN_EXPORT SCNParticleProperty const SCNParticlePropertyContactNormal API_AVAILABLE(macos(10.10));   // float3               not controllable
```

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNParticleSystem.h:61-82

```text
61: /*!
62:  @typedef SCNParticleModifierBlock
63:  @param data array of particle properties data stripes, ordered by the given NSArray of properties name in [- handleEvent:forProperties:withBlock:]
64:  @param dataStride array of particle properties data stripes stride, with the same ordering than data.
65:  @param start index of the first particle
66:  @param end index of the last particle
67:  @param deltaTime duration of the simulation step, in seconds.
68:  @discussion This is a small example of usage of a modifier block:
69:  [self.particleSystem addModifierForProperties:@[SCNParticlePropertyPosition, SCNParticlePropertyVelocity] atStage:SCNParticleModifierStagePreCollision withBlock:^(void **data, size_t *dataStride, NSInteger start, NSInteger end, float deltaTime) {
70:      for (NSInteger i = start; i < end; ++i) {
71:         // SCNParticlePropertyPosition (float3)
72:         float *pos = (float *)((char *)data[0] + dataStride[0] * i);
73:         // SCNParticlePropertyVelocity (float3)
74:         float *vel = (float *)((char *)data[1] + dataStride[1] * i);
75:         
76:          // change velocity and/or position
77:          // ...
78:      }
79:  }];
80: */
81: typedef void (^SCNParticleModifierBlock)(void * _Nonnull * _Nonnull data, size_t * _Nonnull dataStride, NSInteger start, NSInteger end, float deltaTime);
82: 
```

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNParticleSystem.h:197-203

```text
197: #pragma mark Emitter properties
198: 
199: // Specifies the duration of the emission. Defaults to 1. Animatable.
200: @property(nonatomic) CGFloat emissionDuration;
201: 
202: // Specifies the variation of the emission duration. Defaults to 0. Animatable.
203: @property(nonatomic) CGFloat emissionDurationVariation;
```

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNParticleSystem.h:310-377

```text
310: // Specifies the texture animation frame rate variation, in frames per second. Defaults to 0. Animatable.
311: @property(nonatomic) CGFloat imageSequenceFrameRateVariation;
312: 
313: // Specifies the texture animation mode. Defaults to SCNTextureAnimationModeRepeat.
314: @property(nonatomic) SCNParticleImageSequenceAnimationMode imageSequenceAnimationMode;
315: 
316: // Specifies the initial color of the particle. Animatable. Defaults to opaque white.
317: @property(nonatomic, retain) UIColor *particleColor;
318: 
319: // Specifies the normalized variation of the color.
320: // With x : hue variation, y : saturation variation, z : brightness variation, w : alpha variation. Animatable.
321: @property(nonatomic) SCNVector4 particleColorVariation;
322: 
323: // Specifies the initial size of the particle. Animatable.
324: @property(nonatomic) CGFloat particleSize;
325: 
326: // Specifies the initial size variation of the particle. Animatable.
327: @property(nonatomic) CGFloat particleSizeVariation;
328: 
329: // Specifies the initial intensity of the particle. Animatable.
330: @property(nonatomic) CGFloat particleIntensity API_AVAILABLE(macos(10.13), ios(11.0), tvos(11.0), watchos(4.0));
331: 
332: // Specifies the initial intensity variation of the particle. Animatable.
333: @property(nonatomic) CGFloat particleIntensityVariation API_AVAILABLE(macos(10.13), ios(11.0), tvos(11.0), watchos(4.0));
334: 
335: // Specifies the blend mode to use to render the particle system. Defaults to SCNParticleBlendModeAdditive.
336: @property(nonatomic) SCNParticleBlendMode blendMode;
337: 
338: // Specifies whether a black pass is required or not when rendering the particle system.
339: // This reinforces the contrast of additive/light systems. Defaults to NO.
340: @property(nonatomic, getter=isBlackPassEnabled) BOOL blackPassEnabled;
341: 
342: // Specifies the orientation mode of the particles. Defaults to SCNParticleOrientationModeBillboardScreenAligned.
343: @property(nonatomic) SCNParticleOrientationMode orientationMode;
344: 
345: // Specifies the sorting mode of the particles. Defaults to SCNParticleSortingModeNone.
346: @property(nonatomic) SCNParticleSortingMode sortingMode;
347: 
348: // Enables the lighting of particle systems
349: @property(nonatomic, getter=isLightingEnabled) BOOL lightingEnabled;
350: 
351: #pragma mark Particle Simulation
352: 
353: // Enables the use of the gravity defined in SCNPhysicsWorld
354: @property(nonatomic) BOOL affectedByGravity;
355: 
356: // Enables the effect of the physics fields added to the SCNPhysicsWorld
357: @property(nonatomic) BOOL affectedByPhysicsFields;
358: 
359: // Specifies whether particles die on collision
360: @property(nonatomic) BOOL particleDiesOnCollision;
361: 
362: // Specifies an array of SCNNode to collide with.
363: @property(nonatomic, copy, nullable) NSArray<SCNNode *> *colliderNodes;
364: 
365: // Specifies the particle mass. Animatable.
366: @property(nonatomic) CGFloat particleMass;
367: 
368: // Specifies the particle mass variation. Animatable.
369: @property(nonatomic) CGFloat particleMassVariation;
370: 
371: // Specifies the particle bounce. Animatable.
372: @property(nonatomic) CGFloat particleBounce;
373: 
374: // Specifies the particle bounce variation. Animatable.
375: @property(nonatomic) CGFloat particleBounceVariation;
376: 
377: // Specifies the particle friction. Animatable.
```

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNParticleSystem.h:406-423

```text
406:  @abstract Determines whether the receiver writes to the depth buffer when rendered. Defaults to NO.
407:  */
408: @property(nonatomic) BOOL writesToDepthBuffer API_AVAILABLE(macos(12.0), ios(15.0), tvos(15.0), watchos(8.0));
409: 
410: // Property controllers.
411: @property(nonatomic, copy, nullable) NSDictionary<SCNParticleProperty, SCNParticlePropertyController *> *propertyControllers;
412: 
413: // Remove all the already-emitted particles and restart the simulation.
414: - (void)reset;
415: 
416: // Events handling
417: // "block" will be invoked for particles that trigger the specified event, with the data and dataStride that corresponds to "properties". The block should only update the particle properties reference by the "indices" passed as argument in the block.
418: - (void)handleEvent:(SCNParticleEvent)event forProperties:(NSArray<SCNParticleProperty> *)properties withBlock:(SCNParticleEventBlock)block;
419: 
420: // Modifications handling
421: // "block" will be invoked at every simulation step at the specified stage. The data and dataStride passed to the block will corresponds to the specified "properties".
422: - (void)addModifierForProperties:(NSArray<SCNParticleProperty> *)properties atStage:(SCNParticleModifierStage)stage withBlock:(SCNParticleModifierBlock)block;
423: - (void)removeModifiersOfStage:(SCNParticleModifierStage)stage;
```

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNShadable.h:65-89

```text
65: 
66: /*!
67:  @property program
68:  @abstract Specifies a custom program used to render the receiver.
69:  @discussion When a program is set, it overrides all the rendering parameters such as material settings and shaderModifiers.
70:  */
71: @property(nonatomic, retain, nullable) SCNProgram *program API_UNAVAILABLE(watchos);
72: 
73: /*!
74:  @method handleBindingOfSymbol:usingBlock:
75:  @abstract Sets the block to call at render time to bind the value for the specified symbol of the receiver's SCNProgram. This method has no effect for symbols declared in shader modifiers.
76:  @param symbol The name of the symbol to bind a value for.
77:  @param block The block to call to bind the specified symbol.
78:  @discussion This method can only be used with OpenGL and OpenGLES based programs.
79:  */
80: - (void)handleBindingOfSymbol:(NSString *)symbol usingBlock:(nullable SCNBindingBlock)block API_AVAILABLE(macos(10.9)) API_UNAVAILABLE(watchos);
81: 
82: /*!
83:  @method handleUnbindingOfSymbol:usingBlock:
84:  @abstract Sets the block to call at render time to unbind the value for the specified symbol of the receiver's SCNProgram. This method has no effect for symbols declared in shader modifiers.
85:  @param symbol The name of the symbol to unbind.
86:  @param block The block to call to unbind the specified symbol.
87:  @discussion This method can only be used with OpenGL and OpenGLES based programs.
88:  */
89: - (void)handleUnbindingOfSymbol:(NSString *)symbol usingBlock:(nullable SCNBindingBlock)block API_AVAILABLE(macos(10.9)) API_UNAVAILABLE(watchos);
```

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNTechnique.h:26-47

```text
26:  The passes are executed sequentially as specified in the "sequence" section. The definition of each pass is within the "passes" section. A pass may have inputs/outputs that reference targets or symbols defined in the "targets" and "symbols" section. The entries of the "symbols" section can be set/get and animated with SCNTechnique's APIs below.
27:  
28:  {
29:    sequence: ["Pass1", "Pass2", ...],
30:    passes: {
31:      "Pass1": {
32:         outputs: <outputs>
33:         inputs: <inputs>
34:         draw: <draw command>
35:         program: <program name>
36:         metalVertexShader: <METAL vertex shader function name>
37:         metalFragmentShader: <METAL fragment shader function name>
38:         colorStates: <color states>               //optional
39:         depthStates: <depth states>               //optional
40:         stencilStates: <stencil states>           //optional
41:         cullMode: <cull mode>                     //optional
42:         blendStates: <blend states>               //optional
43:         viewport: <custom viewport>               //optional
44:         pointOfView: <node name>                  //optional
45:         samples: <sample count>                   //optional
46:         excludeCategoryMask: <category bitMask>   //optional
47:         includeCategoryMask: <category bitMask>   //optional
```

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNTechnique.h:108-109

```text
108: <program name>
109:  Name of a program (a vertex shader + a fragment shader) located in the application bundle.
```

## /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers/SCNTechnique.h:174-180

```text
174:  A string specifying the viewport as 4 float.
175: 
176: <category bitMask>
177:  A integer value representing a node category mask (see SCNNode's categoryBitMask).
178:  if the key "excludeCategoryMask" is not specified then it defaults to 0.
179:  if the key "includeCategoryMask" is not specified then it defaults to all bits set.
180:  The DRAW_SCENE command will then render nodes that validate the following test (node.categoryBitMask & includeCategoryMask) && !(excludeCategoryMask & node.categoryBitMask).
```

## /Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe/dart3d/ios/Classes/FsceneRealizer.swift:6116-6120

```text
6116:                     + "geometries or material — skipped")
6117:                 return
6118:             }
6119:             let sys = SCNParticleSystem()
6120:             sys.isLocal = true  // upstream simulates in node space
```

## /Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe/dart3d/ios/Classes/FsceneRealizer.swift:6267-6305

```text
6267:             if let texKey = d3Ref(props["texture"]),
6268:                let tex = textures[texKey]?.contents {
6269:                 sys.particleImage = tex
6270:             }
6271:             // Clamped before any product: two huge-but-valid Int dims
6272:             // overflow `cols * rows` and trap. 4096 per axis is far past
6273:             // any usable atlas (a cell must still be ≥ 1 texel).
6274:             let flipCols = min(max(d3Int(props["flipbookColumns"]) ?? 1, 1),
6275:                                Self.maxFlipbookAxis)
6276:             let flipRows = min(max(d3Int(props["flipbookRows"]) ?? 1, 1),
6277:                                Self.maxFlipbookAxis)
6278:             if flipCols > 1 || flipRows > 1 {
6279:                 sys.imageSequenceColumnCount = flipCols
6280:                 sys.imageSequenceRowCount = flipRows
6281:             }
6282: 
6283:             // Mesh emitters degrade to an untextured sprite pass on
6284:             // iOS (SCNParticleSystem is sprite-only) tinted by the
6285:             // material's AUTHORED baseColor factor — read from the
6286:             // material def, since `diffuse.contents` holds the image
6287:             // once a base-color texture binds. Per-particle color is
6288:             // inert on mesh emitters (upstream parity): startColor
6289:             // and colorOverLife don't apply.
6290:             if mesh {
6291:                 if let matKey = d3Ref(props["material"]) {
6292:                     let mp = resourceDefs[matKey]?["properties"]
6293:                         as? [String: Any]
6294:                     if let c = d3Color(mp?["baseColor"]) {
6295:                         sys.particleColor = c
6296:                     } else if let c = materials[matKey]?.diffuse.contents
6297:                                 as? UIColor {
6298:                         sys.particleColor = c
6299:                     }
6300:                 }
6301:                 host.logOnce("\(logKey).meshDegrade",
6302:                     "meshParticleEmitter on node \(key): realized as a "
6303:                     + "sprite pass (SCNParticleSystem is sprite-only)")
6304:             } else {
6305:                 // startColor samples ONCE at spawn — a gradient
```

## /Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe/dart3d/ios/Classes/FsceneRealizer.swift:6367-6377

```text
6367:                 || props["maxFrameTime"] != nil
6368:                 || props["maxParticles"] != nil {
6369:                 host.logOnce("\(logKey).simKnobs",
6370:                     "particleEmitter on node \(key): seed/fixedStep/"
6371:                     + "maxFrameTime/maxParticles have no SceneKit "
6372:                     + "counterpart — the render clock drives the sim")
6373:             }
6374: 
6375:             node.addParticleSystem(sys)
6376:             scheduleParticleBursts(sys, node: node, props: props,
6377:                                    looping: looping, duration: duration,
```

## /Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe/dart3d/ios/Classes/FsceneRealizer.swift:6785-6821

```text
6785:             let skinner = SCNSkinner(
6786:                 baseGeometry: geo,
6787:                 bones: bones,
6788:                 boneInverseBindTransforms: skin.ibms.map {
6789:                     NSValue(scnMatrix4: $0)
6790:                 },
6791:                 boneWeights: weightSource,
6792:                 boneIndices: indexSource)
6793:             skinner.skeleton = skeleton
6794:             // A replaced skinner goes to the graveyard — the in-flight
6795:             // pass's frozen storage can still reference it.
6796:             if let old = node.skinner { host.retire(old) }
6797:             node.skinner = skinner
6798:             // Extra primitives ride `d3prim:` children — each needs a
6799:             // skinner over the same bones/IBMs/skeleton, sourced from
6800:             // its own geometry's bone streams. A prim without bone
6801:             // sources stays rigid (upstream skins what it can).
6802:             for child in node.childNodes
6803:             where child.name?.hasPrefix("d3prim:") == true {
6804:                 if let old = child.skinner { host.retire(old) }
6805:                 child.skinner = nil
6806:                 guard let cg = child.geometry,
6807:                       let cw = cg.sources.first(where: {
6808:                           $0.semantic == .boneWeights }),
6809:                       let ci = cg.sources.first(where: {
6810:                           $0.semantic == .boneIndices })
6811:                 else { continue }
6812:                 let cs = SCNSkinner(
6813:                     baseGeometry: cg,
6814:                     bones: bones,
6815:                     boneInverseBindTransforms: skin.ibms.map {
6816:                         NSValue(scnMatrix4: $0)
6817:                     },
6818:                     boneWeights: cw,
6819:                     boneIndices: ci)
6820:                 cs.skeleton = skeleton
6821:                 child.skinner = cs
```

## /Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe/dart3d/ios/Classes/RenderTargets.swift:558-628

```text
558:     /// Per-frame sibling point-of-view capture — runs in
559:     /// `didApplyConstraintsAtTime` (same hook the offscreen
560:     /// scheduler uses). Index 0's pov is the real node — its mask
561:     /// write lands on the real camera here, inside the host scene's
562:     /// own callback (the same write `applyScreenViewCamera` does).
563:     /// Proxy siblings are NOT touched here: their pose (the camera
564:     /// node's presentation transform) and a camera COPY carrying the
565:     /// view's `layerMask` are snapshotted for the main-thread poke,
566:     /// which applies them right before `setNeedsDisplay` — writing the
567:     /// detached proxies on this queue raced the siblings' own draws
568:     /// (a torn pose: new transform, old camera, or half a matrix).
569:     /// A camera that stops resolving keeps its sibling's last pose.
570:     /// The leading sibling rebinds when its camera node was replaced
571:     /// under the same id (a remove + re-add left the sibling on the
572:     /// detached old node) or first becomes resolvable.
573:     func syncScreenSubviews() {
574:         var poses: [Int: (SCNMatrix4, SCNCamera)] = [:]
575:         for (i, s) in screenSubviews.enumerated() {
576:             guard let camNode = nodesById[s.rec.cameraKey],
577:                   let cam = camNode.camera else { continue }
578:             let mask = s.rec.layerMask == UInt32.max
579:                 ? Int(bitPattern: UInt.max) : Int(s.rec.layerMask)
580:             if i == 0 && (!s.drivesRealNode || camNode !== s.pov) {
581:                 logOnce("w24.rebind.\(s.rec.cameraKey)",
582:                     "split view camera \(s.rec.cameraKey) (re)bound; "
583:                     + "rebuilding sibling views")
584:                 updateScreenSubviews()
585:                 return
586:             }
587:             if s.drivesRealNode {
588:                 cam.categoryBitMask = mask
589:                 continue
590:             }
591:             if let copy = cam.copy() as? SCNCamera {
592:                 copy.categoryBitMask = mask
593:                 poses[i] = (camNode.presentation.worldTransform, copy)
594:             }
595:         }
596:         siblingPoseLock.lock()
597:         siblingPoseSnapshot = poses.isEmpty
598:             ? nil : (gen: screenSubviewBuild, poses: poses)
599:         siblingPoseLock.unlock()
600:     }
601: 
602:     /// Pokes every sibling for a redraw — called from
603:     /// `didRenderScene`. The list lives on main; the hop is once per
604:     /// host frame and the draws land on the next display commit. The
605:     /// frame's pose snapshot applies first, in one transaction, so
606:     /// the requested draw sees one consistent pose.
607:     func pokeScreenSubviews() {
608:         guard multiScreenMode else { return }
609:         DispatchQueue.main.async { [weak self] in
610:             guard let self else { return }
611:             self.siblingPoseLock.lock()
612:             let snap = self.siblingPoseSnapshot
613:             self.siblingPoseSnapshot = nil
614:             self.siblingPoseLock.unlock()
615:             if let snap, snap.gen == self.mainScreenSubviewGen {
616:                 SCNTransaction.begin()
617:                 SCNTransaction.disableActions = true
618:                 for (i, pose) in snap.poses
619:                 where i < self.mainScreenSubviewPovs.count {
620:                     let pov = self.mainScreenSubviewPovs[i]
621:                     pov.transform = pose.0
622:                     pov.camera = pose.1
623:                 }
624:                 SCNTransaction.commit()
625:             }
626:             for s in self.mainScreenSubviews {
627:                 s.view.setNeedsDisplay()
628:             }
```

## /Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe/dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/Dart3dView.kt:1254-1262

```text
1254: 
1255:     private fun applyClearColor() {
1256:         val opts = Renderer.ClearOptions()
1257:         opts.clearColor = doubleArrayOf(
1258:             clearColor[0].toDouble(), clearColor[1].toDouble(),
1259:             clearColor[2].toDouble(), clearColor[3].toDouble())
1260:         opts.clear = true
1261:         renderer.clearOptions = opts
1262:     }
```

## /Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe/dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/Dart3dView.kt:3506-3555

```text
3506:     private fun applyViews(recs: List<RenderTargets.ViewRec>) {
3507:         // The shared screen view must never hold a dying camera.
3508:         view.camera = camera
3509:         for (rec in viewRecs) destroyViewObjects(rec)
3510:         viewRecs.clear()
3511:         screenViews.clear()
3512:         for ((_, rt) in renderTargets) rt.views.clear()
3513:         for (rec in recs.sortedBy { it.order }) {
3514:             val camEntity = EntityManager.get().create()
3515:             val cam = engine.createCamera(camEntity)
3516:             rec.cameraEntity = camEntity
3517:             rec.camera = cam
3518:             // decodeStage may have run before these cameras existed
3519:             // (initial load / re-realize) — carry the stage exposure.
3520:             // An offscreen view renders at exposure 1, never at
3521:             // Filament's photographic default.
3522:             setCameraExposure(cam,
3523:                 if (rec.targetKey == null) lastEffExposure else 1.0f)
3524:             val tk = rec.targetKey
3525:             if (tk != null) {
3526:                 val rtRec = renderTargets[tk]
3527:                 if (rtRec == null) {
3528:                     // Resolved at decode; an rt that died between
3529:                     // decode and apply drops the entry like an
3530:                     // unresolved ref.
3531:                     destroyViewObjects(rec)
3532:                     continue
3533:                 }
3534:                 val v = engine.createView()
3535:                 v.scene = scene
3536:                 v.camera = cam
3537:                 // Post-processing on a user RenderTarget routes through
3538:                 // an intermediate blit — offscreen passes keep the raw
3539:                 // draw so the color attachment is the literal frame.
3540:                 v.isPostProcessingEnabled = false
3541:                 v.setShadowType(shadowType())
3542:                 v.setShadowingEnabled(viewQuality != "low")
3543:                 v.setRenderTarget(rtRec.rt)
3544:                 v.viewport = rec.viewport?.let { viewportOf(it) }
3545:                     ?: Viewport(0, 0, rtRec.spec.width,
3546:                         rtRec.spec.height)
3547:                 v.setVisibleLayers(0xFF, rec.layerMask and 0xFF)
3548:                 rec.view = v
3549:                 rtRec.views.add(rec)
3550:             } else {
3551:                 // Screen entry — an extra swapchain pass on `view`,
3552:                 // rendered in `order` after the default pass is
3553:                 // skipped (entries ARE the screen view list).
3554:                 screenViews.add(rec)
3555:             }
```

## /Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe/dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/Dart3dView.kt:5835-5884

```text
5835:     private fun render(tNanos: Long): Boolean {
5836:         // No surface, no frame: UiHelper clears readiness in
5837:         // onDetachedFromSurface, before Android destroys the window.
5838:         if (!uiHelper.isReadyToRender) return false
5839:         val sc = swapChain ?: return false
5840:         bakedShadowCatchers.renderDirty(
5841:             renderer, FsceneRealizer.surgicalContext(this))
5842:         if (renderer.beginFrame(sc, tNanos)) {
5843:             // W14: due offscreen passes first — a material sampling an
5844:             // rt reads this frame's output in the screen passes below.
5845:             // An rt's views render in `order` (sorted at apply).
5846:             for ((_, rec) in renderTargets) {
5847:                 if (rec.views.isEmpty() ||
5848:                     !RenderTargets.due(rec, tNanos)) continue
5849:                 for (v in rec.views) {
5850:                     v.view?.let {
5851:                         renderer.render(it)
5852:                         logCommandOnce("w14.rtpass.${rec.spec.width}",
5853:                             "rt pass rendered ${rec.spec.width}x" +
5854:                                 "${rec.spec.height}")
5855:                     }
5856:                 }
5857:                 rec.lastRenderNanos = tNanos
5858:                 rec.dirty = false
5859:             }
5860:             // Screen passes share `view`: each entry's camera,
5861:             // viewport (Filament's origin is bottom-left), layer mask,
5862:             // and resolved AA/renderScale push per pass. The stage
5863:             // look/effects stay written on `view` so every screen pass
5864:             // gets the same post stack. No screen entries → `view`
5865:             // renders the default pass — the pre-W14 path.
5866:             if (screenViews.isEmpty()) {
5867:                 renderer.render(view)
5868:             } else {
5869:                 for (rec in screenViews) {
5870:                     val cam = rec.camera ?: continue
5871:                     view.camera = cam
5872:                     view.viewport = rec.viewport?.let { viewportOf(it) }
5873:                         ?: Viewport(0, 0, viewportW, viewportH)
5874:                     view.setVisibleLayers(0xFF, rec.layerMask and 0xFF)
5875:                     view.multiSampleAntiAliasingOptions = rec.msaa
5876:                     view.antiAliasing = rec.aa
5877:                     view.dynamicResolutionOptions = rec.dsr
5878:                     renderer.render(view)
5879:                 }
5880:             }
5881:             renderer.endFrame()
5882:             if (!firstSceneFrameDone && nodesById.isNotEmpty()) {
5883:                 firstSceneFrameDone = true
5884:                 ColdStart.mark("first frame submitted")
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/Renderer.cpp:510-528

```text
510: 
511:         // ask the engine to do what it needs to (e.g. updates light buffer, materials...)
512:         engine.prepare(driver);
513:     };
514: 
515:     // mPresentationTime is only ever set when the backend supports it, so we can't be in paced
516:     // mode on a backend or platform that ignores the presentation time.
517:     bool const isPacedMode = mPresentationTime.time_since_epoch().count() != 0;
518:     if (isPacedMode || shouldRenderFrame()) {
519:         // if beginFrame() returns true, we are expecting a call to endFrame(),
520:         // so do the beginFrame work right now, instead of requiring a call to render()
521:         beginFrameInternal();
522:         return true;
523:     }
524: 
525:     // however, if we return false, the user is allowed to ignore us and render a frame anyway,
526:     // so we need to delay this work until that happens.
527:     mBeginFrameInternal = beginFrameInternal;
528: 
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/Renderer.cpp:671-757

```text
671: void FRenderer::renderStandaloneView(FView const* view) {
672:     FILAMENT_TRACING_CALL(FILAMENT_TRACING_CATEGORY_FILAMENT);
673: 
674:     using namespace std::chrono;
675: 
676:     FILAMENT_CHECK_PRECONDITION(view->getRenderTarget())
677:             << "View \"" << view->getName() << "\" must have a RenderTarget associated";
678: 
679:     FILAMENT_CHECK_PRECONDITION(!mSwapChain)
680:             << "renderStandaloneView() must be called outside of beginFrame() / endFrame()";
681: 
682:     if (UTILS_LIKELY(view->getScene())) {
683:         mPreviousRenderTargets.clear();
684: 
685:         // ask the engine to do what it needs to (e.g. updates light buffer, materials...)
686:         FEngine& engine = mEngine;
687:         FEngine::DriverApi& driver = engine.getDriverApi();
688: 
689:         engine.prepare(driver);
690: 
691:         driver.beginFrame(
692:                 steady_clock::now().time_since_epoch().count(),
693:                 mDisplayInfo.refreshRate == 0.0 ? 0 : int64_t(
694:                         1'000'000'000.0 / mDisplayInfo.refreshRate), 0);
695: 
696:         // because we don't have a "present" call, we use flush so the driver can submit
697:         // the command buffer; we do this before driver.endFrame() to mimic what would
698:         // happen with Renderer::beginFrame/endFrame.
699:         renderInternal(driver, view, true);
700: 
701:         engine.submitFrame();
702: 
703:         driver.endFrame(0);
704: 
705:         // engine.flush() has already been called by renderInternal(), but we need an extra one
706:         // for endFrame() above. This operation in actually not too heavy, it just kicks the
707:         // driver thread, which is most likely already running.
708:         engine.flush();
709:     }
710: }
711: 
712: void FRenderer::render(FView const* view) {
713:     FILAMENT_TRACING_CALL(FILAMENT_TRACING_CATEGORY_FILAMENT);
714: 
715:     mEngine.propagateBackendException();
716: 
717:     if (UTILS_UNLIKELY(mBeginFrameInternal)) {
718:         // This is unlikely to happen, the user should not call render() if we returned false from
719:         // beginFrame(). But because this is allowed, we handle it gracefully.
720:         mBeginFrameInternal();
721:         mBeginFrameInternal = {};
722:     }
723: 
724:     // after beginFrame() is called, mSwapChain should be true
725:     assert_invariant(mSwapChain);
726: 
727:     if (UTILS_LIKELY(view && view->getScene() && view->hasCamera())) {
728:         renderInternal(mEngine.getDriverApi(), view, false);
729:     }
730: }
731: 
732: void FRenderer::renderInternal(DriverApi& driver, FView const* view, bool const flush) {
733:     FEngine& engine = mEngine;
734: 
735:     FILAMENT_CHECK_PRECONDITION(!view->hasPostProcessPass() ||
736:             engine.hasFeatureLevel(FeatureLevel::FEATURE_LEVEL_1))
737:                     << "post-processing is not supported at FEATURE_LEVEL_0";
738: 
739:     // per-renderpass data
740:     auto& arena = engine.getPerRenderPassArena();
741:     ArenaScope const scope(arena);
742: 
743:     // create a root job so no other job can escape
744:     JobSystem& js = engine.getJobSystem();
745:     auto *rootJob = js.setRootJob(js.createJob());
746: 
747:     // execute the render pass
748:     renderJob(driver, arena, const_cast<FView&>(*view));
749: 
750:     if (flush) {
751:         driver.flush();
752:     }
753: 
754:     // make sure to flush the command buffer
755:     engine.flush();
756: 
757:     // and wait for all jobs to finish as a safety (this should be a no-op)
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/Renderer.cpp:1067-1118

```text
1067:     // When we don't have a custom RenderTarget, customRenderTarget below is nullptr and is
1068:     // recorded in the list of targets already rendered into -- this ensures that
1069:     // initializeClearFlags() is called only once for the default RenderTarget.
1070:     auto& previousRenderTargets = mPreviousRenderTargets;
1071:     FRenderTarget* const customRenderTarget = downcast(view.getRenderTarget());
1072:     if (UTILS_LIKELY(
1073:             previousRenderTargets.find(customRenderTarget) == previousRenderTargets.end())) {
1074:         previousRenderTargets.insert(customRenderTarget);
1075:         initializeClearFlags();
1076:     }
1077: 
1078:     // Note:  it is not well-defined what colorspace this clearColor is defined into. This leads
1079:     //        to inconsistent colors depending on enabled features. When the clear is performed
1080:     //        into a temporary buffer (common case), the clearColor is color-graded. A problem
1081:     //        arises when transparent views are used, in this case the clear color is not
1082:     //        color-graded.
1083:     const ClearColorValue clearColor = mClearOptions.clearColor;
1084: 
1085:     const uint8_t clearStencil = mClearOptions.clearStencil;
1086:     const TargetBufferFlags clearFlags = mClearFlags;
1087:     const TargetBufferFlags discardStartFlags = mDiscardStartFlags;
1088:     const TargetBufferFlags keepOverrideStartFlags = TargetBufferFlags::ALL & ~discardStartFlags;
1089:     TargetBufferFlags keepOverrideEndFlags = TargetBufferFlags::NONE;
1090: 
1091:     if (customRenderTarget) {
1092:         // For custom RenderTarget, we look at each attachment flag and if they have their
1093:         // SAMPLEABLE usage bit set, we assume they must not be discarded after the render pass.
1094:         keepOverrideEndFlags |= customRenderTarget->getSampleableAttachmentsMask();
1095:     }
1096: 
1097:     // Renderer's ClearOptions apply once at the beginning of the frame (not for each View),
1098:     // however, it's implemented as part of executing a render pass on the current render target,
1099:     // and that happens for each View. So we need to disable clearing after the 1st View has
1100:     // been processed.
1101:     mDiscardStartFlags &= ~TargetBufferFlags::COLOR;
1102:     mClearFlags &= ~TargetBufferFlags::COLOR;
1103: 
1104:     // the clearFlags and clearColor set below are "sticky" to the imported target, meaning
1105:     // they will apply anytime we render into this target, THIS INCLUDES when this target
1106:     // is "replacing" another one. E.g. typically when the color pass ends-up drawing directly
1107:     // here.
1108:     auto [viewRenderTarget, attachmentMask] = getRenderTarget(view);
1109:     FrameGraphId<FrameGraphTexture> const fgViewRenderTarget = fg.import("viewRenderTarget", {
1110:             .attachments = attachmentMask,
1111:             .viewport = DEBUG_DYNAMIC_SCALING ? svp : vp,
1112:             .clearColor = clearColor,
1113:             .samples = 0,
1114:             .clearFlags = clearFlags,
1115:             .keepOverrideStart = keepOverrideStartFlags,
1116:             .keepOverrideEnd = keepOverrideEndFlags
1117:     }, viewRenderTarget);
1118: 
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/Engine.cpp:759-799

```text
759: void FEngine::prepare(DriverApi& driver) {
760:     FILAMENT_TRACING_CALL(FILAMENT_TRACING_CATEGORY_FILAMENT);
761:     // prepare() is called once per Renderer frame. Ideally we would upload the content of
762:     // UBOs that are visible only. It's not such a big issue because the actual upload() is
763:     // skipped if the UBO hasn't changed. Still we could have a lot of these.
764:     const bool useUboBatching = isUboBatchingEnabled();
765: 
766:     if (useUboBatching) {
767:         assert_invariant(mUboManager != nullptr);
768:         mUboManager->beginFrame(driver);
769:     }
770: 
771:     UboManager* uboManager = mUboManager;
772:     size_t const capacity = getMinCommandBufferSize();
773:     for (auto& materialInstanceList: mMaterialInstances) {
774:         materialInstanceList.second.forEach(
775:                 [this, &driver, uboManager, capacity](FMaterialInstance const* item) {
776:                     // post-process materials instances must be commited explicitly because their
777:                     // parameters are typically not set at this point in time.
778:                     if (item->getMaterial()->getMaterialDomain() == MaterialDomain::SURFACE) {
779:                         // If the remaining space is less than half the capacity, we flush right
780:                         // away to allow some headroom for commands that might come later.
781:                         if (UTILS_UNLIKELY(driver.getCircularBuffer().getUsed() > capacity / 2)) {
782:                             flush();
783:                         }
784:                         item->commit(driver, uboManager);
785:                     }
786:                 });
787:     }
788: 
789:     if (useUboBatching) {
790:         assert_invariant(mUboManager != nullptr);
791:         getUboManager()->finishBeginFrame(driver);
792:     }
793: 
794:     mMaterials.forEach([](FMaterial* material) {
795: #if FILAMENT_ENABLE_MATDBG // NOLINT(*-include-cleaner)
796:         material->checkProgramEdits();
797: #endif
798:     });
799: }
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/MaterialInstance.cpp:215-273

```text
215:     if (mPrograms.isInitialized()) {
216:         mPrograms.terminate(engine);
217:     }
218: }
219: 
220: void FMaterialInstance::commit(FEngine& engine) const {
221:     if (UTILS_LIKELY(mMaterial->getMaterialDomain() != MaterialDomain::SURFACE)) {
222:         commit(engine.getDriverApi(), engine.getUboManager());
223:     }
224: }
225: 
226: void FMaterialInstance::commit(FEngine::DriverApi& driver, UboManager* uboManager) const {
227:     if (!mTextureParameters.empty()) {
228:         FEngine const& engine = mMaterial->getEngine();
229:         // First pass: check preconditions
230:         for (auto const& [binding, p]: mTextureParameters) {
231:             assert_invariant(p.texture);
232:             FILAMENT_CHECK_PRECONDITION(engine.isValid(p.texture))
233:                     << "Invalid texture still bound to MaterialInstance: '" << getName() << "'\n";
234:         }
235:         // Second pass: update state
236:         for (auto const& [binding, p]: mTextureParameters) {
237:             Handle<HwTexture> const handle = p.texture->getHwHandleForSampling();
238:             assert_invariant(handle);
239:             mDescriptorSet.setSampler(mMaterial->getDescriptorSetLayout(),
240:                 binding, handle, p.params);
241:         }
242:     }
243: 
244: 
245:     if (mUniforms.isDirty()) {
246:         mUniforms.clean();
247:         if (isUsingUboBatching()) {
248:             if (!BufferAllocator::isValid(getAllocationId())) {
249:                 // The allocation hasn't happened yet, return.
250:                 return;
251:             }
252: 
253:             uboManager->updateSlot(driver, getAllocationId(), mUniforms.toBufferDescriptor(driver));
254:         }
255:         else {
256:             auto* ubHandle = std::get_if<Handle<HwBufferObject>>(&mUboData);
257:             assert_invariant(ubHandle != nullptr);
258:             driver.updateBufferObject(*ubHandle, mUniforms.toBufferDescriptor(driver), 0);
259:         }
260:     }
261: 
262:     // TODO: eventually we should remove this in RELEASE builds
263:     fixMissingSamplers();
264: 
265:     if (isUsingUboBatching() && !BufferAllocator::isValid(getAllocationId())) {
266:         return;
267:     }
268: 
269:     // Commit descriptors if needed (e.g. when textures are updated,or the first time)
270:     mDescriptorSet.commit(mMaterial->getDescriptorSetLayout(), driver);
271: }
272: 
273: // ------------------------------------------------------------------------------------------------
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/RenderableManager.cpp:866-900

```text
866: void FRenderableManager::setMaterialInstanceAt(Instance const instance, uint8_t const level,
867:         size_t const primitiveIndex, FMaterialInstance const* mi) {
868:     assert_invariant(mi);
869:     if (instance) {
870:         Slice<FRenderPrimitive> const primitives = getRenderPrimitives(instance, level);
871:         if (primitiveIndex < primitives.size()) {
872:             FMaterial const* material = mi->getMaterial();
873: 
874:             // we want a feature level violation to be a hard error (exception if enabled, or crash)
875:             FILAMENT_CHECK_PRECONDITION(mEngine.hasFeatureLevel(material->getFeatureLevel()))
876:                     << "Material \"" << material->getName().c_str_safe() << "\" has feature level "
877:                     << uint8_t(material->getFeatureLevel())
878:                     << " which is not supported by this Engine";
879: 
880:             primitives[primitiveIndex].setMaterialInstance(mi);
881:             AttributeBitset const required = material->getRequiredAttributes();
882:             AttributeBitset const declared = primitives[primitiveIndex].getEnabledAttributes();
883:             // Print the warning only when the handle is available. Otherwise, this may end up
884:             // emitting many invalid warnings as the `declared` bitset is not populated yet.
885:             bool const isPrimitiveInitialized = !!primitives[primitiveIndex].getHwHandle();
886:             if (UTILS_UNLIKELY(isPrimitiveInitialized && (declared & required) != required)) {
887:                 LOG(WARNING) << "[instance=" << instance.asValue() << ", primitive @ "
888:                              << primitiveIndex << "] missing required attributes (" << required
889:                              << "), declared=" << declared;
890:             }
891:         }
892:     }
893: }
894: 
895: void FRenderableManager::clearMaterialInstanceAt(Instance const instance, uint8_t const level,
896:         size_t const primitiveIndex) {
897:     if (instance) {
898:         Slice<FRenderPrimitive> const primitives = getRenderPrimitives(instance, level);
899:         if (primitiveIndex < primitives.size()) {
900:             primitives[primitiveIndex].setMaterialInstance(nullptr);
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/RenderableManager.cpp:971-994

```text
971: void FRenderableManager::setGeometryAt(Instance const instance, uint8_t const level, size_t const primitiveIndex,
972:         PrimitiveType const type, FVertexBuffer const* vertices, FIndexBuffer const* indices,
973:         size_t const offset, size_t const count) noexcept {
974:     if (instance) {
975:         Slice<FRenderPrimitive> const primitives = getRenderPrimitives(instance, level);
976:         if (primitiveIndex < primitives.size()) {
977:             primitives[primitiveIndex].set(mHwRenderPrimitiveFactory, mEngine.getDriverApi(),
978:                     type, vertices, indices, offset, count);
979:         }
980:     }
981: }
982: 
983: void FRenderableManager::setGeometryAt(Instance const instance, uint8_t const level, size_t const primitiveIndex,
984:         PrimitiveType const type, FVertexBuffer const* vertices,
985:         size_t const offset, size_t const count) noexcept {
986:     if (instance) {
987:         Slice<FRenderPrimitive> const primitives = getRenderPrimitives(instance, level);
988:         if (primitiveIndex < primitives.size()) {
989:             primitives[primitiveIndex].set(mHwRenderPrimitiveFactory, mEngine.getDriverApi(),
990:                     type, vertices, nullptr, offset, count);
991:         }
992:     }
993: }
994: 
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/RenderPass.cpp:674-709

```text
674:         for (auto const& primitive: primitives) {
675:             FMaterialInstance const* const mi = primitive.getMaterialInstance();
676:             if (UTILS_UNLIKELY(!mi)) {
677:                 // This can happen because RenderPrimitives can be initialized with
678:                 // a null MaterialInstance. In this case, skip the primitive.
679:                 if constexpr (isColorPass) {
680:                     curr->key = uint64_t(Pass::SENTINEL);
681:                     ++curr;
682:                 }
683:                 curr->key = uint64_t(Pass::SENTINEL);
684:                 ++curr;
685:                 continue;
686:             }
687: 
688:             // TODO: we should disable the SKN variant if this primitive doesn't have either
689:             //       skinning or morphing.
690: 
691:             FMaterial const* const ma = mi->getMaterial();
692:             cmd.info.mi = mi;
693:             cmd.info.rph = primitive.getHwHandle();
694:             cmd.info.vbih = primitive.getVertexBufferInfoHandle();
695:             cmd.info.offset = primitive.getOffset();
696:             cmd.info.count = primitive.getCount();
697:             cmd.info.type = primitive.getPrimitiveType();
698:             cmd.info.isIndexed = primitive.isIndexed();
699:             cmd.info.morphingOffset = primitive.getMorphingBufferOffset();
700: // FIXME: morphtarget buffer
701: //            cmd.info.morphTargetBuffer = morphing.morphTargetBuffer ?
702: //                    morphing.morphTargetBuffer->getHwHandle() : SamplerGroupHandle{};
703: 
704:             if constexpr (isColorPass) {
705:                 setupColorCommand(cmd, renderableVariant, specKey, mi,
706:                         inverseFrontFaces, hasDepthClamp);
707:                 const bool blendPass = Pass(cmd.key & PASS_MASK) == Pass::BLENDED;
708:                 if (blendPass) {
709:                     // TODO: at least for transparent objects, AABB should be per primitive
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/RenderPass.cpp:1118-1127

```text
1118:                     driver.setPushConstant(ShaderStage::VERTEX,
1119:                             +PushConstantIds::MORPHING_BUFFER_OFFSET, int32_t(info.morphingOffset));
1120:                 }
1121: 
1122:                 if (UTILS_LIKELY(info.isIndexed)) {
1123:                     // For indexed draws, offset/count carry indexOffset/indexCount.
1124:                     driver.draw2(info.offset, info.count, info.instanceCount);
1125:                 } else {
1126:                     // For non-indexed draws, offset/count carry vertexOffset/vertexCount.
1127:                     driver.drawArrays(info.offset, info.count, info.instanceCount);
```

## /private/tmp/dart3d-e9-debug-design-20261027/judge/evidence/filament/RenderPrimitive.cpp:61-83

```text
61: void FRenderPrimitive::set(HwRenderPrimitiveFactory& factory, backend::DriverApi& driver,
62:         RenderableManager::PrimitiveType const type,
63:         FVertexBuffer const* vertexBuffer, FIndexBuffer const* indexBuffer,
64:         size_t const offset, size_t const count) noexcept {
65:     if (mHandle) {
66:         factory.destroy(driver, mHandle);
67:     }
68: 
69:     AttributeBitset const enabledAttributes = vertexBuffer->getDeclaredAttributes();
70: 
71:     auto const& ebh = vertexBuffer->getHwHandle();
72:     // A null IndexBuffer is permitted for non-indexed (attribute-less) rendering.
73:     auto const ibh = indexBuffer ? indexBuffer->getHwHandle() : backend::IndexBufferHandle{};
74: 
75:     mHandle = factory.create(driver, ebh, ibh, type);
76:     mVertexBufferInfoHandle = vertexBuffer->getVertexBufferInfoHandle();
77: 
78:     mPrimitiveType = type;
79:     mOffset = offset;
80:     mCount = count;
81:     mEnabledAttributes = enabledAttributes;
82:     mIsIndexed = (indexBuffer != nullptr);
83: }
```
