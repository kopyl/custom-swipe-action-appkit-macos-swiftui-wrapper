import SwiftUI

struct ContentView: View {
    @State private var items: [String] = Array(1...5).map(\.description)
    @State private var hoveredItem: String? = nil
    
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
    
    func makeNSView(context: Context) -> StatusIconContainerView<Content> {
        let container = StatusIconContainerView<Content>()  // Corrected generic usage
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
            hostingView.trailingAnchor.constraint(equalTo: indicator.leadingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            indicator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            indicator.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])
        
        let widthConstraint = indicator.widthAnchor.constraint(equalToConstant: rectWidth)
        widthConstraint.isActive = true
        container.indicatorWidthConstraint = widthConstraint
        
        DispatchQueue.main.async {
            context.coordinator.hostItemInitWidth = container.frame.size.width
            hostItemInitWidth = container.frame.size.width
        }
        
        return container
    }
    
    func updateNSView(_ nsView: StatusIconContainerView<Content>, context: Context) {
        guard let hostingView = nsView.subviews.first as? NSHostingView<Content> else { return }
        hostingView.rootView = content
        
        guard let widthConstraint = context.coordinator.widthConstraint else { return }
        widthConstraint.constant = rectWidth
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

class StatusIconContainerView<Content: View>: NSView {
    var indicatorWidthConstraint: NSLayoutConstraint?
    private var eventMonitor: Any?
    private var hostItemInitWidth: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        addTrackingArea()
        
        DispatchQueue.main.async {
            self.hostItemInitWidth = self.bounds.width
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] val in
            guard let self = self else { return val }
            
            var changeTo = (self.indicatorWidthConstraint?.constant ?? 0) - val.scrollingDeltaX
            if changeTo < 0 {
                changeTo = 0
            }
            if changeTo > self.hostItemInitWidth + 20 {
                changeTo = self.hostItemInitWidth + 20
            }
            
            self.indicatorWidthConstraint?.constant = changeTo
            return val
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            indicatorWidthConstraint?.animator().constant = 0

            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
