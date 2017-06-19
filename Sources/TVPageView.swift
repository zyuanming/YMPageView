//
//  TVPageView.swift
//  TippleVa
//
//  Created by Zhang Yuanming on 6/19/17.
//  Copyright © 2017 baidu. All rights reserved.
//

import Foundation
import UIKit

protocol TVPageViewDataSource: NSObjectProtocol {
    func numberOfItems(in pageView: TVPageView) -> Int
    func swipeView(_ pageView: TVPageView, viewForItemAt index: Int) -> UIView
}

protocol TVPageViewDelegate: NSObjectProtocol {
    func pageView(_ pageView: TVPageView, didScrollTo index: Int)
}

class TVPageView: UIView {

    weak var delegate: TVPageViewDelegate?
    weak var dataSource: TVPageViewDataSource? {
        didSet {
            addContainerView()
            _selectedIndex = 0
            showSelectedPage()
        }
    }
    var scrollView = UIScrollView()
    fileprivate var segmentedBackgroundViews: [UIView] = []
    fileprivate var _selectedIndex = 0

    var selectedIndex: Int {
        get { return _selectedIndex }
        set {
            showSelectedViewController(at: newValue, animated: true)
            _selectedIndex = newValue
        }
    }


    // MARK: - LifeCycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.white
        addPrivateViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        scrollView.delegate = nil
    }

    fileprivate func addPrivateViews() {
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.bounces = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[v]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["v": scrollView]))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[v]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["v": scrollView]))
    }

    fileprivate func addContainerView() {
        segmentedBackgroundViews.removeAll()

        guard let numberOfItems = dataSource?.numberOfItems(in: self) else { return }

        var horizontalConstraintsFormat = "H:|"
        var viewsDict: [String: UIView] = ["ancestorView": scrollView]
        for index in 0..<numberOfItems {
            let pageBackgroundView = UIView()
            segmentedBackgroundViews.append(pageBackgroundView)
            pageBackgroundView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(pageBackgroundView)
            scrollView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[subview(==ancestorView)]|", options: [], metrics: nil, views: ["subview": pageBackgroundView, "ancestorView": scrollView]))

            viewsDict["v\(index)"] = pageBackgroundView
            horizontalConstraintsFormat += "[v\(index)(==ancestorView)]"
        }

        horizontalConstraintsFormat += "|"
        scrollView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: horizontalConstraintsFormat, options: [], metrics: nil, views: viewsDict))

    }

    func showSelectedPage() {
        loadSubControllerIfNeeded()
        scrollToPageAtIndex(selectedIndex)
    }

    func loadSubControllerIfNeeded(_ index: Int? = nil) {
        guard let numberOfItems = dataSource?.numberOfItems(in: self) else { return }

        let currentIndex = index ?? selectedIndex

        if 0 <= currentIndex && currentIndex < numberOfItems {
            let backgroundView = segmentedBackgroundViews[currentIndex]
            backgroundView.subviews.forEach { $0.removeFromSuperview() }
            let targetView = dataSource?.swipeView(self, viewForItemAt: currentIndex) ?? UIView()
            backgroundView.addSubview(targetView)
            targetView.translatesAutoresizingMaskIntoConstraints = false
            backgroundView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[v]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["v": targetView]))
            backgroundView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[v]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["v": targetView]))
        }
    }


    func scrollToPageAtIndex(_ index: Int, animated: Bool = false) {

        var scrollBounds = self.scrollView.bounds
        scrollBounds.origin = CGPoint(x: CGFloat(index) * self.scrollView.bounds.width, y: 0)

        let newIndex = index

        scrollView.setContentOffset(CGPoint(x: scrollView.bounds.width * CGFloat(index), y: 0), animated: false)


        if animated {
            let oldIndex = Int(scrollView.contentOffset.x / scrollView.frame.width)
            guard let newTargetView = dataSource?.swipeView(self, viewForItemAt: newIndex),
                let oldTargetView = dataSource?.swipeView(self, viewForItemAt: oldIndex)
            else { return }

            let shiftX = newIndex > oldIndex ? scrollView.bounds.width : -scrollView.bounds.width
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                self.delegate?.pageView(self, didScrollTo: index)
            }
            let oldViewFromValue = CGFloat(newIndex - oldIndex) * scrollView.bounds.width
            let oldViewToValue = CGFloat(newIndex - oldIndex - (newIndex > oldIndex ? 1 : -1)) * scrollView.bounds.width

            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = NSNumber(value: Double(shiftX) as Double)
            animation.toValue = NSNumber(value: 0 as Double)
            animation.duration = 0.3
            animation.beginTime = 0.0
            animation.isRemovedOnCompletion = true

            newTargetView.layer.add(animation, forKey: "shift")

            let animation2 = CABasicAnimation(keyPath: "transform.translation.x")
            animation2.fromValue = NSNumber(value: Double(oldViewFromValue) as Double)
            animation2.toValue = NSNumber(value: Double(oldViewToValue) as Double)
            animation2.duration = 0.3
            animation2.beginTime = 0.0
            animation2.isRemovedOnCompletion = true

            oldTargetView.layer.add(animation2, forKey: "shift")
            CATransaction.commit()
        } else {
            self.delegate?.pageView(self, didScrollTo: index)
        }

    }

    func showSelectedViewController(at index: Int, animated: Bool) {
        if selectedIndex != index {
            loadSubControllerIfNeeded()
            scrollToPageAtIndex(index, animated: animated)
            _selectedIndex = index
        }
    }

}



// MARK: - UIScrollViewDelegate

extension TVPageView: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        let offset = scrollView.contentOffset.x / scrollView.bounds.width
        let currentPageIndex = Int(offset + 0.5)
        if _selectedIndex != currentPageIndex {
            loadSubControllerIfNeeded(currentPageIndex)
            _selectedIndex = currentPageIndex
        }

        if offset == trunc(offset) {
            delegate?.pageView(self, didScrollTo: currentPageIndex)
        }
    }

}


