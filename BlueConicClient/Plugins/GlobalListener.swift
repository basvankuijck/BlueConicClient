/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

public class GlobalListener: Plugin {
    private var _client: BlueConicClient?
    private var _context: InteractionContext?
    
    struct Property {
        // Expire interval for visits. When this interval is passed without pageview we start the "visitclick" at 0.
        // Number in minutes.
        
        static let VISIT_EXPIRE_INTERVAL: Int = 30 * 60 * 1000 // 1800000 equals to 30 minutes
        
        // Global listener properties.
        static let CURRENT_OSNAME: String = "currentosname";
        static let OSNAME: String = "osname";
        static let CURRENT_OSVERSION: String = "currentosversion";
        static let OSVERSION: String = "osversion";
        static let CURRENT_RESOLUTION: String = "currentresolution";
        static let CURRENT_SCREEN_WIDTH: String = "currentscreenwidth";
        static let CURRENT_SCREEN_HEIGHT: String = "currentscreenheight";
        static let RESOLUTION: String = "resolution";
        static let LANGUAGE: String = "language";
        
        // Visits to the app.
        static let VISITS: String = "visits";
        
        // Page views current session.
        static let VISIT_CLICKS: String = "visitclicks";
        
        // Page views overall.
        static let CLICK_COUNT: String = "clickcount";
        static let LAST_VISIT_DATE: String = "lastvisitdate";
        
        // Mobile specific properties (for global listener).
        static let APP_ID: String = "mobile_app_id";
        static let APP_NAME: String = "mobile_app_name";
        static let APP_NAME_VERSION: String = "mobile_app_nameversion";
        static let APP_VENDOR: String = "mobile_app_vendor";
        static let APP_MODEL: String = "mobile_app_model";
        static let APP_DPI: String = "mobile_app_dpi";
    }
    
    public override convenience init(client: BlueConicClient, context: InteractionContext) {
        self.init()
        self._client = client
        self._context = context
    }
    
    public override func onLoad() {
        self.setSystemInformation()
        self.setStatistics()
    }
    
    /**
    * Sets system information to the profile(software and hardware)
    */
    private func setSystemInformation() {
        var propertyValuesToAdd = Dictionary<String, [String]>()
        var propertyValuesToSet = Dictionary<String, [String]>()
        
        if self._client?.getViewController() != nil {
            // Store the information of the operating system
            let systemName: String = UIDevice.currentDevice().systemName
            let systemVersion: String = UIDevice.currentDevice().systemVersion
            let version: String = "\(systemName) \(systemVersion)"
            
            // Store the screensizes of the mobile
            let screenRect: CGRect = UIScreen.mainScreen().bounds
            let screenWidth: CGFloat = screenRect.width
            let screenHeight: CGFloat = screenRect.height
            let scale: CGFloat = UIScreen.mainScreen().scale
            let resuolution: String = "\(Int(screenWidth * scale))x\(Int(screenHeight * scale))"

            // Global listener properties.
            // Get the OS information.
            propertyValuesToSet[Property.CURRENT_OSNAME] = [systemName]
            propertyValuesToAdd[Property.OSNAME] = [systemName]
            
            propertyValuesToSet[Property.CURRENT_OSVERSION] = [version]
            propertyValuesToAdd[Property.OSVERSION] = [version]
            
            propertyValuesToSet[Property.CURRENT_SCREEN_WIDTH] = ["\(Int(screenWidth))"]
            propertyValuesToSet[Property.CURRENT_SCREEN_HEIGHT] = ["\(Int(screenHeight))"]
            propertyValuesToSet[Property.CURRENT_RESOLUTION] = [resuolution]
            propertyValuesToAdd[Property.CURRENT_RESOLUTION] = [resuolution]
            
            // Get the Languages
            propertyValuesToSet[Property.LANGUAGE] = [getSystemLanguage()]
            
            if let info = NSBundle.mainBundle().infoDictionary {
                if info.count > 0 {
                    // Set app ID
                    let appId: String = info[Constants.MobileApp.BUNDLE_IDENTIFIER] as! String
                    
                    // Set app name
                    var appName: String? = info[Constants.MobileApp.BUNDLE_NAME] as? String
                    if appName == nil {
                        appName = info[Constants.MobileApp.SWIFT_BUNDLE_NAME] as? String
                    }
                    if appName == nil {
                        appName = appId
                    }
                    // Set app version
                    let appVersion: String = info[Constants.MobileApp.BUNDLE_VERSION] as! String
                    let appNameVersion: String = "\(appName!) \(appVersion)"
                    
                    // Set device name
                    let deviceName: String = self.platformNiceString()
                    
                    propertyValuesToSet[Property.APP_ID] = [appId]
                    propertyValuesToSet[Property.APP_NAME] = [appName!]
                    propertyValuesToSet[Property.APP_NAME_VERSION] = [appNameVersion]
                    propertyValuesToSet[Property.APP_VENDOR] = ["Apple"]
                    propertyValuesToSet[Property.APP_MODEL] = [deviceName]
                }
            }
        }
        self.handleProperties(propertyValuesToAdd, propertyValuesToSet: propertyValuesToSet)
    }
    
