/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

@objc public class AdvancedEvent: Event {
    public var eventName: String
    
    private var _context: [String]?
    public var context: [String]?{
        get {
            return self._context
        }
    }

	private var myLocation: UIViewController?

	public init(eventName: String) {
        self.eventName = eventName
    }

    public init(eventName: String, context:[String]) {
        self.eventName = eventName
        self._context = context
    }
}
