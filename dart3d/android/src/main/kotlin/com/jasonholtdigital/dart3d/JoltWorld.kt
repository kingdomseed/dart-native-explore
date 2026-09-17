package com.jasonholtdigital.dart3d

import android.util.Log
import com.github.stephengold.joltjni.AllHitCastRayCollector
import com.github.stephengold.joltjni.AllHitCollideShapeCollector
import com.github.stephengold.joltjni.Body
import com.github.stephengold.joltjni.BodyCreationSettings
import com.github.stephengold.joltjni.BodyInterface
import com.github.stephengold.joltjni.BoxShape
import com.github.stephengold.joltjni.BroadPhaseLayerInterfaceTable
import com.github.stephengold.joltjni.ClosestHitCastShapeCollector
import com.github.stephengold.joltjni.ClosestHitCollideShapeCollector
import com.github.stephengold.joltjni.CollideShapeSettings
import com.github.stephengold.joltjni.CollisionGroup
import com.github.stephengold.joltjni.CombineFunction
import com.github.stephengold.joltjni.Constraint
import com.github.stephengold.joltjni.ContactManifold
import com.github.stephengold.joltjni.CustomContactListener
import com.github.stephengold.joltjni.FixedConstraintSettings
import com.github.stephengold.joltjni.GroupFilterTable
import com.github.stephengold.joltjni.HingeConstraint
import com.github.stephengold.joltjni.HingeConstraintSettings
import com.github.stephengold.joltjni.JobSystem
import com.github.stephengold.joltjni.JobSystemThreadPool
import com.github.stephengold.joltjni.Jolt
import com.github.stephengold.joltjni.JoltPhysicsObject
import com.github.stephengold.joltjni.MotorSettings
import com.github.stephengold.joltjni.ObjectLayerPairFilterTable
import com.github.stephengold.joltjni.ObjectVsBroadPhaseLayerFilterTable
import com.github.stephengold.joltjni.PointConstraintSettings
import com.github.stephengold.joltjni.PhysicsSystem
import com.github.stephengold.joltjni.Quat
import com.github.stephengold.joltjni.RMat44
import com.github.stephengold.joltjni.RRayCast
import com.github.stephengold.joltjni.RShapeCast
import com.github.stephengold.joltjni.RVec3
import com.github.stephengold.joltjni.RayCastResult
import com.github.stephengold.joltjni.RayCastSettings
import com.github.stephengold.joltjni.ShapeCastSettings
import com.github.stephengold.joltjni.SixDofConstraint
import com.github.stephengold.joltjni.SixDofConstraintSettings
import com.github.stephengold.joltjni.SliderConstraint
import com.github.stephengold.joltjni.SliderConstraintSettings
import com.github.stephengold.joltjni.SphereShape
import com.github.stephengold.joltjni.SubShapeIdPair
import com.github.stephengold.joltjni.TempAllocator
import com.github.stephengold.joltjni.TempAllocatorMalloc
import com.github.stephengold.joltjni.TwoBodyConstraint
import com.github.stephengold.joltjni.TwoBodyConstraintSettings
import com.github.stephengold.joltjni.Vec3
import com.github.stephengold.joltjni.enumerate.EActivation
import com.github.stephengold.joltjni.enumerate.EAxis
import com.github.stephengold.joltjni.enumerate.EConstraintSpace
import com.github.stephengold.joltjni.enumerate.EMotorState
import com.github.stephengold.joltjni.enumerate.EPhysicsUpdateError
import com.github.stephengold.joltjni.enumerate.ESpringMode
import com.github.stephengold.joltjni.enumerate.ESwingType
import com.github.stephengold.joltjni.enumerate.ValidateResult
import com.github.stephengold.joltjni.readonly.ConstShape

private const val TAG = "dart3d"

/**
 * One collider-pair lifecycle transition (W8), decoded to engine
 * space — the owning view mirrors to the LH wire frame and fires.
 * `point`/`normal`/`separation` are meaningful only on
 * `began`/`triggerEntered`; `ended`/`triggerExited` carry none.
 */
class ContactEvent(
    val kind: String,
    val nodeKeyA: Long,
    val nodeKeyB: Long,
    val point: DoubleArray?,
    val normal: FloatArray?,
    val separation: Float,
)

/**
 * One physics-query hit in engine (RH) space. `point`/`normal` are
 * absent where the backend doesn't report them (overlap has neither;
 * a raycast normal probe can miss). `distance` is measured along the
 * query direction.
 */
class QueryHit(
    val nodeKey: Long,
    val point: DoubleArray?,
    val normal: FloatArray?,
    val distance: Float,
)

// MARK: - W9 joints (all values already in engine space — the view
// mirrors: body-local anchors/axes negate z, quats take (−x,−y,z,w),
// and angular SCALARS flip sign, so revolute limits arrive swapped and
// its motor velocity negated while prismatic scalars pass through;
// generic per-axis entries arrive pre-mirrored per the same rule in
// constraint space)

/** One generic-axis motor config, engine-space. `maxForce` null = uncapped. */
class JointMotorDesc(
    val targetPosition: Float,
    val targetVelocity: Float,
    val stiffness: Float,
    val damping: Float,
    val maxForce: Float?,
    val accelerationModel: Boolean,
)

/** One `axes` entry — `motion` is the wire string (locked|free|limited). */
class JointAxisDesc(
    val motion: String,
    val lower: Float,
    val upper: Float,
    val motor: JointMotorDesc?,
)

/**
 * A joint op's decoded fields (upstream `JointDesc`), engine-space.
 * `nodeKeyA`/`nodeKeyB` are the joined bodies' LocalId keys — a null
 * `nodeKeyB` means the joint anchors to the world (W12 joint
 * components' absent `otherNode`, realized via `Body.sFixedToWorld()`);
 * the Jolt-space anchors/axes are BODY-LOCAL and get rotated into world
 * space through each body's live pose at creation (Jolt settings take
 * world-space values once).
 */
class JointDesc(
    val type: String,
    val nodeKeyA: Long,
    val nodeKeyB: Long?,
    val collide: Boolean,
    val anchorA: FloatArray,
    val anchorB: FloatArray,
    val axisA: FloatArray?,
    val axisB: FloatArray?,
    val basisA: FloatArray?,
    val basisB: FloatArray?,
    val lower: Float?,
    val upper: Float?,
    val motorVelocity: Float?,
    val motorMaxForce: Float?,
    val breakDistance: Float?,
    val axes: List<JointAxisDesc>?,
)

