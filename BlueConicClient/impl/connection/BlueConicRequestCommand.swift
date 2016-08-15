/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

class BlueConicRequestCommand: NSObject {


    // Private variables
    private var _methodName: String!
    private var _callId: String!
    private var _parameters: Dictionary<String, AnyObject>?
    private var _complexParameters: Bool = false

    /**
    Constructs a method call with the specified method name.

    - parameter methodName: The method name of the call, eg getProperties
    - parameter callId: The identifier for this method call
    */
    convenience init(methodName: String, callId: Int) {
        self.init(methodName: methodName, callId: callId, parameters: nil, complexParameters: false)
    }

    /**
    Constructs a method call with the specified method name and parameters.

    - parameter methodName: The method name of the call, eg "getProperties"
    - parameter callId: The identifier for this method call
    - parameter parameters: The map of parameters names to corresponding values, possibly nil.
    - parameter complexParameters: Indicates whether the parameters are complex parameters.
    */
    init(methodName: String, callId: Int, parameters: Dictionary<String, AnyObject>?, complexParameters: Bool) {
        super.init()
        self._methodName = methodName
        self._callId = "\(callId)" as String
        self._parameters = parameters
        self._complexParameters = complexParameters
    }

    /**
    Creates the json String representation for this method call.

    - returns:  the json String representation for this method call.
    */
    func toJson() -> String {

        // Create a new dictionary to store the method call attributes
        var dictionary: Dictionary<String, AnyObject> = [:]
        dictionary[Constants.METHOD] = self._methodName
        dictionary[Constants.Calls.JSON_KEY] = Constants.Calls.JSON_VALUE
        dictionary[Constants.ID] = self._callId

        if let parameters = self._parameters {

            var parametersValues = Dictionary<String, AnyObject>()
            if self._complexParameters {
                // Create a map of parameters
                parametersValues = [Constants.PROPERTIES: self.getValuesOfEntries(parameters)]
            } else {
                parametersValues = parameters
            }

            // Convert the map to json and add the result to main map
            var mapData: NSData?
            do {
                mapData = try NSJSONSerialization.dataWithJSONObject(parametersValues, options: [])
            } catch {
                mapData = nil
            }
            let mapJson: String? = NSString(data: mapData!, encoding: NSUTF8StringEncoding) as? String
            dictionary[Constants.PARAMS] =  mapJson!
        }

        // Convert the map to the json representation
        var data: NSData?
        do {
            data = try NSJSONSerialization.dataWithJSONObject(dictionary, options: [])
        } catch {
            data = nil
        }
        return NSString(data: data!, encoding: NSUTF8StringEncoding) as! String
    }

    /**
    Returns a Dictionary with all values of each PropertyCommitEntry
    This function is needed to validate a complexParamters JSONSerialization

    - parameter parameters: a Dictionary with BlueConicPropertyCommitEntries
    - returns: A Dictionary with the values as an Array of each BlueConicPropertyCommitEntry
    */
    func getValuesOfEntries(parameters: Dictionary<String, AnyObject>) -> Dictionary<String, AnyObject> {
        var result = Dictionary<String, AnyObject>()
        for (key, value) in  parameters {
            if let entry = value as? BlueConicPropertyCommitEntry {
                result[key] = entry.getValues()
            }
        }
        return result
    }
}