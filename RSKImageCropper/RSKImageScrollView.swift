/*
  File: RSKImageScrollView.swift
  Abstract: Centers image within the scroll view and configures image sizing and display.
  Version: 1.3 modified by Ruslan Skorb on 8/24/14.
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES LOSS OF USE, DATA, OR PROFITS OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 
 */

import UIKit

// MARK: -

class RSKImageScrollView: UIScrollView, UIScrollViewDelegate {
    var imageSize = CGSize.zero
    var pointToCenterAfterResize = CGPoint.zero
    var scaleToRestoreAfterResize = CGFloat(0.0)
    var isAspectFill = false

    var zoomView: UIImageView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        bouncesZoom = true
        scrollsToTop = false
        decelerationRate = UIScrollViewDecelerationRateFast
        delegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func didAddSubview(subview: UIView) {
        super.didAddSubview(subview)
        centerZoomView()
    }

    func setAspectFill(aspectFill: Bool) {
        if isAspectFill != aspectFill {
            isAspectFill = aspectFill
            
            if zoomView != nil {
                setMaxMinZoomScalesForCurrentBounds()
                
                if zoomScale < minimumZoomScale {
                    zoomScale = minimumZoomScale
                }
            }
        }
    }

    func setFrame(frame: CGRect) {
        let sizeChanging = frame.size != self.frame.size
        
        if sizeChanging {
            prepareToResize()
        }
        
        self.frame = frame
        
        if sizeChanging {
            recoverFromResizing()
        }
        
        centerZoomView()
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return zoomView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerZoomView()
    }

    // MARK: - Center zoomView within scrollView

    func centerZoomView() {
        // center zoomView as it becomes smaller than the size of the screen
        
        // we need to use contentInset instead of contentOffset for better positioning when zoomView fills the screen
        if isAspectFill {
            var top = CGFloat(0.0)
            var left = CGFloat(0.0)
            
            // center vertically
            if contentSize.height < bounds.height {
                top = (bounds.height - contentSize.height) * 0.5
            }
            
            // center horizontally
            if contentSize.width < bounds.width {
                left = (bounds.width - contentSize.width) * 0.5
            }
            
            contentInset = UIEdgeInsetsMake(top, left, top, left)
        } else {
            guard let zoomView = zoomView else { return }
        
            var frameToCenter = zoomView.frame
            
            // center horizontally
            if frameToCenter.width < bounds.width {
                frameToCenter.origin.x = (bounds.width - frameToCenter.width) * 0.5
            } else {
                frameToCenter.origin.x = 0
            }
            
            // center vertically
            if frameToCenter.height < bounds.height {
                frameToCenter.origin.y = (bounds.height - frameToCenter.height) * 0.5
            } else {
                frameToCenter.origin.y = 0
            }
            
            zoomView.frame = frameToCenter
        }
    }

    // MARK: - Configure scrollView to display new image

    func displayImage(_ image: UIImage) {
        // clear view for the previous image
        zoomView?.removeFromSuperview()
        zoomView = nil
        
        // reset our zoomScale to 1.0 before doing any further calculations
        zoomScale = 1.0
        
        // make views to display the new image
        zoomView = UIImageView(image: image)
        addSubview(zoomView!)
        
        configureForImageSize(image.size)
    }

    func configureForImageSize(_ imageSize: CGSize) {
        self.imageSize = imageSize
        contentSize = imageSize
        setMaxMinZoomScalesForCurrentBounds()
        setInitialZoomScale()
        setInitialContentOffset()
        contentInset = .zero
    }