/** A `breakDistance` joint exceeded its anchor separation — W9 event.
 *  `nodeKeyB` is null for a world-anchored component joint (W12). */
class JointBrokeEvent(
    val id: Int,
    val nodeKeyA: Long,
    val nodeKeyB: Long?,
)

/**
 * One Jolt `PhysicsSystem` per scene view, stepped on the view's
 * Choreographer loop (SceneKit owns stepping on iOS; Jolt wants explicit
 * updates). Bodies live in the same right-handed space as the Filament
 * scene — the wire conversion happens in the realizer, not here.
 */
class JoltWorld {

    companion object {
        init {
            ensureJolt()
        }

        private var joltReady = false

        /** One-time global init — safe to call per view. */
        @Synchronized
        fun ensureJolt() {
            if (joltReady) return
            System.loadLibrary("joltjni")
            JoltPhysicsObject.startCleaner()
            Jolt.registerDefaultAllocator()
            Jolt.installDefaultAssertCallback()
            Jolt.installDefaultTraceCallback()
            check(Jolt.newFactory()) { "Jolt.newFactory failed" }
            Jolt.registerTypes()
            joltReady = true
        }

        // Object layers: moving bodies collide with everything;
        // non-moving ones only with moving bodies.
        const val OBJ_NON_MOVING = 0
        const val OBJ_MOVING = 1
        const val NUM_OBJ_LAYERS = 2
        const val BP_NON_MOVING = 0
        const val BP_MOVING = 1
        const val NUM_BP_LAYERS = 2
        const val MAX_BODIES = 1024
    }

    /** `physicsWorld.fixedTimestep` — the stepper reads it per frame. */
    var fixedTimestep = 1f / 60f

    /** `physicsWorld.maxSubsteps` — cap on collision steps per frame. */
    var maxSubsteps = 8

    // The filter base classes are package-private-constructor —
    // jolt-jni's concrete *Table implementations are the supported
    // extension point. PhysicsSystem.init stores these as raw native
    // pointers, so the wrappers must stay reachable for the system's
    // lifetime — R8 strips write-only fields in release builds, which
    // lets the cleaner free the native peers mid-run. The fences in
    // update() keep that contract.
    private val bpLayers = BroadPhaseLayerInterfaceTable(
        NUM_OBJ_LAYERS, NUM_BP_LAYERS).apply {
        mapObjectToBroadPhaseLayer(OBJ_NON_MOVING, BP_NON_MOVING)
        mapObjectToBroadPhaseLayer(OBJ_MOVING, BP_MOVING)
    }
    // The pair-filter table starts with every pair disabled —
    // enable exactly what should collide: moving vs everything.
    private val pairFilter = ObjectLayerPairFilterTable(NUM_OBJ_LAYERS).apply {
        enableCollision(OBJ_MOVING, OBJ_MOVING)
        enableCollision(OBJ_MOVING, OBJ_NON_MOVING)
    }
    private val objVsBp = ObjectVsBroadPhaseLayerFilterTable(
        bpLayers, NUM_BP_LAYERS, pairFilter, NUM_OBJ_LAYERS)

    // collisionLayer/collisionMask bitmasks map onto a shared
    // GroupFilterTable: each body gets its own sub-group and a pair is
    // disabled unless (a.layer & b.mask) != 0 && (b.layer & a.mask) != 0
    // — the upstream interaction rule, which is symmetric and so fits
    // the table's symmetric disable bits. Bodies must all share this
    // filter: Jolt collides bodies whose group filters differ (or are
    // absent) unconditionally, which would let a missing filter punch
    // through a zero mask.
    private val groupTable = GroupFilterTable(MAX_BODIES)
    private var nextSubGroup = 0
    private val subGroupLayerMask = ArrayList<Long>()
    private var groupOverflowLogged = false

    // Upstream per-material combine rules land on Jolt's per-system
    // combine functions — the closest expressible mapping. Last collider
    // wins when documents disagree. The fields keep the wrappers
    // reachable (the system stores the raw function pointers).
    private var combineFriction: CombineFunction? = null
    private var combineRestitution: CombineFunction? = null

    val physicsSystem = PhysicsSystem()
    private val tempAllocator: TempAllocator = TempAllocatorMalloc()
    private val jobSystem: JobSystem = JobSystemThreadPool(
        Jolt.cMaxPhysicsJobs, Jolt.cMaxPhysicsBarriers,
        Runtime.getRuntime().availableProcessors(),
    )

    val bodyInterface: BodyInterface
        get() = physicsSystem.bodyInterface

    // W8 contact events. `bodyNodeKeys` maps a Jolt body id back to
    // the node's LocalId key — onContactRemoved hands back only body
    // ids (via SubShapeIdPair), so userData alone can't resolve it.
    // `sensorBodyIds` answers the same callback's sensor test after
    // the bodies are out of reach. Both are concurrent: Jolt may
    // invoke the listener on a job-system worker thread while
    // addBody/removeBody run on the frame thread.
    private val bodyNodeKeys = java.util.concurrent.ConcurrentHashMap<Int, Long>()
    private val sensorBodyIds =
        java.util.concurrent.ConcurrentHashMap.newKeySet<Int>()

    // W9 joints. `joints` maps the caller's id to its record; a record
    // with a null constraint is DEFERRED — a/b named nodes whose
    // bodies aren't live yet (a collider awaiting a payload defers its
    // body) — and realizes when addBody registers the last one.
    // `nodeBodies` is the nodeKey→body inverse of bodyNodeKeys that
    // lookup needs; `bodySubGroups` records each body's GroupFilterTable
    // sub-group so `collide:false` can disable just that pair (the
    // refcount map restores it when the last disabling joint dies).
    // Jolt stores added constraints as raw pointers — the records keep
    // the wrappers reachable (fenced in update()) like the filter
    // tables above, and each wrapper is closed once the system drops it.
    private class JointRecord(
        val id: Int,
        var desc: JointDesc,
        var constraint: Constraint? = null,
        var bodyA: Body? = null,
        var bodyB: Body? = null,
        // packed (lo,hi) sub-group pair this record disabled — the
        // refcount in jointDisabledPairs decides when to re-enable.
        var disabledPair: Long = -1L,
    )

