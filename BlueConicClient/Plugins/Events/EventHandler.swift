/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

public class EventHandler {

	public var listenerId: String = ""

	var handleEvent: (Event) -> ()

	init(handler: (Event) -> ()) {
		self.handleEvent = handler
	}
}