    func setMaxMinZoomScalesForCurrentBounds() {
        let boundsSize = bounds.size
        
        // calculate min/max zoomscale
        let xScale = boundsSize.width  / imageSize.width    // the scale needed to perfectly fit the image width-wise
        let yScale = boundsSize.height / imageSize.height   // the scale needed to perfectly fit the image height-wise
        var minScale = CGFloat(0.0)
        
        if !isAspectFill {
            minScale = min(xScale, yScale) // use minimum of these to allow the image to become fully visible
        } else {
            minScale = max(xScale, yScale) // use maximum of these to allow the image to fill the screen
        }
        
        var maxScale = max(xScale, yScale)
        
        // Image must fit/fill the screen, even if its size is smaller.
        let xImageScale = maxScale * imageSize.width / boundsSize.width
        let yImageScale = maxScale * imageSize.height / boundsSize.width
        var maxImageScale = max(xImageScale, yImageScale)
        
        maxImageScale = max(minScale, maxImageScale)
        maxScale = max(maxScale, maxImageScale)

        // don't let minScale exceed maxScale. (If the image is smaller than the screen, we don't want to force it to be zoomed.)
        if minScale > maxScale {
            minScale = maxScale
        }
            
        maximumZoomScale = maxScale
        minimumZoomScale = minScale
    }

    func setInitialZoomScale() {
        let boundsSize = bounds.size
        let xScale = boundsSize.width  / imageSize.width    // the scale needed to perfectly fit the image width-wise
        let yScale = boundsSize.height / imageSize.height   // the scale needed to perfectly fit the image height-wise
        let scale = max(xScale, yScale)
        zoomScale = scale
    }

    func setInitialContentOffset() {
        guard let zoomView = zoomView else { return }
    
        let boundsSize = bounds.size
        let frameToCenter = zoomView.frame
        
        var contentOffset = CGPoint(x: 0.0, y: 0.0)
        if frameToCenter.width > boundsSize.width {
            contentOffset.x = (frameToCenter.width - boundsSize.width) * 0.5
        } else {
            contentOffset.x = 0
        }
        if frameToCenter.height > boundsSize.height {
            contentOffset.y = (frameToCenter.height - boundsSize.height) * 0.5
        } else {
            contentOffset.y = 0
        }
        
        setContentOffset(contentOffset, animated: false)
    }

    // MARK: Methods called during rotation to preserve the zoomScale and the visible portion of the image

    // MARK: - Rotation support

    func prepareToResize() {
        let boundsCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        pointToCenterAfterResize = convert(boundsCenter, to: zoomView)

        scaleToRestoreAfterResize = zoomScale
        
        // If we're at the minimum zoom scale, preserve that by returning 0, which will be converted to the minimum
        // allowable scale when the scale is restored.
        if scaleToRestoreAfterResize <= minimumZoomScale + CGFloat(FLT_EPSILON) {
            scaleToRestoreAfterResize = 0
        }
    }

    func recoverFromResizing() {
        guard let zoomView = zoomView else { return }
    
        setMaxMinZoomScalesForCurrentBounds()
        
        // Step 1: restore zoom scale, first making sure it is within the allowable range.
        let maxZoomScale = max(minimumZoomScale, scaleToRestoreAfterResize)
        self.zoomScale = min(maximumZoomScale, maxZoomScale)
        
        // Step 2: restore center point, first making sure it is within the allowable range.
        
        // 2a: convert our desired center point back to our own coordinate space
        let boundsCenter = convert(pointToCenterAfterResize, from: zoomView)

        // 2b: calculate the content offset that would yield that center point
        var offset = CGPoint(
            x: boundsCenter.x - bounds.size.width / 2.0,
            y: boundsCenter.y - bounds.size.height / 2.0)

        // 2c: restore offset, adjusted to be within the allowable range
        let maxOffset = maximumContentOffset
        let minOffset = minimumContentOffset
        
        var realMaxOffset = min(maxOffset.x, offset.x)
        offset.x = max(minOffset.x, realMaxOffset)
        
        realMaxOffset = min(maxOffset.y, offset.y)
        offset.y = max(minOffset.y, realMaxOffset)
        
        self.contentOffset = offset
    }

    var maximumContentOffset: CGPoint {
        let contentSize = self.contentSize
        let boundsSize = bounds.size
        return CGPoint(x: contentSize.width - boundsSize.width, y: contentSize.height - boundsSize.height)
    }

    var minimumContentOffset: CGPoint {
        return .zero
    }
}
