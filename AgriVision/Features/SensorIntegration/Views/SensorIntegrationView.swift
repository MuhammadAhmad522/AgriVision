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
                
                ZStack {
                    // Glass Card
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.Auth.cardCornerRadius))
                    
                    Color.white.opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.Auth.cardCornerRadius))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("Sensor Integration")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppColors.charcoalGreen)
                                .padding(.top, 40)
                            
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
                                        .font(.system(size: 100))
                                        .foregroundColor(AppColors.charcoalGreen)
                                }
                                .frame(width: 280, height: 180)
                                
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
                                        Text(viewModel.verificationMessage ?? "Device Verified")
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
                                            Text(viewModel.isVerifying ? "Verifying..." : "Verify Connection")
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
                                
                                Text("The pairing code helps us identify your pre-registered hardware. Click verify once your device is plugged in.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.black.opacity(0.5))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                            }
                            .padding(.horizontal, UIConstants.Auth.cardHorizontalPadding)
                            
                            Spacer(minLength: 20)
                            
                            AuthPrimaryButton(
                                title: "Let's Go",
                                isLoading: viewModel.isLoading
                            ) {
                                viewModel.completeSetup()
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
                .frame(width: UIConstants.Auth.cardWidth)
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.Auth.cardCornerRadius)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                
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
            
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(AppColors.mediumGreen.opacity(0.8))
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
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
    SensorIntegrationView(viewModel: SensorIntegrationViewModel(dataService: MockAgriDataRepository(), fieldData: FieldSelectionData(name: "Test", coordinates: [], areaHa: 0, cropType: "Wheat", plantationDate: Date(), expectedHarvestDate: Date())))
}
