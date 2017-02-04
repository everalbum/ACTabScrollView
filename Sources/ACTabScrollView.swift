//
//  ACTabScrollView.swift
//  ACTabScrollView
//
//  Created by AzureChen on 2015/8/19.
//  Copyright (c) 2015 AzureChen. All rights reserved.
//

//  TODO:
//   1. Performace improvement
//   2. Test reloadData function
//   3. Tabs in the bottom
//   4. Bottom line or shadow
//   5. Support Carthage

import UIKit

@IBDesignable
public class ACTabScrollView: UIView, UIScrollViewDelegate {
    
    // MARK: Public Variables
    @IBInspectable public var defaultPage: Int = 0
    @IBInspectable public var tabSectionHeight: CGFloat = -1
    @IBInspectable public var tabSectionBackgroundColor: UIColor = UIColor.whiteColor()
    @IBInspectable public var contentSectionBackgroundColor: UIColor = UIColor.whiteColor()
    @IBInspectable public var tabGradient: Bool = true
    @IBInspectable public var arrowIndicator: Bool = false
    @IBInspectable public var pagingEnabled: Bool = true {
        didSet {
            contentSectionScrollView.pagingEnabled = pagingEnabled
        }
    }
    @IBInspectable public var cachedPageLimit: Int = 3
    
    public var delegate: ACTabScrollViewDelegate?
    public var dataSource: ACTabScrollViewDataSource?
    public var scrollingDisabled: Bool = false {
        didSet {
            tabSectionScrollView.scrollEnabled = !scrollingDisabled
            contentSectionScrollView.scrollEnabled = !scrollingDisabled
        }
    }
    
    // MARK: Private Variables
    public var tabSectionScrollView: UIScrollView!
    public var contentSectionScrollView: UIScrollView!
    private var arrowView: ArrowView!
    
    private var cachedPageTabs: [Int: UIView] = [:]
    private var cachedPageContents: CacheQueue<Int, UIView> = CacheQueue()
    private var realcachedPageLimit: Int {
        var limit = 3
        if (cachedPageLimit > 3) {
            limit = cachedPageLimit
        } else if (cachedPageLimit < 1) {
            limit = numberOfPages
        }
        return limit
    }
    
    private var isStarted = false
    private var pageIndex: Int!
    private var prevPageIndex: Int?
    
    private var isWaitingForPageChangedCallback = false
    private var pageChangedCallback: (Void -> Void)?
    
    // MARK: DataSource
    private var numberOfPages = 0
    
    @available(iOS 10.0, *)
    lazy var feedbackGenerator: UISelectionFeedbackGenerator = { return UISelectionFeedbackGenerator() }()
    
    private func widthForTabAtIndex(index: Int) -> CGFloat {
        return cachedPageTabs[index]?.frame.width ?? 0
    }
    
    private func tabViewForPageAtIndex(index: Int) -> UIView? {
        return dataSource?.tabScrollView(self, tabViewForPageAtIndex: index)
    }
    
    private func contentViewForPageAtIndex(index: Int) -> UIView? {
        return dataSource?.tabScrollView(self, contentViewForPageAtIndex: index)
    }
    