    /**
    * Set statistics to the profile.<br />
    * 1. clickcount - Pageviews overall.<br />
    * 2. visitclicks - Pageviews current session. A new session is started when an interval of "VISIT_EXPIRE_INTERVAL"<br />
    * 3. visits - Visits to the app (new visit after 30 min is passed without a pageview).<br />
    */
    private func setStatistics() {
        let propertyValuesToAdd = Dictionary<String, [String]>()
        var propertyValuesToSet = Dictionary<String, [String]>()
        
        if let client: BlueConicClient = self._client {
            
            // Get the last time this profile visited one of the domains. Note that this is not the "lastvisit"
            // which is determined serverside.
            let lastVisitDateValue: String = client.getProfileValue(Property.LAST_VISIT_DATE)
            
            // Visits to the app (new visit is counted when VISIT_EXPIRE_INTERVAL min. is passed since previous pageview).
            let visitsValue: String = client.getProfileValue(Property.VISITS)
            
            // Page views overall.
            let clickCountValue: String = client.getProfileValue(Property.CLICK_COUNT)
            
            // Page views current session.
            let visitClicksValue: String = client.getProfileValue(Property.VISIT_CLICKS)

            // Get the Int64 value
            let lastVisitDate: Int64 = NSString(string: lastVisitDateValue).longLongValue
            let visits: Int64 = NSString(string: visitsValue).longLongValue
            let clickCount: Int64 = NSString(string: clickCountValue).longLongValue
            let visitClicks: Int64 = NSString(string: visitClicksValue).longLongValue
            
            // Increase the click count
            let newClickCount: Int64 = clickCount + 1
            
            // Get the current time in millis
            let now = NSDate()
            let nowInMillis: Int64 = Int64(now.timeIntervalSince1970 * 1000)
            
            // Determine the expire date(e.g. when we need start counting again).
            let expire = lastVisitDate + Property.VISIT_EXPIRE_INTERVAL
            
            // MARK: Update the properties
            
            // 1. Set the click count (e.g. the overall page views).
            propertyValuesToSet[Property.CLICK_COUNT] = ["\(newClickCount)"]

            if nowInMillis > expire || visits == 0 {
                // 2. visitClicks - Page views current session. Restart the count.
                propertyValuesToSet[Property.VISIT_CLICKS] = ["\(1)"]
                
                // 3. Visits to the app.
                propertyValuesToSet[Property.VISITS] = ["\(visits+1)"]
            } else {
                // 2. visitClicks - Page views current session.
                propertyValuesToSet[Property.VISIT_CLICKS] = ["\(visitClicks+1)"]
            }

            
            // 4. Update the "lastvisitdate".
            propertyValuesToSet[Property.LAST_VISIT_DATE] = ["\(nowInMillis)"]
            
            // Store the values on the profile
            self.handleProperties(propertyValuesToAdd, propertyValuesToSet: propertyValuesToSet)
            
            
        }
    }
    
    /**
    * Handle property values.
    * @param propertyValuesToAdd Values to add to the current values of the property.
    * @param propertyValuesToSet Values to set to the property(removes the old values).
    */
    private func handleProperties(propertyValuesToAdd: Dictionary<String, [String]>, propertyValuesToSet: Dictionary<String, [String]>) {
    
        // Handle the properties to set
        for (key,value) in propertyValuesToSet {
            self._client?.setProfileValues(key, values: value)
        }
        
        // Handle the properties to set
        for (key,value) in propertyValuesToAdd {
            self._client?.addProfileValues(key, values: value)
        }
    }
    
