import SwiftUI

class SwipeActionConfig {
    let fullSwipeThreshold: CGFloat = 300
    let fullSwipeAnimationDuration: CGFloat = 0.05
}

struct SwipeAction<Content: View>: NSViewRepresentable {
    var spacing: CGFloat = 0
    var cornerRadius: CGFloat = 0
    
    let content: Content
    private var swipeActionViewWidth: CGFloat = 0
    
    var onFullSwipe: (() -> Void)? = nil
    
    init(
        spacing: CGFloat = 0,
        cornerRadius: CGFloat = 0,
        @ViewBuilder content: () -> Content,
        onFullSwipe: (() -> Void)? = nil
    ) {
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        
        self.content = content()
        self.onFullSwipe = onFullSwipe
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
        swipeActionView.layer?.cornerRadius = cornerRadius
        
        container.addSubview(swipeActionView)
        
        let hostingViewLeadingConstraint = hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: dynamicPadding)
        let hostingViewTrailingConstraint = hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        
        let swipeActionViewLeadingConstraint = swipeActionView.leadingAnchor.constraint(equalTo: container.trailingAnchor, constant: self.spacing)
        let swipeActionViewTrailingConstraint = swipeActionView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: self.spacing)
        
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

        container.swipeActionViewLeadingConstraint = swipeActionViewLeadingConstraint
        container.swipeActionViewTrailingConstraint = swipeActionViewTrailingConstraint
        
        container.hostingViewLeadingConstraint = hostingViewLeadingConstraint
        container.hostingViewTrailingConstraint = hostingViewTrailingConstraint
        container.spacing = self.spacing
        container.onFullSwipe = onFullSwipe
        
        return container
    }
    
    func updateNSView(_ nsView: SwipeActionContainerView<Content>, context: Context) {
        guard let hostingView = nsView.subviews.compactMap({ $0 as? NSHostingView<Content> }).first else { return }
        hostingView.rootView = content
    }
}

class SwipeActionContainerView<Content: View>: NSView {
    let config = SwipeActionConfig()

    var onFullSwipe: (() -> Void)? = nil
    
    var swipeActionViewLeadingConstraint: NSLayoutConstraint?
    var swipeActionViewTrailingConstraint: NSLayoutConstraint?
    
    var hostingViewLeadingConstraint: NSLayoutConstraint?
    var hostingViewTrailingConstraint: NSLayoutConstraint?
    
    var spacing: CGFloat = 0
    
    private var eventMonitor: Any?
    private var hostItemInitWidth: CGFloat = 0
    private var isRunningFullSwipe: Bool = false
    private var isRunningFullSwipeFinished: Bool = false
    private var trackingArea: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        addTrackingArea()
        
        DispatchQueue.main.async {
            self.hostItemInitWidth = self.bounds.width
            self.clipsToBounds = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        guard eventMonitor == nil else { return }
            
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] scrollWheelEvent in
            guard let self = self else { return scrollWheelEvent }
            guard self.isRunningFullSwipe == false else { return scrollWheelEvent }
            
            guard isRunningFullSwipeFinished == false else { return scrollWheelEvent }
            
            var changeToLeadingConstraintHost = (self.hostingViewTrailingConstraint?.constant ?? 0) + scrollWheelEvent.scrollingDeltaX
            
            var changeToTrailingConstraintHost = (self.hostingViewTrailingConstraint?.constant ?? 0) + scrollWheelEvent.scrollingDeltaX
            
            var changeToLeadingConstraintSwipe: CGFloat = (self.swipeActionViewLeadingConstraint?.constant ?? 0) + scrollWheelEvent.scrollingDeltaX
            
            if -changeToLeadingConstraintSwipe > config.fullSwipeThreshold {
                self.isRunningFullSwipe = true
                
                NSAnimationContext.runAnimationGroup { animation in
                    animation.duration = self.config.fullSwipeAnimationDuration
                    
                    self.swipeActionViewLeadingConstraint?.animator().constant = -self.hostItemInitWidth
                    
                    self.hostingViewLeadingConstraint?.animator().constant = -self.hostItemInitWidth
                    self.hostingViewTrailingConstraint?.animator().constant = -self.hostItemInitWidth
                    
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                } completionHandler: {
                    self.isRunningFullSwipe = false
                    self.isRunningFullSwipeFinished = true
                    self.onFullSwipe?()
                }
                return scrollWheelEvent
            }
            
            guard scrollWheelEvent.phase == .changed else {
                hideSwipeActionToRight()
                return scrollWheelEvent
            }
            
            if changeToTrailingConstraintHost > 0 {
                changeToTrailingConstraintHost = 0
            }
            if changeToLeadingConstraintHost > 0 {
                changeToLeadingConstraintHost = 0
            }
            
            if changeToTrailingConstraintHost < -self.hostItemInitWidth {
                changeToTrailingConstraintHost = -self.hostItemInitWidth
            }
            
            if changeToLeadingConstraintSwipe > self.spacing {
                changeToLeadingConstraintSwipe = self.spacing
            }
            
            self.hostingViewLeadingConstraint?.constant = changeToLeadingConstraintHost
            self.hostingViewTrailingConstraint?.constant = changeToTrailingConstraintHost
            
            self.swipeActionViewLeadingConstraint?.constant = changeToLeadingConstraintSwipe
            
            return scrollWheelEvent
        }
    }
    
    private func hideSwipeActionToRight() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            
            hostingViewLeadingConstraint?.animator().constant = 0
            hostingViewTrailingConstraint?.animator().constant = 0
            
            swipeActionViewLeadingConstraint?.animator().constant = 0 + self.spacing
        }
    }

    override func mouseExited(with event: NSEvent) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        guard self.onFullSwipe == nil else { return }
        
        hideSwipeActionToRight()
        
        self.isRunningFullSwipeFinished = false
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.swipeActionViewLeadingConstraint?.animator().constant = self.spacing
        }
    }
}
