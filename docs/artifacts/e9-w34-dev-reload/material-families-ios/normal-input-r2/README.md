The first material-family run used `_surface.geometryNormal`. The ordinary
unlit quad displayed gray/white regions and the two sprites disappeared in
normals, while baseColor, metallic, roughness and depth rendered. No shader
compiler failure was found in that process's retained log. This observation
does not establish a general SceneKit field limitation or its internal cause.

The controlled R2 changes only the non-PBR normal expression to `_surface.normal`.
The retained image shows a uniform tilted-quad normal and covered sprite normals.
The source in this directory identifies that intermediate experiment. The final
correction uses `_surface.normal` and disables normal mapping only on non-PBR
diagnostic material copies with a solid normal contents value, following Apple's
documented normal-property behavior. The material fixture now carries a normal
texture to check that the geometric diagnostic ignores it. PBR behavior remains
unchanged.

https://developer.apple.com/documentation/scenekit/scnmaterial/normal?language=objc
