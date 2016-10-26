//
// CGGeometryExtension.swift
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

// tgmath functions aren't used on iOS when modules are enabled.
// Open Radar - http://www.openradar.me/16744288
// Work around this by redeclaring things here.

import UIKit

#if arch(x86_64) || CPU_TYPE_ARM64
    let INFINITY = Double.greatestFiniteMagnitude
    let RSK_EPSILON = CGFloat(DBL_EPSILON)
    let RSK_MIN = CGFloat(DBL_MIN)
#else
    let INFINITY = CGFloat.greatestFiniteMagnitude
    let RSK_EPSILON = CGFloat(FLT_EPSILON)
    let RSK_MIN = CGFloat(FLT_MIN)
#endif

// Line segments.
struct RSKLineSegment {
    let start: CGPoint
    let end: CGPoint
}

let RSKPointNull = CGPoint(x: INFINITY, y: INFINITY)

func RSKRectCenterPoint(rect: CGRect) -> CGPoint {
    return CGPoint(
        x: rect.minX + rect.width / 2,
        y: rect.minY + rect.height / 2)
}

func RSKRectScaleAroundPoint(rect0: CGRect, point: CGPoint, sx: CGFloat, sy: CGFloat) -> CGRect {
    var rect = rect0

    var translationTransform = CGAffineTransform(translationX: -point.x, y: -point.y)
    rect = rect.applying(translationTransform)
    let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
    rect = rect.applying(scaleTransform)
    translationTransform = CGAffineTransform(translationX: point.x, y: point.y)
    rect = rect.applying(translationTransform)
    return rect
}

func RSKPointIsNull(_ point: CGPoint) -> Bool {
    return point.equalTo(RSKPointNull)
}

func RSKPointRotateAroundPoint(_ point0: CGPoint, pivot: CGPoint, angle: CGFloat) -> CGPoint {
    var point = point0

    var translationTransform = CGAffineTransform(translationX: -pivot.x, y: -pivot.y)
    point = point.applying(translationTransform)
    let rotationTransform = CGAffineTransform(rotationAngle: angle)
    point = point.applying(rotationTransform)
    translationTransform = CGAffineTransform(translationX: pivot.x, y: pivot.y)
    point = point.applying(translationTransform)
    return point
}

func RSKPointDistance(p1: CGPoint, p2: CGPoint) -> CGFloat {
    let dx = p1.x - p2.x
    let dy = p1.y - p2.y
    return sqrt(pow(dx, 2) + pow(dy, 2))
}

func RSKLineSegmentMake(start: CGPoint, end: CGPoint) -> RSKLineSegment {
    return RSKLineSegment(start: start, end: end)
}

func RSKLineSegmentRotateAroundPoint(line: RSKLineSegment, pivot: CGPoint, angle: CGFloat) -> RSKLineSegment {
    return RSKLineSegmentMake(start: RSKPointRotateAroundPoint(line.start, pivot: pivot, angle: angle),
                              end: RSKPointRotateAroundPoint(line.end, pivot: pivot, angle: angle))
}

/*
 Equations of line segments:
 
 pA = ls1.start + uA * (ls1.end - ls1.start)
 pB = ls2.start + uB * (ls2.end - ls2.start)
 
 In the case when `pA` is equal `pB` we have:
 
 x1 + uA * (x2 - x1) = x3 + uB * (x4 - x3)
 y1 + uA * (y2 - y1) = y3 + uB * (y4 - y3)
 
 uA = (x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3) / (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
 uB = (x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3) / (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
 
 numeratorA = (x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)
 denominatorA = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
 
 numeratorA = (x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)
 denominatorB = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
 
 [1] Denominators are equal.
 [2] If numerators and denominator are zero, then the line segments are coincident. The point of intersection is the midpoint of the line segment.
 
 x = (x1 + x2) * 0.5
 y = (y1 + y2) * 0.5
 
 or
 
 x = (x3 + x4) * 0.5
 y = (y3 + y4) * 0.5
 
 [3] If denominator is zero, then the line segments are parallel. There is no point of intersection.
 [4] If `uA` and `uB` is included into the interval [0, 1], then the line segments intersects in the point (x, y).
 
 x = x1 + uA * (x2 - x1)
 y = y1 + uA * (y2 - y1)
 
 or
 
 x = x3 + uB * (x4 - x3)
 y = y3 + uB * (y4 - y3)
 */
func RSKLineSegmentIntersection(ls1: RSKLineSegment, ls2: RSKLineSegment) -> CGPoint {
    let x1 = ls1.start.x
    let y1 = ls1.start.y
    let x2 = ls1.end.x
    let y2 = ls1.end.y
    let x3 = ls2.start.x
    let y3 = ls2.start.y
    let x4 = ls2.end.x
    let y4 = ls2.end.y

    let numeratorA = (x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)
    let numeratorB = (x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)
    let denominator = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
    
    // Check the coincidence.
    if CGFloat(fabs(numeratorA)) < RSK_EPSILON &&
       CGFloat(fabs(numeratorB)) < RSK_EPSILON &&
       CGFloat(fabs(denominator)) < RSK_EPSILON
    {
        return CGPoint(x: (x1 + x2) * 0.5, y: (y1 + y2) * 0.5)
    }
    
    // Check the parallelism.
    if CGFloat(fabs(denominator)) < RSK_EPSILON {
        return RSKPointNull
    }
    
    // Check the intersection.
    let uA = numeratorA / denominator
    let uB = numeratorB / denominator
    if uA < 0 || uA > 1 || uB < 0 || uB > 1 {
        return RSKPointNull
    }
    
    return CGPoint(x: x1 + uA * (x2 - x1), y: y1 + uA * (y2 - y1))
}
