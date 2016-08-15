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

// METHOD_TYPE used for HTTPMethod
enum METHOD_TYPE {
    case GET, POST, PUT, DELETE
    var value: String {
        switch self {
        case .GET: return "GET"
        case .POST: return "POST"
        case .PUT: return "PUT"
        case .DELETE: return "DELETE"
        }
    }
}

class BlueConicConnector: NSObject {
    private var _mobileSessionId: String?
    private var _userName: String?

    // NSConnection properties
    private var _originalRequest: NSURLRequest?
    private var _data: NSData!

    private var _error: NSError?
    private var _response: NSURLResponse?

    // Retry properties
    private var _retryCount: Int = 0
    private let MAX_RETRIES = 3

    init(userName: String?, mobileSessionId: String?) {
        self._userName = userName
        self._mobileSessionId = mobileSessionId
        self._retryCount = 0
    }

    /**
    Invokes a number of methods.

    - parameter baseUrl: The base url of the http request.
    - parameter calls: The array of method call objects
    - parameter invocationError: The place to store an error

    - returns: The mapping of method call ids to the correspondig result dictionary or nil of the invocation failed.
    - returns: The error-response of method calls, filled when something when wrong otherwise it is nil.
    */
    func execute(baseUrl: String, calls: [BlueConicRequestCommand], screenName: String?) -> (response: Dictionary<String, AnyObject>?, error: NSError?) {
        // Make sure cookies are accepted
        let cookieStore: NSHTTPCookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        if cookieStore.cookieAcceptPolicy == NSHTTPCookieAcceptPolicy.Never {
            // Set the strategy to the minimum required value
            cookieStore.cookieAcceptPolicy = NSHTTPCookieAcceptPolicy.OnlyFromMainDocumentDomain
        }
        self._data = NSData()

        // Create the request that should be executed
        let request: NSURLRequest = self.createRequest(baseUrl, commands: calls, screenName: screenName)
        self._originalRequest = request

        // Execute the request synchronously
        let queue: NSOperationQueue = NSOperationQueue()


        // FIX ME: iPad Air 2 with iOS 8.0 till 8.4 has some WiFi-problems. which could lead to an error {error.code -1005}
        NSURLConnection.sendAsynchronousRequest(request, queue: queue, completionHandler:{ (response: NSURLResponse?, data: NSData?, error: NSError?) -> Void in
            self._response = response
            self._data = data
            self._error = error
        })

        CFRunLoopRun()
        queue.waitUntilAllOperationsAreFinished()

        if self._response != nil && self._response?.URL?.absoluteString != nil && self._response!.URL!.absoluteString != baseUrl {
            if self._retryCount < MAX_RETRIES {
                self._retryCount += 1
                if BlueConicConfiguration.getDebugMode() {
                    NSLog("%@ Redirect to URL: \(Constants.Debug.DEBUG_CONNECTOR), \(self._response!.URL!.absoluteString)")
                }
                return execute(self._response!.URL!.absoluteString!, calls: calls, screenName: screenName)
            }
        }

        // Retry on failure
        if let error = self._error where error.code == -1005 {
            if self._retryCount < MAX_RETRIES {
                self._retryCount += 1
                if BlueConicConfiguration.getDebugMode() {
                    NSLog("%@ Sending data to BlueConic. Retry attempt: %i;", Constants.Debug.DEBUG_CONNECTOR, self._retryCount)
                }
                self._error = nil
                return execute(baseUrl, calls: calls, screenName: screenName)
            }
        }

        // Check weather the call completed successfully
        if self._error != nil {
            return(nil,self._error)
        }

        // Check the response
        if self._response == nil || !(self._response?.isKindOfClass(NSHTTPURLResponse) != nil) {
            return(nil,nil)
        }

        // Check the response code
        let httpResponse: NSHTTPURLResponse = self._response as! NSHTTPURLResponse
        if httpResponse.statusCode != 200 {    //200, OK
            return(nil, nil)
        }

        //Parse the response into a dictionary
        let parsedResponse = parseResponse(self._data!)

        if parsedResponse.error != nil || parsedResponse.result == nil {
            return(nil, parsedResponse.error)
        }

        // Return the results for each call in a dictionary
        return (parsedResponse.result, nil)
    }

