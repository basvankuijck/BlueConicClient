/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

@objc public class ClickEvent: Event {
    private var _selector: String

    public var selector: String{
        get {
            return self._selector
        }
    }

    public init(selector: String){
        self._selector = selector
    }
}