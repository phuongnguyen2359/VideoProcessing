//
//  SavedVideoViewController.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/9/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import UIKit
import AVKit

class SavedVideoViewController: UIViewController {
    var fileNames = [String]()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My collection"
        readFilesFromDirectory()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
    }
    
    func readFilesFromDirectory() {
        do {
            fileNames = try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()).reversed()
            tableView.reloadData()
        } catch {
            
        }
    }
    
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.dataSource = self
            tableView.delegate = self
        }
    }
    
    private func playVideo(at path: URL) {

        let playerViewController = AVPlayerViewController()
        let player = AVPlayer(url: path)
        playerViewController.player = player
        present(playerViewController, animated: true) {
            player.play()
        }
    }
}

extension SavedVideoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SavedVideoTableViewCell", for: indexPath) as! SavedVideoTableViewCell
        cell.videoName.text = fileNames[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var path = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        path.appendPathComponent(fileNames[indexPath.row])
        playVideo(at: path)
        
    }
}

class SavedVideoTableViewCell: UITableViewCell {
    
    @IBOutlet weak var videoName: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
}
