//
// RSKImageCropViewController.swift
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

public enum RSKImageCropMode: Int {
    case circle = 0
    case square = 1
    case custom = 2
}

// K is a constant such that the accumulated error of our floating-point computations is definitely bounded by K units in the last place.
#if arch(x86_64) || CPU_TYPE_ARM64
    let kK = CGFloat(9)
#else
    let kK = CGFloat(0)
#endif

/**
 The `RSKImageCropViewControllerDataSource` protocol is adopted by an object that provides a custom rect and a custom path for the mask.
 */
public protocol RSKImageCropViewControllerDataSource: class {

    /**
     Asks the data source a custom rect for the mask.
     
     @return A custom rect for the mask.
     
     @discussion Only valid if `cropMode` is `RSKImageCropModeCustom`.
     */
    var customMaskRect: CGRect { get }

    /**
     Asks the data source a custom path for the mask.
     
     @return A custom path for the mask.
     
     @discussion Only valid if `cropMode` is `RSKImageCropModeCustom`.
     */
    var customMaskPath: UIBezierPath { get }

    /**
     Asks the data source a custom rect in which the image can be moved.
     
     @return A custom rect in which the image can be moved.
     
     @discussion Only valid if `cropMode` is `RSKImageCropModeCustom`. If you want to support the rotation  when `cropMode` is `RSKImageCropModeCustom` you must implement it. Will be marked as `required` in version `2.0.0`.
     */
    var customMovementRect: CGRect { get }

}

/**
 The `RSKImageCropViewControllerDelegate` protocol defines messages sent to a image crop view controller delegate when crop image was canceled or the original image was cropped.
 */
public protocol RSKImageCropViewControllerDelegate: class {

    /**
     Tells the delegate that crop image has been canceled.
     */
    func didCancelCrop()

    /**
     Tells the delegate that the original image will be cropped.
     */
    func willCropImage(_ originalImage: UIImage)

    /**
     Tells the delegate that the original image has been cropped. Additionally provides a crop rect used to produce image.
     */
    func didCropImage(_ croppedImage: UIImage, usingCropRect cropRect: CGRect)

    /**
     Tells the delegate that the original image has been cropped. Additionally provides a crop rect and a rotation angle used to produce image.
     */
    func didCropImage(_ croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat)

}

public class RSKImageCropViewController: UIViewController, UIGestureRecognizerDelegate{
    fileprivate let kResetAnimationDuration = CGFloat(0.4)
    fileprivate let kLayoutImageScrollViewAnimationDuration = CGFloat(0.25)

    fileprivate lazy var imageScrollView: RSKImageScrollView = {
        let view = RSKImageScrollView(frame: .zero)
        view.clipsToBounds = false
        view.isAspectFill = self.isAvoidEmptySpaceAroundImage
        return view
    }()

    fileprivate lazy var overlayView: RSKTouchView = {
        let view = RSKTouchView()
        view.receiver = self.imageScrollView
        view.layer.addSublayer(self.maskLayer)
        return view
    }()

