//
//  SampleDataViewController.swift
//  YMStretchableHeaderTabViewController
//
//  Created by Zhang Yuanming on 4/30/17.
//  Copyright © 2017 None. All rights reserved.
//

import UIKit

class SampleDataViewController: UITableViewController {

    var datas: [String] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        tableView.rowHeight = 44
        tableView.reloadData()
//        tableView.contentSize.height = view.bounds.height
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return datas.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

//        if tableView.contentSize.height < view.bounds.height {
//            tableView.contentSize.height = view.bounds.height
//        }
        if 0 <= indexPath.row, indexPath.row < datas.count {
            let text = datas[indexPath.row]
            cell.textLabel?.text = text
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let numberOfRows = CGFloat(tableView.dataSource?.tableView(tableView, numberOfRowsInSection: section) ?? 0)

        if numberOfRows == 0 {
            return tableView.frame.height
        } else {
            let extralHeight = tableView.frame.height - numberOfRows * tableView.rowHeight - tableView.contentInset.bottom

            return max(0.01, extralHeight)
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.01
    }

}
