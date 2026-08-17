import PhotosUI
import SwiftUI
import UIKit

struct AIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    init(viewModel: AIChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Theme.Colors.background, Theme.Colors.primaryLight.opacity(0.22)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    messageList
                    composer
                }
            }
            .navigationTitle("AI Field Advisor · Beta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.primaryMedium, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if viewModel.onDismiss != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", action: viewModel.dismiss).foregroundStyle(.white)
                    }
                }
            }
            .overlay(alignment: .top) {
                if let error = viewModel.errorMessage {
                    ToastView(message: error, type: .error).padding(.top, 8)
                }
            }
            .task { await viewModel.fetchHistory() }
            .onChange(of: photoItems) { _, items in
                Task { await importPhotos(items) }
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    if let data = image.jpegData(compressionQuality: 0.88) {
                        viewModel.addImage(data: data)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "leaf.circle.fill").textStyle(.display).foregroundStyle(Theme.Colors.primaryMedium)
                            Text("Ask about this field").font(.title3.bold()).foregroundStyle(Theme.Colors.primary)
                            Text("Share a crop photo or question. Advice is evidence-based but should be confirmed before chemical or dosage decisions.")
                                .textStyle(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .padding(28)
                    }
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message, attachmentData: viewModel.attachmentData)
                            .id(message.id)
                    }
                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView().tint(Theme.Colors.primaryMedium)
                            Text("Reviewing field evidence…").textStyle(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let id = viewModel.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if !viewModel.selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.selectedImages) { item in
                            ZStack(alignment: .topTrailing) {
                                if let image = UIImage(data: item.data) {
                                    Image(uiImage: image).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                Button { viewModel.removeImage(item.id) } label: {
                                    Image(systemName: "xmark.circle.fill").symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.7))
                                }
                                .offset(x: 5, y: -5)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                Menu {
                    PhotosPicker(selection: $photoItems, maxSelectionCount: max(0, 3 - viewModel.selectedImages.count), matching: .images) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
                    Button { showCamera = true } label: { Label("Camera", systemImage: "camera") }
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.Colors.primaryMedium)
                        .frame(width: 42, height: 42)
                }
                .disabled(viewModel.isLoading || viewModel.selectedImages.count >= 3)

                TextField("Ask your field advisor…", text: $viewModel.currentMessage, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Colors.primaryLight.opacity(0.7)))
                    .disabled(viewModel.isLoading)

                Button { Task { await viewModel.sendMessage() } } label: {
                    Image(systemName: "paperplane.fill").foregroundStyle(.white).frame(width: 42, height: 42)
                        .background(viewModel.canSend ? Theme.Colors.primaryMedium : .gray, in: Circle())
                }
                .disabled(!viewModel.canSend)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let sourceData = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: sourceData),
                  let data = image.jpegData(compressionQuality: 0.88) else { continue }
            await MainActor.run { viewModel.addImage(data: data, filename: "field-photo.jpg", mimeType: "image/jpeg") }
        }
        await MainActor.run { photoItems = [] }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let attachmentData: [UUID: Data]

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == "user" { Spacer(minLength: 48) }
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
                if !message.attachments.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                        ForEach(message.attachments) { attachment in
                            if let data = attachmentData[attachment.id], let image = UIImage(data: data) {
                                Image(uiImage: image).resizable().scaledToFill().frame(height: 130).clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                ProgressView().frame(height: 100)
                            }
                        }
                    }
                }
                if !message.content.isEmpty {
                    Text(message.content).font(.body).textSelection(.enabled)
                }
                Text(message.createdAt.formatted(date: .omitted, time: .shortened)).textStyle(.caption).opacity(0.7)
            }
            .padding(12)
            .foregroundStyle(message.role == "user" ? .white : Theme.Colors.primary)
            .background(message.role == "user" ? Theme.Colors.primaryMedium : Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(message.role == "user" ? Color.clear : Theme.Colors.primaryLight.opacity(0.45)))
            if message.role != "user" { Spacer(minLength: 48) }
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker
        init(parent: CameraImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

#Preview {
    AIChatView(viewModel: AIChatViewModel(dataService: MockAgriDataRepository(), fieldId: UUID()))
}
