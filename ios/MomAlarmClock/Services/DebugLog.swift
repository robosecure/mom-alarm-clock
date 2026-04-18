import Foundation

/// Compile-time gated logger. Calls are no-ops in Release — the compiler strips them.
/// Use instead of `print(...)` for developer diagnostics. Release builds go through
/// Crashlytics.record(error:) or os.Logger explicitly at each site that needs prod signal.
enum DebugLog {
    @inline(__always)
    static func log(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        #if DEBUG
        print("\(message()) [\(file):\(line)]")
        #endif
    }
}