    // MARK: Init
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initialize()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        initialize()
    }
    
    private func initialize() {
        // init views
        tabSectionScrollView = UIScrollView()
        contentSectionScrollView = UIScrollView()
        arrowView = ArrowView(frame: CGRect(x: 0, y: 0, width: 30, height: 10))
        
        self.addSubview(contentSectionScrollView)
        self.addSubview(tabSectionScrollView)
        self.addSubview(arrowView)
        
        tabSectionScrollView.pagingEnabled = false
        tabSectionScrollView.showsHorizontalScrollIndicator = false
        tabSectionScrollView.showsVerticalScrollIndicator = false
        tabSectionScrollView.delegate = self
        
        contentSectionScrollView.pagingEnabled = pagingEnabled
        contentSectionScrollView.showsHorizontalScrollIndicator = false
        contentSectionScrollView.showsVerticalScrollIndicator = false
        contentSectionScrollView.delegate = self
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        // reset status and stop scrolling immediately
        if (isStarted) {
            isStarted = false
            stopScrolling()
        }
        
        // set custom attrs
        tabSectionScrollView.backgroundColor = self.tabSectionBackgroundColor
        contentSectionScrollView.backgroundColor = self.contentSectionBackgroundColor
        arrowView.arrorBackgroundColor = self.tabSectionBackgroundColor
        arrowView.hidden = !arrowIndicator
        
        // first time setup pages
        setupPages()
        
        // async necessarily
        dispatch_async(dispatch_get_main_queue()) {
            // first time set defaule pageIndex
            self.initWithPageIndex(self.pageIndex ?? self.defaultPage)
            self.isStarted = true
            
            // load pages
            self.lazyLoadPages()
        }
    }
    
    override public func prepareForInterfaceBuilder() {
        let textColor = UIColor(red: 203.0 / 255, green: 203.0 / 255, blue: 203.0 / 255, alpha: 1.0)
        let tabSectionHeight = self.tabSectionHeight >= 0 ? self.tabSectionHeight : 64
        
        // labels
        let tabSectionLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: tabSectionHeight))
        let contentSectionLabel = UILabel(frame: CGRect(x: 0, y: tabSectionHeight + 1, width: self.frame.width, height: self.frame.height - tabSectionHeight - 1))
        
        tabSectionLabel.text = "Tab Section"
        tabSectionLabel.textColor = textColor
        tabSectionLabel.textAlignment = .Center
        if #available(iOS 8.2, *) {
            tabSectionLabel.font = UIFont.systemFontOfSize(27, weight: UIFontWeightHeavy)
        } else {
            tabSectionLabel.font = UIFont.systemFontOfSize(27)
        }
        tabSectionLabel.backgroundColor = tabSectionBackgroundColor
        contentSectionLabel.text = "Content Section"
        contentSectionLabel.textColor = textColor
        contentSectionLabel.textAlignment = .Center
        if #available(iOS 8.2, *) {
            contentSectionLabel.font = UIFont.systemFontOfSize(27, weight: UIFontWeightHeavy)
        } else {
            contentSectionLabel.font = UIFont.systemFontOfSize(27)
        }
        contentSectionLabel.backgroundColor = contentSectionBackgroundColor
        
        // rect and seperator
        let rectView = UIView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        rectView.layer.borderWidth = 1
        rectView.layer.borderColor = textColor.CGColor
        
        let seperatorView = UIView(frame: CGRect(x: 0, y: tabSectionHeight, width: self.frame.width, height: 1))
        seperatorView.backgroundColor = textColor
        
        // arrow
        arrowView.frame.origin = CGPoint(x: (self.frame.width - arrowView.frame.width) / 2, y: tabSectionHeight)
        
        // add subviews
        self.addSubview(tabSectionLabel)
        self.addSubview(contentSectionLabel)
        self.addSubview(rectView)
        self.addSubview(seperatorView)
        self.addSubview(arrowView)
    }
    
    // MARK: - Tab Clicking Control
    func tabViewDidClick(sensor: UITapGestureRecognizer) {
        guard scrollingDisabled == false else { return }
        
        activedScrollView = tabSectionScrollView
        moveToIndex(sensor.view!.tag, animated: true)
    }
    
    func tabSectionScrollViewDidClick(sensor: UITapGestureRecognizer) {
        guard scrollingDisabled == false else { return }
        
        activedScrollView = tabSectionScrollView
        moveToIndex(pageIndex, animated: true)
    }
    
    // MARK: - Scrolling Control
    private var activedScrollView: UIScrollView?
    
    // scrolling animation begin by dragging
    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        // tell the delegate we started scrolling
        delegate?.tabScrollViewDidStartScrolling(self)
        
        // stop current scrolling before start another scrolling
        stopScrolling()
        // set the activedScrollView
        activedScrollView = scrollView
        
        if #available(iOS 10.0, *) {
            feedbackGenerator.prepare()
        }
    }
    
    // scrolling animation stop with decelerating
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        delegate?.tabScrollViewEndStartScrolling(self)
        moveToIndex(currentPageIndex(), animated: true)
    }
    
    // scrolling animation stop without decelerating
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if (!decelerate) {
            delegate?.tabScrollViewEndStartScrolling(self)
            moveToIndex(currentPageIndex(), animated: true)
        }
    }
    
    // scrolling animation stop programmatically
    public func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        if (isWaitingForPageChangedCallback) {
            isWaitingForPageChangedCallback = false
            pageChangedCallback?()
        }
    }
    
    // scrolling
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        let currentIndex = currentPageIndex()
        
        if (scrollView == activedScrollView) {
            let speed = self.frame.width / widthForTabAtIndex(currentIndex)
            
            var tabsWidth: CGFloat = 0
            var contentsWidth: CGFloat = 0
            for i in 0 ..< currentIndex {
                tabsWidth += widthForTabAtIndex(i)
                contentsWidth += self.frame.width
            }
            
            if (scrollView == tabSectionScrollView) {
                contentSectionScrollView.contentOffset.x = ((tabSectionScrollView.contentOffset.x - tabsWidth) * speed) + contentsWidth
            }
            
            if (scrollView == contentSectionScrollView) {
                tabSectionScrollView.contentOffset.x = ((contentSectionScrollView.contentOffset.x - contentsWidth) / speed) + tabsWidth
            }
            updateTabAppearance()
        }
        
        if (isStarted && pageIndex != currentIndex) {
            // set index
            pageIndex = currentIndex
            
            // lazy loading
            lazyLoadPages()
            
            // callback
            delegate?.tabScrollView(self, didScrollPageTo: currentIndex)
            
            if #available(iOS 10.0, *) {
                feedbackGenerator.selectionChanged()
            }

        }
    }
    
    // MARK: Public Methods
