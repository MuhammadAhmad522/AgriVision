import Combine
import Foundation

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentMessage = "" {
        didSet { if !isLoading && currentMessage != oldValue { pendingIdempotencyKey = nil } }
    }
    @Published private(set) var selectedImages: [ChatImageUpload] = []
    @Published private(set) var attachmentData: [UUID: Data] = [:]

    private let dataService: AgriDataService
    private let fieldId: UUID
    private var pendingIdempotencyKey: String?
    var onDismiss: (() -> Void)?

    init(dataService: AgriDataService, fieldId: UUID) {
        self.dataService = dataService
        self.fieldId = fieldId
    }

    var canSend: Bool {
        !isLoading && (!currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty)
    }

    func fetchHistory() async {
        isLoading = true
        errorMessage = nil
        do {
            messages = try await dataService.fetchChatHistory(for: fieldId)
            await loadMissingAttachments()
        } catch {
            presentError(error.userFacingMessage)
        }
        isLoading = false
    }

    func addImage(data: Data, filename: String = "field-photo.jpg", mimeType: String = "image/jpeg") {
        guard selectedImages.count < 3 else {
            presentError("Attach no more than three images.")
            return
        }
        guard data.count <= 10 * 1024 * 1024 else {
            presentError("Each image must be 10 MB or smaller.")
            return
        }
        selectedImages.append(ChatImageUpload(data: data, filename: filename, mimeType: mimeType))
        pendingIdempotencyKey = nil
    }

    func removeImage(_ id: UUID) {
        selectedImages.removeAll { $0.id == id }
        pendingIdempotencyKey = nil
    }

    func sendMessage() async {
        let text = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !selectedImages.isEmpty else { return }
        let key = pendingIdempotencyKey ?? UUID().uuidString
        pendingIdempotencyKey = key
        isLoading = true
        errorMessage = nil
        do {
            let turn = try await dataService.sendChatMessage(for: fieldId, message: text, images: selectedImages, idempotencyKey: key)
            messages.append(turn.userMessage)
            messages.append(turn.assistantMessage)
            for (attachment, image) in zip(turn.userMessage.attachments, selectedImages) {
                attachmentData[attachment.id] = image.data
            }
            currentMessage = ""
            selectedImages = []
            pendingIdempotencyKey = nil
        } catch {
            presentError(error.userFacingMessage)
        }
        isLoading = false
    }

    func imageData(for attachmentID: UUID) -> Data? { attachmentData[attachmentID] }

    func dismiss() { onDismiss?() }

    private func loadMissingAttachments() async {
        for attachment in messages.flatMap(\.attachments) where attachmentData[attachment.id] == nil {
            if let data = try? await dataService.fetchChatAttachment(fieldId: fieldId, attachmentId: attachment.id) {
                attachmentData[attachment.id] = data
            }
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        ToastMessageAutoDismiss.schedule(expectedMessage: message, currentMessage: { self.errorMessage }, clearMessage: { self.errorMessage = nil })
    }
}
