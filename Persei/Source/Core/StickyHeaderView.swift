// For License please refer to LICENSE file in the root of Persei project

import UIKit

private var ContentOffsetContext = 0
private let DefaultContentHeight: CGFloat = 64

open class StickyHeaderView: UIView {
    
    // MARK: - Init
    
    func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(backgroundImageView)
        addSubview(contentContainer)

        contentContainer.addSubview(shadowView)
        
        clipsToBounds = true
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        commonInit()
    }

    public convenience init() {
        self.init(frame: CGRect(x: 0, y: 0, width: 20, height: DefaultContentHeight))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    // MARK: - View lifecycle
    
    open override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        if newSuperview == nil, let view = superview as? UIScrollView {
            view.removeObserver(self, forKeyPath:#keyPath(UIScrollView.contentOffset), context: &ContentOffsetContext)
            view.panGestureRecognizer.removeTarget(self, action: #selector(handlePan))
            
            if insetsApplied {
                removeInsets()
            }
        }
    }
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if let view = superview as? UIScrollView {
            view.isScrollEnabled = false
            view.addObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset), options: [.initial, .new], context: &ContentOffsetContext)
//            view.panGestureRecognizer.addTarget(self, action: #selector(StickyHeaderView.handlePan))
            view.sendSubviewToBack(self)
            
            if needRevealed && !insetsApplied {
                addInsets()
            } else if insetsApplied {
                removeInsets()
            }
        }
    }

    private let contentContainer: UIView = {
        let view = UIView()
        view.layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        view.backgroundColor = .clear

        return view
    }()
    
    private let shadowView = HeaderShadowView(frame: .zero)
    
    @IBOutlet open var contentView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let view = contentView {
                view.frame = contentContainer.bounds
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                contentContainer.addSubview(view)
                contentContainer.sendSubviewToBack(view)
            }
        }
    }
    
    public enum ContentViewGravity {
        case top, center, bottom
    }
    
    /**
    Affects on `contentView` sticking position during view stretching: 
    
    - Top: `contentView` sticked to the top position of the view
    - Center: `contentView` is aligned to the middle of the streched view
    - Bottom: `contentView` sticked to the bottom
    
    Default value is `Center`
    **/
    open var contentViewGravity: ContentViewGravity = .center
    
    // MARK: - Background Image
    private let backgroundImageView = UIImageView()

    @IBInspectable
    open var backgroundImage: UIImage? {
        didSet {
            backgroundImageView.image = backgroundImage
            backgroundImageView.isHidden = backgroundImage == nil
        }
    }
    
    // MARK: - ScrollView

    private var scrollView: UIScrollView {
        guard
            let scrollView = superview as? UIScrollView
            else { fatalError("superview is not UIScrollView") }
        
        return scrollView
    }
    
    // MARK: - KVO
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &ContentOffsetContext {
            didScroll()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: - State
    
    fileprivate var needRevealed = false
    
    open var revealed: Bool = false {
        didSet {
            if oldValue != revealed {
                if superview == nil {
                    needRevealed = revealed
                } else if revealed {
                    //  开始展开
                    addInsets()
                } else {
                    // 关闭
                    removeInsets()
                }
            }
        }
    }
    
    // 动画控制展开
    private func setRevealed(_ revealed: Bool, animated: Bool, adjustContentOffset adjust: Bool) {
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .beginFromCurrentState, animations: {
                self.revealed = revealed
            }, completion: { completed in
                if adjust {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.scrollView.contentOffset.y = -self.scrollView.effectiveContentInset.top * 0.9
                    })
                }
            })
        } else {
            self.revealed = revealed
            
            if adjust {
                scrollView.contentOffset.y = -scrollView.effectiveContentInset.top  * 0.7
            }
        }
    }
    
    // 展开
    open func setRevealed(_ revealed: Bool, animated: Bool) {
        setRevealed(revealed, animated: animated, adjustContentOffset: true)
    }

    private func fractionRevealed() -> CGFloat {
        return min(bounds.height / contentHeight, 0.7)
    }

    // MARK: - Applyied Insets
    
    private var appliedInsets: UIEdgeInsets = .zero
    private var insetsApplied: Bool {
        return appliedInsets != .zero
    }

    private func applyInsets(_ insets: UIEdgeInsets) {
        let originalInset = scrollView.effectiveContentInset - appliedInsets
        let targetInset = originalInset + insets

        appliedInsets = insets
        scrollView.effectiveContentInset = targetInset
    }
    
    // 给一个 112 的top 偏移
    private func addInsets() {
        assert(!insetsApplied, "Internal inconsistency")
        applyInsets(UIEdgeInsets(top: contentHeight, left: 0, bottom: 0, right: 0))
    }

    private func removeInsets() {
        assert(insetsApplied, "Internal inconsistency")
        applyInsets(.zero)
    }
    
    // MARK: - ContentHeight
    
    @IBInspectable open var contentHeight: CGFloat = DefaultContentHeight {
        didSet {
            if superview != nil {
                layoutToFit()
            }
        }
    }
    
    // MARK: - Threshold
    
    @IBInspectable open var threshold: CGFloat = 0.3
    
    // MARK: - Content Offset Hanlding
    
    private func applyContentContainerTransform(_ progress: CGFloat) {
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 500
        
        let angle = (1 - progress) * (.pi / 2)
        transform = CATransform3DRotate(transform, angle, 1, 0, 0)
        
        contentContainer.layer.transform = transform
    }
    
    private func didScroll() {
        layoutToFit()
        layoutIfNeeded()
        
        let progress = fractionRevealed()
        shadowView.alpha = max(1 - progress - 0.3, 0)

        applyContentContainerTransform(progress)
    }
    
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .ended {
            let value = scrollView.normalizedContentOffset.y * (revealed ? 1 : -1)
            let triggeringValue = contentHeight * threshold
            let velocity = recognizer.velocity(in: scrollView).y
            
            if triggeringValue < value {
                let adjust = !revealed || velocity < 0 && -velocity < contentHeight
                setRevealed(!revealed, animated: true, adjustContentOffset: adjust)
            } else if 0 < bounds.height && bounds.height < contentHeight {
                UIView.animate(withDuration: 0.3, animations: {
                    self.scrollView.contentOffset.y = -self.scrollView.effectiveContentInset.top * 0.9
                }) 
            }
        }
    }
    
    // MARK: - Layout
    
    open override func layoutSubviews() {
        super.layoutSubviews()

        backgroundImageView.frame = bounds
        
        let containerY: CGFloat
        switch contentViewGravity {
        case .top:
            containerY = min(bounds.height - contentHeight, bounds.minY)

        case .center:
            containerY = min(bounds.height - contentHeight, bounds.midY - contentHeight / 2)
            
        case .bottom:
            containerY = bounds.height - contentHeight
        }
        
        contentContainer.frame = CGRect(x: 0, y: containerY, width: bounds.width, height: contentHeight)
        // shadow should be visible outside of bounds during rotation
        shadowView.frame = contentContainer.bounds.insetBy(dx: -round(contentContainer.bounds.width / 16), dy: 0)
    }

    private func layoutToFit() {
        let origin = scrollView.contentOffset.y + scrollView.effectiveContentInset.top - appliedInsets.top
        frame.origin.y = origin
        
        print("scrollView.contentOffset.y = \(scrollView.contentOffset.y) | origin = \(origin)")
        
        sizeToFit()
    }
    
    open override func sizeThatFits(_: CGSize) -> CGSize {
        let revealedHeight: CGFloat = appliedInsets.top - scrollView.normalizedContentOffset.y
        let collapsedHeight: CGFloat = scrollView.normalizedContentOffset.y * -1
        let height: CGFloat = revealed ? revealedHeight : collapsedHeight
        let output = CGSize(width: scrollView.bounds.width, height: max(height, 0))
        
        return output
    }
}
