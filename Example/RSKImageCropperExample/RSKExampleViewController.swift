//
// RSKExampleViewController.m
//
// Copyright (c) 2014-present Ruslan Skorb, http://ruslanskorb.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import UIKit

class RSKExampleViewController: UIViewController, RSKImageCropViewControllerDelegate {
    let kPhotoDiameter = CGFloat(130.0)
    let kPhotoFrameViewPadding = CGFloat(2.0)
    
    var photoFrameView = UIView()
    var addPhotoButton = UIButton()
    var didSetupConstraints = false

    // #pragma mark - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = []
        
        self.navigationItem.title = "RSKImageCropper"
        
        // ---------------------------
        // Add the frame of the photo.
        // ---------------------------
        
        self.photoFrameView.backgroundColor = UIColor(red:182/255.0, green:182/255.0, blue:187/255.0, alpha:1.0)
        self.photoFrameView.translatesAutoresizingMaskIntoConstraints = false
        self.photoFrameView.layer.masksToBounds = true
        self.photoFrameView.layer.cornerRadius = (kPhotoDiameter + kPhotoFrameViewPadding) / 2
        self.view.addSubview(self.photoFrameView)
        
        // ---------------------------
        // Add the button "add photo".
        // ---------------------------
        
        self.addPhotoButton.backgroundColor = UIColor.white
        self.addPhotoButton.translatesAutoresizingMaskIntoConstraints = false
        self.addPhotoButton.layer.masksToBounds = true
        self.addPhotoButton.layer.cornerRadius = kPhotoDiameter / 2
        self.addPhotoButton.imageView?.contentMode = .scaleAspectFit
        self.addPhotoButton.titleLabel?.lineBreakMode = .byWordWrapping
        self.addPhotoButton.titleLabel?.textAlignment = .center
        self.addPhotoButton.setTitle("add\nphoto", for: .normal)
        self.addPhotoButton.setTitleColor(UIColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0), for: .normal)
        self.addPhotoButton.addTarget(self, action: #selector(onAddPhotoButtonTouch), for: .touchUpInside)
        self.view.addSubview(self.addPhotoButton)
        
        // ----------------
        // Add constraints.
        // ----------------
        
        self.view.setNeedsUpdateConstraints()
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        if self.didSetupConstraints {
            return
        }
        
        // ---------------------------
        // The frame of the photo.
        // ---------------------------
        
        var constraint = NSLayoutConstraint(item: self.photoFrameView, attribute:.width, relatedBy:.equal,
                                                                         toItem:nil, attribute:.notAnAttribute, multiplier:1.0,
                                                                       constant:(kPhotoDiameter + kPhotoFrameViewPadding))
        self.photoFrameView.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(item: self.photoFrameView, attribute:.height, relatedBy:.equal,
                                                     toItem:nil, attribute:.notAnAttribute, multiplier:1.0,
                                                   constant:(kPhotoDiameter + kPhotoFrameViewPadding))
        self.photoFrameView.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(item: self.photoFrameView, attribute:.centerX, relatedBy:.equal,
                                                     toItem:self.view, attribute:.centerX, multiplier:1.0,
                                                   constant:0.0)
        self.view.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(item: self.photoFrameView, attribute:.centerY, relatedBy:.equal,
                                                     toItem:self.view, attribute:.centerY, multiplier:1.0,
                                                   constant:0.0)
        self.view.addConstraint(constraint)
        
        // ---------------------------
        // The button "add photo".
        // ---------------------------
        
        constraint = NSLayoutConstraint(item: self.addPhotoButton, attribute:.width, relatedBy:.equal,
                                                     toItem:nil, attribute:.notAnAttribute, multiplier:1.0,
                                                   constant:kPhotoDiameter)
        self.addPhotoButton.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(item: self.addPhotoButton, attribute:.height, relatedBy:.equal,
                                                     toItem:nil, attribute:.notAnAttribute, multiplier:1.0,
                                                   constant:kPhotoDiameter)
        self.addPhotoButton.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(item: self.addPhotoButton, attribute:.centerX, relatedBy:.equal,
                                                     toItem:self.photoFrameView, attribute:.centerX, multiplier:1.0,
                                                   constant:0.0)
        self.view.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(item: self.addPhotoButton, attribute:.centerY, relatedBy:.equal,
                                                     toItem:self.photoFrameView, attribute:.centerY, multiplier:1.0,
                                                   constant:0.0)
        self.view.addConstraint(constraint)
        
        self.didSetupConstraints = true
    }

    // #pragma mark - Action handling

    func onAddPhotoButtonTouch(sender: UIButton) {
        let photo = UIImage(named: "photo")!
        let imageCropVC = RSKImageCropViewController(image: photo, cropMode: .circle)
        imageCropVC.delegate = self
        self.navigationController?.pushViewController(imageCropVC, animated: true)
    }

    // #pragma mark - RSKImageCropViewControllerDelegate

    func didCancelCrop() {
        let _ = self.navigationController?.popViewController(animated: true)
    }

    func didCropImage(_ croppedImage: UIImage, usingCropRect cropRect: CGRect) {
        self.addPhotoButton.setImage(croppedImage, for: .normal)
        let _ = self.navigationController?.popViewController(animated: true)
    }
    
    func didCropImage(_ croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        self.addPhotoButton.setImage(croppedImage, for: .normal)
        let _ = self.navigationController?.popViewController(animated: true)
    }
    
    /**
     Tells the delegate that the original image will be cropped.
     */
    public func willCropImage(_ originalImage: UIImage) {
        
    }
}
