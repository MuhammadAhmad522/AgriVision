import SwiftUI

/**
 `DashboardView` is what the user actually sees on their screen.
 It is a passive view: it only renders state provided by the ViewModel and calls
 ViewModel methods in response to user interaction. It contains no business logic
 (Single Responsibility Principle).
 */
struct DashboardView: View {

    /// `@StateObject` owns the ViewModel and keeps it alive as long as this View is on screen.
    @StateObject var viewModel: DashboardViewModel

    var body: some View {
        List {
            // Error banner — rendered only when the ViewModel exposes an error message.
            // The View does not interpret or transform the error; it simply displays it.
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }

            Section(header: Text("Live Sensor Data")) {
                if viewModel.isLoading {
                    ProgressView("Updating...")
                } else {
                    ForEach(viewModel.readings) { reading in
                        SensorReadingRow(reading: reading)
                    }
                }
            }
        }
        .navigationTitle(viewModel.title)
        .onAppear {
            Task {
                await viewModel.refreshData()
            }
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
}

struct SensorReadingRow: View {
    let reading: SensorReading

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(reading.type)
                    .font(.headline)

                Text(reading.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(String(format: "%.1f", reading.value)) \(reading.unit)")
                .fontWeight(.bold)
                .foregroundColor(AppColors.mediumGreen)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView(viewModel: DashboardViewModel(dataService: MockAgriDataRepository()))
    }
}
