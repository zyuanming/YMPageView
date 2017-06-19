//
//  TVSwipeView.swift
//  TippleVa
//
//  Created by Zhang Yuanming on 6/19/17.
//  Copyright © 2017 baidu. All rights reserved.
//

import Foundation
import UIKit

enum SwipeViewAlignment {
    case edge
    case center
}

protocol TVSwipeViewDataSource {
    func numberOfItems(in swipeView: TVSwipeView) -> Int
    func swipeView(_ swipeView: TVSwipeView, viewForItemAt index: Int, reusing view: UIView?) -> UIView
}

@objc protocol TVSwipeViewDelegate {
    @objc optional func swipeViewItemSize(_ swipeView: TVSwipeView) -> CGSize
    @objc optional func swipeViewDidScroll(_ swipeView: TVSwipeView) -> Void
    @objc optional func swipeViewCurrentItemIndexDidChange(_ swipeView: TVSwipeView) -> Void
    @objc optional func swipeViewWillBeginDragging(_ swipeView: TVSwipeView) -> Void
    @objc optional func swipeViewDidEndDragging(_ swipeView: TVSwipeView, willDecelerate:Bool) -> Void
    @objc optional func swipeViewWillBeginDecelerating(_ swipeView: TVSwipeView) -> Void
    @objc optional func swipeViewDidEndDecelerating(_ swipeView: TVSwipeView) -> Void
    @objc optional func swipeViewDidEndScrollingAnimation(_ swipeView: TVSwipeView) -> Void
    @objc optional func shouldSelectItemAtIndex(_ index: Int, swipeView: TVSwipeView) -> Bool
    @objc optional func didSelectItemAtIndex(_ index: Int, swipeView: TVSwipeView) -> Void
}

class TVSwipeView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {

    fileprivate(set) var scrollView: UIScrollView
    fileprivate(set) var itemViews: [Int: UIView] = [:]
    fileprivate(set) var itemViewPool: [UIView] = []
    fileprivate(set) var previousItemIndex = 0
    fileprivate(set) var previousContentOffset = CGPoint.zero
    fileprivate(set) var itemSize = CGSize.zero
    fileprivate(set) var suppressScrollEvent = false
    fileprivate(set) var scrollDuration = 0.0
    fileprivate(set) var scrolling = false
    fileprivate(set) var startTime = 0.0
    fileprivate(set) var lastTime = 0.0
    fileprivate(set) var startOffset = 0.0 as CGFloat
    fileprivate(set) var endOffset = 0.0 as CGFloat
    fileprivate(set) var lastUpdateOffset = 0.0 as CGFloat
    fileprivate(set) var timer: Timer?
    fileprivate(set) var numberOfItems = 0
    private var _scrollOffset: CGFloat = 0
    fileprivate var scrollOffset: CGFloat {
        set {
            if (abs(self.scrollOffset - newValue) > 0.0001) {
                _scrollOffset = newValue
                lastUpdateOffset = newValue - 1.0; //force refresh
                scrolling = false; //stop scrolling
                updateItemSizeAndCount()
                updateScrollViewDimensions()
                updateLayout()
                let contentOffset = vertical
                    ? CGPoint(x: 0.0, y: clampedOffset(newValue) * itemSize.height)
                    : CGPoint(x: clampedOffset(newValue) * itemSize.width, y: 0.0)
                setContentOffsetWithoutEvent(contentOffset)
                didScroll()
            }
        }

        get {
            return _scrollOffset
        }
    }
    private var _currentItemIndex = 0
    fileprivate var currentItemIndex: Int {
        set {
            _currentItemIndex = newValue
            scrollOffset = CGFloat(currentItemIndex)
        }
        get {
            return _currentItemIndex
        }
    }
    var numberOfPages : Int {
        return Int(ceil(Double(numberOfItems) / Double(itemsPerPage)))
    }

    //MARK: - Settable properties:

    var defersItemViewLoading = false

