import SwiftUI

public struct ComponentCatalogView: View {
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xLarge) {
                
                // Typography Section
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Typography")
                        .textStyle(.title2)
                    
                    Text("Display Text")
                        .textStyle(.display)
                    Text("Title 1 Text")
                        .textStyle(.title1)
                    Text("Title 2 Text")
                        .textStyle(.title2)
                    Text("Title 3 Text")
                        .textStyle(.title3)
                    Text("Body Text")
                        .textStyle(.body)
                    Text("Body Strong")
                        .textStyle(.bodyStrong)
                    Text("Caption Text")
                        .textStyle(.caption)
                    Text("Caption Strong")
                        .textStyle(.captionStrong)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Buttons Section
                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                    Text("Buttons")
                        .textStyle(.title2)
                    
                    AgriButton(title: "Primary Button", style: .primary) {}
                    AgriButton(title: "Loading Primary", style: .primary, isLoading: true) {}
                    AgriButton(title: "Secondary Button", style: .secondary) {}
                    AgriButton(title: "Ghost Button", style: .ghost) {}
                }
                .padding()
                
                // Cards Section
                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                    Text("Cards")
                        .textStyle(.title2)
                    
                    GlassCard(title: "Farm Overview") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Humidity")
                                    .textStyle(.caption)
                                Text("64%")
                                    .textStyle(.title3)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Status")
                                    .textStyle(.caption)
                                Text("Optimal")
                                    .textStyle(.bodyStrong)
                                    .foregroundColor(Theme.Colors.primary)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}

#Preview {
    ComponentCatalogView()
}
