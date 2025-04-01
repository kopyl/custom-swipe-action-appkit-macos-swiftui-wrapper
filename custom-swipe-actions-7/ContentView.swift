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
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.gray.opacity(0.2))
                    }
                }
            }
        }
    }
}

class SwipeActionConfig {
    let fullSwipeThreshold: CGFloat = 200
}

struct SwipeAction<Content: View>: NSViewRepresentable {
    let content: Content
    @State private var swipeActionViewWidth: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> SwipeActionContainerView<Content> {
        let container = SwipeActionContainerView<Content>()
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)
        
        /// This calculation is needed because there is a padding on a wrapped View in SwiftUI,
        /// then swipe action won't come to the very left of the screen
        let contentSize = hostingView.fittingSize
        let containerWidth = container.fittingSize.width
        let dynamicPadding = max((containerWidth - contentSize.width) / 2, 0)

        let swipeActionView = NSView()
        swipeActionView.translatesAutoresizingMaskIntoConstraints = false
        swipeActionView.wantsLayer = true
        swipeActionView.layer?.backgroundColor = NSColor.red.cgColor
        container.addSubview(swipeActionView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: dynamicPadding),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -dynamicPadding),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor, constant: dynamicPadding),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -dynamicPadding),

            swipeActionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            swipeActionView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            swipeActionView.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])
        
        let swipeActionViewWidthConstraint = swipeActionView.widthAnchor.constraint(equalToConstant: swipeActionViewWidth)
        swipeActionViewWidthConstraint.isActive = true
        container.swipeActionViewWidthConstraint = swipeActionViewWidthConstraint
        
        return container
    }
    
    func updateNSView(_ nsView: SwipeActionContainerView<Content>, context: Context) {
        guard let hostingView = nsView.subviews.first as? NSHostingView<Content> else { return }
        hostingView.rootView = content
        
        guard let widthConstraint = context.coordinator.widthConstraint else { return }
        widthConstraint.constant = swipeActionViewWidth
    }
    
    class Coordinator {
        var parent: SwipeAction
        var widthConstraint: NSLayoutConstraint?
        
        init(_ parent: SwipeAction) {
            self.parent = parent
        }
    }
}

class SwipeActionContainerView<Content: View>: NSView {
    let config = SwipeActionConfig()
    
    var swipeActionViewWidthConstraint: NSLayoutConstraint?
    private var eventMonitor: Any?
    private var hostItemInitWidth: CGFloat = 0
    private var isRunningFullSwipe: Bool = false
    private var isRunningFullSwipeFinished: Bool = false

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
            guard self.isRunningFullSwipe == false else { return val }
            
            guard isRunningFullSwipeFinished == false else { return val }

            var changeTo = (self.swipeActionViewWidthConstraint?.constant ?? 0) - val.scrollingDeltaX
            
            if changeTo > config.fullSwipeThreshold {
                self.isRunningFullSwipe = true
                
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.05
                    self.swipeActionViewWidthConstraint?.animator().constant = self.hostItemInitWidth
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                } completionHandler: {
                    self.isRunningFullSwipe = false
                    self.isRunningFullSwipeFinished = true
                }
                return val
            }
            
            guard val.phase == .changed else {
                hideSwipeActionToRight()
                return val
            }
            
            if changeTo < 0 {
                changeTo = 0
            }
            if changeTo > self.hostItemInitWidth {
                changeTo = self.hostItemInitWidth
            }
            
            self.swipeActionViewWidthConstraint?.constant = changeTo
            return val
        }
    }
    
    private func hideSwipeActionToRight() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            swipeActionViewWidthConstraint?.animator().constant = 0
        }
    }

    override func mouseExited(with event: NSEvent) {
        hideSwipeActionToRight()
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        self.isRunningFullSwipeFinished = false
    }
}

#Preview {
    ContentView()
}
