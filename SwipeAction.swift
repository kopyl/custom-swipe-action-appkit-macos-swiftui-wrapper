import SwiftUI

class SwipeActionConfig {
    let fullSwipeThreshold: CGFloat = 200
    let fullSwipeAnimationDuration: CGFloat = 0.05
}

struct SwipeAction<Content: View>: NSViewRepresentable {
    var spacing: CGFloat = 0
    var cornerRadius: CGFloat = 0
    
    let content: Content
    private var swipeActionViewWidth: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    init(
        spacing: CGFloat = 0,
        cornerRadius: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        
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
        
        return container
    }
    
    func updateNSView(_ nsView: SwipeActionContainerView<Content>, context: Context) {}
}

class SwipeActionContainerView<Content: View>: NSView {
    let config = SwipeActionConfig()
    
    var swipeActionViewLeadingConstraint: NSLayoutConstraint?
    var swipeActionViewTrailingConstraint: NSLayoutConstraint?
    
    var hostingViewLeadingConstraint: NSLayoutConstraint?
    var hostingViewTrailingConstraint: NSLayoutConstraint?
    
    var spacing: CGFloat = 0
    
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
            self.clipsToBounds = true
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
            
            let changeToLeadingConstraintHost = (self.hostingViewTrailingConstraint?.constant ?? 0) + scrollWheelEvent.scrollingDeltaX
            
            var changeToTrailingConstraintHost = (self.hostingViewTrailingConstraint?.constant ?? 0) + scrollWheelEvent.scrollingDeltaX
            
            var changeToLeadingConstraintSwipe: CGFloat = (self.swipeActionViewLeadingConstraint?.constant ?? 0) + scrollWheelEvent.scrollingDeltaX

            if -changeToLeadingConstraintSwipe > config.fullSwipeThreshold {
                self.isRunningFullSwipe = true
                
                NSAnimationContext.runAnimationGroup { animation in
                    animation.duration = self.config.fullSwipeAnimationDuration
                    
                    self.swipeActionViewLeadingConstraint?.animator().constant = -self.hostItemInitWidth
                    self.swipeActionViewTrailingConstraint?.animator().constant = 0
                    
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
            
            if changeToTrailingConstraintHost > 0 {
                changeToTrailingConstraintHost = 0
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
            self.swipeActionViewTrailingConstraint?.constant = 0
            
            return scrollWheelEvent
        }
    }
    
    private func hideSwipeActionToRight() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            
            hostingViewLeadingConstraint?.animator().constant = 0
            hostingViewTrailingConstraint?.animator().constant = 0
            
            swipeActionViewLeadingConstraint?.animator().constant = 0 + self.spacing
            swipeActionViewTrailingConstraint?.animator().constant = 0
        }
    }

    override func mouseExited(with event: NSEvent) {
        hideSwipeActionToRight()
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        self.isRunningFullSwipeFinished = false
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.swipeActionViewLeadingConstraint?.animator().constant = self.spacing
        }
    }
}