    private val joints = LinkedHashMap<Int, JointRecord>()
    private val nodeBodies = HashMap<Long, Body>()
    private val bodySubGroups = HashMap<Int, Int>()
    private val jointDisabledPairs = HashMap<Long, Int>()
    private val jointLoggedOnce = HashSet<String>()

    /** Sink for joint `broke` events — the view sets it, mirroring
     * the [onContact] contract. Invoked inside [update]. */
    @Volatile
    var onJointBroke: ((JointBrokeEvent) -> Unit)? = null

    private fun logJointOnce(tag: String, msg: String) {
        if (jointLoggedOnce.add(tag)) Log.w(TAG, msg)
    }

    /**
     * Sink for one [ContactEvent] per pair transition — the view sets
     * it (it owns the viewId) and forwards to Dart. Jolt invokes the
     * listener inside [update]; Dart3dJni hops to main regardless.
     */
    @Volatile
    var onContact: ((ContactEvent) -> Unit)? = null

    /**
     * The listener's native peer is stored on the system as a raw
     * pointer — same lifetime contract as the filter tables: fenced
     * in update(), closed after the system dies.
     */
    private val contactListener = object : CustomContactListener() {
        override fun onContactAdded(
            body1Va: Long, body2Va: Long, manifoldVa: Long,
            settingsVa: Long,
        ) {
            // VA-wrapped bodies are non-owning views — no close.
            val b1 = Body(body1Va)
            val b2 = Body(body2Va)
            val keyA = bodyNodeKeys[b1.id] ?: return
            val keyB = bodyNodeKeys[b2.id] ?: return
            // jolt-jni's ContactManifold exposes no per-point list and
            // no impulse — emit ONE point at the world-space baseOffset
            // (spec-documented approximation; the wire gets imp:0).
            val manifold = ContactManifold(manifoldVa)
            val p = manifold.baseOffset
            val n = manifold.worldSpaceNormal
            onContact?.invoke(ContactEvent(
                kind = if (b1.isSensor || b2.isSensor)
                    "triggerEntered" else "began",
                nodeKeyA = keyA,
                nodeKeyB = keyB,
                point = doubleArrayOf(p.xx(), p.yy(), p.zz()),
                normal = floatArrayOf(n.x, n.y, n.z),
                separation = -manifold.penetrationDepth,
            ))
        }

        // onContactPersisted stays a no-op — upstream has no
        // "persisted" event, so the lifecycle callback is dropped.

        override fun onContactRemoved(pairVa: Long) {
            val pair = SubShapeIdPair(pairVa)
            val id1 = pair.body1Id
            val id2 = pair.body2Id
            val keyA = bodyNodeKeys[id1] ?: return
            val keyB = bodyNodeKeys[id2] ?: return
            onContact?.invoke(ContactEvent(
                kind = if (id1 in sensorBodyIds || id2 in sensorBodyIds)
                    "triggerExited" else "ended",
                nodeKeyA = keyA,
                nodeKeyB = keyB,
                point = null, normal = null, separation = 0f,
            ))
        }

        override fun onContactValidate(
            body1Va: Long, body2Va: Long,
            offsetX: Double, offsetY: Double, offsetZ: Double,
            resultVa: Long,
        ): Int = ValidateResult.AcceptAllContactsForThisBodyPair.ordinal
    }

    init {
        physicsSystem.init(
            /* maxBodies */ MAX_BODIES,
            /* numBodyMutexes */ 0,
            /* maxBodyPairs */ 1024,
            /* maxContactConstraints */ 1024,
            bpLayers, objVsBp, pairFilter,
        )
        physicsSystem.setGravity(Vec3(0f, -9.8f, 0f))
        physicsSystem.setContactListener(contactListener)
        physicsSystem.optimizeBroadPhase()
    }

    fun setGravity(x: Float, y: Float, z: Float) {
        physicsSystem.setGravity(Vec3(x, y, z))
    }

    /**
     * Steps the sim by [dt] split into [collisionSteps] equal sub-steps
     * (callers pass `dt = fixedTimestep * steps`); returns false on a
     * Jolt error.
     */
    fun update(dt: Float, collisionSteps: Int): Boolean {
        val err = physicsSystem.update(dt, collisionSteps, tempAllocator, jobSystem)
        java.lang.ref.Reference.reachabilityFence(bpLayers)
        java.lang.ref.Reference.reachabilityFence(objVsBp)
        java.lang.ref.Reference.reachabilityFence(pairFilter)
        java.lang.ref.Reference.reachabilityFence(groupTable)
        java.lang.ref.Reference.reachabilityFence(combineFriction)
        java.lang.ref.Reference.reachabilityFence(combineRestitution)
        java.lang.ref.Reference.reachabilityFence(contactListener)
        if (err != EPhysicsUpdateError.None) {
            Log.w(TAG, "jolt update error: $err")
            return false
        }
        pollJointBreaks()
        java.lang.ref.Reference.reachabilityFence(joints)
        return true
    }

    /**
     * Allocates a sub-group in the shared [GroupFilterTable] for a body
     * carrying collider [layer]/[mask] bitmasks, disabling it against
     * every existing sub-group the upstream rule excludes. Returns null
     * (with a single warning) once the table is full — the body then
     * collides under the object-layer filters only.
     */
    fun collisionGroup(layer: Int, mask: Int): CollisionGroup? {
        val sg = nextSubGroup
        if (sg >= MAX_BODIES) {
            if (!groupOverflowLogged) {
                groupOverflowLogged = true
                Log.w(TAG, "collision sub-groups exhausted; layer/mask filter skipped")
            }
            return null
        }
        nextSubGroup++
        for (j in 0 until subGroupLayerMask.size) {
            val packed = subGroupLayerMask[j]
            val otherLayer = (packed ushr 32).toInt()
            val otherMask = packed.toInt()
            if ((layer and otherMask) == 0 || (otherLayer and mask) == 0) {
                groupTable.disableCollision(sg, j)
            }
        }
        subGroupLayerMask.add(
            (layer.toLong() shl 32) or (mask.toLong() and 0xFFFFFFFFL))
        return CollisionGroup(groupTable, 0, sg)
    }

