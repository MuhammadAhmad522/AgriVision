import SwiftUI

/**
 `DashboardView` is what the user actually sees on their screen.
 SwiftUI uses a declarative syntax: we describe *what* the UI should look like,
 and SwiftUI figures out *how* to draw it.
 */
struct DashboardView: View {
    
    /// `@StateObject` is used for properties that store a ViewModel.
    /// It "owns" the ViewModel and keeps it alive as long as this View is on the screen.
    /// Because the ViewModel is an `ObservableObject`, the View will redraw anytime its `@Published` properties change.
    @StateObject var viewModel: DashboardViewModel
    
    /// The `body` property is required by all SwiftUI Views. It describes the view's content and layout.
    var body: some View {
        // A `List` is like a scrolling table. It stacks items vertically.
        List {
            // A `Section` groups related rows together with an optional header or footer.
            Section(header: Text("Live Sensor Data")) {
                
                // If our ViewModel is currently fetching data, show a spinning loading circle.
                if viewModel.isLoading {
                    ProgressView("Updating...")
                } else {
                    // `ForEach` loops through our array of `readings`.
                    // It creates a new row for every single item in the array.
                    ForEach(viewModel.readings) { reading in
                        SensorReadingRow(reading: reading)
                    }
                }
            }
        }
        // Modifiers alter the View's appearance or behavior.
        
        // Sets the title at the top of the screen
        .navigationTitle(viewModel.title)
        
        // `.onAppear` runs a piece of code exactly once when this View first shows up on the screen.
        .onAppear {
            // We use `Task { ... }` to start background work (like fetching network data) inside SwiftUI.
            Task {
                await viewModel.refreshData()
            }
        }
        
        // `.refreshable` automatically adds "pull-to-refresh" functionality to the List!
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

/**
 This section is only used for Xcode's Canvas. It lets us see a live preview of the View
 without having to launch the entire app in the simulator.
 */
#Preview {
    NavigationStack {
        DashboardView(viewModel: DashboardViewModel())
    }
}
