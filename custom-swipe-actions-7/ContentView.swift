import SwiftUI

struct ContentView: View {
@State private var items: [String] = Array(1...5).map(\.description)
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items, id: \.self) { item in
                    
                    SwipeAction {
                        Text(item)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.gray.opacity(0.2))
                    }
                }
            }
        }
    }
}

struct SwipeAction<Content: View>: NSViewRepresentable {
    let content: Content
    @State private var rectWidth: CGFloat = 0
    @State private var hostItemInitWidth: CGFloat = 0
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> StatusIconContainerView {
        let container = StatusIconContainerView()
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)

        let indicator = NSView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.wantsLayer = true
        indicator.layer?.backgroundColor = NSColor.red.cgColor
        container.addSubview(indicator)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            indicator.leadingAnchor.constraint(equalTo: hostingView.trailingAnchor),
            indicator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            indicator.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])

        let widthConstraint = indicator.widthAnchor.constraint(equalToConstant: rectWidth)
        widthConstraint.isActive = true
        context.coordinator.widthConstraint = widthConstraint

        // Store the initial width in the coordinator
        DispatchQueue.main.async {
            context.coordinator.hostItemInitWidth = container.frame.size.width
            hostItemInitWidth = container.frame.size.width
        }

        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { val in
            rectWidth -= val.scrollingDeltaX
            if rectWidth < 0 {
                rectWidth = 0
            }
            if rectWidth > context.coordinator.hostItemInitWidth + 20 {
                rectWidth = hostItemInitWidth + 20
            }
            return val
        };

        return container
    }
    
    func updateNSView(_ nsView: StatusIconContainerView, context: Context) {
        // Update the content if needed
        if let hostingView = nsView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
        
        // Update the width constraint when rectWidth changes
        if let widthConstraint = context.coordinator.widthConstraint {
            widthConstraint.constant = rectWidth
        }
    }
    
    class Coordinator {
        var parent: SwipeAction
        var widthConstraint: NSLayoutConstraint?
        var hostItemInitWidth: CGFloat = 0

        init(_ parent: SwipeAction) {
            self.parent = parent
        }
    }
}

class StatusIconContainerView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#Preview {
    ContentView()
}
