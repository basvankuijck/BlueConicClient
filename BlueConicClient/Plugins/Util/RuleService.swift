/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/
extension JSON {
	var method: Method? {
		get {
			switch self.type {
			case .String:
				return  Method(rawValue:self.object as! String)
			default:
				return nil
			}
		}
		set {
			self.object = NSString(string:newValue!.rawValue)
		}
	}
}

enum Method: String {
	case Add = "add",
	Sum = "merge",
	Set = "set"
	var description: String {
		return self.rawValue
	}
}



import Foundation
public class RuleService: NSObject {
	private var _client: BlueConicClient?
	private var _context: InteractionContext?
	private var _debugMode: Bool = false
	private var _profileChanges: [ProfileChange] = []
	private var _listenerId: String!

	private var _eventManager: BlueConicEventManager!
	private var _eventMap: Dictionary<String,[JSON]>?

	private var _clickRuleMap: Dictionary<UIControl, [JSON]> = [UIControl: [JSON]]()

	private var _handler: EventHandler?

	public struct ProfileChange {
		var property: String
		var values: [String]
		var method: Method
		var description: String {
			return "Property: \(property), values \(values), method: \(method.description)"
		}
	}

	/**
	Inits everything needed for the engagementservice
	*/
	public convenience init(listenerId: String) {
		self.init()
		self._client = BlueConicClient.getInstance(nil)

		self._listenerId = listenerId


		// Get the debug status from the app plist
		self._debugMode = ListenerUtil.getDebugMode()
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
					self.save()
				}

			}
		})
	}


	/**
	Convenience class to apply rules. This is then transformed into a json array object my mapping each arraymember into a JSON object.
	- parameter  rules:  An array of AnyObjects
	*/
	public func applyRules(rules: [AnyObject]) {
		self.applyRules(rules.map({ JSON($0) }))
	}


	/*
	* Loops over all available rules and applies them when possible
	* :param: rules  an array of rules in a JSON object
	*/
	public func applyRules(rules: [JSON]) {
		for rule in rules {
			self.BCLog("Handling \(rule)")

			if let ruleType: String = rule[PluginConstants.Listener.TAG_RULE_TYPE].string {
				switch ruleType {
				case PluginConstants.Listener.RULETYPE_SCORE_CONTENT, "":
					self.handleContentRule(rule)
				case PluginConstants.Listener.RULETYPE_SCORE_CLICK:
					if let clickSelector = ListenerUtil.getSelector(rule[PluginConstants.Listener.TAG_CLICKAREA]) {
						self.BCLog("Adding target to \(clickSelector)")
						self.BCLog("element? \(self._client?.getView(clickSelector))")
						// We need to use var to addTarget
						if let element = self._client?.getView(clickSelector) as? UIControl {
							// map objects with their rule, since we can't set parameters with addTarget
							element.addTarget(self, action: #selector(RuleService.touchAction(_:)), forControlEvents: UIControlEvents.TouchDown)
							self.addToClickRuleMap(element, rule: rule)
							self.registerEvent(rule, className: NSStringFromClass(ClickEvent))
						} else {
							self.registerEvent(rule, className: NSStringFromClass(ClickEvent))
							self.BCLog("Element from \(clickSelector) not clickable, registering event for custom ClickEvents")
						}
					} else {
						self.BCLog("Found click rule without clickarea selector: \(rule)")
					}
				case PluginConstants.Listener.RULETYPE_SCORE_FORMSUBMIT:
					if let clickSelector = ListenerUtil.getSelector(rule[PluginConstants.Listener.TAG_FORM]) {
						// We need to use var to addTarget
						if let element = self._client?.getView(clickSelector) as? UIControl {
							// map objects with their rule, since we can't set parameters with addTarget
							element.addTarget(self, action: #selector(RuleService.touchAction(_:)), forControlEvents: UIControlEvents.TouchDown)
							self.addToClickRuleMap(element,rule: rule)
							self.registerEvent(rule, className: NSStringFromClass(FormSubmitEvent))
						} else {
							self.BCLog("Element from \(clickSelector) not clickable")
						}
					} else {
						self.BCLog("Found form submit rule without form selector: \(rule)")
					}
				case PluginConstants.Listener.RULETYPE_SCORE_URL:
					var content = ""
					if let urlRule = rule[PluginConstants.Listener.TAG_URL].string {
						// We can't reliably check referrers.
						if urlRule == "url" || urlRule == "or" || urlRule == "urlreferrer" {
							let words = ListenerUtil.getWords(rule)
							if let url = self._client?.getScreenName() {
								content += url
							} else {
								NSLog("Unable to get the current screenName with the url rule: \(rule)")
							}
                            
							if ListenerUtil.contentContainsWord(rule,content:[content],interests: words) {
								self.addProfilechange(rule)
							}
						}
					}
				case PluginConstants.Listener.RULETYPE_SCORE_EVENT, PluginConstants.Listener.RULETYPE_SCORE_SOCIAL_EVENT:
					self.registerEvent(rule, className: NSStringFromClass(AdvancedEvent))
				default:
                    self.BCLog("Invalid or not supported rule detected")
				}
			}
		}
	}

	private func getValues(rule: JSON) -> [String]? {
		var values: [String] = []

		if let value = rule[PluginConstants.Listener.TAG_VALUES].string where value == PluginConstants.Listener.TAG_DATETIME{
			//Set datetime values
			values = [ListenerUtil.getCurrentTime()]
		} else if let value = rule[PluginConstants.Listener.TAG_VALUES].arrayObject as? [String] {
			// set array of values
			values = value
		} else if let value = rule[PluginConstants.Listener.TAG_VALUES][PluginConstants.Listener.TAG_SELECTED_OPTION].string {
			//			print("rule\(rule)")
			if value == "regexp" {
				// need getlocation
                if let location = self._client?.getScreenName() {
                    let nsString = location as NSString
                    let regexString = rule[PluginConstants.Listener.TAG_VALUES]["regexp"].stringValue
                    if let regex  = try? NSRegularExpression(pattern: regexString, options: []) {
                        let results:  [NSTextCheckingResult] = regex.matchesInString(location, options: [], range: NSMakeRange(0,nsString.length))
                        let finalResult = results.map {nsString.substringWithRange($0.range)}

                        values = finalResult.filter() {$0 != ""}
                    } else {
                        self.BCLog("No valid reg. exp: '\(regexString)'")
                    }
                }
            } else if value == PluginConstants.Listener.TAG_SELECTOR {
				values = ListenerUtil.getContent(rule[PluginConstants.Listener.TAG_VALUES][PluginConstants.Listener.TAG_SELECTOR].stringValue)
			} else if value == "parameter" {
				// not suited to mobile
			}
		}

		return values.count > 0 ? values : nil
	}

	private func addProfilechange(rule: JSON) {
		if let profileProperty: String = rule[PluginConstants.Listener.TAG_PROFILE_PROPERTY][0][PluginConstants.Listener.TAG_PROFILE_PROPERTY].string {
			if let addSet = rule[PluginConstants.Listener.TAG_ADD_SET].method, values = getValues(rule) {
				self._profileChanges.append(ProfileChange(property: profileProperty, values: values, method: addSet))
			}
		}
	}

	/**
	The changes object only exists if there have been any changes, convenience function to check this.

	- returns:  bool that denotes a change has occured
	*/
	public func isChanged() -> Bool {
		return !self._profileChanges.isEmpty
	}

    private func getFirstNonEmptyValue(values: [String]?) -> String {
        if let values = values {
            for value:String in values {
                if value != "" {
                    return value.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                }
            }
        }
        // when there are no values, start counting at zero
        return "0"
    }

	/**
	Save points to BlueConic by setting the changes object to a property.
	*/
	public func save() {
		if self.isChanged() {
			for profileChange: ProfileChange in self._profileChanges {
				self.saveChange(profileChange)
			}
		}
		self._profileChanges = []

	}

	private func saveChange(change:ProfileChange) {
		self.BCLog("Profile Change: \(change.description)")
		if change.method == Method.Set{
			// Set
			self._client?.setProfileValues(change.property, values: change.values)
		} else if change.method == Method.Sum {
			// sum
			let currentValue = getFirstNonEmptyValue(self._client?.getProfileValues(change.property))
			if let summedValue = sum(currentValue ,newValues: change.values) {
				self.BCLog("Summed value: \(summedValue)")
				self._client?.setProfileValue(change.property, value: summedValue)
			} else {
				// do nothing if we can't sum
			}
		} else {
			self._client?.addProfileValues(change.property, values: change.values)
		}
	}


    private func sum(currentValue: String, newValues: [String]) -> String?{
		self.BCLog("Merging currentValue \(currentValue) with \(newValues)")
        if let currentDouble:Double = Double(convertToFormattable(currentValue)) {
			let valueMap:[Double?] = newValues.map{ return Double(self.convertToFormattable($0)) }
			return round(valueMap.filter{$0 != nil}.reduce(currentDouble){$0 + $1!}).description
        }
        return nil
    }


	private func BCLog(log:String){
		if self._debugMode {
			NSLog(log)
		}
	}


	/**
	Handles an touch event rule as set in blueconic. Similar to handleEventRule, handleContentRule, etc. Unlike other rule handlers this is called when a touch action is detected

	- parameter  touchRule:  A Json object describing the rule as configured in blueconic
	- parameter  allInterestsArray:  A string array of interests for the complete listener
	*/
	private func handleTouchEvent(touchRule: JSON, clickEvent: ClickEvent) {
        var words: [String] = ListenerUtil.getWords(touchRule)

        if let clickArea = ListenerUtil.getSelector(touchRule[PluginConstants.Listener.TAG_CLICKAREA]) where clickArea == clickEvent.selector,
            let selector = ListenerUtil.getSelector(touchRule[PluginConstants.Listener.TAG_CONTENT_AREA]) {
                if words[0] == PluginConstants.Listener.PRE_ANY && (selector == PluginConstants.Listener.PRE_ANY || selector == PluginConstants.Listener.ANY) {
                    addProfilechange(touchRule)
                } else if ListenerUtil.contentContainsWord(touchRule, content:ListenerUtil.getContent(selector), interests: words){
                    addProfilechange(touchRule)
                }
        }
	}

	/**
	* Handles the content rule when the content is updated with the update content event
	* - parameter rule: JSON object of the content rule as defined in the listener
	* - parameter updateContentEvent: The update content event
	*/
	private func handleUpdateContentEvent(rule:JSON, updateContentEvent: UpdateContentEvent) {
		self.handleContentRule(rule)
	}

	private func handleContentRule(rule:JSON) {
		if let selector = ListenerUtil.getSelector(rule[PluginConstants.Listener.TAG_CONTENT_AREA]) {
			let words = ListenerUtil.getWords(rule)
			if ListenerUtil.contentContainsWord(rule,content:ListenerUtil.getContent(selector),interests: words) {
				self.addProfilechange(rule)
			}
			self.registerEvent(rule, className: NSStringFromClass(UpdateContentEvent))
		} else {
            self.BCLog("Found content rule without selector: \(rule)")
		}
	}

	private func handleAdvancedEvent(rule:JSON,  advancedEvent: AdvancedEvent){
        if let event = rule[PluginConstants.Listener.TAG_EVENT].string where event == advancedEvent.eventName {
			var contextContent: [String] = []
			if let eventContext = advancedEvent.context {
                if let contextPosition = rule[PluginConstants.Listener.TAG_CONTEXT_POSITION].string,
                    let contextPositionNr = Int(contextPosition) {
                        // When it has been provided, only match with the value at the given context position
                        contextContent = [eventContext[contextPositionNr - 1]]
				} else {
					contextContent = eventContext
				}
			}
			let words = ListenerUtil.getWords(rule)
			if ListenerUtil.contentContainsWord(rule, content: contextContent, interests: words) {
				self.addProfilechange(rule)
			}
		}
	}


	/**
	* Registers an event in the event manager
	* - parameter rule: The JSON Object representing the rule as defined in the listener
	* - parameter className: Class name of the event
	*/
	private func registerEvent(rule: JSON ,  className: String) {
		self.BCLog("registering \(className)")
		self.addRuleToMap(className, rule: rule)
        BlueConicEventFactory.getInstance().subscribe(className, listenerId: self._listenerId, handlerFunction: self._handler)
		// add it to the rule map

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

			self._eventMap!.updateValue(rules!, forKey: eventName)
		} else {
			self._eventMap = [eventName:[rule]]
		}
	}

	/**
	Respond to touchAction
	- parameter  sender:  the ui element that triggered the event
	*/
	public func touchAction(sender: UIControl) {
		if let touchRules = self._clickRuleMap[sender] {
			for touchRule in touchRules {
				if let selector = touchRule[PluginConstants.Listener.TAG_CLICKAREA][PluginConstants.Listener.TAG_SELECTOR].string{
					BlueConicEventFactory.getInstance().publish(ClickEvent(selector:selector))
					BlueConicEventFactory.getInstance().publish(FormSubmitEvent(selector:selector))
					break
				} else if let selector = touchRule[PluginConstants.Listener.TAG_FORM][PluginConstants.Listener.TAG_SELECTOR].string{
					BlueConicEventFactory.getInstance().publish(FormSubmitEvent(selector:selector))
					BlueConicEventFactory.getInstance().publish(ClickEvent(selector:selector))
					break
				}
			}
		}
	}




	private func addToClickRuleMap(element:UIControl, rule: JSON) {
		if self._clickRuleMap[element] == nil {
			self._clickRuleMap[element] = [rule]
		} else {
			var rules: [JSON] = self._clickRuleMap[element]!
			rules.append(rule)
			self._clickRuleMap[element] = rules
		}
	}

    private func convertToFormattable(value: String) -> String {
        let hasDot = value.rangeOfString(".", options:NSStringCompareOptions.BackwardsSearch)
        let hasComma = value.rangeOfString("," , options:NSStringCompareOptions.BackwardsSearch)

        if hasDot != nil && hasComma != nil{
            var v = ""
            if hasDot?.startIndex < hasComma?.startIndex {
                v = value.stringByReplacingOccurrencesOfString(".", withString: "")
            } else {
                v = value.stringByReplacingOccurrencesOfString(",", withString: "")
            }
            return v.stringByReplacingOccurrencesOfString(",", withString: ".")
        } else if hasDot != nil || hasComma != nil {
            let divider = hasDot != nil ? "." : ","

            var valueParts = value.componentsSeparatedByString(divider)
            if valueParts.count != 2  {
                return value.stringByReplacingOccurrencesOfString(divider, withString: "")
            } else if valueParts[0].characters.count <= 3 && valueParts[1].characters.count == 3 {
                return value.stringByReplacingOccurrencesOfString(divider, withString: "")
            } else if valueParts[1].characters.count != 3 {
                return value.stringByReplacingOccurrencesOfString(divider, withString: ".")
            }
        }
        return value
    }
}