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

// Static instance of the BlueConicClient
struct Static {
    static var instance: BlueConicClient?
    static var token: dispatch_once_t = 0
}

/**
Implementation of the BlueConic client, handling the profile retrieval and storage.
This may be from cache, persistent storage on the client or direct requests to the BlueConic server.

&lt;pre&gt:
// Swift:
import BlueConicClient

// Objective-C:
#import &lt;BlueConicClient/BlueConicClient-Swift.h&gt;
&lt;/pre&gt:

*/
@objc public class BlueConicClient: NSObject {

    // List of private values
    // CommitLog, Cache and Reachability are part of the connecting architecture.
    private var _commitLog: BlueConicCommitLog!
    private var _requestCommitLog: BlueConicCommitLog!
    private var _cache: BlueConicCache!
    private var _reachability:  BlueConicReachability!


    // Profile properties
    private var _labels: Dictionary<String, AnyObject> = [:]
    private var _profileId: String?

    // Configuration properties
    private var _debugMode: Bool = false
    private var _operationQueue: NSOperationQueue!
    private var _updateRequired: Bool = false

    // Simulator properties
    private var _sessionId: String?
    private var _userName: String?

    // Plugin properties
    private var _currentPlugins = [Plugin]()
    private var _plugins = Dictionary<String, AnyClass>()

    // Connection properties
    private var _connections = [Connection]()

    // Session time measure
    private var _sessionStartTime: Double = 0.0
    private var _sessionStopTime: Double = 0.0
    private var _activeContexts: Int = 0

    // Current context property
    private var _context: UIViewController!
    private var _locale: String?
    private var _screenName: String = ""
    private final var _configuration: BlueConicConfiguration!

    /**
    Get an instance of the BlueConic client.
    &lt;pre&gt:
    // Swift:
    let client: BlueConicClient = BlueConicClient.getInstance(self)

    // Objective-C:
    BlueConicClient* client = [BlueConicClient getInstance:self];
    &lt;/pre&gt:
    
    - parameter context: The application context.

    - returns: The BlueConic client instance.
    */
    public class func getInstance(context: UIViewController?) -> BlueConicClient {
        dispatch_once(&Static.token) {
            Static.instance = BlueConicClient(context: context)
            NSTimer.scheduledTimerWithTimeInterval(5.0, target: Static.instance!, selector: #selector(BlueConicClient.sync), userInfo: nil, repeats: true)
        }

        Static.instance?.setContext(context)
        return Static.instance!
    }

    /**
    Private constructor
    Creates a new BlueConicClient instance. This instance loads the cache and commitlog state
    from disk and starts task for syncing state and checking network state.
    */
    private convenience init(context: UIViewController?) {
        self.init()
        self.setContext(context)
    }

    /**
    Constructor
    */
    override init() {
        super.init()
        let startTime = CFAbsoluteTimeGetCurrent()
        // Make sure unsaved profile properties will be sent to the server.
        self._updateRequired = true
        self._configuration = BlueConicConfiguration()

        // Get the debug status from the app plist
        self._debugMode = BlueConicConfiguration.getDebugMode()

        if self._debugMode {
            NSLog("%@ Hostname: %@", Constants.Debug.DEBUG_CLIENT, self._configuration.getHostName())
            NSLog("%@ App ID: %@", Constants.Debug.DEBUG_CLIENT, BlueConicConfiguration.getPackageName())
        }

        // Get the commitlog from disk if present
        self._commitLog = self.loadCommitLog(Constants.Files.COMMITLOG)
        self._requestCommitLog = self.loadCommitLog(Constants.Files.REQUEST_COMMITLOG)


        // Get the cache from disk if present
        self._cache = self.loadCache()

        // Load the profile id from the previous session
        self._profileId = self.loadProfileId()

        // Load the profile property lables form the previous session
        self._labels = self.loadLabels()

        // Start checking for an internet connection
        self._reachability = BlueConicReachability.reachabilityForInternetConnection()
        self._reachability.startNotifier()

        // Create an operation queue with on thread
        self._operationQueue = NSOperationQueue()
        self._operationQueue.maxConcurrentOperationCount = 1

        if self._debugMode {
            NSLog("%@ Created new BlueConic client in (%@ ms)", Constants.Debug.DEBUG_CLIENT, NSString(format:"%.2f", ((CFAbsoluteTimeGetCurrent() as Double) - startTime) * 1000))
        }
    }

    /**
    Returns the first value for a given profile property.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift:
    let hobby: String = client.getProfileValue(&quot;hobby&quot;)

    // Objective-C:
    NSString* hobby = [client getProfileValue:@&quot;hobby&quot;];
    &lt;/pre&gt:

    - parameter property: The profile property to get the values for.

    - returns: The first value
    */
    public func getProfileValue(property: String) -> String {
        return self._cache.getProfileValue(property)
    }

    /**
    Return the values for a given profile property.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift:
    let hobbies: [String] = client.getProfileValues(&quot;hobbies&quot;)

    // Objective-C:
    NSArray* hobbies = [client getProfileValues:@&quot;hobbies&quot;];
    &lt;/pre&gt:

    - parameter property: The profile property to get the values for.

    - returns: A collection containing the values.
    */
    public func getProfileValues(property: String) -> [String]? {
        return self._cache.getProfileValues(property)
    }

    /**
    Returns the current ViewController.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift:
    let viewController = client.getViewController()

    // Objective-C:
    UIViewController* viewController = [client getViewController];
    &lt;/pre&gt:

    - returns:     The current ViewController.
    */
    public func getViewController() -> UIViewController? {
        return self._context
    }