    var dataSource: TVSwipeViewDataSource? {   // cannot be connected in IB at this time; must do it in code
        didSet {
            if (dataSource != nil) {
                reloadData()
            }
        }
    }
    var delegate: TVSwipeViewDelegate? {  // cannot be connected in IB at this time; must do it in code
        didSet {
            if (delegate != nil) {
                setNeedsLayout()
            }
        }
    }
    var itemsPerPage: Int = 1 {
        didSet {
            if (itemsPerPage != oldValue) {
                setNeedsLayout()
            }
        }
    }
    var truncateFinalPage: Bool = false {
        didSet {
            if (truncateFinalPage != oldValue) {
                setNeedsLayout()
            }
        }
    }
    var alignment: SwipeViewAlignment = SwipeViewAlignment.center {
        didSet {
            if (alignment != oldValue) {
                setNeedsLayout()
            }
        }
    }
    var pagingEnabled: Bool = true {
        didSet {
            if (pagingEnabled != oldValue) {
                self.scrollView.isPagingEnabled = pagingEnabled
                self.setNeedsLayout()
            }
        }
    }
    var scrollEnabled: Bool = true {
        didSet {
            if (scrollEnabled != oldValue) {
                self.scrollView.isScrollEnabled = scrollEnabled
            }
        }
    }
    var wrapEnabled: Bool = false {
        didSet {
            if (wrapEnabled != oldValue) {
                let previousOffset = self.clampedOffset(self.scrollOffset)
                scrollView.bounces = self.bounces && !wrapEnabled
                self.setNeedsLayout()
                self.scrollOffset = previousOffset
            }
        }
    }
    var delaysContentTouches: Bool = true {
        didSet {
            if (delaysContentTouches != oldValue) {
                scrollView.delaysContentTouches = delaysContentTouches
            }
        }
    }
    var bounces: Bool = true {
        didSet {
            if (bounces != oldValue) {
                scrollView.alwaysBounceHorizontal = !self.vertical && self.bounces
                scrollView.alwaysBounceVertical = self.vertical && self.bounces
                scrollView.bounces = self.bounces && !self.wrapEnabled
            }
        }
    }
    var decelerationRate: CGFloat = 0.0 {
        didSet {
            if (fabs(self.decelerationRate - oldValue) > 0.001) {
                scrollView.decelerationRate = decelerationRate
            }
        }
    }
    var autoscroll: CGFloat = 0.0 {
        didSet {
            if (fabs(self.autoscroll - oldValue) > 0.001) {
                if (autoscroll != 0) {
                    self.startAnimation()
                }
            }
        }
    }
    var vertical: Bool = false {
        didSet {
            if (vertical != oldValue) {
                scrollView.alwaysBounceHorizontal = !self.vertical && self.bounces
                scrollView.alwaysBounceVertical = self.vertical && self.bounces
                self.setNeedsLayout()
            }
        }
    }
    var currentPage: Int {
        get {
            if (itemsPerPage > 1
                && truncateFinalPage
                && !wrapEnabled
                && currentItemIndex > (numberOfItems / itemsPerPage - 1) * itemsPerPage) {
                return numberOfPages - 1
            }
            return Int(round(Double(currentItemIndex) / Double(itemsPerPage)))
        }

        set {
            if (currentPage * itemsPerPage != currentItemIndex) {
                scroll(toPage: currentPage, duration:0.0)
            }
        }
    }


    //MARK: - Initialization

