import Foundation
import SwiftUI

enum ToastMessageAutoDismiss {
    static let defaultDelay: UInt64 = 3 * 1_000_000_000
    
    static func schedule(
        expectedMessage: String,
        currentMessage: @escaping () -> String?,
        clearMessage: @escaping () -> Void,
        after delay: UInt64 = defaultDelay
    ) {
        Task {
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                guard currentMessage() == expectedMessage else { return }
                withAnimation {
                    clearMessage()
                }
            }
        }
    }
}