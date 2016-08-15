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

/**
Interface InteractionContext
*/
@objc public class InteractionContext: NSObject {
    private var _id: String?
    private var _type: String?
    private var _positionIdentifier: String?
    private var _parameters = Dictionary<String, [String]>()
    private var _context: UIViewController?
    private var _locale: String?
    private var _defaultLocale: String?

    private let _debugMode = BlueConicConfiguration.getDebugMode()

    /**
    Default init() for BlueConicCommitLog
    
    - parameter interactions: is a collection of data that is retrieved from the server
    - parameter context: The current ViewController
    - parameter locale: The locale the interaction should use, e.g. 'en_US'
    */
    init(interaction: Dictionary<String, AnyObject>, context: UIViewController?, locale: String?) {
        super.init()
        self._id = interaction[Constants.Interactions.ID] as? String
        self._type = interaction[Constants.Interactions.TYPE] as? String
        self._positionIdentifier = interaction[Constants.Interactions.POSITION_KEY] as? String
        self._defaultLocale = interaction[Constants.Interactions.DEFAULT_LOCALE] as? String

        let allParameters = interaction[Constants.Interactions.PARAMETERS] as! [Dictionary<String, AnyObject>]
        if locale != nil && locale!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) != "" {
            self._parameters = getParametersOfLocale(allParameters, locale: locale!)

        } else {
            if let defaultLocale = self._defaultLocale {
                self._parameters = getParametersOfLocale(allParameters, locale: defaultLocale)
            }
        }
        self._context = context
        self._locale = locale
    }

    /**
    Returns the interaction id.
    &lt;pre&gt:
    // Swift: 
    let interactionId: String? = context.getInteractionId()
    
    // Objective-C: 
    NSString* interactionId = [context getInteractionId];
    &lt;/pre&gt:

    - returns:     The interaction id
    */
    public func getInteractionId() -> String? {
        return self._id
    }

    /**
    Returns the interaction parameters in a map.
    &lt;pre&gt:
    // Swift: 
    let parameters: Dictionary<String, [String]> = context.getParameters()
    
    // Objective-C: 
    NSDictinoary* parameters = [context getParameters];
    &lt;/pre&gt:

    - returns:     The parameters
    */
    public func getParameters() -> Dictionary<String, [String]> {
        return self._parameters
    }


    /**
    Returns the connection by id.
    &lt;pre&gt:
    // Swift:
    let context: InteractionContext!
    let connection: Connection? = context.getConnection(connectionId)

    // Objective-C:
    InteractionContext* context;
    Connection* connection = [context getConnection:connectionId];
    &lt;/pre&gt:

    - returns:     The connection.
    */
    public func getConnection(id: String) -> Connection? {
        if id == "" {
            return nil;
        }
        for connection in BlueConicClient.getInstance(nil).getConnections() {
            if connection.getId() == id {
                return connection
            }
        }
        return nil
    }

    /**
    Returns a view for the interaction.
    &lt;pre&gt:
    // Swift: 
    let view: UIView? = context.getView()
    
    // Objective-C: 
    UIView* view = [context getView];
    &lt;/pre&gt:

    - returns:     The component matching the selector or the position of the interaction or null if no match is found.
    */
    public func getView() -> UIView? {
        return BlueConicClient.getView(self._context, selector: self._positionIdentifier)
    }


    /**
    Returns the 'selector' of the position.
    &lt;pre&gt:
    // Swift: 
    let position: String? = context.getPositionIdentifier()
    
    // Objective-C: 
    NSString* position = [context getPositionIdentifier];
    &lt;/pre&gt:

    - returns:     The selector, e.g. "#position_1"
    */
    public func getPositionIdentifier() -> String? {
        return self._positionIdentifier
    }

    /**
     Returns the Locale dictionary.
     first, if the locale exists in allParameters return the dictionary based on that locale
     second, if the locale doesn't exists but the default locale does. then return the dictionary based on the default locale
     third, if the locale and the default locale doesn't exists, then return the dictinonary based on the first locale
     fourth, if the are not locales available to use, return an empty dictionary
     - returns: Map based on the locale.
    */
    private func getLocaleDictionary(allParameters: [Dictionary<String, AnyObject>], locale: String) -> [Dictionary<String, AnyObject>] {
        var availableLocales: [String] = []
        for dictionary in allParameters {
            // add all locales to an array
            if let locale = dictionary[Constants.Interactions.LOCALE] as? String {
                availableLocales.append(locale)
            }

            // get the parameters of the locale
            if locale == dictionary[Constants.Interactions.LOCALE] as? String {
                if let parameters = dictionary["parameter"] as? [Dictionary<String, AnyObject>] {
                    if self._debugMode {
                        NSLog("%@ Locale used: '%@'", Constants.Debug.DEBUG_CLIENT, locale)
                    }
                    return parameters
                }
            }
        }

        // if the locale didn't exists as locale, use the default locale instead.
        if let defaultLocale = self._defaultLocale where locale != self._defaultLocale {
            if self._debugMode {
                NSLog("%@ The locale '%@' doesn't exists, using default locale '%@' instead. Based on all locales: '%@'", Constants.Debug.DEBUG_CLIENT, locale, defaultLocale, availableLocales)
            }
            return self.getLocaleDictionary(allParameters, locale: defaultLocale)
        } else if !allParameters.isEmpty {
            // if the locale and the default locale didn't exists in the parameters, use the first locale found
            if let firstLocale = allParameters[0][Constants.Interactions.LOCALE] as? String {
                if self._debugMode {
                    NSLog("%@ The default locale '%@' is not valid, using the first valid locale '%@' instead.  Based on all locales: '%@'", Constants.Debug.DEBUG_CLIENT, locale, firstLocale, availableLocales)
                }
                return self.getLocaleDictionary(allParameters, locale: firstLocale)
            }
        }

        if self._debugMode {
            NSLog("%@ The plugin doesn't contain locales.", Constants.Debug.DEBUG_CLIENT)
        }
        return [Dictionary<String, AnyObject>]()
    }



    private func getParametersOfLocale(allParameters: [Dictionary<String, AnyObject>], locale: String) -> Dictionary<String, [String]> {
        let parameters = self.getLocaleDictionary(allParameters, locale: locale)
        return BlueConicConfiguration.parametersToDictionary(parameters)
    }

}
