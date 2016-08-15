/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

public class FormListeningService: NSObject {
	private var _client: BlueConicClient?
	private var _context: InteractionContext?
	private var _debugMode: Bool = false
	private var _profileChanges: [ProfileChange] = []
	private var _listenerId: String!

	private var _eventManager: BlueConicEventFactory!
	private var _eventMap: Dictionary<String,[JSON]> = [String:[JSON]]()

	private var _clickRuleMap: Dictionary<UIControl, [JSON]> = [UIControl: [JSON]]()
	var delegate: UIPickerViewDelegate?
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
	Inits everything needed for the Form Listening service
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
			self.BCLog("handling event \(event) in eventmap \(self._eventMap)")

			if let rules = self._eventMap[event.name] {
				if let formSubmitEvent = event as? FormSubmitEvent {
					for rule in rules {
						if let profileChange = self.handleTouchEvent(rule, clickEvent: formSubmitEvent) {
							self._profileChanges.append(profileChange)
						}
					}
                } else if let fieldChangeEvent = event as? FieldChangeEvent {
					for rule in rules {
						if let profileChange = self.handleTouchEvent(rule, clickEvent: fieldChangeEvent) {
							self._profileChanges.append(profileChange)
						}
					}
                } else if let clickEvent = event as? ClickEvent {
                    for rule in rules {
                        if let profileChange = self.handleTouchEvent(rule, clickEvent: clickEvent) {
                            self._profileChanges.append(profileChange)
                        }
                    }
                } else if let updateValuesEvent = event as? UpdateValuesEvent {
                    for rule in rules {
                        if let profileChange = self.handleUpdateValuesEvent(rule, updateValuesEvent: updateValuesEvent) {
                            self._profileChanges.append(profileChange)
                        }
                    }
                }
                // save changes
				self.save()
			}
		})
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
			if let actionType = rule[PluginConstants.Listener.TAG_ACTION][PluginConstants.Listener.TAG_TYPE].string {
				if actionType == PluginConstants.Listener.TAG_ONCHANGE {
					if let selector = rule[PluginConstants.Listener.TAG_FORMFIELD][PluginConstants.Listener.TAG_SELECTOR].string{
						//Add something for pickerview
						if let element = self._client?.getView( selector) as? UIControl {
                            self.BCLog("Apply on change rule: \(rule)")
							let targetMethod = #selector(FormListeningService.fieldChangeAction(_:))
							switch element {
							case is UISegmentedControl, is UIDatePicker, is UIStepper, is UISwitch :
								element.addTarget(self, action: targetMethod, forControlEvents: UIControlEvents.ValueChanged)
							case is UISlider:
								if (element as! UISlider).continuous {
									element.addTarget(self, action: targetMethod, forControlEvents: UIControlEvents.TouchUpInside)
								}else{
									element.addTarget(self, action: targetMethod, forControlEvents: UIControlEvents.ValueChanged)
								}
							case is UITextField:
								element.addTarget(self, action: targetMethod, forControlEvents: UIControlEvents.EditingDidEndOnExit)
								element.addTarget(self, action: targetMethod, forControlEvents: UIControlEvents.EditingDidEnd)
								element.addTarget(self, action: targetMethod, forControlEvents: UIControlEvents.ValueChanged)
							default:
								self.BCLog("Unable to add a target to the element: \(element)")
							}
							self.addToClickRuleMap(element, rule: rule)
							self.registerEvent(rule, className: NSStringFromClass(FieldChangeEvent))
						} else if var _ = self._client?.getView(selector) as? UIPickerView {
							self.BCLog( "Can't listen to UIPickerView realtime, throw a FieldChangeEvent instead")
						} else {
                            self.BCLog("Apply on value change rule: \(rule)")
                            self.registerEvent(rule, className: NSStringFromClass(UpdateValuesEvent))
						}
					}
				} else if actionType == PluginConstants.Listener.TAG_CLICKSELECTION {
					if let selector = rule[PluginConstants.Listener.TAG_ACTION][PluginConstants.Listener.TAG_SELECTOR].string{
						// We need to use var to addTarget
						if let element = self._client?.getView( selector) as? UIControl {
                            self.BCLog("Apply on click rule: \(rule)")
							// map objects with their rule, since we can't set parameters with addTarget
							element.addTarget(self, action: #selector(FormListeningService.touchAction(_:)), forControlEvents: UIControlEvents.TouchDown)
							self.addToClickRuleMap(element, rule: rule)
						} else {
							self.BCLog("Unable to get the view with the selector: \(selector), for a click action")
						}
                        self.registerEvent(rule, className: NSStringFromClass(ClickEvent))
					}
				}  else if actionType == PluginConstants.Listener.TAG_FORMSELECTION {
					if let selector = rule[PluginConstants.Listener.TAG_ACTION][PluginConstants.Listener.TAG_SELECTOR].string{

						// We need to use var to addTarget
						if let element = self._client?.getView( selector) as? UIControl {
                            self.BCLog("Apply on form selection rule: \(rule)")
							// map objects with their rule, since we can't set parameters with addTarget
							element.addTarget(self, action: #selector(FormListeningService.touchAction(_:)), forControlEvents: UIControlEvents.TouchDown)
							self.addToClickRuleMap(element, rule: rule)
						} else {
							self.BCLog("Unable to get the view with the selector: \(selector), for a form action")
						}
                        self.registerEvent(rule, className: NSStringFromClass(FormSubmitEvent))
					}
                } else {
                    self.BCLog("Appling a rule with the type '\(actionType)' is not supported")
                }
			}
		}
	}
	private func getValues(rule: JSON) -> [String]? {

		var values: [String] = []
		if let selector = rule[PluginConstants.Listener.TAG_FORMFIELD][PluginConstants.Listener.TAG_SELECTOR].string {
			if let element = self._client?.getView( selector) as? UIPickerView {
				let cont = ListenerUtil.getContent(selector)
				self.BCLog("The content from getValues: \(cont)")
				for index in 0 ..< element.numberOfComponents {

					let rowIndex = element.selectedRowInComponent(index)
					self.BCLog("index: \(index) rowindex: \(rowIndex)")
					if let rowTitle = element.delegate?.pickerView?(element, attributedTitleForRow: rowIndex, forComponent: index){
						values.append(rowTitle.description)
					} else if let rowTitle = element.delegate?.pickerView?(element, titleForRow: rowIndex, forComponent: index) {
						values.append(rowTitle)
					}
				}
			}
			if let element = self._client?.getView( selector) as? UIControl {
				switch element {
				case is UIDatePicker:
					values = [(element as! UIDatePicker).date.description]
				case is UISegmentedControl:
					let segmentControl: UISegmentedControl = (element as! UISegmentedControl)
					if let newValue = segmentControl.titleForSegmentAtIndex(segmentControl.selectedSegmentIndex) {
						values = [newValue]
					}
				case is UISwitch:
					values = [(element as! UISwitch).on.description]
				case is UIStepper:
					values = [(element as! UIStepper).value.description]
				case is UISlider:
					values = [(element as! UISlider).value.description]
				case is UITextField:
					values = ListenerUtil.getContent(selector)
				default:
					self.BCLog("no matching type")
				}
			} else {
				self.BCLog("Unable to get the view with the selector: \(selector), for a form action")
			}
		}

		return values.count > 0 ? values : nil
	}

	private func makeProfilechange(rule: JSON) -> ProfileChange?{
		if let profileProperty: String = rule[PluginConstants.Listener.TAG_PROFILE_PROPERTY][0][PluginConstants.Listener.TAG_PROFILE_PROPERTY].string,
			addSet = rule[PluginConstants.Listener.TAG_ADD_SET].method,
			values = getValues(rule) {
			return ProfileChange(property: profileProperty, values: convertValues(rule, values: values), method: addSet)

		}
		return nil
	}

	/**
	The changes object only exists if there have been any changes, convenience function to check this.

	- returns:  bool that denotes a change has occured
	*/
	public func isChanged() -> Bool {
		return !self._profileChanges.isEmpty
	}

	/**
	Save points to BlueConic by setting the changes object to a property.
	*/
	public func save() {
		if self.isChanged() {
			self.BCLog("saving")
			for profileChange: ProfileChange in self._profileChanges {
				self.saveChange(profileChange)
			}
		}
		self._profileChanges = []

	}

	private func saveChange(change: ProfileChange) {
		self.BCLog("Profile Change: \(change.description)")
		if change.method == Method.Set{
			// Set
			self._client?.setProfileValues(change.property, values: change.values)
		}  else {
			self._client?.addProfileValues(change.property, values: change.values)
		}
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
	private func handleTouchEvent(touchRule: JSON, clickEvent: ClickEvent) -> ProfileChange? {
		if let selector = touchRule[PluginConstants.Listener.TAG_FORMFIELD][PluginConstants.Listener.TAG_SELECTOR].string where !ListenerUtil.getContent(selector).isEmpty {
			return makeProfilechange(touchRule)
		}
		return nil
	}

    /**
     Handles the update value event. change the profile property by the values from the update values event.
     - parameter  touchRule:  A Json object describing the rule as configured in blueconic
     - parameter  updateValuesEvent:  the event with the profile property values.
     */
    private func handleUpdateValuesEvent(rule: JSON, updateValuesEvent: UpdateValuesEvent) -> ProfileChange? {
        if let selector = rule[PluginConstants.Listener.TAG_FORMFIELD][PluginConstants.Listener.TAG_SELECTOR].string where selector == updateValuesEvent.selector,
            let profileProperty: String = rule[PluginConstants.Listener.TAG_PROFILE_PROPERTY][0][PluginConstants.Listener.TAG_PROFILE_PROPERTY].string,
            addSet = rule[PluginConstants.Listener.TAG_ADD_SET].method where updateValuesEvent.values.count > 0 {
                return ProfileChange(property: profileProperty, values: convertValues(rule, values: updateValuesEvent.values), method: addSet)
        }
        return nil
    }


	/**
	Handles an touch event rule as set in blueconic. Similar to handleEventRule, handleContentRule, etc. Unlike other rule handlers this is called when a touch action is detected

	- parameter  touchRule:  A Json object describing the rule as configured in blueconic
	- parameter  allInterestsArray:  A string array of interests for the complete listener
	*/
	private func handleFieldChangeEvent(touchRule: JSON, clickEvent: ClickEvent) -> ProfileChange? {
		if let selector = ListenerUtil.getSelector(touchRule["contentarea"]) where !ListenerUtil.getContent(selector).isEmpty {
			return makeProfilechange(touchRule)
		}
		return nil
	}

	/**
	* Registers an event in the event manager
	* - parameter rule: The JSON Object representing the rule as defined in the listener
	* - parameter className: Class name of the event
	*/
	private func registerEvent(rule: JSON ,  className: String) {
		self.BCLog("registering \(className)")
		// add it to the rule map
		self.addRuleToMap(className, rule: rule);
		BlueConicEventFactory.getInstance().subscribe(className, listenerId: self._listenerId, handlerFunction: self._handler)
	}

	/**
	* Manages a map from class name of the event to rule
	* - parameter eventName: Classname of the event
	* - parameter rule: The JSON Object representing the rule as defined in the listener
	*/
	private func addRuleToMap(eventName: String, rule: JSON) {
		if self._eventMap[eventName] != nil {
			self._eventMap[eventName]?.append(rule)
		} else {
			self._eventMap[eventName] = [rule]
		}
	}

	/**
	Respond to fieldChangeAction
	- parameter  sender:  the ui element that triggered the event
	*/
	public func fieldChangeAction(sender: UIControl) {
		if let touchRules = self._clickRuleMap[sender] {
			for touchRule in touchRules {
				if let selector = touchRule["formfield"]["selector"].string{
					BlueConicEventFactory.getInstance().publish(FieldChangeEvent(selector:selector))
					break
				}
			}
		}
	}

	/**
	Respond to touchAction
	- parameter  sender:  the ui element that triggered the event
	*/
	public func touchAction(sender: UIControl) {
		if let touchRules = self._clickRuleMap[sender] {
			for touchRule in touchRules {
				if let selector = touchRule["action"]["selector"].string {
					BlueConicEventFactory.getInstance().publish(FormSubmitEvent(selector:selector))
					break
				}
			}
		}
	}

	private func addToClickRuleMap(element: UIControl, rule: JSON) {
		if self._clickRuleMap[element] == nil {
			self._clickRuleMap[element] = [rule]
		} else {
			var rules: [JSON] = self._clickRuleMap[element]!
			rules.append(rule)
			self._clickRuleMap[element] = rules
		}
	}

	public func convertValues(rule: JSON, values: [String]) -> [String]{
		if let mappings = rule[PluginConstants.Listener.TAG_CONVERTER][PluginConstants.Listener.TAG_MAPPINGS].array{
			return values.map({self.getConvertedValue($0, mappings: mappings)})
		}
		return values
	}

	private func getConvertedValue(value: String, mappings: [JSON]) -> String {
		for mapping in mappings {
			if let original = mapping["o"].string, change = mapping["c"].string where original == value  {
				return change
			}
		}
		return value
	}
}