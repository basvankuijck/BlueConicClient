/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

public class PreferredHourListener: Plugin {

	private var _client: BlueConicClient?
	private var _context: InteractionContext?

	static let LOG_TAG:String = "PREFERRED_HOUR"
	static let PARAMETER_PROPERTY:String = "property"
	static let PARAMETER_LOCALE:String = "locale"
	static let TAG_PROFILE_PROPERTY:String = "profileproperty"

	/**
	Default initializer for a blueconic plugin
	- parameter  client:  An instance of the BlueConicClient
	- parameter  context:  An instance of the InteractionContext
	*/
	public override convenience init(client: BlueConicClient, context: InteractionContext) {
		self.init()
		self._client = client
		self._context = context

	}

	/**
	OnLoad function for blueconic plugin.
	This starts the plugin.
	*/
	public override func onLoad() {
		if self._client == nil {
			return
		}

		// get the values from the parameters
        if let context = self._context,
            let property:String = ListenerUtil.getProfilePropertyFromParameters(context.getParameters()) {
                let locale:String = ListenerUtil.getValueFromParameters(context, key: PreferredHourListener.PARAMETER_LOCALE)

                let now = NSDate()
                let myCalendar = NSCalendar.currentCalendar()
                let comps = myCalendar.components(NSCalendarUnit.Hour, fromDate: now)
                let hours = comps.hour

                let timeFrame:String = getTimeFrame(hours, locale: locale);
                let days = daysSince2012(now, userCalendar: myCalendar)
                let newChanges: JSON = [timeFrame: ["p\(days)": 1], "TIME":ListenerUtil.getCurrentTime()]
                self._client?.addProfileValue("_\(property)",  value:newChanges.description)

		}
	}

	private func daysSince2012(now:NSDate, userCalendar: NSCalendar) -> Int{
		let baseDateComponents = NSDateComponents()
		baseDateComponents.year = 2012
		baseDateComponents.month = 1
		baseDateComponents.day = 1
		baseDateComponents.timeZone = NSTimeZone(name: "UTC")
		let base: NSDate = userCalendar.dateFromComponents(baseDateComponents)!
		return Int(floor((NSDate().timeIntervalSinceDate(base) as Double) / (24 * 3600)))
	}

	/**
	* Returns the hour timestamp, eg 09:00 - 10:00 for NL and 9 AM - 10 AM for US
	*/
	private func getTimeFrame( hour:Int, locale:String) -> String {
		return "\(getHour(hour, locale: locale)) - \(getHour(hour + 1, locale:locale))"
	}

	/**
	* Returns the timestamp for one hour, eg 09:00 for NL and 9 AM for US
	*/
	private func getHour(hour: Int, locale: String) -> String  {
        var resultHour = hour
		if "en-us" == locale {
			// use US notation
			let amPm: String = hour >= 12 ? "PM" : "AM"
			resultHour = resultHour % 12
			resultHour = resultHour == 0 ? 12: resultHour // the hour '0' should be '12'

			return "\(resultHour) \(amPm)"
		} else {
			// use NL notation
			let hourString: String = (hour < 10 ? ("0 \(hour)") : "\(hour)")
			return "\(hourString):00"
		}

	}
}