//    func scroll(offsetX: CGFloat) {
//    }
    
    public func reloadData() {
        // setup pages
        setupPages()
        
        // load pages
        lazyLoadPages()
    }
    
    public func changePageToIndex(index: Int, animated: Bool) {
        activedScrollView = tabSectionScrollView
        moveToIndex(index, animated: animated)
    }
    
    public func changePageToIndex(index: Int, animated: Bool, completion: (Void -> Void)) {
        isWaitingForPageChangedCallback = true
        pageChangedCallback = completion
        changePageToIndex(index, animated: animated)
    }
    
    // MARK: Private Methods
    private func stopScrolling() {
        tabSectionScrollView.setContentOffset(tabSectionScrollView.contentOffset, animated: false)
        contentSectionScrollView.setContentOffset(contentSectionScrollView.contentOffset, animated: false)
    }
    
    private func initWithPageIndex(index: Int) {
        // set pageIndex
        pageIndex = index
        prevPageIndex = pageIndex
        
        // init UI
        if (numberOfPages != 0) {
            var tabOffsetX = 0 as CGFloat
            var contentOffsetX = 0 as CGFloat
            for i in 0 ..< index {
                tabOffsetX += widthForTabAtIndex(i)
                contentOffsetX += self.frame.width
            }
            // set default position of tabs and contents
            tabSectionScrollView.contentOffset = CGPoint(x: 0, y: tabSectionScrollView.contentOffset.y)
            contentSectionScrollView.contentOffset = CGPoint(x: contentOffsetX, y: contentSectionScrollView.contentOffset.y)
            updateTabAppearance(animated: false)
        }
    }
    
    private func currentPageIndex() -> Int {
        let width = self.frame.width
        var currentPageIndex = Int((contentSectionScrollView.contentOffset.x + (0.5 * width)) / width)
        if (currentPageIndex < 0) {
            currentPageIndex = 0
        } else if (currentPageIndex >= self.numberOfPages) {
            currentPageIndex = self.numberOfPages - 1
        }
        return currentPageIndex
    }

    public var maxTabViewHeight: CGFloat {
        var max: CGFloat = 0
        for i in 0 ..< numberOfPages {
            if let tabView = tabViewForPageAtIndex(i) {
                if (tabView.frame.height > max) {
                    max = tabView.frame.height
                }
            }
        }
        return max
    }
    
    private func setupPages() {
        // reset number of pages
        numberOfPages = dataSource?.numberOfPagesInTabScrollView(self) ?? 0
        
        // clear all caches
        cachedPageTabs.removeAll()
        for subview in tabSectionScrollView.subviews {
            subview.removeFromSuperview()
        }
        cachedPageContents.removeAll()
        for subview in contentSectionScrollView.subviews {
            subview.removeFromSuperview()
        }
        
        if (numberOfPages != 0) {
            // cache tabs and get the max height
            for i in 0 ..< numberOfPages {
                if let tabView = tabViewForPageAtIndex(i) {
                    cachedPageTabs[i] = tabView
                }
            }
            
            let tabSectionHeight = self.tabSectionHeight >= 0 ? self.tabSectionHeight : maxTabViewHeight
            let contentSectionHeight = self.frame.size.height - tabSectionHeight
            
            // setup tabs first, and set contents later (lazyLoadPages)
            var tabSectionScrollViewContentWidth: CGFloat = 0
            for i in 0 ..< numberOfPages {
                if let tabView = cachedPageTabs[i] {
                    tabView.frame = CGRect(
                        origin: CGPoint(
                            x: tabSectionScrollViewContentWidth,
                            y: 0),
                        size: tabView.frame.size)
                    
                    // bind event
                    tabView.tag = i
                    tabView.userInteractionEnabled = true
                    tabView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "tabViewDidClick:"))
                    tabSectionScrollView.addSubview(tabView)
                }
                tabSectionScrollViewContentWidth += widthForTabAtIndex(i)
            }
            // reset the fixed size of tab section
            let tabSectionFrameInsets = delegate?.tabSectionScrollViewFrameInset() ?? UIEdgeInsetsZero
            tabSectionScrollView.frame = CGRect(x: tabSectionFrameInsets.left,
                                                y: 0,
                                                width: self.frame.size.width - tabSectionFrameInsets.left - tabSectionFrameInsets.right,
                                                height: tabSectionHeight)
            
            tabSectionScrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "tabSectionScrollViewDidClick:"))
            tabSectionScrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: self.frame.width - widthForTabAtIndex(numberOfPages - 1))
            tabSectionScrollView.contentSize = CGSize(width: tabSectionScrollViewContentWidth, height: tabSectionHeight)
            
            // reset the fixed size of content section
            var contentScrollViewFrame: CGRect = CGRect(x: 0, y: tabSectionHeight, width: self.frame.size.width, height: contentSectionHeight)
            if delegate?.tabScrollViewContentViewFrameFillsViewBounds() == true {
                contentScrollViewFrame = CGRect(origin: .zero, size: self.frame.size)
            }
            contentSectionScrollView.frame = contentScrollViewFrame
            
            // reset the origin of arrow view
            arrowView.frame.origin = CGPoint(x: (self.frame.width - arrowView.frame.width) / 2, y: tabSectionHeight)
        }
    }
    
    private func updateTabAppearance(animated animated: Bool = true) {
        if (tabGradient) {
            if (numberOfPages != 0) {
                for i in 0 ..< numberOfPages {
                    var alpha: CGFloat = 1.0
                    
                    let offset = abs(i - pageIndex)
                    if (offset > 1) {
                        alpha = 0.2
                    } else if (offset > 0) {
                        alpha = 0.4
                    } else {
                        alpha = 1.0
                    }
                    
                    if let tab = self.cachedPageTabs[i] {
                        if (animated) {
                            UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.AllowUserInteraction, animations: {
                                tab.alpha = alpha
                                return
                            }, completion: nil)
                        } else {
                            tab.alpha = alpha
                        }
                    }
                }
            }
        }
    }
    
    private func moveToIndex(index: Int, animated: Bool) {
        if (index >= 0 && index < numberOfPages) {
            if (pagingEnabled) {
                // force stop
                stopScrolling()
                
                if (activedScrollView == nil || activedScrollView == tabSectionScrollView) {
                    activedScrollView = contentSectionScrollView
                    contentSectionScrollView.scrollRectToVisible(CGRect(
                        origin: CGPoint(x: self.frame.width * CGFloat(index), y: 0),
                        size: self.frame.size), animated: true)
                }
            }
            
            if (prevPageIndex != index) {
                prevPageIndex = index
                // callback
                delegate?.tabScrollView(self, didChangePageTo: index)
            }
        }
    }
    
    private func lazyLoadPages() {
        if (numberOfPages != 0) {
            let offset = 1
            let leftBoundIndex = pageIndex - offset > 0 ? pageIndex - offset : 0
            let rightBoundIndex = pageIndex + offset < numberOfPages ? pageIndex + offset : numberOfPages - 1
            
            var currentContentWidth: CGFloat = 0.0
            for i in 0 ..< numberOfPages {
                let width = self.frame.width
                if (i >= leftBoundIndex && i <= rightBoundIndex) {
                    let frame = CGRect(
                        x: currentContentWidth,
                        y: 0,
                        width: width,
                        height: contentSectionScrollView.frame.size.height)
                    insertPageAtIndex(i, frame: frame)
                }
                
                currentContentWidth += width
            }
            contentSectionScrollView.contentSize = CGSize(width: currentContentWidth, height: contentSectionScrollView.frame.height)
            
            // remove older caches
            while (cachedPageContents.count > realcachedPageLimit) {
                if let (_, view) = cachedPageContents.popFirst() {
                    view.removeFromSuperview()
                }
            }
        }
    }
    
    private func insertPageAtIndex(index: Int, frame: CGRect) {
        if (cachedPageContents[index] == nil) {
            if let view = contentViewForPageAtIndex(index) {
                view.frame = frame
                cachedPageContents[index] = view
                contentSectionScrollView.addSubview(view)
            }
        } else {
            cachedPageContents.awake(index)
        }
    }
    
}