    /**
     * Applies an upstream material combine rule ('average', 'minimum',
     * 'maximum', 'multiply') to the system-wide friction combine.
     * Returns false for a rule name Jolt can't express — the caller
     * logs once and leaves the default.
     */
    fun setFrictionCombine(rule: String): Boolean =
        combineFunctionFor(rule, friction = true)?.let {
            combineFriction = it
            physicsSystem.setCombineFriction(it)
            true
        } ?: false

    /** Restitution twin of [setFrictionCombine]. */
    fun setRestitutionCombine(rule: String): Boolean =
        combineFunctionFor(rule, friction = false)?.let {
            combineRestitution = it
            physicsSystem.setCombineRestitution(it)
            true
        } ?: false

    private fun combineFunctionFor(rule: String, friction: Boolean): CombineFunction? =
        when (rule) {
            "average" -> CombineFunction.average(friction)
            "minimum" -> CombineFunction.min(friction)
            "maximum" -> CombineFunction.max(friction)
            "multiply" -> CombineFunction.product(friction)
            else -> null
        }

    /**
     * Creates and adds a body for the node keyed [nodeKey] — the
     * single creation point, so the W8 event maps are populated here
     * (the body's userData carries the key too; the id→key map is the
     * one the removed-pair callback can still reach).
     */
    fun addBody(bcs: BodyCreationSettings, activate: Boolean, nodeKey: Long): Body {
        bcs.setUserData(nodeKey)
        val body = bodyInterface.createBody(bcs)
        bodyInterface.addBody(
            body.id,
            if (activate) EActivation.Activate else EActivation.DontActivate,
        )
        bodyNodeKeys[body.id] = nodeKey
        nodeBodies[nodeKey] = body
        // The body's group-table sub-group (W9 `collide:false` pair
        // disables index it). An unset/overflow group reads back as
        // cInvalidSubGroup (−1) and is skipped.
        val sg = bcs.collisionGroup.subGroupId
        if (sg >= 0) bodySubGroups[body.id] = sg
        if (body.isSensor) sensorBodyIds.add(body.id)
        // Bodies arriving late realize deferred joints. Snapshot —
        // realizeJoint may drop a malformed record mid-iteration.
        for (rec in joints.values.toList()) {
            if (rec.constraint == null &&
                (rec.desc.nodeKeyA == nodeKey || rec.desc.nodeKeyB == nodeKey)) {
                realizeJoint(rec)
            }
        }
        return body
    }

    fun removeBody(body: Body) {
        val nodeKey = bodyNodeKeys[body.id]
        // Joints bound to the dying body must release their constraint
        // BEFORE it dies — Jolt forbids removing a body under
        // constraint. The record re-pends, then immediately re-binds
        // when nodeBodies already names a successor (a rebuild creates
        // the new body before the old one is torn down); a true
        // removal stays deferred for removeJointsForNode /
        // retainJointsForNodes to kill outright.
        if (nodeKey != null) {
            // Unmap first — otherwise the re-realize below could rebind
            // a joint to this dying body (both endpoints leaving in
            // one teardown pass would then orphan the constraint).
            if (nodeBodies[nodeKey] === body) nodeBodies.remove(nodeKey)
            for (rec in joints.values.toList()) {
                if (rec.constraint != null &&
                    (rec.bodyA === body || rec.bodyB === body)) {
                    teardownJoint(rec)
                    realizeJoint(rec)
                }
            }
        }
        bodySubGroups.remove(body.id)
        // Unmap BEFORE the body leaves — removing a live contact makes
        // Jolt fire onContactRemoved, and an unmapped id drops the
        // event (a deleted node shouldn't emit 'ended').
        bodyNodeKeys.remove(body.id)
        sensorBodyIds.remove(body.id)
        bodyInterface.removeBody(body.id)
        bodyInterface.destroyBody(body.id)
    }

    // MARK: - W9 joints

    /**
     * `addJoint` — records [desc] under the caller's [id] and realizes
     * it when both bodies are live (immediately in the common case,
     * or on the next [addBody] for a still-pending body — the
     * deferred-joint analogue of a payload claim). A reused live id is
     * torn down and rebuilt, matching upstream's legal reuse.
     */
    fun addJoint(id: Int, desc: JointDesc) {
        joints[id]?.let {
            logJointOnce("addJoint.dup.$id",
                "addJoint $id on a live joint id; recreating")
            teardownJoint(it)
        }
        val rec = JointRecord(id, desc)
        joints[id] = rec
        realizeJoint(rec)
    }

    /**
     * `updateJoint` — jolt-jni constraints have no in-place update for
     * anchors/axes, so per the upstream contract this recreates:
     * teardown + realize against the bodies' CURRENT poses. On an
     * unknown id it degenerates to add.
     */
    fun updateJoint(id: Int, desc: JointDesc) {
        val rec = joints[id] ?: run {
            logJointOnce("updateJoint.$id",
                "updateJoint $id: no such joint; treating as add")
            addJoint(id, desc)
            return
        }
        teardownJoint(rec)
        rec.desc = desc
        realizeJoint(rec)
    }

    fun removeJoint(id: Int) {
        val rec = joints.remove(id) ?: run {
            logJointOnce("removeJoint.$id", "removeJoint $id: no such joint")
            return
        }
        teardownJoint(rec)
    }

    /**
     * Drops every joint (live or deferred) touching [nodeKey] — called
     * from node teardown, where the node is gone for good (a mere body
     * rebuild re-pends instead, see [removeBody]).
     */
    fun removeJointsForNode(nodeKey: Long) {
        val it = joints.values.iterator()
        while (it.hasNext()) {
            val rec = it.next()
            if (rec.desc.nodeKeyA == nodeKey || rec.desc.nodeKeyB == nodeKey) {
                it.remove()
                teardownJoint(rec)
            }
        }
    }

    /** Drops every joint — scene install and [close]. */
    fun clearJoints() {
        for (rec in joints.values) teardownJoint(rec)
        joints.clear()
        jointDisabledPairs.clear()
    }

    /**
     * Drops every joint (live or deferred) whose nodes aren't all in
     * [keep] — a same-session re-realize keeps joints whose bodies
     * come back ([removeBody] re-pends and [addBody] re-realizes);
     * a different document mints different LocalId session keys, so
     * its nodes never satisfy a stale record.
     */
    fun retainJointsForNodes(keep: Set<Long>) {
        val it = joints.values.iterator()
        while (it.hasNext()) {
            val rec = it.next()
            if (rec.desc.nodeKeyA !in keep ||
                (rec.desc.nodeKeyB != null && rec.desc.nodeKeyB !in keep)) {
                it.remove()
                teardownJoint(rec)
            }
        }
    }

