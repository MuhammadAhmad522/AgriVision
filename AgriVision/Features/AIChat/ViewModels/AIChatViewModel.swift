import Foundation
import Combine

@MainActor
final class AIChatViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentMessage: String = ""
    
    // MARK: - Dependencies
    private let dataService: AgriDataService
    private let fieldId: UUID
    
    // MARK: - Output closures for Coordinator
    var onDismiss: (() -> Void)?
    
    init(dataService: AgriDataService, fieldId: UUID) {
        self.dataService = dataService
        self.fieldId = fieldId
    }
    
    // MARK: - Actions
    func fetchHistory() async {
        isLoading = true
        errorMessage = nil
        do {
            messages = try await dataService.fetchChatHistory(for: fieldId)
        } catch {
            errorMessage = error.localizedDescription
            ToastMessageAutoDismiss.schedule(
                expectedMessage: errorMessage ?? "",
                currentMessage: { self.errorMessage },
                clearMessage: { self.errorMessage = nil }
            )
        }
        isLoading = false
    }
    
    func sendMessage() async {
        let text = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Optimistic UI updates
        let fakeUserMsg = ChatMessage(id: UUID(), role: "user", content: text, createdAt: Date())
        messages.append(fakeUserMsg)
        currentMessage = ""
        isLoading = true
        
        do {
            let aiResponse = try await dataService.sendChatMessage(for: fieldId, message: text)
            messages.append(aiResponse)
        } catch {
            errorMessage = error.localizedDescription
            messages.removeAll { $0.id == fakeUserMsg.id } // Rollback on failure
            ToastMessageAutoDismiss.schedule(
                expectedMessage: errorMessage ?? "",
                currentMessage: { self.errorMessage },
                clearMessage: { self.errorMessage = nil }
            )
        }
        
        isLoading = false
    }
    
    func dismiss() {
        onDismiss?()
    }
}