    /**
    Parses the response data of an rpc resource call.

    - parameter data: The response bytes.
    - parameter error: The place to store an error

    :return: The mapping of method call ids to the correspondig result dictionary or nil of the invocation failed.
    :return: The error-response of the parsing, filled when something when wrong otherwise it is nil.
    */
    func parseResponse(receiveData: NSData) -> (result: Dictionary<String, AnyObject>?, error: NSError?){
        // Get the response body as String
        var result: Dictionary<String, AnyObject> = [:]
        var response: String = NSString(data: receiveData, encoding: NSUTF8StringEncoding)! as String


        if response.hasPrefix("bc_json(") {
            response = response.substringFromIndex(response.startIndex.advancedBy("bc_json(".characters.count))   //remove bc_json(
            response = response.substringToIndex(response.endIndex.advancedBy(-1))  //remove )
        }

        if BlueConicConfiguration.getDebugMode() {
            NSLog("%@ Reponse from Blueconic: %@", Constants.Debug.DEBUG_CONNECTOR, response)
        }

        var jsonError: NSError?
        let trimmedData: NSData = response.dataUsingEncoding(NSUTF8StringEncoding)!
        if trimmedData.length > 0 {
            let jsonObject: AnyObject!
            do {
                jsonObject = try NSJSONSerialization.JSONObjectWithData(trimmedData, options: NSJSONReadingOptions.MutableContainers)
            } catch let error as NSError {
                jsonError = error
                jsonObject = nil
            }

            // Check whether parsing was successful
            if jsonError != nil || jsonObject == nil {
                return (nil, jsonError)
            }

            // Expect an Array of method results
            if let jsonArray = jsonObject as? [AnyObject] {
                for resultObject in jsonArray {
                    if let methodResult = resultObject as? Dictionary<String, AnyObject> {
                        if let methodId = methodResult[Constants.ID] as? String {
                            result[methodId] = methodResult
                        }
                    }
                }
                // Return the result for each call in a dictionary
                return (result, nil)
            }
        }
        // Unable to parse the data
        return (nil, nil)
    }

    /**
    Creates the corresponding request object for the specified arguments.

    - parameter urlString: the base url
    - parameter commands: The array of method call objects that should be included in the request
    - returns: The request object for the specified parameters
    */
    func createRequest(urlString: String, commands: [BlueConicRequestCommand], screenName: String?) -> NSURLRequest {
        // Start building the request object
        let url: NSURL! = NSURL(string: urlString)
        let request: NSMutableURLRequest! = NSMutableURLRequest(URL: url)

        // Set the user agent to this framework
        request.setValue(Constants.BLUECONIC_NAME, forHTTPHeaderField: Constants.Connector.USER_AGENT_FIELD)

        // Set the referrer data
        let referrerScreenName = screenName != nil ? screenName : ""

        let referrer: String = "app://\(BlueConicConfiguration.getPackageName())/\(referrerScreenName!)"

        // Add the referrer to the HTTPHeader
        request.setValue(referrer, forHTTPHeaderField: Constants.Connector.REFERRER)
        request.setValue("close", forHTTPHeaderField: "Connection")
        // Set the timeout for the request to 30 seconds
        request.timeoutInterval = 30

        // Disable pipelingin
        request.HTTPShouldUsePipelining = false

        // Don't allow caching
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData

        // Use POST to avoid urls size limit issues
        request.HTTPMethod = METHOD_TYPE.POST.value
        request.setValue(Constants.Connector.CONTENT_TYPE_VALUE, forHTTPHeaderField: Constants.Connector.CONTENT_TYPE_FIELD)
        if BlueConicConfiguration.getDebugMode() {
            if request.allHTTPHeaderFields != nil {
                NSLog("%@ request headers to Blueconic: %@", Constants.Debug.DEBUG_CONNECTOR, request.allHTTPHeaderFields!)
            }
        }
        //println("[DEBUG] Request HEADER: \(request.allHTTPHeaderFields!)")
        request.HTTPBody = self.getPostData(commands)

        let result: NSURLRequest = request.copy() as! NSURLRequest
        return result
    }

