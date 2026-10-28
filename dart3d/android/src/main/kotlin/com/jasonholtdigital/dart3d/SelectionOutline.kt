package com.jasonholtdigital.dart3d

internal class SelectionOutline {
    data class LinearRgba(val r: Float, val g: Float, val b: Float, val a: Float)
    data class Change(val node: Long, val color: LinearRgba?)

    private val colors = HashMap<Long, LinearRgba>()

    fun apply(changes: List<Change>) {
        for ((node, color) in changes) {
            if (color == null) colors.remove(node) else colors[node] = color
        }
    }

    fun removeNodes(ids: Set<Long>) {
        colors.keys.removeAll(ids)
    }

    fun retainNodes(ids: Set<Long>) {
        colors.keys.retainAll(ids)
    }

    fun clearScene() {
        colors.clear()
    }
}
