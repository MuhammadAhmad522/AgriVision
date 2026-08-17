import SwiftUI

struct AlertRow: View {
    var iconName: String
    var iconColor: Color
    var text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 5)
            
            Text(text)
                .textStyle(.body)
                .foregroundColor(.black)
                .lineLimit(1)
            
            Spacer()
        }
        .frame(height: 60)
    }
}
