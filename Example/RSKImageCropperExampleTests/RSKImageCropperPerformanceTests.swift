//
// RSKImageCropperPerformanceTests.m
//
// Copyright (c) 2015 Ruslan Skorb, http://ruslanskorb.com/
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

import XCTest
@testable import RSKImageCropperExample

class RSKImageCropViewControllerTests: XCTestCase {
    var imageCropViewController: RSKImageCropViewController?

    override func setUp() {
        super.setUp()
        
        self.imageCropViewController = RSKImageCropViewController(image: UIImage(named: "photo")!)
        
        self.imageCropViewController!.view.setNeedsUpdateConstraints()
        self.imageCropViewController!.view.updateConstraintsIfNeeded()
        self.imageCropViewController!.view.setNeedsLayout()
        self.imageCropViewController!.view.layoutIfNeeded()
        self.imageCropViewController!.viewWillAppear(false)
        self.imageCropViewController!.viewDidAppear(false)
    }

    override func tearDown() {
        self.imageCropViewController = nil
        
        super.tearDown()
    }

    func testCropImagePerformanceWithDefaultSettings() {
        self.measure {
            self.imageCropViewController!.cropImage()
        }
    }

    func testCropImagePerformanceWithCustomRotationAngle() {
        self.imageCropViewController!.rotationAngle = CGFloat(M_PI_4)
        self.measure {
            self.imageCropViewController!.cropImage()
        }
    }

    func testCropImagePerformanceWhenApplyMaskToCroppedImage() {
        self.imageCropViewController!.isApplyMaskToCroppedImage = true
        self.measure {
            self.imageCropViewController!.cropImage()
        }
    }

    func testCropImagePerformanceWithCustomRotationAngleAndWhenApplyMaskToCroppedImage() {
        self.imageCropViewController!.rotationAngle = CGFloat(M_PI_4)
        self.imageCropViewController!.isApplyMaskToCroppedImage = true
        self.measure {
            self.imageCropViewController!.cropImage()
        }
    }
}
