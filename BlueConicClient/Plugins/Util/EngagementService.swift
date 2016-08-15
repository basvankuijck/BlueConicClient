/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/


import Foundation

public class EngagementService: NSObject {
    private var _client: BlueConicClient?
	private var _context: InteractionContext?
	private var _debugMode: Bool = false
    private var _engagementObject: Dictionary<String, AnyObject> = Dictionary<String, AnyObject>()
    private var _propertyName: String = ""
    private var _internalPropertyName: String = ""

    private var _calculatedIndexValues: Bool = false
    private var _isInterest: Bool = false
    internal var allInterests: [String] = []

    private var _changes: Dictionary<String, Dictionary<String, Int>>?
    private var _valuesCount: Int?

    private var _days: Int = 0
    private var _decay: Int = 0
    private var _aggregationOffset: Int = 0

    private var _eventManager: BlueConicEventManager!
	private var _eventMap: Dictionary<String,[JSON]>?

    private var _elementRuleMap: Dictionary<UIControl, [JSON]> = [UIControl: [JSON]]()

	private var _handler: EventHandler?

    public convenience init(client: BlueConicClient) {
        self.init()
        self._client = client

    }
    /**
    Deinit. Clear the event handlers based on the interaction id of context.
    */
    deinit {
        if let interactionId = self._context?.getInteractionId() {
            BlueConicEventFactory.getInstance().clearEventHandlers(interactionId)
        }
    }

    /**
    Inits everything needed for the engagementservice
    */
	public convenience init(client: BlueConicClient, context: InteractionContext, propertyName: String, decay: Int?, isInterest: Bool, allInterests: [String]?) {
        self.init()
        self._client = client
		self._context = context
        self._propertyName = propertyName
        self._internalPropertyName = "_" + propertyName

        self._isInterest = isInterest
		if allInterests != nil {
			self.allInterests = allInterests!
		}

		// Get the debug status from the app plist

		self._debugMode = ListenerUtil.getDebugMode()

        let userCalendar = NSCalendar.currentCalendar()
        let baseDateComponents = NSDateComponents()
        baseDateComponents.year = 2012
        baseDateComponents.month = 1
        baseDateComponents.day = 1
        baseDateComponents.timeZone = NSTimeZone(name: "UTC")


        let base: NSDate = userCalendar.dateFromComponents(baseDateComponents)!

        self._days = Int(floor((NSDate().timeIntervalSinceDate(base) as Double) / (24 * 3600)))

        if decay != nil {
            self._decay = decay!
        }

        self._aggregationOffset = self._decay
		self._eventManager = BlueConicEventFactory.getInstance()
		self._handler = EventHandler(handler: {
			//This eventcallback is triggered when a matching event is fired. This is what eventually scores the event.
			(event:Event) -> () in
			if self._debugMode {
				NSLog("handling event \(event) in eventmap \(self._eventMap)")
			}
			if let rules = self._eventMap?[event.name] {
				for rule in rules {
					if let advancedEvent = event as? AdvancedEvent {
						self.handleAdvancedEvent(rule, advancedEvent: advancedEvent)
					} else if let updateContentEvent = event as? UpdateContentEvent {
						self.handleUpdateContentEvent(rule, updateContentEvent: updateContentEvent)
					} else if let clickEvent = event as? ClickEvent {
						self.handleTouchEvent(rule, clickEvent: clickEvent )
					} else if let formSubmitEvent = event as? FormSubmitEvent {
						self.handleTouchEvent(rule, clickEvent: formSubmitEvent)
					}


				}
					self.save()
			}
		})
    }

	private func applyContentRule (rule: JSON) {
		if let selector = ListenerUtil.getSelector(rule[PluginConstants.Listener.TAG_CONTENT_AREA]) {
			addPointsForRule(rule, content: ListenerUtil.getContent(selector))
			registerEvent(rule, className: NSStringFromClass(UpdateContentEvent))
		} else {
            if self._debugMode {
                NSLog("Found a rule without selector")
            }
		}
	}