    /**
    Creates the corresponding request body for the specified arguments.

    - parameter commands: The array of method call objects that should be included in the request body
    - returns: The request body for the specified method calls
    */
    func getPostData(commands: [BlueConicRequestCommand]) -> NSData {
        // Start with an empty result
        var allCommands: String  = "["

        // Join the calls using a comma as a delimiter
        var first: Bool = true
        for command in commands {

            if !first {
                allCommands = (allCommands ?? "") + ","
            } else {
                first = false
            }

            // Get the json string for the method call
            let json = command.toJson()
            allCommands = (allCommands ?? "") + json as String
        }
        // Close the array
        allCommands = (allCommands ?? "") + "]"

        // Url encode the resulting json array
        let encodeCommands: String = allCommands.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLFragmentAllowedCharacterSet())!

        // Get the app id to include in the request
        let encodeAppId: String = BlueConicConfiguration.getPackageName()

        // Generate the post body
        var body: String = "requests=\(encodeCommands)&overruleReferrer=\(encodeAppId)"
        body = addSimulatorData(body)
        body = addTime(body)
        if BlueConicConfiguration.getDebugMode() {
            NSLog("%@ Request body to Blueconic: %@", Constants.Debug.DEBUG_CONNECTOR, body)
        }
        //println("[DEBUG] Request BODY: \(body)")
        return body.dataUsingEncoding(NSUTF8StringEncoding)!
    }

    class func setUpdateCommand(addProperties: Dictionary<String, BlueConicCommitEntry>, setProperties: Dictionary<String, BlueConicCommitEntry>, events: [BlueConicCommitEntry]) -> [BlueConicRequestCommand] {
        var commands = [BlueConicRequestCommand]()

        // Always send a getProfile call
        commands.append(BlueConicConnector.getProfileCommand(CallId.Profile.rawValue))

        // Add a call if profile properties should be added
        if addProperties.count > 0 {
            commands.append(BlueConicConnector.getAddPropertiesCommand(CallId.AddProperties.rawValue, properties: addProperties))
        }

        // Add a call if profile properties should be set
        if setProperties.count > 0 {
            commands.append(BlueConicConnector.getSetPropertiesCommand(CallId.SetProperties.rawValue, properties: setProperties))
        }

        // Add a call if events should be created
        if events.count > 0 {
            for event in events {
                if let entry = event as? BlueConicEventCommitEntry {
                    let eventCount: Int = entry.getCount()
                    for index in 0 ..< eventCount {
                        commands.append(BlueConicConnector.getEventCommand(index + (CallId.Events.rawValue), eventType: entry.getType(), interactionId: entry.getId()))
                    }
                }
            }
        }

        return commands
    }


    /**
    Creates a BlueConicRequestCommand, which can be used by the connector to send and retrieve data.

    - parameter id: Int is an unique id that can be used when retrieving data.

    :returns a BlueConicRequestCommand that contains the profileParameters.
    */
    class func getProfileCommand(id: Int) -> BlueConicRequestCommand {
        // Create a parameter list with PAGEVIEW as object
        let parameterList: NSArray = [Constants.ProfileProperties.PARAMETER_VALUE]

        // Add the profile parameters with forceCreate as key
        let profileParameters = [Constants.ProfileProperties.PARAMETER_KEY: parameterList]

        // Create a method call with get profile as request
        return BlueConicRequestCommand(methodName: Constants.Calls.GET_PROFILE, callId: id, parameters: profileParameters, complexParameters: false)
    }

    /**
    Return the profile properties.
    - parameter hash: optional hash string of the values currently in the cache. When present, only profile properties with a different value are returned.

    - returns: The map with profile properties.
    */
    class func getGetPropertiesCommand(id: Int, hash: String?) -> BlueConicRequestCommand {
        // Add the profile parameters with forceCreate as key
        var parameters = Dictionary<String, [String]>()
        if hash != nil {
            parameters["hash"] = [hash!]
        }
        // Create a method call with getProperties as request
        return BlueConicRequestCommand(methodName: Constants.Calls.GET_PROPERTIES, callId: id, parameters: parameters, complexParameters: false)
    }

    class func getAddPropertiesCommand(id: Int, properties: Dictionary<String, BlueConicCommitEntry>) -> BlueConicRequestCommand {
            return BlueConicRequestCommand(methodName: Constants.Calls.ADD_PROPERTIES, callId: id, parameters: properties, complexParameters: true)
    }

    class func getSetPropertiesCommand(id: Int, properties: Dictionary<String, BlueConicCommitEntry>) -> BlueConicRequestCommand {
        return BlueConicRequestCommand(methodName: Constants.Calls.SET_PROPERTIES, callId: id, parameters: properties, complexParameters: true)
    }

    /**
    Creates a BlueConicRequestCommand, which can be used by the connector to send and retrieve data.

    - parameter id: Int is an unique id that can be used when retrieving data.

    - returns: a BlueConicRequestCommand that contains a create event that retrieve the interactions.
    */
    class func getInteractionCommand(id: Int) -> BlueConicRequestCommand {
        // Create a parameter list with PAGEVIEW as object
        let parameterList: NSArray = [Constants.Interactions.PARAMETER_VALUE]

        // Add the PAGEVIEW with forceCreate as key and add an empty string array with intraction as key
        let interactionParameters = [Constants.Interactions.PARAMETER_KEY: parameterList, Constants.Interactions.INTERACTION_KEY: NSArray()]

        // Create a method call with create event as request
        return BlueConicRequestCommand(methodName: Constants.Calls.CREATE_EVENT, callId: id, parameters: interactionParameters, complexParameters: false)
    }

    /*
    Creates a BlueConicRequestCommand, which can be used by the connector to send and retrieve data.

    :param: id Is an unique id that can be used when retrieving data.
    :param: eventType: The type of the event added to the parameterlist {VIEW, CLICK, CONVERSION}
    :param: interactionId: The interaction identifier
    :returns: a BlueConicRequestCommand that contains a createEvent.
    */
    class func getEventCommand(id: Int, eventType: String, interactionId: String) -> BlueConicRequestCommand {
        let eventParameters: Dictionary<String, AnyObject> = [Constants.Interactions.PARAMETER_KEY: [eventType], Constants.Interactions.INTERACTION_KEY: [interactionId]]

        return BlueConicRequestCommand(methodName: Constants.Calls.CREATE_EVENT, callId: id, parameters: eventParameters, complexParameters: false)
    }

    /**
    Adds username and mobileSessionId information to the parameters, so they can be sent in the
    request to connect to the simulator.

    - parameter parameters: The request parameters.
    */
    func addSimulatorData(body: String) -> String {
        if self._userName == nil || self._userName == "" || self._mobileSessionId == nil || self._mobileSessionId == "" {
            return body
        }
        return (body ?? "") + "&username=\(self._userName!)&mobileSessionId=\(self._mobileSessionId!)"
    }

    /**
    Adds username and mobileSessionId information to the parameters, so they can be sent in the
    request to connect to the simulator.

    - parameter parameters: The request parameters.
    */
    func addTime(body: String) -> String {
        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([.Hour, .Minute], fromDate: date)
        let time = "\(components.hour):\(components.minute)"

        return (body ?? "") + "&time=\(time)"
    }
}
