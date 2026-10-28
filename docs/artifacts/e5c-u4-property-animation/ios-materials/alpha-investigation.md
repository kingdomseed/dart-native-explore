# Ordinary material alpha investigation

The bounded U4 texture/snapshot run exposed attenuation in the ordinary BLEND
path. Exact sRGB PNG samples at corresponding checker positions:

- Opaque shared red texel: [255,158,155].
- Gray backing beside the alpha face: [199,199,199].
- Alpha face red texel at factor [1,.25,.25,.25]: [190,184,184].

Red falls below both matching opaque source and backing, so this is not counted
as correct straight-alpha composition. The custom screenshot pipeline is not a
calibrated linear measurement. Source/texture identity and native factors were
verified separately in native-checks.json. No alpha-fidelity pass is assigned.

Installed iPhoneSimulator27.1 SCNShadable.h:405,418 places surface modulation
before lighting and calls diffuse.a opacity. Lines142–145 require the final
fragment output to be premultiplied, but do not say generated RGB arriving at
the fragment modifier is straight. Ordinary material code modulates diffuse
RGBA, then adds a late output.rgb *= output.a. Sprite code instead replaces the
entire output from its own straight-color expression; its prior proof does not
justify another multiplication in the generated ordinary shading path.

Independent read-only Codex triage agrees this warrants one-variable replay:
remove only the late ordinary RGB multiplication, preserving transparent pragma,
material settings and all authored inputs. The working candidate is not a
confirmed correction until replay. No renderer workaround or new feature.

Before source is FsceneRealizer.before-alpha.swift. Initial observation R1
overflowed the log message budget and was shortened for R2; R1 contributes no
complete material observations. The first non-PTY dn invocation could not
accept q, so its own identified process received SIGINT and ended with Lost
connection to device. R2 and clean reruns both ended Application finished.
No other agent process or app was stopped.
