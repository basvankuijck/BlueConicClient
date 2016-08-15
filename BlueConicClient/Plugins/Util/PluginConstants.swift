/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

/*
static constants defined here
*/
struct PluginConstants {
	struct Listener {
		static let PRE_PREFIX: String = "pre_"
		static let PRE_ANY: String = "pre_any"
		static let PRE_BODY: String = "pre_body"
		static let PRE_MOBILE: String = "pre_mobile"
		static let ANY: String = "any"
		static let SCORE_INTEREST: String = "K"

		static let CONTAINS: String = "contains"
		static let MATCHES: String = "matches"

		static let RULETYPE_SCORE_URL: String = "scoreurl"
		static let RULETYPE_INTEREST_URL: String = "interesturl"
		static let RULETYPE_SCORE_FORMSUBMIT: String = "scoreformsubmit"
		static let RULETYPE_INTEREST_FORMSUBMIT: String = "interestformsubmit"
		static let RULETYPE_SCORE_CLICK: String = "scoreclick"
		static let RULETYPE_INTEREST_CLICK: String = "interestclick"
		static let RULETYPE_SCORE_CONTENT: String = "scorecontent"
		static let RULETYPE_INTEREST_CONTENT: String = "interestcontent"
		static let RULETYPE_SCORE_EVENT: String = "scoreevent"
		static let RULETYPE_INTEREST_EVENT: String = "interestevent"
		static let RULETYPE_SCORE_SOCIAL_EVENT: String = "scoresocialevent"
		static let RULETYPE_INTEREST_SOCIAL_EVENT: String = "interestsocialevent"

		static let TAG_CONTAINS_MATCHES: String = "containsmatches"
		static let TAG_RULE_TYPE: String = "ruletype"
		static let TAG_PROFILE_PROPERTY: String = "profileproperty"
		static let TAG_CONTENT_AREA: String = "contentarea"
		static let TAG_SELECTOR: String = "selector"
		static let TAG_EVENT: String = "event"
		static let TAG_CONTEXT_POSITION: String = "contextposition"
		static let TAG_FORM: String = "form"
		static let TAG_CLICKAREA: String = "clickarea"
		static let TAG_WORDS: String = "words"
		static let TAG_INTERESTS: String = "interests"
		static let TAG_POINTS: String = "points"
		static let TAG_URL: String = "url"
		static let TAG_VALUES: String = "values"
		static let TAG_REGEXP: String = "regexp"
		static let TAG_ADD_SET: String = "addset"
		static let TAG_TIME: String = "TIME"
		static let TAG_SELECTED_OPTION: String = "selectedoption"
		static let TAG_DATETIME: String = "datetime"
		static let TAG_ACTION: String = "action"
		static let TAG_TYPE: String = "type"
		static let TAG_ONCHANGE: String = "onchange"
		static let TAG_FORMFIELD: String = "formfield"
		static let TAG_FORMSELECTION: String =  "formselection"
		static let TAG_CLICKSELECTION: String =  "clickselection"
		static let TAG_CONVERTER: String = "converter"
		static let TAG_MAPPINGS: String = "mappings"

		static let URL_RULE_URL: String = "url"
		static let URL_RULE_URLREFERRER: String = "urlreferrer"
		static let URL_RULE_OR: String = "or"

		static let URL_RULE: [String] = [URL_RULE_URL, URL_RULE_URLREFERRER, URL_RULE_OR]
	}
}
