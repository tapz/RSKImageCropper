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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        edgesForExtendedLayout = []
        
        navigationItem.title = "RSKImageCropper"
        
        // ---------------------------
        // Add the frame of the photo.
        // ---------------------------
        
        photoFrameView.backgroundColor = UIColor(red: 182/255.0, green: 182/255.0, blue: 187/255.0, alpha: 1.0)
        photoFrameView.translatesAutoresizingMaskIntoConstraints = false
        photoFrameView.layer.masksToBounds = true
        photoFrameView.layer.cornerRadius = (kPhotoDiameter + kPhotoFrameViewPadding) / 2
        view.addSubview(photoFrameView)
        
        // ---------------------------
        // Add the button "add photo".
        // ---------------------------
        
        addPhotoButton.backgroundColor = UIColor.white
        addPhotoButton.translatesAutoresizingMaskIntoConstraints = false
        addPhotoButton.layer.masksToBounds = true
        addPhotoButton.layer.cornerRadius = kPhotoDiameter / 2
        addPhotoButton.imageView?.contentMode = .scaleAspectFit
        addPhotoButton.titleLabel?.lineBreakMode = .byWordWrapping
        addPhotoButton.titleLabel?.textAlignment = .center
        addPhotoButton.setTitle("add\nphoto", for: .normal)
        addPhotoButton.setTitleColor(UIColor(red: 0/255.0, green: 122/255.0, blue: 255/255.0, alpha: 1.0), for: .normal)
        addPhotoButton.addTarget(self, action: #selector(onAddPhotoButtonTouch), for: .touchUpInside)
        view.addSubview(addPhotoButton)
        
        // ----------------
        // Add constraints.
        // ----------------
        
        view.setNeedsUpdateConstraints()
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        if didSetupConstraints {
            return
        }
        
        // ---------------------------
        // The frame of the photo.
        // ---------------------------
        
        var constraint = NSLayoutConstraint(
            item: photoFrameView,
            attribute:.width,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: (kPhotoDiameter + kPhotoFrameViewPadding))
        
        photoFrameView.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(
            item: photoFrameView,
            attribute:.height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant:(kPhotoDiameter + kPhotoFrameViewPadding))
        
        photoFrameView.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(
            item: photoFrameView,
            attribute:.centerX,
            relatedBy:.equal,
            toItem: view,
            attribute: .centerX,
            multiplier: 1.0,
            constant: 0.0)
        
        view.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(
            item: photoFrameView,
            attribute:.centerY,
            relatedBy:.equal,
            toItem: view,
            attribute: .centerY,
            multiplier: 1.0,
            constant: 0.0)
        
        view.addConstraint(constraint)
        
        // ---------------------------
        // The button "add photo".
        // ---------------------------
        
        constraint = NSLayoutConstraint(
            item: addPhotoButton,
            attribute:.width,
            relatedBy:.equal,
            toItem: nil,
            attribute:
            .notAnAttribute,
            multiplier: 1.0,
            constant: kPhotoDiameter)
        
        addPhotoButton.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(
            item: self.addPhotoButton,
            attribute:.height,
            relatedBy:.equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant:kPhotoDiameter)
        
        addPhotoButton.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(
            item: self.addPhotoButton,
            attribute:.centerX,
            relatedBy:.equal,
            toItem: photoFrameView,
            attribute: .centerX,
            multiplier: 1.0,
            constant: 0.0)
        
        view.addConstraint(constraint)
        
        constraint = NSLayoutConstraint(
            item: self.addPhotoButton,
            attribute:.centerY,
            relatedBy:.equal,
            toItem: photoFrameView,
            attribute: .centerY,
            multiplier: 1.0,
            constant: 0.0)
        
        view.addConstraint(constraint)
        
        didSetupConstraints = true
    }

    // MARK: - Action handling

    func onAddPhotoButtonTouch(sender: UIButton) {
        let photo = UIImage(named: "photo")!
        let imageCropVC = RSKImageCropViewController(image: photo, cropMode: .circle)
        imageCropVC.delegate = self
        navigationController?.pushViewController(imageCropVC, animated: true)
    }

    // MARK: - RSKImageCropViewControllerDelegate

    func didCancelCrop() {
        let _ = navigationController?.popViewController(animated: true)
    }

    func didCropImage(_ croppedImage: UIImage, usingCropRect cropRect: CGRect) {
        addPhotoButton.setImage(croppedImage, for: .normal)
        let _ = navigationController?.popViewController(animated: true)
    }
    
    func didCropImage(_ croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        addPhotoButton.setImage(croppedImage, for: .normal)
        let _ = navigationController?.popViewController(animated: true)
    }
    
    /**
     Tells the delegate that the original image will be cropped.
     */
    public func willCropImage(_ originalImage: UIImage) {
        
    }
}
