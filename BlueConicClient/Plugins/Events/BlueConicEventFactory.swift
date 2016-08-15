/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

@objc public class BlueConicEventFactory: NSObject {

    private class var sharedInstance: BlueConicEventManager {

        struct Static {
            static var onceToken: dispatch_once_t = 0
            static var instance: BlueConicEventManager? = nil
        }

        // This is performed once
        dispatch_once(&Static.onceToken) {
            Static.instance = BlueConicEventManager()
        }
        return Static.instance!
    }

    public class func getInstance() -> BlueConicEventManager {
        return sharedInstance
    }
}