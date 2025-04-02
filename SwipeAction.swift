import SwiftUI

class SwipeActionConfig {
    let fullSwipeThreshold: CGFloat = 200
    let fullSwipeAnimationDuration: CGFloat = 0.05
}

struct SwipeAction<Content: View>: NSViewRepresentable {
    var spacing: CGFloat = 0
    let content: Content
    private var swipeActionViewWidth: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
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
        let swipeActionViewLeadingConstraint = swipeActionView.leadingAnchor.constraint(equalTo: hostingView.trailingAnchor, constant: self.spacing)
        let swipeActionViewTrailingConstraint = swipeActionView.trailingAnchor.constraint(equalTo: swipeActionView.leadingAnchor, constant: swipeActionViewWidth)
        
        NSLayoutConstraint.activate([
            hostingViewLeadingConstraint,
            hostingViewTrailingConstraint,
            hostingView.topAnchor.constraint(equalTo: container.topAnchor, constant: dynamicPadding),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -dynamicPadding),
            
            swipeActionViewLeadingConstraint,
            swipeActionViewTrailingConstraint,
            swipeActionView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            swipeActionView.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])

        container.swipeActionViewTrailingConstraint = swipeActionViewTrailingConstraint
        container.swipeActionViewLeadingConstraint = swipeActionViewLeadingConstraint
        container.hostingViewLeadingConstraint = hostingViewLeadingConstraint
        container.hostingViewTrailingConstraint = hostingViewTrailingConstraint
        container.spacing = self.spacing
        
        return container
    }
    
    func updateNSView(_ nsView: SwipeActionContainerView<Content>, context: Context) {}
}

class SwipeActionContainerView<Content: View>: NSView {
    let config = SwipeActionConfig()
    
    var swipeActionViewTrailingConstraint: NSLayoutConstraint?
    var swipeActionViewLeadingConstraint: NSLayoutConstraint?
    
    var hostingViewLeadingConstraint: NSLayoutConstraint?
    var hostingViewTrailingConstraint: NSLayoutConstraint?
    var spacing: CGFloat = 0
    
    private var eventMonitor: Any?
    private var hostItemInitWidth: CGFloat = 0
    private var isRunningFullSwipe: Bool = false
    private var isRunningFullSwipeFinished: Bool = false
    
    // Added bounds to store calculation results
    private var minWidthConstraint: CGFloat = 0
    private var maxWidthConstraint: CGFloat = 0
    private var minLeadingConstraint: CGFloat = 0
    private var maxLeadingConstraint: CGFloat = 0
    private var minTrailingConstraint: CGFloat = 0
    private var maxTrailingConstraint: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        addTrackingArea()
        
        DispatchQueue.main.async {
            self.hostItemInitWidth = self.bounds.width
            
            // Initialize bounds for constraints once we know the view size
            self.minWidthConstraint = 0
            self.maxWidthConstraint = self.hostItemInitWidth
            self.minLeadingConstraint = -self.hostItemInitWidth
            self.maxLeadingConstraint = 0
            self.minTrailingConstraint = -self.hostItemInitWidth
            self.maxTrailingConstraint = 0
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
        // We'll set up the event monitor only if it's not already set up
        guard eventMonitor == nil else { return }
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] scrollWheelEvent in
            guard let self = self else { return scrollWheelEvent }
            guard !self.isRunningFullSwipe && !self.isRunningFullSwipeFinished else {
                return scrollWheelEvent
            }
            
            // Calculate the new constraint values based on the scroll delta
            let deltaX = scrollWheelEvent.scrollingDeltaX
            let newSwipeTrailingOffset = max(min((self.swipeActionViewTrailingConstraint?.constant ?? 0) - deltaX,
                                               self.maxWidthConstraint),
                                           self.minWidthConstraint)
            
            let newLeadingConstraint = max(min((self.hostingViewLeadingConstraint?.constant ?? 0) + deltaX,
                                             self.maxLeadingConstraint),
                                         self.minLeadingConstraint)
            
            let newTrailingConstraint = max(min((self.hostingViewTrailingConstraint?.constant ?? 0) + deltaX,
                                              self.maxTrailingConstraint),
                                          self.minTrailingConstraint)
            
            // Check if we've reached the full swipe threshold
            if newSwipeTrailingOffset > self.config.fullSwipeThreshold {
                self.isRunningFullSwipe = true
                
                NSAnimationContext.runAnimationGroup { animation in
                    animation.duration = self.config.fullSwipeAnimationDuration
                    
                    self.swipeActionViewTrailingConstraint?.animator().constant = self.hostItemInitWidth
                    self.hostingViewLeadingConstraint?.animator().constant = -self.hostItemInitWidth
                    self.hostingViewTrailingConstraint?.animator().constant = -self.hostItemInitWidth
                    
                    self.swipeActionViewLeadingConstraint?.animator().constant = 0
                    
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                } completionHandler: {
                    self.isRunningFullSwipe = false
                    self.isRunningFullSwipeFinished = true
                }
                return scrollWheelEvent
            }
            
            // If scroll phase isn't "changed", we're done with the swipe, reset
            guard scrollWheelEvent.phase == .changed else {
                self.hideSwipeActionToRight()
                return scrollWheelEvent
            }
            
            // Apply the new constraint values
            self.swipeActionViewTrailingConstraint?.constant = newSwipeTrailingOffset
            self.hostingViewLeadingConstraint?.constant = newLeadingConstraint
            self.hostingViewTrailingConstraint?.constant = newTrailingConstraint
            
            return scrollWheelEvent
        }
    }
    
    private func hideSwipeActionToRight() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            
            swipeActionViewTrailingConstraint?.animator().constant = 0
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
        self.swipeActionViewLeadingConstraint?.animator().constant = self.spacing
    }
}
