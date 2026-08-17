import SwiftUI

struct FieldDetailsView: View {
    @StateObject var viewModel: FieldDetailsViewModel
    @Environment(\.dismiss) var dismiss
    
    // State for selection sheets
    @State private var showCropPicker = false
    @State private var showPlantationPicker = false
    @State private var showHarvestPicker = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background Image
            Image("bg-image")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Glassmorphic Card Overlay (Matching Auth Style)
            VStack {
                Spacer().frame(height: 120) // Accounting for fixed header
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("New Field Details")
                            .textStyle(.title2)
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.top, 40)
                            .padding(.bottom, 10)
                        
                        // Input Forms
                        VStack(spacing: 20) {
                            FieldTextFieldBox(
                                placeholder: "Field Name",
                                text: $viewModel.name
                            )
                            
                            FieldSelectionBox(
                                label: "Crop Type",
                                value: viewModel.selectedCrop,
                                placeholder: "Crop Type",
                                icon: "chevron.down"
                            ) {
                                showCropPicker = true
                            }
                            
                            FieldSelectionBox(
                                label: "Plantation Date",
                                value: dateFormatter.string(from: viewModel.plantationDate),
                                placeholder: "Plantation Date",
                                icon: "calendar"
                            ) {
                                showPlantationPicker = true
                            }
                            
                            FieldSelectionBox(
                                label: "Expected Harvest Date",
                                value: dateFormatter.string(from: viewModel.harvestDate),
                                placeholder: "Expected Harvest Date",
                                icon: "calendar"
                            ) {
                                showHarvestPicker = true
                            }
                            
                            FieldToggleBox(
                                label: "Monitor With IoT Sensors",
                                description: "Optional. Turn on to pair a sensor before saving this field",
                                isOn: $viewModel.monitorWithIoT
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 30)
                        
                        FieldSubmitButton(
                            title: "Save Field",
                            isLoading: viewModel.isLoading
                        ) {
                            viewModel.saveField()
                        }
                        .padding(.bottom, viewModel.isLoading ? 0 : 40)
                        if viewModel.isLoading {
                            Text("Preparing dashboard data…")
                                .textStyle(.captionStrong)
                                .foregroundColor(Theme.Colors.primary.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 40)
                        }
                    }
                    .padding(.horizontal, UIConstants.Auth.cardHorizontalPadding)
                    .frame(width: UIConstants.Auth.cardWidth)
                    .glassmorphism(cornerRadius: UIConstants.Auth.cardCornerRadius)
                }
                
                Spacer()
            }
            
            // Fixed Header Section
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 60)
        }
        .navigationBarHidden(true)
        .overlay(alignment: .top) {
            if let error = viewModel.errorMessage {
                ToastView(message: error, type: .error)
                    .padding(.top, 60)
                    .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showCropPicker) {
            CropSelectionSheet(selection: $viewModel.selectedCrop, options: viewModel.cropTypes)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPlantationPicker) {
            DateSelectionSheet(title: "Plantation Date", selection: $viewModel.plantationDate)
                .presentationDetents([.height(350)])
        }
        .sheet(isPresented: $showHarvestPicker) {
            DateSelectionSheet(title: "Expected Harvest Date", selection: $viewModel.harvestDate)
                .presentationDetents([.height(350)])
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                viewModel.goBack()
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .textStyle(.title2)
                    .foregroundColor(Theme.Colors.primaryMedium)
            }
            
            Spacer()
            
            if let url = viewModel.profileImageURL {
                // Google User Profile Image
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 2)
                
            } else {
                // Email User - Last Name Initial
                ZStack {
                    Circle()
                        .fill(Theme.Colors.primaryLight)
                    
                    Text(viewModel.profileInitial)
                        .textStyle(.bodyStrong)
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 2)
            }
        }
    }
}

// MARK: - Field Detail Components

struct FieldSelectionBox: View {
    let label: String
    let value: String
    let placeholder: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(value.isEmpty ? placeholder : value)
                    .textStyle(.body)
                    .foregroundColor(Theme.Colors.primaryMedium)
                
                Spacer()
                
                Image(systemName: icon)
                    .foregroundColor(Theme.Colors.primaryMedium)
                    .textStyle(.body)
            }
            .padding(.horizontal, 16)
            .frame(width: 366, height: 60)
            .background(Theme.Colors.background)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Theme.Colors.primaryLight, lineWidth: 1)
            )
        }
    }
}

struct FieldToggleBox: View {
    let label: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .textStyle(.body)
                    .foregroundColor(Theme.Colors.primary)
                
                Text(description)
                    .textStyle(.caption)
                    .foregroundColor(Theme.Colors.primaryMedium)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.primaryMedium))
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .frame(width: 366, height: 84)
        .background(Theme.Colors.background)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Theme.Colors.primaryLight, lineWidth: 1)
        )
    }
}

struct FieldTextFieldBox: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textStyle(.body)
            .foregroundColor(Theme.Colors.primaryMedium)
            .padding(.horizontal, 16)
            .frame(width: 366, height: 60)
            .background(Theme.Colors.background)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Theme.Colors.primaryLight, lineWidth: 1)
            )
    }
}

struct FieldSubmitButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.background))
                } else {
                    Text(title)
                        .textStyle(.bodyStrong)
                        .foregroundColor(Theme.Colors.background)
                }
            }
            .frame(width: 326, height: 60)
            .background(
                LinearGradient(gradient: Gradient(colors: [Theme.Colors.primaryLight, Theme.Colors.primaryMedium]), startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(32)
            .shadow(color: Color.black.opacity(0.25), radius: 0, x: 0, y: 4)
        }
        .disabled(isLoading)
    }
}

struct CropSelectionSheet: View {
    @Binding var selection: String
    let options: [String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Crop Type")
                .textStyle(.bodyStrong)
                .foregroundColor(Theme.Colors.primary)
                .padding(.top)
            
            List {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        selection = option
                        dismiss()
                    }) {
                        HStack {
                            Text(option)
                                .foregroundColor(Theme.Colors.primary)
                            Spacer()
                            if selection == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.Colors.primaryMedium)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct DateSelectionSheet: View {
    let title: String
    @Binding var selection: Date
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .textStyle(.bodyStrong)
                Spacer()
                Button("Done") { dismiss() }
                    .fontWeight(.bold)
            }
            .padding()
            .foregroundColor(Theme.Colors.primary)
            
            DatePicker("", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
            
            Spacer()
        }
        .background(Theme.Colors.background.opacity(0.5))
    }
}

#Preview {
    FieldDetailsView(viewModel: FieldDetailsViewModel(dataService: MockAgriDataRepository(), authService: MockAuthService(), coordinates: []))
}