public struct CacheQueue<Key: Hashable, Value> {
    
    var keys: Array<Key> = []
    var values: Dictionary<Key, Value> = [:]
    var count: Int {
        return keys.count
    }
    
    subscript(key: Key) -> Value? {
        get {
            return values[key]
        }
        set {
            // key/value pair exists, delete it first
            if let index = keys.indexOf(key) {
                keys.removeAtIndex(index)
            }
            // append key
            if (newValue != nil) {
                keys.append(key)
            }
            // set value
            values[key] = newValue
        }
    }
    
    mutating func awake(key: Key) {
        if let index = keys.indexOf(key) {
            keys.removeAtIndex(index)
            keys.append(key)
        }
    }
    
    mutating func popFirst() -> (Key, Value)? {
        let key = keys.removeFirst()
        if let value = values.removeValueForKey(key) {
            return (key, value)
        } else {
            return nil
        }
    }
    
    mutating func removeAll() {
        keys.removeAll()
        values.removeAll()
    }
    
}

class ArrowView : UIView {
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
    }
    
    var rect: CGRect!
    var arrorBackgroundColor: UIColor?
    
    var midX: CGFloat { return CGRectGetMidX(rect) }
    var midY: CGFloat { return CGRectGetMidY(rect) }
    var maxX: CGFloat { return CGRectGetMaxX(rect) }
    var maxY: CGFloat { return CGRectGetMaxY(rect) }
    
    override func drawRect(rect: CGRect) {
        self.rect = rect
        
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        CGContextBeginPath(ctx)
        CGContextMoveToPoint(ctx, 0, 0)
        CGContextAddQuadCurveToPoint(ctx, maxX * 0.12, 0, maxX * 0.2, maxY * 0.2)
        CGContextAddLineToPoint(ctx, midX - maxX * 0.05, maxY * 0.9)
        CGContextAddQuadCurveToPoint(ctx, midX, maxY, midX + maxX * 0.05, maxY * 0.9)
        CGContextAddLineToPoint(ctx, maxX * 0.8, maxY * 0.2)
        CGContextAddQuadCurveToPoint(ctx, maxX * 0.88, 0, maxX, 0)
        CGContextClosePath(ctx)
        
        CGContextSetFillColorWithColor(ctx, arrorBackgroundColor?.CGColor ?? UIColor.whiteColor().CGColor)
        CGContextFillPath(ctx);
    }
    
}
