import os

/// Signposts for the work that must stay off the critical path of a scroll, a filter change,
/// a push, or a sheet. They show as intervals in Instruments (the Points of Interest and
/// os_signpost instruments, subsystem `com.perfectliturgy`, category `performance`).
nonisolated enum Performance {
    static let signposter = OSSignposter(subsystem: "com.perfectliturgy", category: "performance")
}