    fileprivate lazy var maskLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillRule = kCAFillRuleEvenOdd
        layer.fillColor = self.maskLayerColor.cgColor
        layer.lineWidth = self.maskLayerLineWidth
        layer.strokeColor = self.maskLayerStrokeColor?.cgColor ?? UIColor.black.cgColor
        return layer
    }()

    fileprivate let maskLayerColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.7)

    fileprivate lazy var moveAndScaleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = UIColor.clear
        label.text = RSKLocalizedString("Move and Scale", "Move and Scale label")
        label.textColor = UIColor.white
        label.isOpaque = false
        return label
    }()

    fileprivate lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(RSKLocalizedString("Cancel", "Cancel button"), for: .normal)
        button.addTarget(self, action: #selector(onCancelButtonTouch), for: .touchUpInside)
        button.isOpaque = false
        return button
    }()

    fileprivate lazy var chooseButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(RSKLocalizedString("Choose", "Choose button"), for: .normal)
        button.addTarget(self, action: #selector(onChooseButtonTouch), for: .touchUpInside)
        button.isOpaque = false
        return button
    }()

    fileprivate lazy var doubleTapGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        recognizer.delaysTouchesEnded = false
        recognizer.numberOfTapsRequired = 2
        recognizer.delegate = self
        return recognizer
    }()

    fileprivate lazy var rotationGestureRecognizer: UIRotationGestureRecognizer = {
        let recognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = self
        recognizer.isEnabled = self.isRotationEnabled
        return recognizer
    }()

    fileprivate var isOriginalNavigationControllerNavigationBarHidden = false
    fileprivate var originalNavigationControllerNavigationBarShadowImage: UIImage?
    fileprivate var originalNavigationControllerViewBackgroundColor: UIColor?
    fileprivate var isOriginalStatusBarHidden = false

    fileprivate var maskRect = CGRect.zero
    fileprivate var maskPath = UIBezierPath() {
        didSet {
            let clipPath = UIBezierPath(rect: rectForClipPath)
            clipPath.append(maskPath)
            clipPath.usesEvenOddFillRule = true
            
            let pathAnimation = CABasicAnimation(keyPath: "path")
            pathAnimation.duration = CATransaction.animationDuration()
            pathAnimation.timingFunction = CATransaction.animationTimingFunction()
            self.maskLayer.add(pathAnimation, forKey: "path")
            
            self.maskLayer.path = clipPath.cgPath
        }
    }

    fileprivate var didSetupConstraints = false
    fileprivate var moveAndScaleLabelTopConstraint = NSLayoutConstraint()
    fileprivate var cancelButtonBottomConstraint = NSLayoutConstraint()
    fileprivate var cancelButtonLeadingConstraint = NSLayoutConstraint()
    fileprivate var chooseButtonBottomConstraint = NSLayoutConstraint()
    fileprivate var chooseButtonTrailingConstraint = NSLayoutConstraint()

    public var isAvoidEmptySpaceAroundImage = false {
        didSet {
            imageScrollView.isAspectFill = isAvoidEmptySpaceAroundImage
        }
    }
    
    public var isApplyMaskToCroppedImage = false
    public var maskLayerLineWidth = CGFloat(1.0)
    public var isRotationEnabled = false {
        didSet {
            rotationGestureRecognizer.isEnabled = isRotationEnabled
        }
    }
    
    public var cropMode = RSKImageCropMode.circle {
        didSet {
            if self.imageScrollView.zoomView != nil {
                reset(animated: false)
            }
        }
    }
    
    fileprivate var portraitCircleMaskRectInnerEdgeInset = CGFloat(15.0)
    fileprivate var portraitSquareMaskRectInnerEdgeInset = CGFloat(20.0)
    fileprivate var portraitMoveAndScaleLabelTopAndCropViewTopVerticalSpace = CGFloat(64.0)
    fileprivate var portraitCropViewBottomAndCancelButtonBottomVerticalSpace = CGFloat(21.0)
    fileprivate var portraitCropViewBottomAndChooseButtonBottomVerticalSpace = CGFloat(21.0)
    fileprivate var portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace = CGFloat(13.0)
    fileprivate var portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace = CGFloat(13.0)
    
    fileprivate var landscapeCircleMaskRectInnerEdgeInset = CGFloat(45.0)
    fileprivate var landscapeSquareMaskRectInnerEdgeInset = CGFloat(45.0)
    fileprivate var landscapeMoveAndScaleLabelTopAndCropViewTopVerticalSpace = CGFloat(12.0)
    fileprivate var landscapeCropViewBottomAndCancelButtonBottomVerticalSpace = CGFloat(12.0)
    fileprivate var landscapeCropViewBottomAndChooseButtonBottomVerticalSpace = CGFloat(12.0)
    fileprivate var landscapeCancelButtonLeadingAndCropViewLeadingHorizontalSpace = CGFloat(13.0)
    fileprivate var landscapeCropViewTrailingAndChooseButtonTrailingHorizontalSpace = CGFloat(13.0)

    fileprivate var originalImage: UIImage? {
        didSet {
            if self.isViewLoaded && self.view.window != nil {
                displayImage()
            }
        }
    }
    
    public weak var dataSource: RSKImageCropViewControllerDataSource?
    public weak var delegate: RSKImageCropViewControllerDelegate?

    /// -----------------------------------
    /// @name Accessing the Mask Attributes
    /// -----------------------------------

    /**
     The color to fill the stroked outline of the path of the mask layer, or nil for no stroking. Default valus is nil.
     */
    var maskLayerStrokeColor: UIColor?

    //MARK: - Lifecycle

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    public convenience init(image: UIImage) {
        self.init()
        self.originalImage = image
    }

    public convenience init(image: UIImage, cropMode: RSKImageCropMode) {
        self.init(image: image)
        self.cropMode = cropMode
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override var prefersStatusBarHidden: Bool {
        return true
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        edgesForExtendedLayout = []
        automaticallyAdjustsScrollViewInsets = false
        
        view.backgroundColor = UIColor.black
        view.clipsToBounds = true
        
        view.addSubview(imageScrollView)
        view.addSubview(overlayView)
        view.addSubview(moveAndScaleLabel)
        view.addSubview(cancelButton)
        view.addSubview(chooseButton)
        
        view.addGestureRecognizer(doubleTapGestureRecognizer)
        view.addGestureRecognizer(rotationGestureRecognizer)
    }
    
    fileprivate var isAppExtension: Bool {
        if let exePath = Bundle.main.executablePath {
            return exePath.contains(".appex")
        }
        
        return false
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !isAppExtension {
            isOriginalStatusBarHidden = UIApplication.shared.isStatusBarHidden
            UIApplication.shared.isStatusBarHidden = true
        }
        
        if let navi = navigationController {
            isOriginalNavigationControllerNavigationBarHidden = navi.isNavigationBarHidden
            navi.setNavigationBarHidden(true, animated: false)
        
            originalNavigationControllerNavigationBarShadowImage = navi.navigationBar.shadowImage
            navi.navigationBar.shadowImage = nil
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let navi = navigationController {
            originalNavigationControllerViewBackgroundColor = navi.view.backgroundColor
            navi.view.backgroundColor = UIColor.black
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if !isAppExtension {
            UIApplication.shared.isStatusBarHidden = isOriginalStatusBarHidden
        }
        
        if let navi = navigationController {
            navi.setNavigationBarHidden(isOriginalNavigationControllerNavigationBarHidden, animated:animated)
            navi.navigationBar.shadowImage = originalNavigationControllerNavigationBarShadowImage
            navi.view.backgroundColor = originalNavigationControllerViewBackgroundColor
        }
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        updateMaskRect()
        layoutImageScrollView()
        layoutOverlayView()
        updateMaskPath()
        view.setNeedsUpdateConstraints()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if imageScrollView.zoomView == nil {
            displayImage()
        }
    }

    public override func updateViewConstraints() {
        super.updateViewConstraints()
        
        if !didSetupConstraints {
            // ---------------------------
            // The label "Move and Scale".
            // ---------------------------
            
            let constraint = NSLayoutConstraint(
                item: moveAndScaleLabel,
                attribute: .centerX,
                relatedBy: .equal,
                toItem: view,
                attribute: .centerX,
                multiplier: 1.0,
                constant: 0.0)
                
            view.addConstraint(constraint)
            
            var constant = portraitMoveAndScaleLabelTopAndCropViewTopVerticalSpace
            moveAndScaleLabelTopConstraint = NSLayoutConstraint(
                item: moveAndScaleLabel,
                attribute: .top,
                relatedBy: .equal,
                toItem: view,
                attribute: .top,
                multiplier: 1.0,
                constant: constant)
                
            view.addConstraint(moveAndScaleLabelTopConstraint)
            
            // --------------------
            // The button "Cancel".
            // --------------------
            
            constant = self.portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace
            cancelButtonLeadingConstraint = NSLayoutConstraint(
                item: cancelButton,
                attribute: .leading,
                relatedBy: .equal,
                toItem: view,
                attribute: .leading,
                multiplier: 1.0,
                constant: constant)
                
            view.addConstraint(cancelButtonLeadingConstraint)
            
            constant = portraitCropViewBottomAndCancelButtonBottomVerticalSpace
            cancelButtonBottomConstraint = NSLayoutConstraint(
                item: view,
                attribute: .bottom,
                relatedBy: .equal,
                toItem: cancelButton,
                attribute: .bottom,
                multiplier: 1.0,
                constant: constant)
                
            view.addConstraint(cancelButtonBottomConstraint)
            
            // --------------------
            // The button "Choose".
            // --------------------
            
            constant = portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace
            chooseButtonTrailingConstraint = NSLayoutConstraint(
                item: view,
                attribute: .trailing,
                relatedBy: .equal,
                toItem: chooseButton,
                attribute: .trailing,
                multiplier: 1.0,
                constant: constant)
                
            view.addConstraint(chooseButtonTrailingConstraint)
            
            constant = portraitCropViewBottomAndChooseButtonBottomVerticalSpace
            chooseButtonBottomConstraint = NSLayoutConstraint(
                item: view,
                attribute: .bottom,
                relatedBy: .equal,
                toItem: chooseButton,
                attribute: .bottom,
                multiplier: 1.0,
                constant: constant)
                
            view.addConstraint(chooseButtonBottomConstraint)
            
            didSetupConstraints = true
        } else {
            if isPortraitInterfaceOrientation() {
                moveAndScaleLabelTopConstraint.constant = portraitMoveAndScaleLabelTopAndCropViewTopVerticalSpace
                cancelButtonBottomConstraint.constant = portraitCropViewBottomAndCancelButtonBottomVerticalSpace
                cancelButtonLeadingConstraint.constant = portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace
                chooseButtonBottomConstraint.constant = portraitCropViewBottomAndChooseButtonBottomVerticalSpace
                chooseButtonTrailingConstraint.constant = portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace
            } else {
                moveAndScaleLabelTopConstraint.constant = landscapeMoveAndScaleLabelTopAndCropViewTopVerticalSpace
                cancelButtonBottomConstraint.constant = landscapeCropViewBottomAndCancelButtonBottomVerticalSpace
                cancelButtonLeadingConstraint.constant = landscapeCancelButtonLeadingAndCropViewLeadingHorizontalSpace
                chooseButtonBottomConstraint.constant = landscapeCropViewBottomAndChooseButtonBottomVerticalSpace
                chooseButtonTrailingConstraint.constant = landscapeCropViewTrailingAndChooseButtonTrailingHorizontalSpace
            }
        }
    }

    // MARK: - Custom Accessors

    fileprivate var cropRect: CGRect {
        var rect = CGRect.zero
        let zoomScale = 1.0 / imageScrollView.zoomScale
        
        rect.origin.x = round(imageScrollView.contentOffset.x * zoomScale)
        rect.origin.y = round(imageScrollView.contentOffset.y * zoomScale)
        rect.size.width = imageScrollView.bounds.width * zoomScale
        rect.size.height = imageScrollView.bounds.height * zoomScale
        
        let width = rect.width
        let height = rect.height
        let ceilWidth = ceil(width)
        let ceilHeight = ceil(height)
        
        if fabs(ceilWidth - width) < pow(10, kK) * RSK_EPSILON * fabs(ceilWidth + width) || fabs(ceilWidth - width) < RSK_MIN ||
            fabs(ceilHeight - height) < pow(10, kK) * RSK_EPSILON * fabs(ceilHeight + height) || fabs(ceilHeight - height) < RSK_MIN
        {
            rect.size.width = ceilWidth
            rect.size.height = ceilHeight
        } else {
            rect.size.width = floor(width)
            rect.size.height = floor(height)
        }
        
        return rect
    }

    fileprivate var rectForClipPath: CGRect {
        if maskLayerStrokeColor == nil {
            return overlayView.frame
        } else {
            let maskLayerLineHalfWidth = maskLayerLineWidth / 2.0
            return overlayView.frame.insetBy(dx: -maskLayerLineHalfWidth, dy: -maskLayerLineHalfWidth)
        }
    }

    fileprivate var rectForMaskPath: CGRect {
        if maskLayerStrokeColor == nil {
            return maskRect
        } else {
            let maskLayerLineHalfWidth = self.maskLayerLineWidth / 2.0
            return maskRect.insetBy(dx: maskLayerLineHalfWidth, dy: maskLayerLineHalfWidth)
        }
    }

    internal var rotationAngle: CGFloat {
        get {
            let transform = imageScrollView.transform
            return atan2(transform.b, transform.a)
        }
        
        set(rotationAngle) {
            if self.rotationAngle != rotationAngle {
                let rotation = (rotationAngle - self.rotationAngle)
                let transform = imageScrollView.transform.rotated(by: rotation)
                imageScrollView.transform = transform
            }
        }
    }

    fileprivate var zoomScale: CGFloat {
        return imageScrollView.zoomScale
    }

    fileprivate func setZoomScale(_ zoomScale: CGFloat) {
        self.imageScrollView.zoomScale = zoomScale
    }

    // MARK: - Action handling

    @objc fileprivate func onCancelButtonTouch() {
        cancelCrop()
    }

    @objc fileprivate func onChooseButtonTouch() {
        cropImage()
    }

    @objc fileprivate func handleDoubleTap(gestureRecognizer: UITapGestureRecognizer) {
        reset(animated: true)
    }

    @objc fileprivate func handleRotation(gestureRecognizer: UIRotationGestureRecognizer) {
        rotationAngle += gestureRecognizer.rotation
        gestureRecognizer.rotation = 0
        
        if gestureRecognizer.state == .ended {
            UIView.animate(
                withDuration: TimeInterval(kLayoutImageScrollViewAnimationDuration),
                delay: 0.0,
                options: .beginFromCurrentState,
                animations: {
                    self.layoutImageScrollView()
                },
                completion:nil)
        }
    }

    // MARK: - Public

    fileprivate func isPortraitInterfaceOrientation() -> Bool {
        return view.bounds.height > view.bounds.width
    }

    // MARK: - Private

    fileprivate func reset(animated: Bool) {
        if animated {
            UIView.beginAnimations("rsk_reset", context: nil)
            UIView.setAnimationCurve(.easeInOut)
            UIView.setAnimationDuration(TimeInterval(kResetAnimationDuration))
            UIView.setAnimationBeginsFromCurrentState(true)
        }
        
        resetRotation()
        resetFrame()
        resetZoomScale()
        resetContentOffset()
        
        if animated {
            UIView.commitAnimations()
        }
    }

    fileprivate func resetContentOffset() {
        guard let zoomView = imageScrollView.zoomView else { return }
        
        let boundsSize = imageScrollView.bounds.size
        let frameToCenter = zoomView.frame
        
        var contentOffset = CGPoint(x: 0.0, y: 0.0)
        if frameToCenter.width > boundsSize.width {
            contentOffset.x = (frameToCenter.width - boundsSize.width) * 0.5
        } else {
            contentOffset.x = 0
        }
        if (frameToCenter.height > boundsSize.height) {
            contentOffset.y = (frameToCenter.height - boundsSize.height) * 0.5
        } else {
            contentOffset.y = 0
        }
        
        self.imageScrollView.contentOffset = contentOffset
    }

    fileprivate func resetFrame() {
        layoutImageScrollView()
    }

    fileprivate func resetRotation() {
        rotationAngle = 0.0
    }

    fileprivate func resetZoomScale() {
        guard let originalImage = originalImage else { return }
    
        var zoomScale = CGFloat(0.0)
        if view.bounds.width > view.bounds.height {
            zoomScale = view.bounds.height / originalImage.size.height
        } else {
            zoomScale = view.bounds.width / originalImage.size.width
        }
        self.imageScrollView.zoomScale = zoomScale
    }

    fileprivate func intersectionPointsOfLineSegment(lineSegment: RSKLineSegment, withRect rect: CGRect) -> [CGPoint] {
        let top = RSKLineSegmentMake(
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.minY))
        
        let right = RSKLineSegmentMake(
            start: CGPoint(x: rect.maxX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY))
        
        let bottom = RSKLineSegmentMake(
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.maxY))
        
        let left = RSKLineSegmentMake(
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.minX, y: rect.maxY))
        
        let p0 = RSKLineSegmentIntersection(ls1: top, ls2: lineSegment)
        let p1 = RSKLineSegmentIntersection(ls1: right, ls2: lineSegment)
        let p2 = RSKLineSegmentIntersection(ls1: bottom, ls2: lineSegment)
        let p3 = RSKLineSegmentIntersection(ls1: left, ls2: lineSegment)
        
        var intersectionPoints = [CGPoint]()
        if !RSKPointIsNull(p0) {
            intersectionPoints.append(p0)
        }
        if !RSKPointIsNull(p1) {
            intersectionPoints.append(p1)
        }
        if !RSKPointIsNull(p2) {
            intersectionPoints.append(p2)
        }
        if !RSKPointIsNull(p3) {
            intersectionPoints.append(p3)
        }
        
        return intersectionPoints
    }

    fileprivate func displayImage() {
        guard let originalImage = originalImage else { return }
        
        imageScrollView.displayImage(originalImage)
        reset(animated: false)
    }

    fileprivate func layoutImageScrollView() {
        var scrollViewFrame = CGRect.zero
        
        // The bounds of the image scroll view should always fill the mask area.
        switch cropMode {
            case .square:
                if rotationAngle == 0.0 {
                    scrollViewFrame = maskRect
                } else {
                    // Step 1: Rotate the left edge of the initial rect of the image scroll view clockwise around the center by `rotationAngle`.
                    let initialRect = maskRect
                    let rotationAngle = self.rotationAngle
                    
                    let leftTopPoint = CGPoint(x: initialRect.origin.x, y: initialRect.origin.y)
                    let leftBottomPoint = CGPoint(x: initialRect.origin.x, y: initialRect.origin.y + initialRect.size.height)
                    let leftLineSegment = RSKLineSegmentMake(start: leftTopPoint, end: leftBottomPoint)
                    
                    let pivot = RSKRectCenterPoint(rect: initialRect)
                    
                    var alpha = CGFloat(fabs(rotationAngle))
                    let rotatedLeftLineSegment = RSKLineSegmentRotateAroundPoint(line: leftLineSegment, pivot: pivot, angle: alpha)
                    
                    // Step 2: Find the points of intersection of the rotated edge with the initial rect.
                    let points = intersectionPointsOfLineSegment(lineSegment: rotatedLeftLineSegment, withRect: initialRect)
                    
                    // Step 3: If the number of intersection points more than one
                    // then the bounds of the rotated image scroll view does not completely fill the mask area.
                    // Therefore, we need to update the frame of the image scroll view.
                    // Otherwise, we can use the initial rect.
                    if points.count > 1 {
                        // We have a right triangle.
                        
                        // Step 4: Calculate the altitude of the right triangle.
                        if (alpha > CGFloat(M_PI_2)) && (alpha < CGFloat.pi) {
                            alpha = alpha - CGFloat(M_PI_2)
                        } else if (alpha > (CGFloat.pi + CGFloat(M_PI_2))) && (alpha < (CGFloat.pi + CGFloat.pi)) {
                            alpha = alpha - (CGFloat.pi + CGFloat(M_PI_2))
                        }
                        let sinAlpha = sin(alpha)
                        let cosAlpha = cos(alpha)
                        let hypotenuse = RSKPointDistance(p1: points[0], p2: points[1])
                        let altitude = hypotenuse * sinAlpha * cosAlpha
                        
                        // Step 5: Calculate the target width.
                        let initialWidth = initialRect.width
                        let targetWidth = initialWidth + altitude * 2
                        
                        // Step 6: Calculate the target frame.
                        let scale = targetWidth / initialWidth
                        let center = RSKRectCenterPoint(rect: initialRect)
                        scrollViewFrame = RSKRectScaleAroundPoint(rect0: initialRect, point: center, sx: scale, sy: scale)
                        
                        // Step 7: Avoid floats.
                        scrollViewFrame.origin.x = round(scrollViewFrame.minX)
                        scrollViewFrame.origin.y = round(scrollViewFrame.minY)
                        scrollViewFrame = scrollViewFrame.integral
                    } else {
                        // Step 4: Use the initial rect.
                        scrollViewFrame = initialRect
                    }
                }
            case .circle:
                scrollViewFrame = maskRect
            case .custom:
                guard let dataSource = dataSource else {
                    fatalError("Data source needed for custom crop mode!")
                }
                
                scrollViewFrame = dataSource.customMovementRect
                // Will be changed to `CGRectNull` in version `2.0.0`.
                //frame = self.maskRect
        }
        
        let transform = imageScrollView.transform
        imageScrollView.transform = .identity
        imageScrollView.frame = scrollViewFrame
        imageScrollView.transform = transform
    }

    fileprivate func layoutOverlayView() {
        let frame = CGRect(x: 0, y: 0, width: view.bounds.width * 2, height: view.bounds.height * 2)
        overlayView.frame = frame
    }

    fileprivate func updateMaskRect() {
        switch cropMode {
            case .circle:
                let viewWidth = view.bounds.width
                let viewHeight = view.bounds.height
                
                let diameter: CGFloat!
                if isPortraitInterfaceOrientation() {
                    diameter = min(viewWidth, viewHeight) - portraitCircleMaskRectInnerEdgeInset * 2
                } else {
                    diameter = min(viewWidth, viewHeight) - landscapeCircleMaskRectInnerEdgeInset * 2
                }
                
                let maskSize = CGSize(width: diameter, height: diameter)
                
                maskRect = CGRect(
                    x: (viewWidth - maskSize.width) * 0.5,
                    y: (viewHeight - maskSize.height) * 0.5,
                    width: maskSize.width,
                    height: maskSize.height)
            case .square:
                let viewWidth = view.bounds.width
                let viewHeight = view.bounds.height
                
                let length: CGFloat!
                if isPortraitInterfaceOrientation() {
                    length = min(viewWidth, viewHeight) - portraitSquareMaskRectInnerEdgeInset * 2
                } else {
                    length = min(viewWidth, viewHeight) - landscapeSquareMaskRectInnerEdgeInset * 2
                }
                
                let maskSize = CGSize(width: length, height: length)
                
                maskRect = CGRect(
                    x: (viewWidth - maskSize.width) * 0.5,
                    y: (viewHeight - maskSize.height) * 0.5,
                    width: maskSize.width,
                    height: maskSize.height)
            case .custom:
                guard let dataSource = dataSource else {
                    fatalError("Data source needed for custom crop mode!")
                }
            
                maskRect = dataSource.customMaskRect
        }
    }

    fileprivate func updateMaskPath() {
        switch cropMode {
            case .circle:
                maskPath = UIBezierPath(ovalIn: rectForMaskPath)
            case .square:
                maskPath = UIBezierPath(rect: rectForMaskPath)
            case .custom:
                guard let dataSource = dataSource else {
                    fatalError("Data source needed for custom crop mode!")
                }
            
                maskPath = dataSource.customMaskPath
        }
    }

    fileprivate func croppedImage(image: UIImage, cropRect: CGRect, scale imageScale: CGFloat, orientation imageOrientation: UIImageOrientation) -> UIImage {
        if let images = image.images {
            var croppedImages = [UIImage]()
            
            images.forEach {
                croppedImages.append(croppedImage(image: $0, cropRect: cropRect, scale: imageScale, orientation: imageOrientation))
            }
            
            return UIImage.animatedImage(with: croppedImages, duration: image.duration)!
        } else {
            if let croppedCGImage = image.cgImage!.cropping(to: cropRect) {
                return UIImage(cgImage: croppedCGImage, scale: imageScale, orientation: imageOrientation)
            }
            
            return image
        }
    }

    fileprivate func croppedImage(image: UIImage, cropMode: RSKImageCropMode, cropRect cropRect0: CGRect, rotationAngle: CGFloat, zoomScale: CGFloat, maskPath: UIBezierPath, applyMaskToCroppedImage: Bool) -> UIImage {
        var cropRect = cropRect0
        
        // Step 1: check and correct the crop rect.
        let imageSize = image.size
        let x = cropRect.minX
        let y = cropRect.minY
        let width = cropRect.width
        let height = cropRect.height
        
        var imageOrientation = image.imageOrientation
        if imageOrientation == .right || imageOrientation == .rightMirrored {
            cropRect.origin.x = y
            cropRect.origin.y = round(imageSize.width - cropRect.width - x)
            cropRect.size.width = height
            cropRect.size.height = width
        } else if imageOrientation == .left || imageOrientation == .leftMirrored {
            cropRect.origin.x = round(imageSize.height - cropRect.height - y)
            cropRect.origin.y = x
            cropRect.size.width = height
            cropRect.size.height = width
        } else if imageOrientation == .down || imageOrientation == .downMirrored {
            cropRect.origin.x = round(imageSize.width - cropRect.width - x)
            cropRect.origin.y = round(imageSize.height - cropRect.height - y)
        }
        
        let imageScale = image.scale
        cropRect = cropRect.applying(CGAffineTransform(scaleX: imageScale, y: imageScale))
        
        // Step 2: create an image using the data contained within the specified rect.
        var croppedImage = self.croppedImage(image: image, cropRect: cropRect, scale: imageScale, orientation: imageOrientation)
        
        // Step 3: fix orientation of the cropped image.
        croppedImage = croppedImage.fixOrientation()
        imageOrientation = croppedImage.imageOrientation
        
        // Step 4: If current mode is `RSKImageCropModeSquare` and the image is not rotated
        // or mask should not be applied to the image after cropping and the image is not rotated,
        // we can return the cropped image immediately.
        // Otherwise, we must further process the image.
        if (cropMode == .square || !applyMaskToCroppedImage) && rotationAngle == 0.0 {
            // Step 5: return the cropped image immediately.
            return croppedImage
        } else {
            // Step 5: create a new context.
            let maskSize = maskPath.bounds.integral.size
            let contextSize = CGSize(
                width: ceil(maskSize.width / zoomScale),
                height: ceil(maskSize.height / zoomScale))
            
            UIGraphicsBeginImageContextWithOptions(contextSize, false, imageScale)
            guard let ctx = UIGraphicsGetCurrentContext() else {
                return croppedImage
            }
            
            defer {
                UIGraphicsEndImageContext()
            }
            
            // Step 6: apply the mask if needed.
            if applyMaskToCroppedImage {
                // 6a: scale the mask to the size of the crop rect.
                let maskPathCopy = maskPath.copy() as! UIBezierPath
                let scale = 1 / zoomScale
                maskPathCopy.apply(CGAffineTransform(scaleX: scale, y: scale))
                
                // 6b: move the mask to the top-left.
                let translation = CGPoint(x: -maskPathCopy.bounds.minX, y: -maskPathCopy.bounds.minY)
                maskPathCopy.apply(CGAffineTransform(translationX: translation.x, y: translation.y))
                
                // 6c: apply the mask.
                maskPathCopy.addClip()
            }
            
            // Step 7: rotate the cropped image if needed.
            if rotationAngle != 0 {
                croppedImage = croppedImage.rotateByAngle(angleInRadians: rotationAngle)
            }
            
            // Step 8: draw the cropped image.
            let point = CGPoint(
                x: round((contextSize.width - croppedImage.size.width) * 0.5),
                y: round((contextSize.height - croppedImage.size.height) * 0.5))
            croppedImage.draw(at: point)
            
            // Step 9: get the cropped image affter processing from the context.
            croppedImage = UIGraphicsGetImageFromCurrentImageContext()!
            
            // Step 10: return the cropped image affter processing.
            
            return UIImage(cgImage: croppedImage.cgImage!, scale: imageScale, orientation: imageOrientation)
        }
    }

    internal func cropImage() {
        guard let originalImage = originalImage else { return }
        
        delegate?.willCropImage(originalImage)
        
        DispatchQueue.global(qos: .default).async {
            let croppedImage = self.croppedImage(
                image: originalImage,
                cropMode: self.cropMode,
                cropRect: self.cropRect,
                rotationAngle: self.rotationAngle,
                zoomScale: self.imageScrollView.zoomScale,
                maskPath: self.maskPath,
                applyMaskToCroppedImage: self.isApplyMaskToCroppedImage)
            
            DispatchQueue.main.async {
                self.delegate?.didCropImage(croppedImage, usingCropRect: self.cropRect, rotationAngle: self.rotationAngle)
            }
        }
    }

    fileprivate func cancelCrop() {
        delegate?.didCancelCrop()
    }

    // MARK: - UIGestureRecognizerDelegate

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
