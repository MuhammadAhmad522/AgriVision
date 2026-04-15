import SwiftUI

struct AIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    
    init(viewModel: AIChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { msg in
                            HStack {
                                if msg.role == "user" { Spacer() }
                                
                                Text(msg.content)
                                    .padding(12)
                                    .background(msg.role == "user" ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(msg.role == "user" ? .white : .primary)
                                    .cornerRadius(16)
                                    .padding(msg.role == "user" ? .leading : .trailing, 40)
                                
                                if msg.role == "model" { Spacer() }
                            }
                        }
                    }
                    .padding()
                }
                
                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                HStack {
                    TextField("Ask your agronomist...", text: $viewModel.currentMessage)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isLoading)
                    
                    Button {
                        Task { await viewModel.sendMessage() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(viewModel.currentMessage.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("AI Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        viewModel.dismiss()
                    }
                }
            }
            .task {
                await viewModel.fetchHistory()
            }
        }
    }
}