    /**
     * Builds + registers [rec]'s constraint if both bodies are live;
     * a missing body leaves the record deferred (its next chance is
     * the [addBody] that lands it). A malformed build drops the record
     * with a warning — the "plain missing token" no-op lane.
     */
    private fun realizeJoint(rec: JointRecord) {
        if (rec.constraint != null) return
        val d = rec.desc
        val a = nodeBodies[d.nodeKeyA]
        // A null nodeKeyB anchors to the world — Jolt's canonical fixed
        // body (identity pose, so anchorB arrives already world-space).
        val b = if (d.nodeKeyB == null) Body.sFixedToWorld()
            else nodeBodies[d.nodeKeyB]
        if (a == null || b == null) {
            logJointOnce("joint.defer.${rec.id}",
                "joint ${rec.id} (${d.type}): bodies not live; deferred")
            return
        }
        if (a.id == b.id) {
            logJointOnce("joint.self.${rec.id}",
                "joint ${rec.id}: a and b are the same body; dropped")
            joints.remove(rec.id)
            return
        }
        val c = buildConstraint(d, a, b) ?: run {
            joints.remove(rec.id)
            return
        }
        physicsSystem.addConstraint(c)
        rec.constraint = c
        rec.bodyA = a
        rec.bodyB = b
        // The world body has no group-table entry (nothing to collide
        // with) — skip the collide:false pair disable for it.
        if (!d.collide && d.nodeKeyB != null) disableJointPair(rec, a, b)
    }

    /**
     * Removes [rec]'s constraint (if live), frees its wrapper, and
     * restores a pair it disabled — leaves the record deferred-or-
     * dead. Jolt's removeConstraint doesn't free the native object;
     * the wrapper owns it, so close after removal.
     */
    private fun teardownJoint(rec: JointRecord) {
        rec.constraint?.let {
            physicsSystem.removeConstraint(it)
            it.close()
        }
        rec.constraint = null
        rec.bodyA = null
        rec.bodyB = null
        val pair = rec.disabledPair
        if (pair >= 0L) {
            rec.disabledPair = -1L
            val n = (jointDisabledPairs[pair] ?: 0) - 1
            if (n <= 0) {
                jointDisabledPairs.remove(pair)
                groupTable.enableCollision(
                    (pair ushr 32).toInt(), pair.toInt())
            } else {
                jointDisabledPairs[pair] = n
            }
        }
    }

    /**
     * `collide:false` — ConstraintSettings exposes no pair flag in
     * jolt-jni, so the pair is disabled in the shared
     * [GroupFilterTable] instead (same mechanism layer/mask uses). A
     * pair already excluded by the upstream layer/mask rule needs no
     * disable — and must not be re-enabled at teardown.
     */
    private fun disableJointPair(rec: JointRecord, a: Body, b: Body) {
        val sgA = bodySubGroups[a.id]
        val sgB = bodySubGroups[b.id]
        if (sgA == null || sgB == null) {
            logJointOnce("joint.collide.${rec.id}",
                "joint ${rec.id}: collide=false needs both bodies in the" +
                    " shared group table; the pair keeps colliding")
            return
        }
        if (pairExcludedByMask(sgA, sgB)) return
        val pk = (minOf(sgA, sgB).toLong() shl 32) or
            (maxOf(sgA, sgB).toLong() and 0xFFFFFFFFL)
        groupTable.disableCollision(sgA, sgB)
        jointDisabledPairs[pk] = (jointDisabledPairs[pk] ?: 0) + 1
        rec.disabledPair = pk
    }

    /** The upstream rule for sub-groups [sgA]/[sgB]: excluded when
     * either side's layer doesn't appear in the other's mask. */
    private fun pairExcludedByMask(sgA: Int, sgB: Int): Boolean {
        val pa = subGroupLayerMask[sgA]
        val pb = subGroupLayerMask[sgB]
        return ((pa ushr 32).toInt() and pb.toInt()) == 0 ||
            ((pb ushr 32).toInt() and pa.toInt()) == 0
    }