	private func applyTouchRule (rule: JSON) {
		if let clickSelector = ListenerUtil.getSelector(rule[PluginConstants.Listener.TAG_CLICKAREA]) {
			if let element = self._client?.getView(clickSelector) as? UIControl {
				// map objects with their rule, since we can't set parameters with addTarget
				element.addTarget(self, action: #selector(EngagementService.touchAction(_:)), forControlEvents: UIControlEvents.TouchDown)
				addToRuleMap(element, rule: rule)

			} else {
                if self._debugMode {
                    NSLog("Unable to get the view with the selector: \(clickSelector)")
                }
			}
			registerEvent(rule, className: NSStringFromClass(ClickEvent))
		} else {
            if self._debugMode {
                NSLog("Found a click rule without a clickarea selector: \(rule)")
            }
		}
	}

	private func applyFormSubmitRule (rule: JSON) {
		if let clickSelector = ListenerUtil.getSelector(rule[PluginConstants.Listener.TAG_FORM]) {
			if let element = self._client?.getView(clickSelector) as? UIControl {
				// map objects with their rule, since we can't set parameters with addTarget
				element.addTarget(self, action: #selector(EngagementService.touchAction(_:)), forControlEvents: UIControlEvents.TouchDown)
				addToRuleMap(element,rule: rule)
			} else {
                if self._debugMode {
                    NSLog("Unable to get the view with the selector: \(clickSelector)")
                }
			}
			registerEvent(rule, className: NSStringFromClass(FormSubmitEvent))

		} else {
            if self._debugMode {
                NSLog("Found a form submit rule without a form selector: \(rule)")
            }
		}
	}

	private func applyUrlRule (rule: JSON) {
		var content = ""

		// We can't reliably check referrers.
		if let urlRule = rule[PluginConstants.Listener.TAG_URL].string,
            url = self._client?.getScreenName() where PluginConstants.Listener.URL_RULE.contains(urlRule) {
			content += url
		} else {
            if self._debugMode {
                NSLog("Unable to get the current screenName with the url rule: \(rule)")
            }
		}
		addPointsForRule(rule, content: [content])
	}

    /**
    Convenience class to apply rules. This is then transformed into a json array object my mapping each arraymember into a JSON object.
    - parameter  rules:  An array of AnyObjects
    */
    public func applyRules(rules: [AnyObject]) {
        applyRules(rules.map({ JSON($0) }))
    }


    /*
    * Loops over all available rules and applies them when possible
    * :param: rules  an array of rules in a JSON object
    */
    public func applyRules(rules: [JSON]) {
        for rule in rules {
			if self._debugMode {
				NSLog("\(rule)")
			}
            if let ruleType: String = rule["ruletype"].string {
                switch ruleType {
                case PluginConstants.Listener.RULETYPE_SCORE_CONTENT,
					PluginConstants.Listener.RULETYPE_INTEREST_CONTENT:
                    applyContentRule(rule)
                case PluginConstants.Listener.RULETYPE_SCORE_CLICK,
					PluginConstants.Listener.RULETYPE_INTEREST_CLICK:
                    applyTouchRule(rule)
				case PluginConstants.Listener.RULETYPE_SCORE_FORMSUBMIT,
					PluginConstants.Listener.RULETYPE_INTEREST_FORMSUBMIT:
					applyFormSubmitRule(rule)
                case PluginConstants.Listener.RULETYPE_INTEREST_URL,
					PluginConstants.Listener.RULETYPE_SCORE_URL:
					applyUrlRule(rule)
                case PluginConstants.Listener.RULETYPE_SCORE_SOCIAL_EVENT,
					PluginConstants.Listener.RULETYPE_SCORE_EVENT,
					PluginConstants.Listener.RULETYPE_INTEREST_SOCIAL_EVENT,
					PluginConstants.Listener.RULETYPE_INTEREST_EVENT:
					registerEvent(rule, className: NSStringFromClass(AdvancedEvent))
                default:
                    if self._debugMode {
                        NSLog("Invalid or not supported rule detected")
                    }
                }
            }
        }
    }

    /**
    The changes object only exists if there have been any changes, convenience function to check this.

    - returns:  bool that denotes a change has occured
    */
    public func isChanged() -> Bool {
        return self._changes != nil
    }

    /**
    Save points to BlueConic by setting the changes object to a property.
    */
    public func save() {
        if var changes: Dictionary<String, AnyObject> = self._changes {
            changes[PluginConstants.Listener.TAG_TIME] = ListenerUtil.getCurrentTime()
            self._client?.addProfileValue("_" + self._propertyName, value: ListenerUtil.JSONStringify(changes))

            if self._debugMode {
                NSLog("saving: _\(self._propertyName) - \(changes)")
            }
        }

        self._changes = nil
    }

	/**
	Prepares to add points to changes object

	- parameter  keyword:  the keyword that was  matched to
	- parameter  score:  the number of points to assign
	*/
	private func addPoints(keywords: [String], score: Int) {
		for keyword in keywords {
			addPoints(keyword, score: score)
		}
	}

    /**
    Prepares to add points to changes object

    - parameter  keyword:  the keyword that was  matched to
    - parameter  score:  the number of points to assign
    */
    private func addPoints(keyword: String, score: Int) {
        self._calculatedIndexValues = false

        // also add the points to the _changes object
        if self._changes == nil {
            self._changes = [String: [String: Int]]()
        }
        addPointsToObject(&self._changes!, keyword: keyword.lowercaseString, score: score, prefix: "p")
    }

    /**
    Actually adds points to changes object. If the obj already contains points for a certain prefix and date(today), add the points together
    - parameter  obj:  an object in which the points are assigned, this is an inout object since we want the passed object to change
    - parameter  keyword:  the keyword that was  matched to
    - parameter  score:  the number of points to assign
    - parameter  prefix:  a necessary prefix
    */
    private func addPointsToObject(inout obj: Dictionary<String, Dictionary<String, Int>>, keyword: String, score: Int, prefix: String) {
        let identifier = prefix + String(self._days)
        var newPoints = score

        // If obj with keyword exists, and there are already points for a certain prefix, add the points together
        if let currentPoints = obj[keyword]?[identifier] {
            newPoints = newPoints + currentPoints
        } else {
            obj[keyword] = [String: Int]()
        }

        // Set the new score
        // format: {'psv':{'p3':22}} means for psv you have 22 points logged (l) 3 days from the base
        obj[keyword]![identifier] = newPoints
    }

    /**
    Adds point for a rule, depends on whether we're in an interest ranking or not.

    - parameter  rule:  A Json object containing the rule as specified in BlueConic
    - parameter  content:  The content that was found in the object, aggregated into a String array.
    - parameter  allInterestsArray:  An optional string array containing all configured interests.
    */
    private func addPointsForRule(rule: JSON, content: [String]) {
        if self._isInterest {
			let foundInterests = getInterestsFromContent(rule, content: content)
			addPoints(foundInterests, score: rule[PluginConstants.Listener.TAG_POINTS].intValue)
			// addPointsForInterests(rule, content: content)
        } else if ListenerUtil.contentContainsWord(rule, content: content, interests: ListenerUtil.getWords(rule)) {
            // This is a fixed keyword
            addPoints(PluginConstants.Listener.SCORE_INTEREST, score: rule[PluginConstants.Listener.TAG_POINTS].intValue)
        }
    }

    /**
    Adds a certain number of points for the specified interests. Three methods are available for assigning points to arrays, these are:
    * any interests found
    * specified interests
    * interests based on selector

    - parameter  rule:  The JSON engagement rule, specifiying how points should be applied to the interests
    - parameter  content:  A string array representing found content for which points can be applied
    */
	//    private func addPointsForInterests(rule: JSON, content: [String]){
	internal func getInterestsFromContent(rule: JSON, content: [String]) -> [String]{
		let interestWords = ListenerUtil.getWords(rule)
        if let ruleInterests = rule[PluginConstants.Listener.TAG_INTERESTS].array where ruleInterests.count > 0 {
            if ruleInterests[0].stringValue == PluginConstants.Listener.PRE_ANY {
				//{"interests":["pre_any"]}
				// Any pre-defined interest
				return getEachInterestInContent(rule, content:content, interests:allInterests)
            } else if ListenerUtil.contentContainsWord(rule, content: content, interests: interestWords ) {
				//{"interests":["a","b","c"]}
                // Specific pre-defined interests
				return ruleInterests.map{$0.stringValue}
            }
        } else if let selector = rule[PluginConstants.Listener.TAG_INTERESTS][PluginConstants.Listener.TAG_SELECTOR].string {
			//{"interests":{"selector":"#someSelector"}}
			return ListenerUtil.getContent(selector);
        }
		return []
    }

	internal func getEachInterestInContent(rule: JSON, content: [String], interests: [String]) -> [String]{
		return interests.filter{ListenerUtil.contentContainsWord(rule, content: content, interests: [$0])}
	}

	/**
	Handles an touch event rule as set in blueconic. Similar to handleEventRule, handleContentRule, etc. Unlike other rule handlers this is called when a touch action is detected

	- parameter  touchRule:  A Json object describing the rule as configured in blueconic
	- parameter  allInterestsArray:  A string array of interests for the complete listener
	*/
	private func handleTouchEvent(touchRule: JSON, clickEvent: ClickEvent) {
		var words: [String] = ListenerUtil.getWords(touchRule)
		let clickArea = ListenerUtil.getSelector(touchRule[PluginConstants.Listener.TAG_CLICKAREA])
		let formArea = ListenerUtil.getSelector(touchRule[PluginConstants.Listener.TAG_FORM])
		if let selector = ListenerUtil.getSelector(touchRule[PluginConstants.Listener.TAG_CONTENT_AREA]) where (clickArea != nil && clickArea == clickEvent.selector) || (formArea != nil && formArea == clickEvent.selector) {
			if words[0] == PluginConstants.Listener.PRE_ANY && (selector == PluginConstants.Listener.PRE_ANY || selector == PluginConstants.Listener.ANY) {
				// NSLog("selector: \(selector)\twords \(words)")
				// this code mirrors addPointsForInterests, but doesn't have to check for content in all cases
				if self._isInterest {

					if let ruleInterests = touchRule[PluginConstants.Listener.TAG_INTERESTS].array where ruleInterests.count > 0{
						if ruleInterests[0].stringValue == PluginConstants.Listener.PRE_ANY {
							let content = ListenerUtil.getContent(selector)
							// Any pre-defined interest
							let interests = getEachInterestInContent(touchRule, content:content, interests: allInterests)
							addPoints(interests, score: touchRule[PluginConstants.Listener.TAG_POINTS].intValue)
						} else  {
							addPoints( ruleInterests.map{$0.stringValue}, score: touchRule[PluginConstants.Listener.TAG_POINTS].intValue)
						}
					} else if let ruleInterestSelector = touchRule[PluginConstants.Listener.TAG_INTERESTS][PluginConstants.Listener.TAG_SELECTOR].string {
						addPoints(ListenerUtil.getContent(ruleInterestSelector), score: touchRule[PluginConstants.Listener.TAG_POINTS].intValue)
					}

				} else {
					addPoints(PluginConstants.Listener.SCORE_INTEREST, score: touchRule[PluginConstants.Listener.TAG_POINTS].intValue)
				}
			} else {
				addPointsForRule(touchRule, content: ListenerUtil.getContent(selector))
			}
		}
	}

	/**
	* Handles the content rule when the content is updated with the update content event
	* - parameter rule: JSON object of the content rule as defined in the listener
	* - parameter updateContentEvent: The update content event
	*/
	private func handleUpdateContentEvent(rule:JSON, updateContentEvent: UpdateContentEvent) {
		// check if the selector is ok
		if let selector = rule[PluginConstants.Listener.TAG_CONTENT_AREA][PluginConstants.Listener.TAG_SELECTOR].string
			where selector.lowercaseString.rangeOfString(PluginConstants.Listener.PRE_MOBILE) != nil ||
				selector.lowercaseString == updateContentEvent.selector.lowercaseString {
			addPointsForRule(rule, content: updateContentEvent.content)
		}
	}

	private func handleAdvancedEvent(rule:JSON,  advancedEvent: AdvancedEvent){
		let event = rule[PluginConstants.Listener.TAG_EVENT].string

		if event == nil || event != advancedEvent.eventName {
			return
		}

		/*
		* When no context position has been provided, match with all values within the event context. When no context has
		* been provided match with |. This results in a positive match when "any word", and negative matches for the
		* remaining cases.
		*/
		var contextContent = ""
		if let eventContext = advancedEvent.context {
            if let contextPosition = rule[PluginConstants.Listener.TAG_CONTEXT_POSITION].string, 
                let contextPositionNr = Int(contextPosition) {
                    // When it has been provided, only match with the value at the given context position
                    contextContent = eventContext[contextPositionNr - 1]
			} else {
				contextContent = eventContext.joinWithSeparator("|")
			}
		} else {
			contextContent = "|"
		}
		addPointsForRule(rule, content: [contextContent])
	}


	/**
	* Registers an event in the event manager
	* - parameter rule: The JSON Object representing the rule as defined in the listener
	* - parameter className: Class name of the event
	*/
	private func registerEvent(rule: JSON ,  className: String) {
		// add it to the rule map
		addRuleToMap(className, rule: rule)
		let eventInstance = BlueConicEventFactory.getInstance()
        if let interactionId = self._context?.getInteractionId() {
            eventInstance.subscribe(className, listenerId: interactionId, handlerFunction: self._handler)
        }


	}

	/**
	* Manages a map from class name of the event to rule
	* - parameter eventName: Classname of the event
	* - parameter rule: The JSON Object representing the rule as defined in the listener
	*/
	private func addRuleToMap(eventName:String , rule:JSON) {
		if self._eventMap != nil {
			var rules: [JSON]? = self._eventMap![eventName]
			if rules == nil {
				rules = []
			}
			rules!.append(rule)

			self._eventMap?.updateValue(rules!, forKey: eventName)
		} else {
			self._eventMap = [eventName:[rule]]
		}
	}


    /**
    Respond to touchAction
    - parameter  sender:  the ui element that triggered the event
    */
    public func touchAction(sender: UIControl) {
		if self._debugMode {
			NSLog("clicked on \(sender), with rules \(self._elementRuleMap[sender]) ")
		}
        if let touchRules = self._elementRuleMap[sender] {
			for touchRule in touchRules {
				if let selector = touchRule[PluginConstants.Listener.TAG_CLICKAREA][PluginConstants.Listener.TAG_SELECTOR].string{
					BlueConicEventFactory.getInstance().publish(ClickEvent(selector:selector))
					BlueConicEventFactory.getInstance().publish(FormSubmitEvent(selector:selector))
					break
				}
				if let selector = touchRule[PluginConstants.Listener.TAG_FORM][PluginConstants.Listener.TAG_SELECTOR].string{

					BlueConicEventFactory.getInstance().publish(ClickEvent(selector:selector))
					BlueConicEventFactory.getInstance().publish(FormSubmitEvent(selector:selector))
					break
				}
			}
        }
    }

	private func addToRuleMap(element:UIControl, rule: JSON) {
		if self._elementRuleMap[element] == nil {
			self._elementRuleMap[element] = [rule]
		} else {
			var rules: [JSON] = self._elementRuleMap[element]!
			rules.append(rule)
			self._elementRuleMap[element] = rules
		}
	}

}

