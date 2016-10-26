//
// UIImageExtension.swift
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

extension UIImage {
    func fixOrientation() -> UIImage {
        // No-op if the orientation is already correct.
        if imageOrientation == .up {
            return self
        }
        
        // We need to calculate the proper transformation to make the image upright.
        // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
            case .down, .downMirrored:
                transform = transform.translatedBy(x: size.width, y: size.height)
                transform = transform.rotated(by: CGFloat.pi)
                
            case .left, .leftMirrored:
                transform = transform.translatedBy(x: size.width, y: 0)
                transform = transform.rotated(by: CGFloat(M_PI_2));
                
            case .right, .rightMirrored:
                transform = transform.translatedBy(x: 0, y: size.height)
                transform = transform.rotated(by: -CGFloat(M_PI_2))
            default: break
        }
        
        switch imageOrientation {
            case .upMirrored, .downMirrored:
                transform = transform.translatedBy(x: size.width, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
                
            case .leftMirrored, .rightMirrored:
                transform = transform.translatedBy(x: size.height, y: 0)
                transform = transform.scaledBy(x: -1, y: 1)
            default: break
        }
        
        // Now we draw the underlying CGImage into a new context, applying the transform
        // calculated above.
        UIGraphicsBeginImageContextWithOptions(size, false,  UIScreen.main.scale)
        defer {
            UIGraphicsEndImageContext()
        }
        /*
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: cgImage!.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage!.colorSpace!,
            bitmapInfo: cgImage!.bitmapInfo.rawValue) else { return self }*/
        
        guard let ctx = UIGraphicsGetCurrentContext() else { return self }
        ctx.concatenate(transform)
        
        switch imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                draw(in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
                
            default:
                draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        
        // And now we just create a new UIImage from the drawing context.
        if let cgi = ctx.makeImage() {
            return UIImage(cgImage: cgi)
        }
        
        return self
    }

    public func rotateByAngle(angleInRadians: CGFloat) -> UIImage {
        let contextSize = size
        
        UIGraphicsBeginImageContextWithOptions(contextSize, false, self.scale)
        defer {
            UIGraphicsEndImageContext()
        }
        
        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
        
        context.translateBy(x: 0.5 * contextSize.width, y: 0.5 * contextSize.height)
        context.rotate(by: angleInRadians)
        context.translateBy(x: -0.5 * contextSize.width, y: -0.5 * contextSize.height)
        draw(at: .zero)
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
}
