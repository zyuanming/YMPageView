//
//  SecondViewController.swift
//  YMPageView
//
//  Created by Zhang Yuanming on 6/19/17.
//  Copyright © 2017 None. All rights reserved.
//

import Foundation
import UIKit

class SecondViewController: UIViewController {
    lazy var firstVC: SampleDataViewController = {
        let vc = SampleDataViewController()
        vc.datas = "1,2,3,4,5,6,7,8,9,2,3,9,2,3,2,3,2".components(separatedBy: ",")

        return vc
    }()

    lazy var secondVC: SampleDataViewController = {
        let vc = SampleDataViewController()
        vc.datas = "as asd 2eio asd asd asld ,asmd lkasd oi oi ok lk ,m lk oi u yu 12 87 ".components(separatedBy: " ")

        return vc
    }()

    lazy var swipeView: TVSwipeView = {
        let swipeView = TVSwipeView()
        swipeView.backgroundColor = UIColor.white
        swipeView.delegate = self
        swipeView.dataSource = self


        return swipeView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.addSubview(swipeView)
        swipeView.frame = self.view.bounds
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension SecondViewController: TVSwipeViewDataSource, TVSwipeViewDelegate {
    // MARK: - SwipeViewDataSource, SwipeViewDelegate

    func numberOfItems(in swipeView: TVSwipeView) -> Int {
        return 2
    }

    func swipeView(_ swipeView: TVSwipeView, viewForItemAt index: Int, reusing view: UIView?) -> UIView {
        if index == 0 {
            firstVC.didMove(toParentViewController: self)
            return firstVC.view
        } else {
            secondVC.didMove(toParentViewController: self)
            return secondVC.view
        }
    }

    func swipeViewItemSize(_ swipeView: TVSwipeView) -> CGSize {
        return view.bounds.size
    }

    func swipeViewDidScroll(_ swipeView: TVSwipeView) {
        
    }

}