    /**
    Returns a view component based on the given identifier or <code>nil</code> is no match is found.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift:
    @IBOutlet weak var view: UIView!
    let view: UIView? = client.getView(&quot;#view&quot;)

    // Objective-C:
    @property (weak, nonatomic) IBOutlet UIView* view;
    UIView* view = [client getView:@&quot;#view&quot;];
    &lt;/pre&gt:
    
    - parameter expression: The Identifier, e.g. &quot;#view&quot;.

    - returns:     The view or <code>nil</code>
    */
    public func getView(selector: String) -> UIView? {
        return BlueConicClient.getView(self._context, selector: selector)
    }


    /**
    Returns the screenName either set in createEvent or the ViewControllers title.
    
    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift:
    client.createEvent(&quot;PAGEVIEW&quot;, properties: [&quot;screenName&quot;: &quot;Main/HOMETAB&quot;])
    var screenName: String = client.getScreenName()

    // Objective-C:
    [client createEvent:@&quot;PAGEVIEW&quot; properties:@{@&quot;screenName&quot;: @&quot;MAIN/HOMETAB&quot;}];
    NSString* screenName = [client getScreenName];
    &lt;/pre&gt:

    - returns: The screen name
    */
    public func getScreenName() -> String {
        return self._screenName
    }


    /**
    * Returns the screen name. The screen name is determined in the following way:<br />
    * 1. If the {@code properties} hold an entry 'screenName' that is used.<br />
    * 2. If the {@code properties} hold an entry 'location' that is used (backwards compatible).<br />
    * @param properties The properties.
    * @param defaultTitle Default title.
    * @return The screen name.
    */
    private func getScreenNameFromProperties(properties: Dictionary<String, String>?) -> String? {
        if let properties = properties {
            var overrule = properties["screenName"]

            if overrule == nil || overrule == "" {
                overrule = properties["location"]
            }

            if let overrule = overrule {
                if overrule.hasPrefix("/") {
                    return overrule.substringFromIndex(overrule.startIndex.advancedBy(1))
                } else {
                    return overrule
                }
            } else if overrule == nil && self._context != nil {
                // There is no Screen name set in the properties, fallback to the title of the page.
                let pageTitle = (self._context.title != nil) ? self._context.title! : ""

                if self._debugMode {
                    NSLog("%@ There is no screenName set in the properties! Using the title '%@' instead.", Constants.Debug.DEBUG_CLIENT, pageTitle)
                }
                return pageTitle
            }
        }
        return nil
    }

    /**
    Return all the profile properties from cache.

    - parameter property: The profile property to get the values for.
    - returns:   A collection of all profile properties stored in the cache.

    */
    private func getProfileProperties() -> Dictionary<String, [String]> {
        return self._cache.getProperties()
    }

    /**
    Return all the property labels.

    - returns:   A collection containing the labels.
    */
    private func getPropertyLabels() -> Dictionary<String, AnyObject> {
        // Refresh the labels Asychronously
        self._operationQueue.addOperationWithBlock { [weak self] in
            self?.refreshPropertyLabels()
            return
        }
        // Return the labels from the cache
        return self._labels
    }

    /*
    Return the file directory of a filename as a String.

    :param:    fileName    The name of a file, which is in the BlueConic Directory.

    :returns:   A string with the file location.
    */
    func getFileLocation(fileName: String) -> String {
        // Get the documents directory
        var documentDirectories = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentationDirectory, NSSearchPathDomainMask.UserDomainMask, true) 

        let documentDirectory: NSString = documentDirectories[0]

        let bcDirectory: NSString = documentDirectory.stringByAppendingPathComponent(Constants.Files.BLUECONIC_DIR)

        var success: Bool
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(bcDirectory as String, withIntermediateDirectories: true, attributes: nil)
            success = true
        } catch {
            success = false
        }

        if !success {
            // Failed to create the dir...
            if self._debugMode {
                NSLog("%@ Failed to get the file location: %@", Constants.Debug.DEBUG_CLIENT, fileName )
            }
        }

