import SwiftUI

struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel
    
    var body: some View {
        List {
            Section(header: Text("Live Sensor Data")) {
                if viewModel.isLoading {
                    ProgressView("Updating...")
                } else {
                    ForEach(viewModel.readings) { reading in
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
                                .foregroundColor(.green)
                        }
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

#Preview {
    NavigationView {
        DashboardView(viewModel: DashboardViewModel())
    }
}
