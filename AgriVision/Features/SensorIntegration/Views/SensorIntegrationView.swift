import SwiftUI

struct SensorIntegrationView: View {
    @StateObject var viewModel: SensorIntegrationViewModel
    @Environment(\.dismiss) var dismiss
    
    // Selection state
    @State private var showTypePicker = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background Image
            Image("bg-image")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Glassmorphic Card
            VStack {
                Spacer().frame(height: 120) // Header space
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Sensor Integration")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.charcoalGreen)
                            .padding(.top, 28)
                        
                        // 1. QR Scanner Area
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(AppColors.mediumGreen.opacity(0.5), lineWidth: 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(Color.white.opacity(0.2))
                                    )
                                
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 84))
                                    .foregroundColor(AppColors.charcoalGreen)
                            }
                            .frame(width: 280, height: 140)
                            
                            Text("Scan ESP32 QR Code")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.charcoalGreen.opacity(0.8))
                        }
                        
                        // 2. Divider
                        HStack {
                            Rectangle().frame(height: 1).foregroundColor(Color.black.opacity(0.1))
                            Text("or enter pairing code manually")
                                .font(.system(size: 12))
                                .foregroundColor(Color.black.opacity(0.4))
                                .padding(.horizontal, 8)
                                .frame(maxWidth: 170)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            Rectangle().frame(height: 1).foregroundColor(Color.black.opacity(0.1))
                        }
                        .padding(.horizontal, 22)
                        
                        // 3. Manual Entry fields
                        VStack(spacing: 20) {
                            AuthTextField(
                                label: "Assign Hub Name",
                                placeholder: "e.g. North Field ESP32",
                                text: $viewModel.sensorName
                            )
                            
                            AuthTextField(
                                label: "ESP32 Pairing Code",
                                placeholder: "ESP-XXXX-XXXX",
                                text: $viewModel.pairingCode
                            )
                            .disabled(viewModel.isVerified) // Lock code once verified
                            
                            // Verification Button / Status
                            if viewModel.isVerified {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(viewModel.verificationMessage ?? "Sensor Paired")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.green)
                                }
                                .padding(.top, -8)
                            } else {
                                Button(action: {
                                    viewModel.verifyHardware()
                                }) {
                                    HStack {
                                        if viewModel.isVerifying {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        }
                                        Text(viewModel.isVerifying ? "Pairing..." : "Pair Sensor")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppColors.charcoalGreen)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(viewModel.isVerifying)
                            }
                            
                            Text("Power on the device and start its MQTT connection, then pair it to this account. It will be assigned to this field when setup completes.")
                                .font(.system(size: 12))
                                .foregroundColor(Color.black.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                        }
                        .padding(.horizontal, UIConstants.Auth.cardHorizontalPadding)
                        
                        Spacer(minLength: 8)
                        
                        AuthPrimaryButton(
                            title: "Let's Go",
                            isLoading: viewModel.isLoading
                        ) {
                            viewModel.completeSetup()
                        }
                        .padding(.bottom, viewModel.isLoading ? 0 : 12)
                        if viewModel.isLoading {
                            Text("Preparing dashboard data…")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.charcoalGreen.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 12)
                        }
                    }
                    .padding(.horizontal, UIConstants.Auth.cardHorizontalPadding)
                    .frame(width: UIConstants.Auth.cardWidth)
                    .glassmorphism(cornerRadius: UIConstants.Auth.cardCornerRadius)
                }
                
                Spacer()
            }
            
            // Fixed Header
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
        .sheet(isPresented: $showTypePicker) {
            SensorTypeSelectionSheet(selection: $viewModel.selectedSensorType, options: viewModel.sensorTypes)
                .presentationDetents([.medium])
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                viewModel.goBack()
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.mediumGreen)
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
                        .fill(AppColors.limeGreen)
                    
                    Text(viewModel.profileInitial)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 2)
            }
        }
    }
}

// MARK: - Local Components

struct SensorTypeSelectionSheet: View {
    @Binding var selection: String
    let options: [String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Sensor Type")
                .font(.headline)
                .foregroundColor(AppColors.charcoalGreen)
                .padding(.top)
            
            List {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        selection = option
                        dismiss()
                    }) {
                        HStack {
                            Text(option)
                                .foregroundColor(AppColors.charcoalGreen)
                            Spacer()
                            if selection == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.mediumGreen)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    SensorIntegrationView(viewModel: SensorIntegrationViewModel(dataService: MockAgriDataRepository(), authService: MockAuthService(), fieldData: FieldSelectionData(name: "Test", coordinates: [], areaHa: 0, cropType: "Wheat", plantationDate: Date(), expectedHarvestDate: Date())))
}