    /**
     * Builds the concrete constraint for [d] between live bodies
     * [a]/[b]. Settings take WORLD-space anchors/axes — body-local
     * wire values are rotated through each body's live pose here —
     * and are closed once `create` has consumed them. Null when the
     * type or its required fields are malformed.
     */
    private fun buildConstraint(d: JointDesc, a: Body, b: Body): Constraint? {
        val wa = anchorWorld(a, d.anchorA)
        val wb = anchorWorld(b, d.anchorB)
        return when (d.type) {
            // Default world axes lock the relative orientation the
            // bodies have at creation — exactly "fixed".
            "fixed" -> FixedConstraintSettings().run {
                setSpace(EConstraintSpace.WorldSpace)
                setPoint1(wa)
                setPoint2(wb)
                createClosing(a, b)
            }
            "spherical" -> PointConstraintSettings().run {
                setSpace(EConstraintSpace.WorldSpace)
                setPoint1(wa.xx(), wa.yy(), wa.zz())
                setPoint2(wb.xx(), wb.yy(), wb.zz())
                createClosing(a, b)
            }
            "revolute" -> {
                val axA = axisWorld(a, d.axisA) ?: return null
                val axB = axisWorld(b, d.axisB) ?: return null
                val s = HingeConstraintSettings()
                s.setSpace(EConstraintSpace.WorldSpace)
                s.setPoint1(wa)
                s.setPoint2(wb)
                s.setHingeAxis1(axA)
                s.setHingeAxis2(axB)
                // Normal axes fix the hinge's zero-angle reference —
                // any perpendicular works; using the same world vector
                // for both puts the bodies' relative angle at 0 now.
                s.setNormalAxis1(axA.getNormalizedPerpendicular())
                s.setNormalAxis2(axB.getNormalizedPerpendicular())
                d.lower?.let { s.setLimitsMin(it) }
                d.upper?.let { s.setLimitsMax(it) }
                d.motorMaxForce?.let { mf ->
                    // Spec mapping: motorMaxForce → friction torque.
                    // Jolt's friction brakes only an UNPOWERED hinge —
                    // the powered cap lives in the motor's torque
                    // limit, so set both to cover the intent.
                    s.setMaxFrictionTorque(mf)
                    torqueLimited(mf).also { ms ->
                        s.setMotorSettings(ms)
                        ms.close()
                    }
                }
                val c = s.createClosing(a, b) as HingeConstraint
                d.motorVelocity?.let {
                    c.setMotorState(EMotorState.Velocity)
                    c.setTargetAngularVelocity(it)
                }
                c
            }
            "prismatic" -> {
                val axA = axisWorld(a, d.axisA) ?: return null
                val axB = axisWorld(b, d.axisB) ?: return null
                val s = SliderConstraintSettings()
                s.setSpace(EConstraintSpace.WorldSpace)
                s.setPoint1(wa)
                s.setPoint2(wb)
                s.setSliderAxis1(axA)
                s.setSliderAxis2(axB)
                s.setNormalAxis1(axA.getNormalizedPerpendicular())
                s.setNormalAxis2(axB.getNormalizedPerpendicular())
                d.lower?.let { s.setLimitsMin(it) }
                d.upper?.let { s.setLimitsMax(it) }
                d.motorMaxForce?.let { mf ->
                    s.setMaxFrictionForce(mf)
                    forceLimited(mf).also { ms ->
                        s.setMotorSettings(ms)
                        ms.close()
                    }
                }
                val c = s.createClosing(a, b) as SliderConstraint
                d.motorVelocity?.let {
                    c.setMotorState(EMotorState.Velocity)
                    c.setTargetVelocity(it)
                }
                c
            }
            "generic" -> {
                val s = SixDofConstraintSettings()
                s.setSpace(EConstraintSpace.WorldSpace)
                s.setPosition1(wa)
                s.setPosition2(wb)
                // Constraint-space frames: the wire basis quats are
                // body-local (already mirrored); their X/Y basis
                // vectors rotated into world are Jolt's axisX/axisY.
                val qa = a.rotation
                val qb = b.rotation
                val ba = d.basisA?.let { Quat(it) } ?: Quat.sIdentity()
                val bb = d.basisB?.let { Quat(it) } ?: Quat.sIdentity()
                s.setAxisX1(ba.rotateAxisX().apply { rotateInPlace(qa) })
                s.setAxisY1(ba.rotateAxisY().apply { rotateInPlace(qa) })
                s.setAxisX2(bb.rotateAxisX().apply { rotateInPlace(qb) })
                s.setAxisY2(bb.rotateAxisY().apply { rotateInPlace(qb) })
                // Pyramid keeps Y/Z swing limits independent per axis —
                // Cone would fold them into one symmetric cone limit.
                s.setSwingType(ESwingType.Pyramid)
                d.axes?.forEachIndexed { i, ax ->
                    val e = EAxis.values()[i]   // wire JointAxis order
                    when (ax.motion) {
                        "locked" -> s.makeFixedAxis(e)
                        "limited" -> s.setLimitedAxis(e, ax.lower, ax.upper)
                        else -> s.makeFreeAxis(e)
                    }
                    ax.motor?.let { m ->
                        if (ax.motion != "locked") {
                            // setMotorSettings copies the struct — the
                            // owning wrapper closes after the call.
                            axisMotor(m).also { ms ->
                                s.setMotorSettings(e, ms)
                                ms.close()
                            }
                        }
                    }
                }
                val c = s.createClosing(a, b) as SixDofConstraint
                applySixDofMotors(c, d.axes)
                c
            }
            else -> {
                logJointOnce("joint.type.${d.type}",
                    "joint: unknown type '${d.type}'")
                null
            }
        }
    }

    /** Motor settings for a hinge: torque cap = the wire maxForce. */
    private fun torqueLimited(mf: Float): MotorSettings {
        val ms = MotorSettings()
        ms.setTorqueLimit(mf)
        return ms
    }

    /** Motor settings for a slider: force cap = the wire maxForce. */
    private fun forceLimited(mf: Float): MotorSettings {
        val ms = MotorSettings()
        ms.setForceLimit(mf)
        return ms
    }

    /**
     * Per-axis motor settings for a generic axis: the wire's maxForce
     * caps BOTH the force and torque limits (Jolt reads whichever the
     * axis kind consumes); stiffness/damping land on the embedded
     * spring, whose mode carries the wire's `model` — "acceleration"
     * is a mass-normalized drive, "force" a raw spring.
     */
    private fun axisMotor(m: JointMotorDesc): MotorSettings {
        val ms = MotorSettings()
        m.maxForce?.let {
            ms.setForceLimit(it)
            ms.setTorqueLimit(it)
        }
        // getSpringSettings() is a write-through view into the motor's
        // embedded struct (the massPropertiesOverride pattern) — the
        // wrapper itself is co-owned, no close.
        val spring = ms.springSettings
        spring.setMode(if (m.accelerationModel)
            ESpringMode.MassNormalizedStiffnessAndDamping
        else ESpringMode.StiffnessAndDamping)
        spring.setStiffness(m.stiffness)
        spring.setDamping(m.damping)
        return ms
    }

