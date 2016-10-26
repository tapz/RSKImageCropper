//
//  RSKInternalUtility.m
//  RSKImageCropperExample
//
//  Created by Ruslan Skorb on 9/5/15.
//  Copyright (c) 2015 Ruslan Skorb. All rights reserved.
//

import Foundation

func RSKLocalizedString(_ key: String, _ comment: String) -> String {
    return RSKInternalUtility.self.bundleForStrings.localizedString(forKey: key, value: key, table: "RSKImageCropper")
}

class RSKInternalUtility {
    static var bundleForStrings: Bundle = {
        let bundleForClass = Bundle(for: RSKInternalUtility.self)
        let stringsBundlePath = bundleForClass.path(forResource: "RSKImageCropperStrings", ofType: "bundle")!
        return Bundle(path: stringsBundlePath) ?? bundleForClass
    }()
}
