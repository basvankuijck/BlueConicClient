/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

@objc public class Event: NSObject {
	//	private var myEventName: String
	public var name: String{
		get {
			return NSStringFromClass(self.dynamicType)
		}
	}
	private var _location: String?

	public var location: String?{
		get{
			return self._location
		}
		set(newLocation) {
			self._location = newLocation
		}
	}

	private var _handledBy: [String] = []

    public var handledBy: [String] {
        get {
            return self._handledBy
        }
    }

	public func addHandledBy(handledBy: String) {
		self._handledBy.append(handledBy)
	}

}