    /**
     * Constraint-side motor wiring for a `generic` joint: per-axis
     * state plus the CS-space targets. Upstream's motor is a PD drive,
     * which is exactly Jolt 6's `PositionAndVelocity` state (springy
     * when stiffness/damping are set); a bare velocity target maps to
     * `Velocity`. A motor with no targets but a force cap reads as a
     * brake — Jolt applies `maxFriction` on Off axes.
     */
    private fun applySixDofMotors(c: SixDofConstraint, axes: List<JointAxisDesc>?) {
        axes ?: return
        var vel: FloatArray? = null
        var angVel: FloatArray? = null
        var pos: FloatArray? = null
        var orient: Quat? = null
        for (i in axes.indices) {
            val ax = axes[i]
            val m = ax.motor ?: continue
            if (ax.motion == "locked") continue
            val e = EAxis.values()[i]
            val springy = m.stiffness != 0f || m.damping != 0f
            val state = when {
                springy -> EMotorState.PositionAndVelocity
                m.targetVelocity != 0f -> EMotorState.Velocity
                m.targetPosition != 0f -> EMotorState.Position
                else -> EMotorState.Off
            }
            c.setMotorState(e, state)
            if (state == EMotorState.Off) {
                m.maxForce?.let { c.setMaxFriction(e, it) }
                continue
            }
            if (i < 3) {
                if (m.targetVelocity != 0f)
                    (vel ?: FloatArray(3).also { vel = it })[i] =
                        m.targetVelocity
                if (m.targetPosition != 0f)
                    (pos ?: FloatArray(3).also { pos = it })[i] =
                        m.targetPosition
            } else {
                val j = i - 3
                if (m.targetVelocity != 0f)
                    (angVel ?: FloatArray(3).also { angVel = it })[j] =
                        m.targetVelocity
                if (m.targetPosition != 0f) {
                    // Per-axis angle targets compose into the CS target
                    // orientation — exact for one driven axis, X→Y→Z
                    // application order for several (approximation).
                    val u = when (j) {
                        0 -> Vec3.sAxisX()
                        1 -> Vec3.sAxisY()
                        else -> Vec3.sAxisZ()
                    }
                    val q = Quat(u, m.targetPosition)
                    orient = if (orient == null) q else mulQuat(q, orient!!)
                }
            }
        }
        vel?.let { c.setTargetVelocityCs(Vec3(it)) }
        angVel?.let { c.setTargetAngularVelocityCs(Vec3(it)) }
        pos?.let { c.setTargetPositionCs(Vec3(it)) }
        orient?.let { c.setTargetOrientationCs(it) }
    }

    /** Creates the constraint and closes the consumed settings —
     * jolt-jni settings are owning wrappers whose native peer must be
     * freed once `create` has read it. */
    private fun TwoBodyConstraintSettings.createClosing(
        a: Body, b: Body,
    ): TwoBodyConstraint = try {
        create(a, b)
    } finally {
        close()
    }

    /** Body-local point → world through the body's live pose. */
    private fun anchorWorld(body: Body, local: FloatArray): RVec3 {
        val p = body.position
        val v = Vec3(local)
        v.rotateInPlace(body.rotation)
        return RVec3(p.xx() + v.x, p.yy() + v.y, p.zz() + v.z)
    }

    /** Body-local direction → world through the body's live rotation. */
    private fun axisWorld(body: Body, local: FloatArray?): Vec3? {
        if (local == null) {
            logJointOnce("joint.axis.missing",
                "joint: type requires axisA/axisB; dropped")
            return null
        }
        return Vec3(local).apply { rotateInPlace(body.rotation) }
    }

    /** q ⊗ r — jolt-jni's Quat has no multiply; ctor order is (x,y,z,w). */
    private fun mulQuat(q: Quat, r: Quat): Quat = Quat(
        q.w * r.x + q.x * r.w + q.y * r.z - q.z * r.y,
        q.w * r.y - q.x * r.z + q.y * r.w + q.z * r.x,
        q.w * r.z + q.x * r.y - q.y * r.x + q.z * r.w,
        q.w * r.w - q.x * r.x - q.y * r.y - q.z * r.z,
    )

    /**
     * Geometric break check (spec: deliberately not force-based —
     * same rule as iOS). Runs after each step; a violated joint is
     * removed and reported through [onJointBroke].
     */
    private fun pollJointBreaks() {
        if (joints.isEmpty()) return
        var broke: ArrayList<JointRecord>? = null
        for (rec in joints.values) {
            val bd = rec.desc.breakDistance ?: continue
            if (rec.constraint == null) continue
            val a = rec.bodyA ?: continue
            val b = rec.bodyB ?: continue
            val wa = anchorWorld(a, rec.desc.anchorA)
            val wb = anchorWorld(b, rec.desc.anchorB)
            val dx = wa.xx() - wb.xx()
            val dy = wa.yy() - wb.yy()
            val dz = wa.zz() - wb.zz()
            if (dx * dx + dy * dy + dz * dz >
                bd.toDouble() * bd.toDouble()) {
                (broke ?: ArrayList<JointRecord>().also { broke = it })
                    .add(rec)
            }
        }
        broke?.forEach { rec ->
            joints.remove(rec.id)
            teardownJoint(rec)
            onJointBroke?.invoke(
                JointBrokeEvent(rec.id, rec.desc.nodeKeyA, rec.desc.nodeKeyB))
        }
    }

    private var closed = false

    /**
     * Destroys every body, then the system, job system, and allocator.
     * The filter tables go last: the system holds them as raw pointers,
     * so freeing them while it lives is the same hazard the
     * reachabilityFences in update() guard.
     */
    fun close() {
        if (closed) return
        closed = true
        onContact = null
        onJointBroke = null
        clearJoints()
        nodeBodies.clear()
        bodySubGroups.clear()
        jointDisabledPairs.clear()
        bodyNodeKeys.clear()
        sensorBodyIds.clear()
        physicsSystem.destroyAllBodies()
        physicsSystem.close()
        // The system held the listener's raw peer pointer — free the
        // wrapper only now that the system is dead (same rule as the
        // filter tables below).
        contactListener.close()
        jobSystem.close()
        tempAllocator.close()
        bpLayers.close()
        objVsBp.close()
        pairFilter.close()
        groupTable.close()
    }

    /**
     * Teleports a body (the `setTransforms` write on a dynamic-body
     * node). Velocity is untouched — mirrors SceneKit semantics; callers
     * that want a clean respawn also send `setVelocity`.
     */
    fun teleport(body: Body, p: FloatArray, q: FloatArray) {
        bodyInterface.setPositionAndRotation(
            body.id,
            RVec3(p[0].toDouble(), p[1].toDouble(), p[2].toDouble()),
            Quat(q[0], q[1], q[2], q[3]),
            EActivation.Activate,
        )
    }

    // MARK: - W8 physics queries (engine space; the view mirrors)

    /**
     * `RRayCast(origin, direction·maxDistance)` against the narrow
     * phase — closest hit when [all] is false, every hit nearest-first
     * otherwise. Jolt reports no surface normal on a raycast, so each
     * hit borrows one from [normalProbe] (documented approximation).
     */
    fun raycast(origin: RVec3, dirScaled: Vec3, all: Boolean): List<QueryHit> {
        val npq = physicsSystem.narrowPhaseQuery
        val rrc = RRayCast(origin, dirScaled)
        if (all) {
            val settings = RayCastSettings()
            val collector = AllHitCastRayCollector()
            try {
                npq.castRay(rrc, settings, collector)
                collector.sort()
                // Result wrappers are collector-owned views — read
                // them before the collector closes.
                return collector.hits.mapNotNull {
                    rayHit(it, origin, dirScaled)
                }
            } finally {
                collector.close()
                settings.close()
                rrc.close()
            }
        }
        val result = RayCastResult()
        try {
            if (!npq.castRay(rrc, result)) return emptyList()
            return listOfNotNull(rayHit(result, origin, dirScaled))
        } finally {
            result.close()
            rrc.close()
        }
    }

