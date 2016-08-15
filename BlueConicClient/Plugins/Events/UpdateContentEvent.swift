/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

@objc public class UpdateContentEvent: Event {
    private var _content: [String]

    public var content: [String] {
        get {
            return self._content
        }
    }

    private var _selector: String?
    public var selector: String{
        get {
            return self._selector != nil ? self._selector! : ""
        }
    }

    public init(content: String) {
		self._content = [content]
    }

    public init(selector: String, content: String) {
        self._selector = selector
        self._content = [content]
    }



}
