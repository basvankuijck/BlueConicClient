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

public enum EventType: String {
    case CLICK = "CLICK"
    case VIEW = "VIEW"
    case CONVERSION = "CONVERSION"
}

public enum OperationType: String {
    case ADD = "ADD"
    case SET = "SET"
}

public enum CallId: Int {
    case Profile, AddProperties, SetProperties, GetProperties, Interactions, Events
}

class BlueConicConfiguration {
    
    private var _mobileSessionId: String?
    private var _userName: String?

    private var _overruleHostname: String?

    init(){

    }

    /**
    Method returns the Hostname from mainbundle infoDictionary

    - returns: the hostname or nil
    */
    func getHostName() -> String {

        if let overrule = self._overruleHostname {
            return overrule
        }

        var result = ""
        if let hostname = NSBundle.mainBundle().infoDictionary?[Constants.HOST_NAME] as? String {
            if hostname.hasSuffix("/") {
                return hostname.substringToIndex(hostname.endIndex.advancedBy(-1))
            }
            result = hostname
        }

        return result
    }

    /**
    Setter for the hostname.
    
    - parameter hostname,: e.g. 'https://example.blueconic.com'
    */
    func setHostName(hostName: String) {
        self._overruleHostname = hostName
    }

    /**
    Get the PackageName of the Mobile app which is using BlueConicClient
    PackageName is something like com.blueconictest.BCTestApp

    - returns:   a string with NSUTF8StringEncoding (e.q. com.blueconic.TestBCTestApp)
    */
    class func getPackageName() -> String {
        if let info = NSBundle.mainBundle().infoDictionary,
            appId = info[Constants.MobileApp.BUNDLE_IDENTIFIER] as? String {
                let encodeAppId: String? = appId.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLFragmentAllowedCharacterSet())!
            if let result = encodeAppId {
                return result
            }
        }
        return ""
    }

    /**
    Method returns an URL for which the BCSessionId cookie needs to be set(or retrieved).

    - parameter hostName: The hostname.
    - parameter domainGroup: The domain group.
    - returns: The URL.
    */
    class func getDomaingGroupUrl(hostName: String, domainGroup: String?) -> String {
        let domain: String = domainGroup != nil ? domainGroup! : Constants.Connector.DOMAIN_VALUE
        return hostName + "/DG/" + domain + "/rest/rpc/?"
    }



    /**
    Method that returns the Debug Mode, which is set in the main bundle

    - returns:   the debug mode, when true it will log the debug information to the console
    */

    class func getDebugMode() -> Bool {

        if let result: Bool = NSBundle.mainBundle().infoDictionary?[Constants.DEBUG_MODE] as? Bool {
            return result
        }
        return false
    }


    /*
    Set Simulator Data
    When a QR code is scanned it will call this function to save the username and mobile session id
    During this session it will add the username and mobile session id to each method call

    :param: userName this value will be the user's e-mailaddress who is logged at the BlueConic Simulator
    :param: mobileSessionId is an unique id, which allows requests to be send as "Simulated"
    */
    func setSimulatorData(userName: String, mobileSessionId: String) {
        self._userName = userName
        self._mobileSessionId = mobileSessionId
    }

    func getSimulatorUsername() -> String? {
        return self._userName
    }

    func getSimulatorSessionId() -> String? {
        return self._mobileSessionId
    }

    // MARK: Visable ViewController

    /**
    Method that gets the current visible ViewController
    It recieves the root ViewController from sharedApplication
    and loops through it until the current active View Controller is found
    
    - returns:   the active view controller from the Application.
    */
    class func getVisibleViewController() -> UIViewController? {
        if let rootViewController: UIViewController = UIApplication.sharedApplication().keyWindow?.rootViewController {
            return getVisibleViewControllerFrom(rootViewController)
        }
        return nil
    }


    class func getVisibleViewControllerFrom(rootViewController: UIViewController) -> UIViewController  {
        if let nav = rootViewController as? UINavigationController {
            return getVisibleViewControllerFrom(nav.visibleViewController!)
        }
        if let tab = rootViewController as? UITabBarController {
            if let selected = tab.selectedViewController {
                return getVisibleViewControllerFrom(selected)
            }
        }
        if let presented = rootViewController.presentedViewController {
            return getVisibleViewControllerFrom(presented)
        }
        return rootViewController
    }

    class func parametersToDictionary(parameters: [Dictionary<String, AnyObject>]) -> Dictionary<String, [String]> {
        var result = Dictionary<String, [String]>()
        if parameters.count > 0 {
            for parameterDictionary in parameters {
                var paramKey = ""
                var paramValue = [String]()
                for (key,value) in parameterDictionary {
                    if key == "id" {
                        paramKey = value as! String
                    } else if key == "value" {
                        paramValue = value as! [String]
                    }
                }
                result[paramKey] = paramValue
            }
        }
        return result
    }

}