        return bcDirectory.stringByAppendingPathComponent(fileName) as String
    }


    /**
    Returns a component for the interaction.

    - returns:     The component matching the selector or the position of the interaction or null if no match is found.
    */
    class func getView(context: UIViewController?, selector: String?) -> UIView? {
        if selector == nil || !(selector!.hasPrefix(Constants.ID_PREFIX)) {
            return nil
        }
        let id: String = selector!.substringFromIndex(selector!.startIndex.advancedBy(1))
        if let controller = context where controller.respondsToSelector(Selector(id)) {
            return controller.valueForKey(id) as? UIView
        }
        return nil
    }

    /**
    Adds a single property value to the profile.
    If there are already values for a property the new value will be added.
    Values for a property need to be unique; passing the same value multiple times will have no effect.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift:
    client.addProfileValue(&quot;hobbies&quot;, value:&quot;tennis&quot;)

    // Objective-C:
    [client addProfileValue:@&quot;hobbies&quot; value:@&quot;tennis&quot;];
    &lt;/pre&gt:

    - parameter property: The profile property to add the values for.
    - parameter value: The property value to add to the profile.
    */
    public func addProfileValue(property: String, value: String) {
        if property != "" && value != "" {
            var values = [String]()
            values.append(value)
            self.addProfileValues(property, values: values)
        }
    }

    /**
    Adds property values to the profile. The values from the collection are added to the profile.
    If there are already values for a property the new values will be added.
    Values for a property need to be unique; passing the same values multiple times will have no effect.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift:
    let hobbyArray = [&quot;tennis&quot;, &quot;soccer&quot;]
    client.addProfileValues(&quot;hobbies&quot;, values:hobbyArray)

    // Objective-C:
    NSArray* hobbyArray = [NSArray arrayWithObjects:@&quot;tennis&quot;, @&quot;soccer&quot;, nil];
    [client addProfileValues:@&quot;hobbies&quot; values:hobbyArray];
    &lt;/pre&gt:

    - parameter property: The profile property to add the values for.
    - parameter values: The property values to add to the profile.
    */
    public func addProfileValues(property: String, values: [String]) {
        if property != "" && values.count > 0 {
            self._commitLog.addProperties(property, values: values)
            self._cache.addProperties(property, values: values)
            self._updateRequired = true
        }
    }

    /**
    Sets values on the profile. Passing a property that was already set with values will cause for the old values to be removed.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift:
    client.setProfileValue(&quot;hobbies&quot;, value:&quot;tennis&quot;)
    
    // Objective-C: 
    [client setProfileValue:@&quot;hobbies&quot; value:@&quot;tennis&quot;];
    &lt;/pre&gt:

    - parameter property: The profile property to add the values for.
    - parameter values: The profile values to store.
    */
    public func setProfileValue(name: String, value: String) {
        if name != "" && value != "" {
            var values = [String]()
            values.append(value)
            self.setProfileValues(name, values: values)
        }
    }

    /**
    Sets values on the profile. Passing a property that was already set with values will cause for the old values to be removed.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift: 
    let hobbyArray = [&quot;tennis&quot;, &quot;soccer&quot;]
    client.setProfileValues("hobbies", values:hobbyArray) 
    
    // Objective-C: 
    NSArray* hobbyArray = [NSArray arrayWithObjects:@&quot;tennis&quot;, @&quot;soccer&quot;, nil];
    [client setProfileValues:@&quot;hobbies&quot; values:hobbyArray];
    &lt;/pre&gt:

    - parameter property: The profile property to add the values for.
    - parameter values: The profile values to store.
    */
    public func setProfileValues(name: String, values: [String]) {
        if name != "" && values.count > 0 {
            self._commitLog.setProperties(name, values: values)
            self._cache.setProperties(name, values: values)
            self._updateRequired = true
        }
    }

    /**
    Setter for the locale to get the parameters for. By default, the default locale configured in BlueConic is used.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift: 
    client.setLocale(&quot;en_US&quot;)
    
    // Objective-C: 
    [client setLocale:@&quot;en_US&quot;];
    &lt;/pre&gt:

    - parameter locale: The locale, e.g. 'en_US'.
    */
    public func setLocale(locale: String) {
        self._locale = locale
    }

    /**
    Checks whether the app was started with simulator data. If so we try to get the username and the the mobile
    session id to connect to the simulator. The intent should look like:
    &quot;&lt;appID&gt;://&lt;hostname&gt;/&lt;username&gt;/&lt;mobilesSessionId&gt;&quot;.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift: 
    // Implement in AppDelegate.swift 
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool { 
        BlueConicClient.getInstance(nil).setURL(url)
        return true
    } 

    
    // Objective-C: 
    // Implement in AppDelegate.m 
    - (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation { 
        [[BlueConicClient getInstance:nil] setURL:url];
        return YES; 
    }
    &lt;/pre&gt:

    - parameter url: The url retrieved from application.
    */
    public func setURL(url: NSURL) {
        let scheme: String? = url.scheme
        var urlHost: String = ""
        if let host = url.host {
            urlHost = "https://\(host)"
            self._configuration.setHostName(urlHost)
        }
        
        if self._debugMode {
            if scheme != nil {
                NSLog("%@ Scheme data: %@", Constants.Debug.DEBUG_CLIENT, scheme!)
            } else {
                NSLog("%@ Scheme data is nil", Constants.Debug.DEBUG_CLIENT)
            }
        }
        if scheme != nil && scheme!.lowercaseString == BlueConicConfiguration.getPackageName().lowercaseString {
            if let path = url.relativePath {
                var params = path.componentsSeparatedByString("/")
                if params.count == 3 {
                    self._configuration.setSimulatorData(params[1], mobileSessionId: params[2])
                    if self._debugMode {
                        let alert =  UIAlertView(title: "Connected to BlueConic Simulator", message: "Username: \(params[1]) \nMobile session: \(params[2]) \nHost: \(urlHost)", delegate: nil, cancelButtonTitle: nil, otherButtonTitles: "OK")
                        alert.show()
                    }
                }
            }
        }
    }


    /**
    Setter for the screenname of the current viewcontroller, which can be used in the Simulator as screenname

    - parameter screenName: The screen name of the current viewcontroller'.
    */
    func setScreenName(screenName: String) {
        self._screenName = screenName
    }

    func getConnections() -> [Connection] {
        return self._connections
    }


    /**
    Set the current context. UIViewController of the app that is displayed on the page.

    - parameter    context:     The View Controller of the current page
    */
    func setContext(context: UIViewController?) {
        if context != nil {
            self._context = context
        }
    }

    /**
    Registers an event of the specified type with the given properties. For a &quot;PAGEVIEW&quot; event a screen name can be
    passed, so interactions can be restricted on the where tab in BlueConic.
    For a &quot;VIEW&quot;, &quot;CLICK&quot; or &quot;CONVERSION&quot; event an interactionId should be passed to register the event for.

    &lt;h4&gt;Example&lt;/h4&gt;
    &lt;pre&gt:
    // Swift: 
    client.createEvent(&quot;PAGEVIEW&quot;, properties: [&quot;screenName&quot;: &quot;Main/HOMETAB&quot;])
    client.createEvent(&quot;CLICK&quot;, properties: [&quot;interactionId&quot;: self._context.getInteractionId()])
    
    // Objective-C: 
    [client createEvent:@&quot;PAGEVIEW&quot; properties:@{@&quot;screenName&quot;: @&quot;MAIN/HOMETAB&quot;}];
    [client createEvent:@&quot;CLICK&quot; properties:@{@&quot;interactionId&quot;: [self._context getInteractionId]}];
    &lt;/pre&gt:

    - parameter eventType: The event type. (e.g: &quot;PAGEVIEW&quot;, &quot;VIEW&quot;, &quot;CLICK&quot;, &quot;CONVERSION&quot;)
    - parameter properties: A map with properties for the event.


    */
    public func createEvent(eventType: String, properties: Dictionary<String, String>?) {
        if let context = self._context {
            // Get interactions fro this pageview
            if Constants.CommitLog.Event.PAGEVIEW == eventType {
                // Call the onDestroy function for each plugin.
                destroyPlugins()

                if let screenName = self.getScreenNameFromProperties(properties) {
                    self.setScreenName(screenName)
                }

                if self._debugMode {
                    NSLog("%@ Screen Name: %@", Constants.Debug.DEBUG_CLIENT, self._screenName)
                }
                // Handle the Interactions
                self.getInteractions(context, screenName: self._screenName)

            } else {
                if let properties = properties, interactionId = properties["interactionId"], event = EventType(rawValue: eventType) {
                        self._commitLog.createEvent(event, interactionId: interactionId)
                        self._updateRequired = true
                }
            }
        }
    }

    /**
    Periodically saves state on disk and on the BlueConic server.
    This method will be invoked periodically by a background thread
    */
    func sync() {

        // Check whether the state of the cache should be written to disk
        if self._cache.checkModified() {
            self.saveCache()
        }

        // Check whether the state of the commitlog should be written to disk
        if self._commitLog.checkModified() {
            self.saveCommitLog()
        }

        // Make sure the commitlog will be flushed if there have been recent changes
        if self._operationQueue.operationCount == 0 && _updateRequired {
            if self._debugMode {
                NSLog("%@ Sync started.", Constants.Debug.DEBUG_CLIENT)
            }
            self.update() {
                (success) in
                // Callback of the completion block: udpate
                if self._debugMode {
                    if success {
                        NSLog("%@ Sync successful.", Constants.Debug.DEBUG_CLIENT)
                    } else {
                        NSLog("%@ Sync failed.", Constants.Debug.DEBUG_CLIENT)
                    }
                }
            }
        }

    }

    /**
    Refreshes the local cache
    */
    func update(completionHandler: ((Bool) -> Void)?) {
        self.scheduleUpdate(false, completionHandler: completionHandler)
    }

    func loadProfileValues(completionHandler: ((Bool) -> Void)?) {
        self.scheduleUpdate(true, completionHandler: completionHandler)
    }

    /**
    Schedules an update operation the operation queue to flush the commitlog.

    - parameter    refeshCache:         Indicates whether the local cache should be updated aswell.
    - parameter    completionHandler:   The block that should be executed after the operation finished
    */
    func scheduleUpdate(refreshCache: (Bool), completionHandler:((Bool) -> Void)?) {
        let operation = NSBlockOperation(block: {
            if refreshCache {
                self.doRefresh()
            } else {
                self.doUpdate()
            }
        })

        // call the completionHandler when operation is finished
        operation.completionBlock = {
            completionHandler!(operation.finished)
        }
        self._operationQueue!.addOperation(operation)
    }


    /**
    Flushes the commitlog to the server.
    
    - returns:   True when succeeds
    */
    func doUpdate() -> Bool {
        return self.sendUpdates(false)
    }

    /**
    Flushes the commitlog to the server and updates the local cache.
    */
    func doRefresh() -> Bool {
        return self.sendUpdates(true)
    }

    /**
    Flushes the commitlog to the server.
    
    - parameter    refeshCache:     Indicates whether the local cache should be updated aswell.
    - returns:   true if the operation completed successfully, false otherwise.
    */
    func sendUpdates(refreshCache: Bool) -> Bool {
        // Check whether a network connection is available
        if !_reachability.isReachable() {
            return false
        }

        // Reset the update required flag. Try submitting change only once in case of an active connection
        self._updateRequired = false

        // Merge and clear the commitlog with the request commitlog
        self._requestCommitLog.mergeCommitLog(self._commitLog)

        // Get the properties that should be added
        let toAdd: Dictionary<String, BlueConicCommitEntry> = self._requestCommitLog.getProperties(OperationType.ADD)

        // Get the properties that should be set
        let toSet: Dictionary<String, BlueConicCommitEntry> = self._requestCommitLog.getProperties(OperationType.SET)

        // Get the events that should be created
        let toEvents: [BlueConicCommitEntry] = self._requestCommitLog.getEvents()

        // Check whether there is work to do
        if toAdd.count == 0 && toSet.count == 0 && toEvents.count == 0 && !refreshCache {
            return true
        }

        // Keep a list of all method invocations that should be included in the request
        var commands = BlueConicConnector.setUpdateCommand(toAdd, setProperties: toSet, events: toEvents)

        // Add a call if the local cache of profile properties should be updated
        if refreshCache {
            commands.append(BlueConicConnector.getGetPropertiesCommand(CallId.GetProperties.rawValue, hash: nil))
        }

        // Get BlueConicConnector instance
        let connector = BlueConicConnector(userName: self._configuration.getSimulatorUsername(), mobileSessionId: self._configuration.getSimulatorSessionId())
        let domainGroupUrl = BlueConicConfiguration.getDomaingGroupUrl(self._configuration.getHostName(), domainGroup: self._cache.getDomainGroup())

        if self._debugMode {
            NSLog("%@ domainGroupUrl: %@", Constants.Debug.DEBUG_CLIENT, domainGroupUrl)
        }

        // Execute all required methods an check whether an error occurred
        let result = connector.execute(domainGroupUrl, calls: commands, screenName: nil)

        if result.error != nil || result.response == nil {
            // Something went wrong, see the error what happend.
            //BlueConicClient.sendUpdate(): %@", result.error!.localizedDescription)
            if result.error != nil {
                if self._debugMode {
                    NSLog("%@ Unable to get the interactions from BlueConic, reason: %@", Constants.Debug.DEBUG_CLIENT, result.error!.localizedDescription )
                }
            } else {
                if self._debugMode {
                    NSLog("%@ Unable to get the interactions from BlueConic", Constants.Debug.DEBUG_CLIENT)
                }
            }

            return false
        }

        // Process the result of the getProfilecall
        processProfileResult(result.response!["\(CallId.Profile.rawValue)"])

        // Process the result of the getProperties call to update the cache
        processPropertiesResult(result.response!["\(CallId.GetProperties.rawValue)"])

        // The changes have been committed so the commit can be rest
        self._requestCommitLog.clearAll()

        // The operation has been executed successfully
        return true
    }

    /**
    Refresh the property labels
    Retrieves and saves the labels
    */
    func refreshPropertyLabels() {
        let profileCallId = 0, labelsCallId = 1
        // Check whether a network connection is available
        if !self._reachability.isReachable() {
            // Unable to refresh
            return
        }

        // Get the json representation for the method call

        // Always send a getProfile call
        let createParameterList = [Constants.ProfileProperties.PARAMETER_VALUE]
        let profileParameters: Dictionary<String, AnyObject> = [Constants.ProfileProperties.PARAMETER_KEY: createParameterList]

        let getProfileCall = BlueConicRequestCommand(methodName: Constants.Calls.GET_PROFILE, callId: profileCallId, parameters: profileParameters, complexParameters: false)

        let call = BlueConicRequestCommand(methodName: Constants.Calls.GET_PROPERTY_LABELS, callId: labelsCallId)
        let calls: [BlueConicRequestCommand] = [getProfileCall, call]

        // Create a new connector
        let connector = BlueConicConnector(userName: self._configuration.getSimulatorUsername(), mobileSessionId: self._configuration.getSimulatorSessionId())
        let domainGroupUrl = BlueConicConfiguration.getDomaingGroupUrl(self._configuration.getHostName(), domainGroup: self._cache.getDomainGroup())

        var result = connector.execute(domainGroupUrl, calls: calls, screenName: nil)

        // Process the result
        if result.error == nil && result.response != nil && result.response!.count > 0 {
            let dictionaryLabels = result.response?["\(labelsCallId)"] as? Dictionary<String, AnyObject>
            let dictionaryResult = dictionaryLabels?[Constants.RESULT] as? Dictionary<String, AnyObject>
            self._labels = dictionaryResult![Constants.PROPERTIES] as! Dictionary<String, AnyObject>

            self.saveLabels()
        } else {
            if result.error != nil {
                if self._debugMode {
                    NSLog("%@ Unable to get the interactions from BlueConic, reason: %@", Constants.Debug.DEBUG_CLIENT, result.error!.localizedDescription )
                }
            } else {
                if self._debugMode {
                    NSLog("%@ Unable to get the interactions from BlueConic", Constants.Debug.DEBUG_CLIENT)
                }
            }

        }
    }
    
    /*
    Get the plugin by names.

    :param: ClassName with project name, e.g. BlueConicPlugins.Banner.
    :returns: The Plugin.Type which can be initialized, also could return <code>nil</code>.
    */
    private func getPlugin(className: String) -> Plugin.Type? {
        // Check if there is a cached plugin
        if let cachedPlugin: AnyClass = self._plugins[className] {
            return cachedPlugin as? Plugin.Type
        }

        // Swift needs ProjectName.PluginName
        if let pluginClass: AnyClass = NSClassFromString(className) {
            // Cache the results
            self._plugins[className] = pluginClass
            return pluginClass as? Plugin.Type
        // Objective-C needs PluginName
        } else if let index = className.rangeOfString(".")?.endIndex {

            let pluginName = className.substringWithRange(index ..< className.endIndex)
            if let pluginClass: AnyClass = NSClassFromString(pluginName) {
                // Cache the results
                self._plugins[className] = pluginClass
                return pluginClass as? Plugin.Type
            }
        }

        // check if the plugin exists in the current project.
        if let info = NSBundle.mainBundle().infoDictionary,
            let projectName: String = info["CFBundleExecutable"] as? String,
            let index = className.rangeOfString(".")?.endIndex {
                let pluginName = className.substringWithRange(index ..< className.endIndex)
                let pluginClassName = projectName + "." + pluginName;
                if let pluginClass: AnyClass = NSClassFromString(pluginClassName) {

                    if self._debugMode {
                        NSLog("%@ Plugin found at <%@>", Constants.Debug.DEBUG_CLIENT, pluginClassName)
                    }

                    self._plugins[className] = pluginClass
                    return pluginClass as? Plugin.Type
                }
        } else {
            if self._debugMode {
                NSLog("%@ Plugin class: <%@> not found", Constants.Debug.DEBUG_CLIENT, className)
            }

        }
        // Cache negative results too
        self._plugins[className] = nil
        return nil
    }

    /**
    Private method. Retrieves interactions.

    - parameter context: The active ViewController of the app.
    - parameter screenName: the screen name in the app (e.g. &quot;Home/MyPage&quot;)
    */
    func getInteractions(context: UIViewController, screenName: String) {
        // Check whether a network connection is available
        if !_reachability.isReachable() {
            return
        }

        self._operationQueue.addOperationWithBlock {
            // Reset the update required flag. Try submitting change only once in case of an active connection
            self._updateRequired = false

            // Merge and clear the commitlog with the request commitlog
            self._requestCommitLog.mergeCommitLog(self._commitLog)

            // Get the properties that should be added
            let toAdd: Dictionary<String, BlueConicCommitEntry> = self._requestCommitLog.getProperties(OperationType.ADD)

            // Get the properties that should be set
            let toSet: Dictionary<String, BlueConicCommitEntry> = self._requestCommitLog.getProperties(OperationType.SET)

            // Get the events that should be created
            let toEvents: [BlueConicCommitEntry] = self._requestCommitLog.getEvents()

            // Get the has of the properties that should be get
            let hash: String = "\(self._cache.getHash())"

            // Remove all the current connections
            self._connections.removeAll()

            // Keep a list of all method invocations that should be included in the request
            var commands = BlueConicConnector.setUpdateCommand(toAdd, setProperties: toSet, events: toEvents)

            // Send a getProperties call
            commands.append(BlueConicConnector.getGetPropertiesCommand(CallId.GetProperties.rawValue, hash: hash))

            // Send a getInteraction call
            commands.append(BlueConicConnector.getInteractionCommand(CallId.Interactions.rawValue))

            let connector = BlueConicConnector(userName: self._configuration.getSimulatorUsername(), mobileSessionId: self._configuration.getSimulatorSessionId())
            let domainGroupUrl = BlueConicConfiguration.getDomaingGroupUrl(self._configuration.getHostName(), domainGroup: self._cache.getDomainGroup())
            if self._debugMode {
                NSLog("%@ Domaingroup URL: %@", Constants.Debug.DEBUG_CLIENT, domainGroupUrl)
            }

            // Execute all required methods an check whether an error occurred
            // result.
            let result = connector.execute(domainGroupUrl, calls: commands, screenName: screenName)

            if result.error != nil || result.response == nil {
                // Something went wrong, see the error what happend.
                if result.error != nil {
                    if self._debugMode {
                        NSLog("%@ Unable to get the interactions from BlueConic, reason: %@", Constants.Debug.DEBUG_CLIENT, result.error!.localizedDescription )
                    }
                } else {
                    if self._debugMode {
                        NSLog("%@ Unable to get the interactions from BlueConic", Constants.Debug.DEBUG_CLIENT)
                    }
                }
                return
            }

            // Process the result of the getProfile call
            self.processProfileResult(result.response!["\(CallId.Profile.rawValue)"])

            // Process the result of the getProperties call
            self.processPropertiesUpdatedResult(result.response!["\(CallId.GetProperties.rawValue)"])

            self.processConnectionsResult(result.response!["\(CallId.Interactions.rawValue)"])

            // Process the result of the getInteractions call to update the cache
            self.processInteractionsResult(context, resultObject: result.response?["\(CallId.Interactions.rawValue)"])
            
            // The changes have been committed so the commit can be rest
            self._requestCommitLog.clearAll()
            return
        }

    }

    /**
    Process the result of the getProfiel call
    Checks if the new given profile id is equals the current, set the new profile id as current if they are not equal

    - parameter resultObject: The response from the method call of type Dictionary
    */
    private func processProfileResult(resultObject: AnyObject?) {
        // Process the result of the getProfilecall

        // Get the dictionary of the result from the getProfile call
        if let profileProperties = resultObject as? Dictionary<String, AnyObject> {

            // Get the profile id returned by the server
            let newProfileId: String? = profileProperties[Constants.ProfileProperties.ID] as? String


            // Get the domainGroupId from result and cache the domain group.
            if let resultDictionary = profileProperties[Constants.RESULT] as? Dictionary<String, AnyObject>,
                domainGroupId = resultDictionary[Constants.DOMAINGROUPID] as? String {
                    setDomainGroup(domainGroupId)
            }

            // Check wether the id is valid
            if let newProfileId = newProfileId where newProfileId != "" {
                // Check whether the profile id has been changed
                if newProfileId != self._profileId {
                    if self._debugMode {
                        let oldProfileId = (self._profileId != nil) ? self._profileId! : ""
                        NSLog("%@ New Profile ID: %@ - Old Profile ID: %@", Constants.Debug.DEBUG_CLIENT, newProfileId, oldProfileId)
                    }
                    let changed: Bool = self._profileId != nil

                    // Store the new profile id
                    self._profileId = newProfileId

                    self.saveProfileId(self._profileId!)

                    // Clear the cache if the profile id changed
                    if (changed) {
                        self._cache.clear()
                    }
                }
            }
        }
    }

    /**
    Process the result of the getProperties call from the getProperties call
    Clear the cache and set the new properties if the response is not empty

    - parameter resultObject: The response from the method call of type Dictionary
    */
    private func processPropertiesResult(resultObject: AnyObject?) {
        // Get the dictionary of the result from the getProperties call
        if let propertyResult = resultObject as? Dictionary<String, AnyObject>,
            resultDictionary = propertyResult[Constants.RESULT] as? Dictionary<String, AnyObject>,
            propertyDictionary = resultDictionary[Constants.PROPERTIES] as? Dictionary<String, [String]> {
                self._cache.clear()
                self._cache.setProperties(propertyDictionary)
        }
    }

    /**
    Process the result of the getProperties call from the getProperties call
    Clear the cache and set the new properties if the response is not empty
    
    - parameter resultObject: The response from the method call of type Dictionary
    */
    private func processPropertiesUpdatedResult(resultObject: AnyObject?) {
        // Get the dictionary of the result from the getProperties call
        if let propertyResult = resultObject as? Dictionary<String, AnyObject>,
            resultDictionary = propertyResult[Constants.RESULT] as? Dictionary<String, AnyObject>,
            propertyDictionary = resultDictionary[Constants.PROPERTIES] as? Dictionary<String, [String]> {
                var updated = [String]()
                for (key, value) in propertyDictionary {
                    self._cache.setProperties(key, values: value)
                    updated.append("\(key) : \(value)")
                }
                if self._debugMode {
                    NSLog("%@ Updated properties: %@", Constants.Debug.DEBUG_CLIENT, updated)
                }
        }
    }

    /**
    Process the result of the getInteractions call
    Check if any of the interactions is registered and if so then call the onLoad() method of that specified plugin.

    - parameter resultObject: The response from the method call of type Dictionary
    */
    private func processInteractionsResult(context: UIViewController, resultObject: AnyObject?) {
        if let interactionDictionary = resultObject as? Dictionary<String, AnyObject>,
            resultDictionary = interactionDictionary[Constants.RESULT] as? Dictionary<String, AnyObject>,
            interactions = resultDictionary[Constants.Interactions.INTERACTIONS_KEY] as? [Dictionary<String, AnyObject>] {
                let pluginsArray: [Plugin] = getRegisteredPluginInteractions(interactions)
                // Call the onLoad function of each plugin that is registered and retrieved from the server.
                loadPlugins(context, plugins: pluginsArray)
        }
    }

    /**
    Process the result of the getInteractions call
    Add all the received connections to the connections list.
    
    - parameter resultObject: The response from the method call of type Dictionary
    */
    private func processConnectionsResult(resultObject: AnyObject?) {
        if let interactionDictionary = resultObject as? Dictionary<String, AnyObject>,
            resultDictionary = interactionDictionary[Constants.RESULT] as? Dictionary<String, AnyObject>,
            connections = resultDictionary[Constants.Connections.CONNECTIONS_KEY] as? [Dictionary<String, AnyObject>] {
                self._connections = self.addConnections(connections)
        }
    }


    /**
    Process the result of the getProperties call
    Check if the interaction type is registered as plugin
    Create a new instance of the plugins that are equal to the interaction type and add it to the array
    
    - parameter interactions: All interactions from the method call response.
    - returns: plugins All interactions that are have an interaction type that is equal to a registered plugin
    */
    private func getRegisteredPluginInteractions(interactions: [Dictionary<String, AnyObject>]) -> [Plugin] {
        var pluginsArray = [Plugin]()

        for interaction in interactions {
            if let interactionId = interaction[Constants.Interactions.ID] as? String,
                interactionPluginClass: String = interaction[Constants.Interactions.CLASS] as? String,
                interactionType = interaction[Constants.Interactions.TYPE] as? String,
                pluginClass: Plugin.Type = getPlugin(interactionPluginClass)  {
                    if self._debugMode {
                        NSLog("%@ pluginClass <%@> found! for type id: %@; and interaction: %@", Constants.Debug.DEBUG_CLIENT, interactionPluginClass, interactionType, interactionId)
                    }
                    let interactionContext = InteractionContext(interaction: interaction, context: self._context, locale: self._locale)
                    let pluginItem: Plugin = pluginClass.init(client: self, context: interactionContext)
                            pluginsArray.append(pluginItem)

            } else {
                if self._debugMode {
                    let interactionClass: String = (interaction[Constants.Interactions.CLASS] as? String != nil) ? interaction[Constants.Interactions.CLASS] as! String : ""
                    let interactionType: String = (interaction[Constants.Interactions.TYPE] as? String != nil) ? interaction[Constants.Interactions.TYPE] as! String : ""
                    let interactionId: String = (interaction[Constants.Interactions.ID] as? String != nil) ? interaction[Constants.Interactions.ID] as! String : ""
                    NSLog("%@ pluginClass <%@> not found for type id: %@; and interaction: %@", Constants.Debug.DEBUG_CLIENT, interactionClass, interactionType, interactionId)
                }
            }
        }
        return pluginsArray
    }

    /**
    Check if the data contains connections and append them the list.
    It changes the parameters to a dictionary, so it is equals to Android and easier to access.
    
    - parameter connections: All the connections data from the method call response.
    - returns: List of connections All the connections that are create by the data
    */
    private func addConnections(connections: [Dictionary<String, AnyObject>]) -> [Connection] {
        var connectionsArray = [Connection]()
        for connection in connections {
            // Only get the needed parameters. use the first locale that is available.
            if let connectionId = connection[Constants.Connections.ID] as? String,
                connectionParameters = connection[Constants.Connections.PARAMETERS] as? [Dictionary<String, AnyObject>],
                parameters = connectionParameters[0][Constants.Connections.PARAMETER] as? [Dictionary<String, AnyObject>] {

                    // Change the parameters to an useable dictionary.
                    let connectionDictinoary = BlueConicConfiguration.parametersToDictionary(parameters)

                    // Add a new connection to the list.
                    connectionsArray.append(Connection(id: connectionId, parameters: connectionDictinoary))
            }
        }
        if self._debugMode {
            NSLog("%@ %i connection(s) added! ", Constants.Debug.DEBUG_CLIENT, connectionsArray.count)
        }

        return connectionsArray
    }

    /**
    Calls the onLoad() method of each plugin

    - parameter context: The active ViewController
    - parameter plugins: The created plugins from the response
    */
    private func loadPlugins(context: UIViewController, plugins: [Plugin]) {
        // Run the following on the Main Thread
        if plugins.count > 0 {
            self._currentPlugins.removeAll()
            NSOperationQueue.mainQueue().addOperationWithBlock() {
                for plugin in plugins {
                    plugin.onLoad()
                    self._currentPlugins.append(plugin)
                }
            }
        }
    }

    /**
    Calls the onDestroy() method of each plugin.
    */
    private func destroyPlugins() {
        for plugin in self._currentPlugins {
            plugin.onDestroy()
        }
    }

    /*
    Load profile id from file

    :returns: profileId or empty string
    */
    func loadProfileId() -> String {
        let file: String = self.getFileLocation(Constants.Files.ID)
        let exists: Bool = NSFileManager.defaultManager().fileExistsAtPath(file)
        if exists {

            do {
                let result: String? = try NSString(contentsOfFile: file, encoding: NSUTF8StringEncoding) as String
                return result!
            } catch let error as NSError? {
                if self._debugMode {
                    let loadError = (error != nil) ? error!.localizedDescription : ""
                    NSLog("%@ Failed to load profile id, reason : %@", Constants.Debug.DEBUG_CLIENT, loadError)
                }
            }
        }
        return ""
    }

    /**
    Write the profileId to a specified file
    
    - parameter    profileId:   The profile identifier retrieved from the server
    */
    func saveProfileId(profileId: String) {
        let file: String = self.getFileLocation(Constants.Files.ID)
        var error: NSError?
        if profileId != "" {
            do {
                try profileId.writeToFile(file, atomically: true, encoding: NSUTF8StringEncoding)
            } catch let error1 as NSError {
                error = error1
            }
        }
        if error != nil {
            if self._debugMode {
                NSLog("%@ Failed to save profile id, reason : %@", Constants.Debug.DEBUG_CLIENT, error!.localizedDescription )
            }
        }
    }

    /**
    Store the domain groups.
    
    - parameter domainGroup: the domain group to set.
    */
    func setDomainGroup(domainGroup: String) {
        self._cache.setDomainGroup(domainGroup)
    }

    /*
    Get the domain group.
    */
    func getDomainGroup() -> String? {
        return self._cache.getDomainGroup()
    }

    /**
    Load all the profile property labels

    - returns:   a NSDicitionary that could contain all the labels or is empty
    */
    func loadLabels() -> Dictionary<String, AnyObject> {
        let file: String = self.getFileLocation(Constants.Files.LABELS)

        if NSFileManager.defaultManager().fileExistsAtPath(file) {
            if let labels = NSKeyedUnarchiver.unarchiveObjectWithFile(file) as? Dictionary<String, AnyObject> {
                return labels
            }
        }

        return Dictionary<String, AnyObject>()
    }

    /**
    Save all the profile property labels to a specified file
    Retrieves all labels from self._labels an write it to a file
    If the file already exists it will be overwritten.
    */
    func saveLabels() {
        let file: String = self.getFileLocation(Constants.Files.LABELS)
        // Serialize and write result atomically to disk
        NSKeyedArchiver.archiveRootObject(self._labels, toFile: file)
    }

    /**
    Load the latest saved BlueConicCommitLog
    
    - returns: a BlueConicCommit log, could return a new instance of BlueConicCommitLog if the file didn't exists
    */
    func loadCommitLog(fileLocation: String) -> BlueConicCommitLog {
        let file: String = self.getFileLocation(fileLocation)

        if NSFileManager.defaultManager().fileExistsAtPath(file) {
            if let commitLog: BlueConicCommitLog = NSKeyedUnarchiver.unarchiveObjectWithFile(file) as? BlueConicCommitLog {
                return commitLog
            }
        }
        return BlueConicCommitLog()
    }

    /**
    Save the current BlueConicCommitLog to a specified file
    If the file already exists it will be overwritten.
    */
    func saveCommitLog() {
        let file: String = self.getFileLocation(Constants.Files.COMMITLOG)
        let requestFile: String = self.getFileLocation(Constants.Files.REQUEST_COMMITLOG)
        // Serialize and write result atomically to disk
        NSKeyedArchiver.archiveRootObject(self._commitLog, toFile: file)
        NSKeyedArchiver.archiveRootObject(self._requestCommitLog, toFile: requestFile)
    }

    /**
    Load the latest saved BlueConicCache
    
    - returns: a BlueConicCache log, could return a new instance of BlueConicCache if the file didn't exists
    */
    func loadCache() -> BlueConicCache {
        let file: String = self.getFileLocation(Constants.Files.CACHE)
        // FIX ME var exists: Bool = NSFileManager.defaultManager().fileExistsAtPath(file)
        if NSFileManager.defaultManager().fileExistsAtPath(file) {
            if let cache: BlueConicCache = NSKeyedUnarchiver.unarchiveObjectWithFile(file) as? BlueConicCache {
                return cache
            }
        }
        return BlueConicCache()
    }

    /**
    Save the current BlueConicCache to a specified file
    If the file already exists it will be overwritten.
    */
    func saveCache() {
        let file: String = self.getFileLocation(Constants.Files.CACHE)
        // Serialize and write result atomically to disk
        NSKeyedArchiver.archiveRootObject(self._cache, toFile: file)
    }

}