    required init?(coder aDecoder: NSCoder) {
        self.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))    // will be modified later
        super.init(coder: aDecoder)
        setUp()
    }

    required override init(frame: CGRect) {
        self.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))    // will be modified later
        super.init(frame: frame)
        setUp()
    }

    func setUp() {
        self.clipsToBounds = true

        scrollView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        scrollView.autoresizesSubviews = true
        scrollView.delegate = self
        scrollView.delaysContentTouches = delaysContentTouches
        scrollView.bounces = bounces && !wrapEnabled
        scrollView.alwaysBounceHorizontal = !vertical && bounces
        scrollView.alwaysBounceVertical = vertical && bounces
        scrollView.isPagingEnabled = pagingEnabled
        scrollView.isScrollEnabled = scrollEnabled
        scrollView.decelerationRate = self.decelerationRate
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.scrollsToTop = false
        scrollView.clipsToBounds = false

        decelerationRate = scrollView.decelerationRate
        previousContentOffset = scrollView.contentOffset

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        tapGesture.delegate = self
        scrollView.addGestureRecognizer(tapGesture)

        //place scrollview at bottom of hierarchy
        self.insertSubview(scrollView, at: 0)

        if self.dataSource != nil {
            reloadData()
        }

    }

    deinit {
        if self.timer != nil {
            timer?.invalidate()
        }
    }

    func isDragging() -> Bool? {
        return scrollView.isDragging
    }

    func isDecelerating() -> Bool? {
        return scrollView.isDecelerating
    }

    //MARK: - View management

    func indexesForVisibleItems() -> Array<Int> {
        let unsortedIndexes = Array(itemViews.keys)

        return unsortedIndexes.sorted(by: <)
    }

    func visibleItemViews() -> Array<UIView> {
        let indexesSorted = self.indexesForVisibleItems()
        var resultArrayOfViews:[UIView] = Array()
        for thisIndex in indexesSorted {
            if let foundView = itemViews[thisIndex] {
                resultArrayOfViews.append(foundView)
            }
        }
        return resultArrayOfViews
    }

    func itemViewAtIndex(_ index: Int) -> UIView? {
        return self.itemViews[index]
    }

    func currentItemView() -> UIView? {
        return self.itemViewAtIndex(currentItemIndex)
    }

    /* This function gets the "index" of a view, but it's not the index in the context of any array, it's the "index" stored as a key in the dictionary, so we need to find the correct view and return the key.  There's probably a good way to do this with filter() and map(), but the set of elements in the dictionary is likely to be small, so we'll just iterate manually. */
    func indexOfItemView(_ view:UIView) -> Int? {

        for (theKey, theValue) in self.itemViews {
            if theValue === view {
                return theKey
            }
        }
        return nil
    }

    func indexOfItemViewOrSubview(_ view: UIView) -> Int? {
        let index = self.indexOfItemView(view)
        if (index == nil && view != scrollView) {
            // we didn't find the index, but the view is a valid view other than the scrollView, so maybe it's a subview of the indexed view.  Let's try to look up its superview instead:
            if let newViewToFind = view.superview {
                return self.indexOfItemViewOrSubview(newViewToFind)
            } else {
                return nil
            }
        }
        return index;
    }


    func setItemView(_ view: UIView, forIndex theIndex:Int) {
        itemViews[theIndex] = view
    }


    //MARK: - View layout
    func updateScrollOffset () {

        if (wrapEnabled)
        {
            let itemsWide = (numberOfItems == 1) ? 1.0: 3.0

            if (vertical)
            {
                let scrollHeight = scrollView.contentSize.height / CGFloat(itemsWide);
                if (scrollView.contentOffset.y < scrollHeight)
                {
                    previousContentOffset.y += scrollHeight;
                    setContentOffsetWithoutEvent(CGPoint(x: 0.0, y: scrollView.contentOffset.y + scrollHeight))
                }
                else if (scrollView.contentOffset.y >= scrollHeight * 2.0)
                {
                    previousContentOffset.y -= scrollHeight;
                    setContentOffsetWithoutEvent(CGPoint(x: 0.0, y: scrollView.contentOffset.y - scrollHeight))
                }
                _scrollOffset = clampedOffset(scrollOffset)
            }
            else
            {
                let scrollWidth = scrollView.contentSize.width / CGFloat(itemsWide)
                if (scrollView.contentOffset.x < scrollWidth)
                {
                    previousContentOffset.x += scrollWidth;
                    setContentOffsetWithoutEvent(CGPoint(x: scrollView.contentOffset.x + scrollWidth, y: 0.0))
                }
                else if (scrollView.contentOffset.x >= scrollWidth * 2.0)
                {
                    previousContentOffset.x -= scrollWidth;
                    setContentOffsetWithoutEvent(CGPoint(x: scrollView.contentOffset.x - scrollWidth, y: 0.0))
                }
                _scrollOffset = clampedOffset(scrollOffset)
            }
        }
        if (vertical && fabs(scrollView.contentOffset.x) > 0.0001)
        {
            setContentOffsetWithoutEvent(CGPoint(x: 0.0, y: scrollView.contentOffset.y))
        }
        else if (!vertical && fabs(scrollView.contentOffset.y) > 0.0001)
        {
            setContentOffsetWithoutEvent(CGPoint(x: scrollView.contentOffset.x, y: 0.0))
        }
    }

    func updateScrollViewDimensions () {

        var frame = self.bounds
        var contentSize = frame.size

        if (vertical)
        {
            contentSize.width -= (scrollView.contentInset.left + scrollView.contentInset.right);
        }
        else
        {
            contentSize.height -= (scrollView.contentInset.top + scrollView.contentInset.bottom);
        }


        switch (alignment) {
        case .center:
            if (vertical)
            {
                frame = CGRect(x:0.0, y:(self.bounds.size.height - itemSize.height * CGFloat(itemsPerPage))/2.0,
                               width:self.bounds.size.width, height:itemSize.height * CGFloat(itemsPerPage))
                contentSize.height = itemSize.height * CGFloat(numberOfItems)
            }
            else
            {
                frame = CGRect(x: (self.bounds.size.width - itemSize.width * CGFloat(itemsPerPage))/2.0,
                               y: 0.0, width: itemSize.width * CGFloat(itemsPerPage), height: self.bounds.size.height);
                contentSize.width = itemSize.width * CGFloat(numberOfItems)
            }

        case .edge:
            if (vertical)
            {
                frame = CGRect(x: 0.0, y: 0.0, width: self.bounds.size.width, height: itemSize.height * CGFloat(itemsPerPage))
                contentSize.height = itemSize.height * CGFloat(numberOfItems) - (self.bounds.size.height - frame.size.height);
            }
            else
            {
                frame = CGRect(x: 0.0, y: 0.0, width: itemSize.width * CGFloat(itemsPerPage), height: self.bounds.size.height);
                contentSize.width = itemSize.width * CGFloat(numberOfItems) - (self.bounds.size.width - frame.size.width)
            }
        }

        if (wrapEnabled)
        {
            let itemsWide = CGFloat((numberOfItems == 1) ? 1.0 : Double(numberOfItems) * 3.0)
            if (vertical)
            {
                contentSize.height = itemSize.height * itemsWide;
            }
            else
            {
                contentSize.width = itemSize.width * itemsWide;
            }
        }
        else if (pagingEnabled && !truncateFinalPage)
        {
            if (vertical)
            {
                contentSize.height = ceil(contentSize.height / frame.size.height) * frame.size.height;
            }
            else
            {
                contentSize.width = ceil(contentSize.width / frame.size.width) * frame.size.width;
            }
        }

        if (!scrollView.frame.equalTo(frame))
        {
            scrollView.frame = frame;
        }

        if (!scrollView.contentSize.equalTo(contentSize))
        {
            scrollView.contentSize = contentSize;
        }
    }

    func offsetForItemAtIndex(_ index:Int) -> CGFloat {

        //calculate relative position
        var offset = CGFloat(index) - scrollOffset
        if (wrapEnabled) {
            if (alignment == SwipeViewAlignment.center) {
                if (offset > CGFloat(numberOfItems)/2.0) {
                    offset -= CGFloat(numberOfItems)
                }
                else if (offset < -CGFloat(numberOfItems)/2.0) {
                    offset += CGFloat(numberOfItems)
                }
            } else {
                let width = vertical ? self.bounds.size.height : self.bounds.size.width
                let x = vertical ? scrollView.frame.origin.y : scrollView.frame.origin.x
                let itemWidth = vertical ? itemSize.height : itemSize.width
                if (offset * itemWidth + x > width) {
                    offset -= CGFloat(numberOfItems)
                }
                else if (offset * itemWidth + x < -itemWidth) {
                    offset += CGFloat(numberOfItems)
                }
            }
        }
        return offset;
    }

    func setFrameForView(_ view: UIView, atIndex index:Int) {

        if ((self.window) != nil) {
            var center = view.center
            if (vertical) {
                center.y = (offsetForItemAtIndex(index) + 0.5) * itemSize.height + scrollView.contentOffset.y;
            } else {
                center.x = (offsetForItemAtIndex(index) + 0.5) * itemSize.width + scrollView.contentOffset.x;
            }

            let disableAnimation = !center.equalTo(view.center)
            let animationEnabled = UIView.areAnimationsEnabled
            if (disableAnimation && animationEnabled) {
                UIView.setAnimationsEnabled(false)
            }
            if (vertical) {
                view.center = CGPoint(x: scrollView.frame.size.width/2.0, y: center.y)
            } else {
                view.center = CGPoint(x: center.x, y: scrollView.frame.size.height/2.0)
            }

            view.bounds = CGRect(x: 0.0, y: 0.0, width: itemSize.width, height: itemSize.height)

            if (disableAnimation && animationEnabled) {
                UIView.setAnimationsEnabled(true)
            }
        }
    }

    func layOutItemViews()  {
        let visibleViews = self.visibleItemViews()
        for view in visibleViews {
            if let theIndex = self.indexOfItemView(view) {
                setFrameForView(view, atIndex:theIndex)
            }
        }
    }

    func updateLayout() {
        updateScrollOffset()
        loadUnloadViews()
        layOutItemViews()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateItemSizeAndCount()
        updateScrollViewDimensions()
        updateLayout()
        if pagingEnabled && !scrolling {
            scrollToItemAtIndex(self.currentItemIndex, duration:0.25)
        }
    }

    //MARK: - View queing

    func queueItemView(_ view: UIView) {
        itemViewPool.append(view)
    }

    func dequeueItemView() -> UIView? {
        if itemViewPool.count <= 0 {
            return nil
        }
        let view = itemViewPool.removeLast()
        return view
    }

    //MARK: - Scrolling

    func didScroll() {
        //handle wrap
        updateScrollOffset()

        //update view
        layOutItemViews()
        delegate?.swipeViewDidScroll?(self)

        if (!defersItemViewLoading || (fabs(minScrollDistanceFromOffset(lastUpdateOffset, toOffset:scrollOffset)) >= 1.0)) {
            //update item index
            _currentItemIndex = clampedIndex(Int(roundf(Float(scrollOffset))))

            //load views
            lastUpdateOffset = CGFloat(currentItemIndex)
            loadUnloadViews()

            //send index update event
            if (previousItemIndex != currentItemIndex) {
                previousItemIndex = currentItemIndex
                delegate?.swipeViewCurrentItemIndexDidChange?(self)
            }
        }
    }

    func easeInOut(_ time: CGFloat) -> CGFloat {
        return (time < 0.5) ? 0.5 * pow(time * 2.0, 3.0) : 0.5 * pow(time * 2.0 - 2.0, 3.0) + 1.0
    }

    func step() {

        let currentTime = CFAbsoluteTimeGetCurrent()
        var delta = CGFloat(lastTime - currentTime)
        self.lastTime = currentTime

        if (scrolling) {
            let time = CGFloat(fmin(1.0, (currentTime - startTime) / scrollDuration))
            delta = easeInOut(time)
            _scrollOffset = clampedOffset(startOffset + (endOffset - startOffset) * delta)
            if (vertical) {
                setContentOffsetWithoutEvent(CGPoint(x: 0.0, y: scrollOffset * itemSize.height))
            } else {
                setContentOffsetWithoutEvent(CGPoint(x: scrollOffset * itemSize.width, y: 0.0))
            }
            didScroll()
            if (time == 1.0) {
                scrolling = false
                didScroll()
                delegate?.swipeViewDidEndScrollingAnimation?(self)
            }
        } else if (autoscroll != 0.0) {
            if (!scrollView.isDragging) {
                self.scrollOffset = clampedOffset(scrollOffset + delta * autoscroll)
            }
        } else {
            stopAnimation()
        }
    }

    func startAnimation() {
        if (timer == nil) {
            self.timer = Timer(timeInterval: 1.0/60.0, target: self, selector: #selector(step), userInfo: nil, repeats: true)
            RunLoop.main.add(timer!, forMode:RunLoopMode.defaultRunLoopMode)
            RunLoop.main.add(timer!, forMode:RunLoopMode.UITrackingRunLoopMode)
        }
    }

    func stopAnimation() {
        if timer != nil {
            timer!.invalidate()
            self.timer = nil;
        }
    }

    func clampedIndex(_ index: Int) -> Int {
        if (wrapEnabled) {
            if numberOfItems != 0 {
                return index - Int(CGFloat(floor(CGFloat(index) / CGFloat(numberOfItems))) * CGFloat(numberOfItems))
            } else {
                return 0
            }
        } else {
            return min(max(0, index), max(0, numberOfItems - 1))
        }
    }

    func clampedOffset(_ offset: CGFloat) -> CGFloat {
        var returnValue = CGFloat(0)
        if (wrapEnabled) {
            if numberOfItems != 0 {
                returnValue =  (offset - floor(offset / CGFloat(numberOfItems)) * CGFloat(numberOfItems))
            } else {
                returnValue = 0.0
            }
        } else {
            returnValue = fmin(fmax(0.0, offset), fmax(0.0, CGFloat(numberOfItems) - 1.0))
        }
        return returnValue;
    }

    func setContentOffsetWithoutEvent(_ contentOffset:CGPoint) {
        if (!scrollView.contentOffset.equalTo(contentOffset))
        {
            let animationEnabled = UIView.areAnimationsEnabled
            if (animationEnabled) {
                UIView.setAnimationsEnabled(false)
            }
            suppressScrollEvent = true
            scrollView.contentOffset = contentOffset
            suppressScrollEvent = false
            if (animationEnabled) {
                UIView.setAnimationsEnabled(true)
            }
        }
    }

    func minScrollDistanceFromIndex(_ fromIndex: Int, toIndex:Int) -> Int {
        let directDistance = toIndex - fromIndex
        if (wrapEnabled) {
            var wrappedDistance = min(toIndex, fromIndex) + numberOfItems - max(toIndex, fromIndex)
            if (fromIndex < toIndex) {
                wrappedDistance = -wrappedDistance
            }
            return (abs(directDistance) <= abs(wrappedDistance)) ? directDistance : wrappedDistance
        }
        return directDistance;
    }

    func minScrollDistanceFromOffset(_ fromOffset:CGFloat, toOffset:CGFloat) -> CGFloat {
        let directDistance = toOffset - fromOffset
        if (wrapEnabled) {
            var wrappedDistance = min(toOffset, fromOffset) + CGFloat(numberOfItems) - max(toOffset, fromOffset)
            if (fromOffset < toOffset) {
                wrappedDistance = -wrappedDistance
            }
            return (abs(directDistance) <= abs(wrappedDistance)) ? directDistance : wrappedDistance
        }
        return directDistance;
    }

    func scrollByOffset(_ offset: CGFloat, duration:TimeInterval) {
        if (duration > 0.0) {
            scrolling = true
            startTime = Date.timeIntervalSinceReferenceDate
            startOffset = scrollOffset
            scrollDuration = duration
            endOffset = startOffset + offset
            if (!wrapEnabled) {
                endOffset = clampedOffset(endOffset)
            }
            startAnimation()
        } else {
            self.scrollOffset = self.scrollOffset + offset
        }
    }

    func scrollToOffset(_ offset: CGFloat, duration:TimeInterval) {
        scrollByOffset(minScrollDistanceFromOffset(scrollOffset, toOffset:offset), duration:duration)
    }

    func scrollByNumberOfItems(_ itemCount: Int, duration:TimeInterval) {
        if (duration > 0.0) {
            var offset = Float(0.0)
            if (itemCount > 0) {
                offset = floorf(Float(scrollOffset)) + Float(itemCount) - Float(scrollOffset)
            } else if (itemCount < 0) {
                offset = ceilf(Float(scrollOffset)) + Float(itemCount) - Float(scrollOffset)
            } else {
                offset = roundf(Float(scrollOffset)) - Float(scrollOffset)
            }
            scrollByOffset(CGFloat(offset), duration:duration)
        } else {
            self.scrollOffset = CGFloat(clampedIndex(previousItemIndex + itemCount))
        }
    }


    func scrollToItemAtIndex(_ index:Int, duration:TimeInterval) {
        scrollToOffset(CGFloat(index), duration:duration)
    }

    func scroll(toPage page: Int, duration:TimeInterval) {
        var index = page * itemsPerPage
        if (truncateFinalPage) {
            index = min(index, numberOfItems - itemsPerPage)
        }
        scrollToItemAtIndex(index, duration:duration)
    }

    //MARK: - View loading

    func loadViewAtIndex(_ index: Int) -> UIView {
        let view = dataSource?.swipeView(self, viewForItemAt: index, reusing: dequeueItemView())

        let oldView = itemViewAtIndex(index)
        if (oldView != nil) {
            queueItemView(oldView!)
            oldView!.removeFromSuperview()
        }

        setItemView(view!, forIndex:index)
        setFrameForView(view!, atIndex:index)
        view!.isUserInteractionEnabled = true
        scrollView.addSubview(view!)

        return view!
    }

    func updateItemSizeAndCount() {
        //get number of items
        numberOfItems = (dataSource?.numberOfItems(in: self))!

        //get item size
        let size = delegate?.swipeViewItemSize?(self)
        if (!size!.equalTo(CGSize.zero)) {
            itemSize = size!
        } else if (numberOfItems > 0) {
            if self.visibleItemViews().count <= 0 {
                let view = dataSource?.swipeView(self, viewForItemAt: 0, reusing: dequeueItemView())
                itemSize = view!.frame.size
            }
        }

        //prevent crashes
        if (itemSize.width < 0.0001) { itemSize.width = 1 }
        if (itemSize.height < 0.0001) { itemSize.height = 1 }
    }

    func loadUnloadViews() {

        //check that item size is known
        let itemWidth = vertical ? itemSize.height : itemSize.width
        if (itemWidth != 0) {
            //calculate offset and bounds
            let width = vertical ? self.bounds.size.height : self.bounds.size.width
            let x = vertical ? scrollView.frame.origin.y : scrollView.frame.origin.x

            //calculate range
            let startOffset = clampedOffset(scrollOffset - x / itemWidth)
            var startIndex = Int(floor(startOffset))
            var numberOfVisibleItems = Int(ceil(width / itemWidth + (startOffset - CGFloat(startIndex))))
            if (defersItemViewLoading) {
                startIndex = currentItemIndex - Int(ceil(x / itemWidth)) - 1
                numberOfVisibleItems = Int(ceil(width / itemWidth) + 3)
            }

            //create indices
            numberOfVisibleItems = min(numberOfVisibleItems, numberOfItems)
            var visibleIndices = [Int]()

            for i in 0 ..< numberOfVisibleItems {
                let index = clampedIndex(i + startIndex)
                visibleIndices.append(index)
            }

            //remove offscreen views
            for number in Array(itemViews.keys) {
                if (!visibleIndices.contains(number)) {
                    let view = itemViews[number]
                    if (view != nil) {
                        queueItemView(view!)
                        view!.removeFromSuperview()
                        itemViews.removeValue(forKey: number)
                    }
                }
            }

            //add onscreen views
            for number in visibleIndices {
                let view = itemViews[number]
                if (view == nil) {
                    loadViewAtIndex(number)
                }
            }
        }
    }

    func reloadItemAtIndex(_ index:Int) {
        //if view is visible
        if (itemViewAtIndex(index) != nil) {
            //reload view
            loadViewAtIndex(index)
        }
    }

    func reloadData() {
        //remove old views
        for view in self.visibleItemViews() {
            view.removeFromSuperview()
        }

        //reset view pools
        itemViews = Dictionary(minimumCapacity: 4)
        itemViewPool = Array()

        //get number of items
        updateItemSizeAndCount()

        //layout views
        setNeedsLayout()

        //fix scroll offset
        if (numberOfItems > 0 && scrollOffset < 0.0) {
            self.scrollOffset = 0
        }
    }

    override func hitTest(_ point: CGPoint, with event:UIEvent?) -> UIView? {

        var view = super.hitTest(point, with:event)
        if (view == nil) {
            return view
        }
        if (view!.isEqual(self)) {
            for subview in scrollView.subviews {
                let offset = CGPoint(x: point.x - scrollView.frame.origin.x + scrollView.contentOffset.x - subview.frame.origin.x,
                                     y: point.y - scrollView.frame.origin.y + scrollView.contentOffset.y - subview.frame.origin.y);
                view = subview.hitTest(offset, with:event)
                if (view != nil)
                {
                    return view
                }
            }
            return scrollView
        }
        return view
    }

    override func didMoveToSuperview() {
        if (self.superview != nil) {
            self.setNeedsLayout()
            if scrolling {
                startAnimation()
            }
        } else {
            stopAnimation()
        }
    }

    //MARK: - Gestures and taps

    func viewOrSuperviewIndex(_ view: UIView) -> Int? {

        if (view == scrollView) {
            return nil
        }
        let index = self.indexOfItemView(view)
        if (index == nil)
        {
            if (view.superview == nil) {
                return nil
            }
            return viewOrSuperviewIndex(view.superview!)
        }
        return index;
    }

    func viewOrSuperviewHandlesTouches(_ view:UIView) -> Bool {
        // This implementation is pretty different from the original, because many of the class-exposure methods are not present in Swift.  The original seems needlessly complex, checking all the superclasses of the view as well.
        if view.responds(to: #selector(UIResponder.touchesBegan(_:with:))) {
            return true
        } else {
            if let theSuperView = view.superview {
                return self.viewOrSuperviewHandlesTouches(theSuperView)
            } else {
                // there's no superview to check, so nothing in the hierarchy can respond.
                return false
            }
        }
    }

    func gestureRecognizer(_ gesture: UIGestureRecognizer, shouldReceive touch:UITouch) -> Bool {
        if (gesture is UITapGestureRecognizer) {
            //handle tap
            let index = viewOrSuperviewIndex(touch.view!)
            if (index != nil) {
                var delegateExistsAndDeclinesSelection = false
                if (delegate != nil) {
                    if let delegateWantsItemSelection = delegate!.shouldSelectItemAtIndex?(index!, swipeView: self) {
                        // delegate is valid and responded to the shouldSelectItemAtIndex selector
                        delegateExistsAndDeclinesSelection = !delegateWantsItemSelection
                    }
                }
                if delegateExistsAndDeclinesSelection ||
                    self.viewOrSuperviewHandlesTouches(touch.view!) {
                    return false
                } else {
                    return true
                }
            }
        }
        return false
    }

    func didTap (_ tapGesture: UITapGestureRecognizer) {
        let point = tapGesture.location(in: scrollView)
        var index = Int(vertical ? (point.y / (itemSize.height)) : (point.x / (itemSize.width)))
        if (wrapEnabled) {
            index = index % numberOfItems
        }
        if (index >= 0 && index < numberOfItems) {
            delegate?.didSelectItemAtIndex?(index, swipeView: self)
        }
    }

    //MARK: - UIScrollViewDelegate methods

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (!suppressScrollEvent) {
            //stop scrolling animation
            scrolling = false

            //update scrollOffset
            let delta = vertical ? (scrollView.contentOffset.y - previousContentOffset.y) : (scrollView.contentOffset.x - previousContentOffset.x)
            previousContentOffset = scrollView.contentOffset
            _scrollOffset += delta / (vertical ? itemSize.height : itemSize.width)

            //update view and call delegate
            didScroll()
        } else {
            previousContentOffset = scrollView.contentOffset
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.swipeViewWillBeginDragging?(self)

        //force refresh
        lastUpdateOffset = self.scrollOffset - 1.0
        didScroll()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate:Bool) {
        if (!decelerate) {
            //force refresh
            lastUpdateOffset = self.scrollOffset - 1.0
            didScroll()
        }
        delegate?.swipeViewDidEndDragging?(self, willDecelerate:decelerate)
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        delegate?.swipeViewWillBeginDecelerating?(self)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        //prevent rounding errors from accumulating
        let integerOffset = CGFloat(round(scrollOffset))
        if (fabs(scrollOffset - integerOffset) < 0.01) {
            _scrollOffset = integerOffset
        }

        //force refresh
        lastUpdateOffset = self.scrollOffset - 1.0
        didScroll()
        
        delegate?.swipeViewDidEndDecelerating?(self)
    }
    
}