    private func getSystemLanguage() -> String {
        let languages =  NSLocale.preferredLanguages()
        if languages.count > 0 {
            let language: String = languages[0] 
            if language.characters.count >= 2 {
                return language.substringToIndex(language.startIndex.advancedBy(2))
            }
        }
        return ""
    }
    
    
    // MARK: Device hardware
    // See https://gist.github.com/Jaybles/1323251 for the inspired code
    
    /**
    * Returns the platform name as rawvalue
    *
    * @return The unique phone/tablet/simulator platform name
    */
    func platformRawString() -> String {
        var size : Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](count: Int(size), repeatedValue: 0)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String.fromCString(machine)!
    }
    
    /**
    * Convert platformRawString to a readable String
    * If the Raw platform string is not equals to one of those platformen below then it will return the raw-value
    * Last updated at: 11th March 2015 - Added iPhone 6 and iPad Mini 2G
    *
    * @return   a nice string of the platform that is running the app
    */
    func platformNiceString() -> String {
        let platform: String = self.platformRawString()
        if platform == "iPhone1,1" {   return "iPhone 1G" }
        if platform == "iPhone1,2" {   return "iPhone 3G" }
        if platform == "iPhone2,1" {   return "iPhone 3GS" }
        if platform == "iPhone3,1" {   return "iPhone 4" }
        if platform == "iPhone3,2" {   return "iPhone 4" }
        if platform == "iPhone3,3" {   return "Verizon iPhone 4" }
        if platform == "iPhone4,1" {   return "iPhone 4S" }
        if platform == "iPhone5,1" {   return "iPhone 5 (GSM)" }
        if platform == "iPhone5,2" {   return "iPhone 5 (GSM+CDMA)" }
        if platform == "iPhone5,3" {   return "iPhone 5C (GSM)" }
        if platform == "iPhone5,4" {   return "iPhone 5C (GSM+CDMA)" }
        if platform == "iPhone6,1" {   return "iPhone 5S (GSM)" }
        if platform == "iPhone6,2" {   return "iPhone 5S (GSM+CDMA)" }
        if platform == "iPhone7,1" {   return "iPhone 6+" }
        if platform == "iPhone7,2" {   return "iPhone 6" }
        
        if platform == "iPod1,1"   {   return "iPod Touch 1G" }
        if platform == "iPod2,1"   {   return "iPod Touch 2G" }
        if platform == "iPod3,1"   {   return "iPod Touch 3G" }
        if platform == "iPod4,1"   {   return "iPod Touch 4G" }
        if platform == "iPod5,1"   {   return "iPod Touch 5G" }
        
        if platform == "iPad1,1"   {   return "iPad" }
        if platform == "iPad2,1"   {   return "iPad 2 (WiFi)" }
        if platform == "iPad2,2"   {   return "iPad 2 (GSM)" }
        if platform == "iPad2,3"   {   return "iPad 2 (CDMA)" }
        if platform == "iPad2,4"   {   return "iPad 2 (WiFi)" }
        if platform == "iPad2,5"   {   return "iPad Mini (WiFi)" }
        if platform == "iPad2,6"   {   return "iPad Mini (GSM)" }
        if platform == "iPad2,7"   {   return "iPad Mini (GSM+CDMA)" }
        if platform == "iPad3,1"   {   return "iPad 3 (WiFi)" }
        if platform == "iPad3,2"   {   return "iPad 3 (GSM+CDMA)" }
        if platform == "iPad3,3"   {   return "iPad 3 (GSM)" }
        if platform == "iPad3,4"   {   return "iPad 4 (WiFi)" }
        if platform == "iPad3,5"   {   return "iPad 4 (GSM)" }
        if platform == "iPad3,6"   {   return "iPad 4 (GSM+CDMA)" }
        if platform == "iPad4,1"   {   return "iPad Air (WiFi)" }
        if platform == "iPad4,2"   {   return "iPad Air (Cellular)" }
        if platform == "iPad4,3"   {   return "iPad Air" }
        if platform == "iPad4,4"   {   return "iPad Mini 2G (WiFi)" }
        if platform == "iPad4,5"   {   return "iPad Mini 2G (Cellular)" }
        if platform == "iPad4,6"   {   return "iPad Mini 2G" }
        
        if platform == "i386"      {   return "Simulator" }
        if platform == "x86_64"    {   return "Simulator" }
        return platform
    }    
}