/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

/**
This class represents the events to which can be subscribed and published. It follows the factory pattern and should be a singleton. This is implemented by having a sharedInstance variable which contains a dispatch_once_t token. This creates a static instance of Event exactly once, and returns this all following times. This means the event initialization is lazy.
*/

struct HandlerMap{
	var id: String
	var handler: EventHandler
}

@objc public class BlueConicEventManager: NSObject {

    // We provide a dictionary containing event names and their corresponding  handlerobjects and handlerfunctions, these are wrapped in an array since
    // one event name might have to respond to several handler objects and functions(rules in blueconic)
	internal var handlersByEvent: Dictionary<String, [HandlerMap]> = [:]

    // all published events are stored, if the subscribe event is done later these can still be published
    internal var eventQueue: [Event] = []


    /**
    Publish an event to all subscribers, add any parameters as a String array. These will be used to match subscribers if configured in Blueconic.
    - parameter  eventName:  A string containing the event name, this has to be an exact match(but case insensitive) to what is configured within blueconic
    - parameter	 eventObject:  An optional array of Strings that can be used for matching with rules within blueconic.
    */
    public func publish(event: Event) {
		event.location = BlueConicClient.getInstance(nil).getScreenName()
		self.eventQueue.append(event)
        self.handleEvent(event)
    }

	/**
	* Clears the event queue
	*/
	public func clearEvents() {
		self.eventQueue.removeAll()
	}


	/**
	* Clears the event handlers, takes an interaction id that matches with several rule id's, removes those rule id's
	*/
	public func clearEventHandlers(key: String?) {
		if let validkey = key {

			for (className,handlerMapList) in self.handlersByEvent {
				for (index,element) in handlerMapList.enumerate() {
					if element.id == validkey {
						self.handlersByEvent[className]?.removeAtIndex(index)
						if self.handlersByEvent[className]?.count == 0 {
							self.handlersByEvent.removeValueForKey(className)
						}
					}
				}
			}

		} else {
			self.handlersByEvent = [:]
		}
	}

	/**
	* Clears the event when the location is changed (another activity is opened)
	*/
	public func cleanup() {
		let location = BlueConicClient.getInstance(nil).getScreenName()
		var removeList: [Int] = []
		for (index, event) in eventQueue.enumerate() {
			if location != event.location {
				removeList.append(index)
			}
		}
		for index in removeList.sort(>) {
				self.eventQueue.removeAtIndex(index)
		}
	}

    /**
    Handles an event after publishing.

    - parameter  event:  a tuple containing an eventname and an event context( an array of strings). This represents a published event.
    */
    internal func handleEvent(event: Event?) {
		for queuedEvent in self.eventQueue {
			if event == nil || event! === queuedEvent {
				if let eventHandlers = self.handlersByEvent[queuedEvent.name] {
					for handlerMap in eventHandlers {
						let curHandler = handlerMap.handler.listenerId
						//println("event: \(queuedEvent) was handled by \(queuedEvent.handledBy), (current handler: \(curHandler)), so handling = \(!contains(queuedEvent.handledBy,curHandler))")

						if(!queuedEvent.handledBy.contains(curHandler) ){
							queuedEvent.addHandledBy(curHandler)
							handlerMap.handler.handleEvent(queuedEvent)
						}
					}
				}
			}
		}
    }

    /**
    Adds an event listener. This listens to publish events with the same name and optionally a certain eventObject configuration.

    - parameter  eventName:  A string containg the publish event name we should listen to
    - parameter  listenerId:  a uuid for the listener that subscribed
    - parameter  handlerFunction:  a function describing how a handled event should be...handled.
    */
	internal func subscribe(eventName: String?, listenerId: String, handlerFunction: EventHandler?) {
		//NSLog("subscribing \(eventName), \(ruleId), \(handlerFunction), to \n\(handlersByEvent)")
		if handlerFunction == nil || eventName == nil {
			return
		}
        let name = eventName!

		handlerFunction!.listenerId = listenerId
		if let handlers = self.handlersByEvent[name] {
			// loop over handlers to make sure they're unique
			var addHandler = true
			for handlerMap in handlers {
				// if a handler already occurs, break and don't save this handler into the handlersByEvent list
				if handlerMap.handler.listenerId == listenerId {
					addHandler = false
					break
				}
			}
			if addHandler {

				self.handlersByEvent[name]!.append(HandlerMap(id:listenerId, handler: handlerFunction!))
			}
		} else {


			self.handlersByEvent[name] = [HandlerMap(id:listenerId, handler: handlerFunction!)]
		}
		handleEvent(nil)
    }
}
