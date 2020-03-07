//
//  MainViewController+OpenVideoLibrary.swift
//  VideoProcessing
//
//  Created by Tran Thi Cam Giang on 3/7/20.
//  Copyright © 2020 Tran Thi Cam Giang. All rights reserved.
//

import UIKit
import AVKit
import MobileCoreServices

extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
            mediaType == (kUTTypeMovie as String),
            let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL else { return }
        
        print(url)
        dismiss(animated: true) {
            self.didSelectVideo?(url)
        }
    }
    
    func openVideoBrowser(sourceType: UIImagePickerController.SourceType, delegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            return
        }
        
        let pickerVC = UIImagePickerController()
        pickerVC.sourceType = sourceType
        pickerVC.mediaTypes = [kUTTypeMovie as String]
        pickerVC.allowsEditing = false
        pickerVC.delegate = delegate
        self.present(pickerVC, animated: true, completion: nil)
    }
}
