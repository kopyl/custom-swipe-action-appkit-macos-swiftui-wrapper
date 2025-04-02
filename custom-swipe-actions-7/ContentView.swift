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

class SwipeActionConfig {
    let fullSwipeThreshold: CGFloat = 200
    let fullSwipeAnimationDuration: CGFloat = 0.05
}

struct SwipeAction<Content: View>: NSViewRepresentable {
    let content: Content
    private var swipeActionViewWidth: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
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
        
        let hostingViewLeadingConstraint = hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: dynamicPadding)
        let hostingViewTrailingConstraint = hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        let swipeActionViewWidthConstraint = swipeActionView.widthAnchor.constraint(equalToConstant: swipeActionViewWidth)
        
        NSLayoutConstraint.activate([
            hostingViewLeadingConstraint,
            hostingViewTrailingConstraint,
            hostingView.topAnchor.constraint(equalTo: container.topAnchor, constant: dynamicPadding),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -dynamicPadding),
            
            swipeActionViewWidthConstraint,
            swipeActionView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            swipeActionView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            swipeActionView.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])

        container.swipeActionViewWidthConstraint = swipeActionViewWidthConstraint
        container.hostingViewLeadingConstraint = hostingViewLeadingConstraint
        container.hostingViewTrailingConstraint = hostingViewTrailingConstraint
        
        return container
    }
    
    func updateNSView(_ nsView: SwipeActionContainerView<Content>, context: Context) {}
}

class SwipeActionContainerView<Content: View>: NSView {
    let config = SwipeActionConfig()
    
    var swipeActionViewWidthConstraint: NSLayoutConstraint?
    var hostingViewLeadingConstraint: NSLayoutConstraint?
    var hostingViewTrailingConstraint: NSLayoutConstraint?
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
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] scrollWheelEvent in
            guard let self = self else { return scrollWheelEvent }
            guard self.isRunningFullSwipe == false else { return scrollWheelEvent }
            
            guard isRunningFullSwipeFinished == false else { return scrollWheelEvent }

            var changeToWidthConstraint = (self.swipeActionViewWidthConstraint?.constant ?? 0) - scrollWheelEvent.scrollingDeltaX
            var changeToLeadingConstraint = (self.hostingViewLeadingConstraint?.constant ?? 0) + scrollWheelEvent.scrollingDeltaX
            var changeToTrailingConstraint = (self.hostingViewTrailingConstraint?.constant ?? 0) + scrollWheelEvent.scrollingDeltaX
            
            if changeToWidthConstraint > config.fullSwipeThreshold {
                self.isRunningFullSwipe = true
                
                NSAnimationContext.runAnimationGroup { animation in
                    animation.duration = self.config.fullSwipeAnimationDuration
                    
                    self.swipeActionViewWidthConstraint?.animator().constant = self.hostItemInitWidth
                    self.hostingViewLeadingConstraint?.animator().constant = -self.hostItemInitWidth
                    self.hostingViewTrailingConstraint?.animator().constant = -self.hostItemInitWidth
                    
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                } completionHandler: {
                    self.isRunningFullSwipe = false
                    self.isRunningFullSwipeFinished = true
                }
                return scrollWheelEvent
            }
            
            guard scrollWheelEvent.phase == .changed else {
                hideSwipeActionToRight()
                return scrollWheelEvent
            }
            
            if changeToWidthConstraint < 0 {
                changeToWidthConstraint = 0
            }
            if changeToWidthConstraint > self.hostItemInitWidth {
                changeToWidthConstraint = self.hostItemInitWidth
            }
            
            if changeToTrailingConstraint > 0 {
                changeToTrailingConstraint = 0
            }
            if changeToTrailingConstraint < -self.hostItemInitWidth {
                changeToTrailingConstraint = -self.hostItemInitWidth
            }
            
            if changeToLeadingConstraint > 0 {
                changeToLeadingConstraint = 0
            }
            if changeToLeadingConstraint < -self.hostItemInitWidth {
                changeToLeadingConstraint = -self.hostItemInitWidth
            }
            
            self.swipeActionViewWidthConstraint?.constant = changeToWidthConstraint
            self.hostingViewLeadingConstraint?.constant = changeToLeadingConstraint
            self.hostingViewTrailingConstraint?.constant = changeToTrailingConstraint
            return scrollWheelEvent
        }
    }
    
    private func hideSwipeActionToRight() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            
            swipeActionViewWidthConstraint?.animator().constant = 0
            hostingViewLeadingConstraint?.animator().constant = 0
            hostingViewTrailingConstraint?.animator().constant = 0
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