    private fun rayHit(
        r: RayCastResult, origin: RVec3, dirScaled: Vec3,
    ): QueryHit? {
        val key = bodyNodeKeys[r.bodyId] ?: return null
        val f = r.fraction
        val px = origin.xx() + dirScaled.x * f
        val py = origin.yy() + dirScaled.y * f
        val pz = origin.zz() + dirScaled.z * f
        val len = dirScaled.length()
        return QueryHit(
            nodeKey = key,
            point = doubleArrayOf(px, py, pz),
            normal = normalProbe(px, py, pz, dirScaled, len, r.bodyId),
            distance = f * len,
        )
    }

    /**
     * Raycast-normal stand-in: collide a ~1cm probe sphere centered
     * just short of the hit point and take the hit's penetration axis,
     * flipped to face the incoming ray (Jolt's axis sign follows its
     * separate-shapes convention, not the ray). Null when the probe
     * finds nothing — the wire omits `n` then.
     */
    private fun normalProbe(
        px: Double, py: Double, pz: Double,
        dirScaled: Vec3, dirLen: Float, hitBodyId: Int,
    ): FloatArray? {
        if (dirLen <= 0f) return null
        // The sphere reaches eps past its center — keep eps under the
        // radius so it still penetrates the surface the ray found.
        val eps = 0.005f
        val cx = px - dirScaled.x / dirLen * eps
        val cy = py - dirScaled.y / dirLen * eps
        val cz = pz - dirScaled.z / dirLen * eps
        val probe = SphereShape(0.01f)
        val pose = RMat44.sTranslation(RVec3(cx, cy, cz))
        val settings = CollideShapeSettings()
        val collector = AllHitCollideShapeCollector()
        try {
            physicsSystem.narrowPhaseQuery.collideShape(
                probe, Vec3(1f, 1f, 1f), pose, settings,
                RVec3(cx, cy, cz), collector)
            // Prefer the body the ray hit; nearby bodies can probe-hit
            // too and their axis is for the wrong surface.
            val hit = collector.hits.firstOrNull { it.bodyId2 == hitBodyId }
                ?: collector.hits.firstOrNull()
                ?: return null
            val n = hit.penetrationAxis
            return opposeDir(n.x, n.y, n.z, dirScaled)
        } finally {
            collector.close()
            settings.close()
            pose.close()
            probe.close()
        }
    }

    /** Sphere overlap at [center] → one nodeKey per body hit. */
    fun overlapSphere(center: RVec3, radius: Float): List<Long> {
        val shape = SphereShape(radius)
        try {
            return overlapBodies(
                shape, RMat44.sTranslation(center), center)
        } finally {
            shape.close()
        }
    }

    /** Box overlap at [center]/[rotation] with Jolt half-extents. */
    fun overlapBox(
        center: RVec3, rotation: Quat, halfExtents: Vec3,
    ): List<Long> {
        val shape = BoxShape(halfExtents)
        try {
            return overlapBodies(
                shape, RMat44.sRotationTranslation(rotation, center), center)
        } finally {
            shape.close()
        }
    }

    private fun overlapBodies(
        shape: ConstShape,
        pose: RMat44, baseOffset: RVec3,
    ): List<Long> {
        val settings = CollideShapeSettings()
        val collector = AllHitCollideShapeCollector()
        try {
            physicsSystem.narrowPhaseQuery.collideShape(
                shape, Vec3(1f, 1f, 1f), pose, settings,
                baseOffset, collector)
            // A compound body can hit per sub-shape — dedupe so each
            // node reports once (upstream OverlapHit keys by node).
            val seen = HashSet<Int>()
            val keys = ArrayList<Long>()
            for (h in collector.hits) {
                if (seen.add(h.bodyId2)) {
                    bodyNodeKeys[h.bodyId2]?.let(keys::add)
                }
            }
            return keys
        } finally {
            collector.close()
            settings.close()
            pose.close()
        }
    }

    /**
     * `castShape` of a sphere from→to — closest hit. Contact points
     * come back relative to the baseOffset (Jolt's convention), so the
     * `from` point is both the cast start and the baseOffset.
     */
    fun shapeCastSphere(from: RVec3, to: RVec3, radius: Float): QueryHit? {
        val dir = Vec3(
            (to.xx() - from.xx()).toFloat(),
            (to.yy() - from.yy()).toFloat(),
            (to.zz() - from.zz()).toFloat())
        val len = dir.length()
        if (len <= 0f) return null
        val shape = SphereShape(radius)
        val start = RMat44.sTranslation(from)
        val cast = RShapeCast(shape, Vec3(1f, 1f, 1f), start, dir)
        val settings = ShapeCastSettings()
        val collector = ClosestHitCastShapeCollector()
        try {
            physicsSystem.narrowPhaseQuery.castShape(
                cast, settings, from, collector)
            if (!collector.hadHit()) return null
            val h = collector.hit
            val key = bodyNodeKeys[h.bodyId2] ?: return null
            val cp = h.contactPointOn2
            val n = h.penetrationAxis
            return QueryHit(
                nodeKey = key,
                point = doubleArrayOf(
                    from.xx() + cp.x, from.yy() + cp.y, from.zz() + cp.z),
                normal = opposeDir(n.x, n.y, n.z, dir),
                distance = h.fraction * len,
            )
        } finally {
            collector.close()
            settings.close()
            cast.close()
            start.close()
            shape.close()
        }
    }

    /** Flips (nx,ny,nz) to oppose [dir] — hit normals face the query. */
    private fun opposeDir(
        nx: Float, ny: Float, nz: Float, dir: Vec3,
    ): FloatArray {
        val s = if (nx * dir.x + ny * dir.y + nz * dir.z > 0f) -1f else 1f
        return floatArrayOf(nx * s, ny * s, nz * s)
    }
}
