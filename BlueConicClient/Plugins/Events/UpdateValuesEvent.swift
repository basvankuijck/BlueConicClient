/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

@objc public class UpdateValuesEvent: Event {
    private var _selector: String?
    private var _values: [String]

    public var values:[String]{
        get {
            return self._values
        }
    }

    public var selector: String{
        get {
            return _selector != nil ? _selector! : ""
        }
    }

    public init(values:[String]) {
        self._values = values
    }

    public init(selector:String, values:[String]) {
        self._values = values
        self._selector = selector
    }
}
