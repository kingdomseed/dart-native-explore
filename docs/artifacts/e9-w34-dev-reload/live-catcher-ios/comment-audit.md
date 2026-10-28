Read-only Comment Sicko audit: no actionable findings, zero deletions and no files touched.
The only retained new source comment names SceneKit's premultiplied-RGB rule;
SCNShadable.h lines 142–145 document that requirement. No other added source
comments or suppressions occur in the six-file baseline delta. The unchanged
implementation_imports suppression stays outside the changed-comment scope.
No builds, tests or devices were used by the auditor.
