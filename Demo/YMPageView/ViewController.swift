//
//  ViewController.swift
//  YMPageView
//
//  Created by Zhang Yuanming on 6/19/17.
//  Copyright © 2017 None. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    lazy var firstVC: SampleDataViewController = {
        let vc = SampleDataViewController()
        vc.datas = ["hello", "hi", "very good", "yes.", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten...", "elevent", "bgqwwwwwiu1`ss1 ", "123yeo", "you are", "i am", "hello word", "hi"]

        return vc
    }()

    lazy var secondVC: SampleDataViewController = {
        let vc = SampleDataViewController()
        vc.datas = ["1", "2", "very 4", "6.", "one", "two", "three", "four", "five", "six", "5", "eight", "0", "ten...", "8", "bgqwwwwwiu1`ss1 ", "123yeo", "you are", "i am", "hello word", "09"]

        return vc
    }()

    lazy var swipeView: TVPageView = {
        let swipeView = TVPageView()
        swipeView.backgroundColor = UIColor.white
        swipeView.dataSource = self
        swipeView.delegate = self

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

extension ViewController: TVPageViewDataSource, TVPageViewDelegate {
    // MARK: - SwipeViewDataSource, SwipeViewDelegate

    func numberOfItems(in swipeView: TVPageView) -> Int {
        return 2
    }

    func swipeView(_ pageView: TVPageView, viewForItemAt index: Int) -> UIView {
        if index == 0 {
            firstVC.didMove(toParentViewController: self)
            return firstVC.view
        } else {
            secondVC.didMove(toParentViewController: self)
            return secondVC.view
        }
    }

    func pageView(_ pageView: TVPageView, didScrollTo index: Int) {

    }
}

