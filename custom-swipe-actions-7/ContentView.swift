import SwiftUI

struct ContentView: View {
    @State private var items: [String] = Array(1...5).map(\.description)
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items, id: \.self) { item in
                    SwipeAction(spacing: 10, cornerRadius: 4) {
                        HStack {
                            Text(item)
                            Spacer()
                            Text(item)
                        }
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .cornerRadius(4)
                    .padding(.horizontal, 10)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
