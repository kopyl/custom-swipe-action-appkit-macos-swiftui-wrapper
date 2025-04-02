import SwiftUI

struct ContentView: View {
    @State private var items: [String] = Array(1...5).map(\.description)
    @State private var hoveredItem: String? = nil
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items, id: \.self) { item in
                    SwipeAction {
                        HStack {
                            Text(item)
                            Spacer()
                            Text(item)
                        }
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.gray.opacity(0.2))
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
