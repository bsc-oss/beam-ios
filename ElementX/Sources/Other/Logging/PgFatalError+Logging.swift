//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//
import Foundation

/// A custom `fatalError` that logs the error message before terminating.
/// This shadows Swift's standard library `fatalError` function.
///
/// - Parameters:
///   - message: The error message to log and display.
///   - file: The file where the error occurred.
///   - line: The line number where the error occurred.
/// - Returns: Never returns, as the program terminates.
func fatalError(_ message: @autoclosure () -> String = "",
                file: StaticString = #file,
                line: UInt = #line) -> Never {
    let errorMessage = message()
    
    // Log the error before terminating
    MXLog.error("PG_CHANGED - Fatal error: \(errorMessage) at \(file):\(line)")
    
    // Call the original Swift fatalError
    Swift.fatalError(errorMessage, file: file, line: line)
}
