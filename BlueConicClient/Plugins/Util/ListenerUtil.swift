/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/
import Foundation
import UIKit

public class ListenerUtil {
	/**
	Checks if the collected content contains a specified word. Also checks how it should match according to blueconic configuration.
	- parameter
	- parameter
	- parameter

	- returns::
	*/
	public class func contentContainsWord(rule: JSON, content: [String], interests: [String]) -> Bool {
		//NSLog("checking content \(content) for \(interests)")

		var matchingtype = rule[PluginConstants.Listener.TAG_CONTAINS_MATCHES].string
		if matchingtype == nil {
			matchingtype = PluginConstants.Listener.CONTAINS
		}
		if content.count < 1 {
			// NSLog("Content doesn't contain words")
			return false
		}

		// join the content and lowercase it
		let contentString: String = content.joinWithSeparator(" ").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).lowercaseString

		for untrimmedInterest in interests {
			let interest = untrimmedInterest.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).lowercaseString
			// NSLog("interest: \(interest) and \(contentString)")
			if interest == PluginConstants.Listener.PRE_ANY ||  interest == "pre_header" {
				return true
			} else if rule[PluginConstants.Listener.TAG_RULE_TYPE].stringValue == PluginConstants.Listener.RULETYPE_SCORE_URL || rule[PluginConstants.Listener.TAG_RULE_TYPE].stringValue == PluginConstants.Listener.RULETYPE_INTEREST_URL {
				if matchingtype == PluginConstants.Listener.CONTAINS {
					// In swift, we shouldn't need to escape any characters within the string
					if contentString.rangeOfString(interest) != nil {
						return true
					}
				} else if contentString == interest {
					return true
				}
			} else if matchingtype == PluginConstants.Listener.CONTAINS && contentString.rangeOfString(interest) != nil {
				//NSLog("found maching word, \(interest)")
				return true
			} else if matchingtype == PluginConstants.Listener.MATCHES {
				for c in content {
					if c.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).lowercaseString == interest {
						//NSLog("found exactly maching word \(interest)")
						return true
					}
				}
			}
		}

		//	NSLog("nothing found")
		return false
	}

	public class func getWords(rule: JSON) -> [String] {
		return self.getWords(rule[PluginConstants.Listener.TAG_WORDS].arrayObject as? [String])
	}
	
	/**
	Returns words if available. If not, returns "pre_any" denoting any interest can be matched
	- parameter words:  an optional string array
	- returns:  a string array containing the provided words or one word "pre_any"
	*/
	public class func getWords(words: [String]?) -> [String] {
		if words != nil && words?.count > 0 {
			return words!
		}
		return [PluginConstants.Listener.PRE_ANY]
	}

	/**
	Returns content matching the selector. It iterates over subcontent to collect all content strings.
	- parameter  selector:  a string containing a selector, this should be in the form of "#<selector>", for example "#exampleButton". Only simple id matches are supported.
	- returns:  a string array containing all found content
	*/
	public class func getContent(selector: String) -> [String] {
		var result: Set<String> = []
		//NSLog("selector for getting content \(selector)")
		if selector.rangeOfString("jQuery(") != nil {
			// we don't want to do anything with jquery
			return []
		} else {
			let contentElement: UIView?
			if selector == "any" {
				contentElement = BlueConicClient.getInstance(nil).getViewController()?.view
			} else {
				// we first get the UIView element
				contentElement = BlueConicClient.getInstance(nil).getView(selector)
			}

			if contentElement != nil {
				// aggregate all content wihtin a uiview using a closure, applyToSubViews recursively navigates all subviews and executes the provided closure
				result = applyToSubViews(contentElement,
					apply: {
						(el: UIView) -> String? in
						el.respondsToSelector(Selector("text")) ? el.valueForKey("text") as? String : nil
					}
				)
			}
		}
		return (Array(result)).filter({$0.characters.count > 0})
	}

	/**
	This function recursively iterates over subviews depth first and applies a provided closure returning set containing all results. Since we return a set, no duplicates are returned.

	- parameter  element:  a UIView element to inspect, if it has subviews these are inspected as well
	- parameter  apply:  a closure to apply to each uiview found

	- returns:  A set of strings representing what is aggregated over the subviews.
	*/
	public class func applyToSubViews(element: UIView?, apply: (UIView) -> (String?)) -> Set<String> {
		// recursively iterate over subviews
		var resultList: Set<String> = []

		if let element = element {
			if let result = apply(element) {
				resultList.insert(result)
			}
            if let subViews: [UIView] = element.subviews {
				for subView in subViews {
					resultList = resultList.union(applyToSubViews(subView, apply: apply))
				}
			}
		}
		return resultList
	}

	/**
	Retrieves a selector from rule json
	- parameter contentArea: A piece of json containing a selector
	- returns:  A selector, if nothing is found returns nil
	*/
	public class func getSelector(contentArea: JSON?) -> String? {
		var selector: String?
		if let contentArea = contentArea {
			if let selectorString = contentArea["selector"].string {
				if selectorString == PluginConstants.Listener.PRE_ANY || selectorString == PluginConstants.Listener.PRE_BODY || selectorString == PluginConstants.Listener.PRE_MOBILE {
					selector = "any"
				} else {
					selector = selectorString
				}
			}
		}
		return selector
	}

	public class func JSONStringify(value: AnyObject, prettyPrinted: Bool = false) -> String {
		let options = prettyPrinted ? NSJSONWritingOptions.PrettyPrinted : NSJSONWritingOptions(rawValue: 0)
		if NSJSONSerialization.isValidJSONObject(value) {

			if let data = try? NSJSONSerialization.dataWithJSONObject(value, options: options),
                let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
					return string as String
            }

		} else {
			NSLog("not valid json")
		}
		return ""
	}

	/**
	Helper function to get the profile properties from the object

	- parameter parameters:  A Dictionary mapping strings to string arrays.

	- returns: an optional string array containing one or more values
	*/
	public class func getProfilePropertyFromParameters(parameters: Dictionary<String, [String]>) -> String? {
		if let propertyArray = parameters["property"],
            let jsonArray = ListenerUtil.stringToJson(propertyArray[0]) as? [Dictionary<String, String>],
            let property = jsonArray[0]["profileproperty"] where !property.isEmpty {
					return property
		}
		return nil
	}

	/**
	Returns a dictionary from the parameters

	- parameter key:  the parameter key containing the dictionary

	- returns: a Dictionary mapping string to anyobject array
	*/
	public class func getDictionaryFromParameters(context: InteractionContext?, key: String) -> Dictionary<String, [AnyObject]>? {
        if let parameters: Dictionary<String, [String]> = context?.getParameters(),
            let values = parameters[key] where values.count > 0 {
                return ListenerUtil.stringToJson(values[0]) as? Dictionary<String, [AnyObject]>
        }

		return nil
	}


	/**
	Get a value from the parameters. Retrieves the parameters from the blueconic client object itself.

	- parameter key:
	- returns: a parameter value
	*/
	public class func getValueFromParameters(context: InteractionContext?, key: String) -> String {
        if let parameters: Dictionary<String, [String]> = context?.getParameters(),
            let values = parameters[key] where values.count > 0 {
                return values[0]
        }

		return ""
	}

	public class func stringToJson(json: String) -> AnyObject? {
        do {
            return try NSJSONSerialization.JSONObjectWithData(json.dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions(rawValue: 0))
        } catch let error as NSError {
            NSLog("Json error: \(error)")
        }

		return nil
	}

	public class func getDebugMode() -> Bool {
		if let result: Bool = NSBundle.mainBundle().infoDictionary?["bc_debug"] as? Bool {
			return result
		}
		return false
	}

	public class func getCurrentTime() -> String {
		return Int64(NSDate().timeIntervalSince1970 * 1000).description
	}
}