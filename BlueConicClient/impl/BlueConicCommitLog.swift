/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

class BlueConicCommitLog: NSObject, NSCoding{

    private var _entries = [BlueConicCommitEntry]()
    private var _modified: Bool = false

    /**
    Default init() for BlueConicCommitLog
    */
    override init(){
        super.init()
        self._entries = [BlueConicCommitEntry]()
        self._modified = true
    }

    /**
    Implementation of NSCoding
    init() with a Coder set on the entries for BlueConicCommitLog
    */
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        if let entries = decoder.decodeObjectForKey(Constants.CommitLog.ENTRIES_KEY) as? [BlueConicCommitEntry] {
            self._entries = entries
        }

        self._modified = false
    }

    /**
    Implementation of NSCoding
    encode with Coder to get the entries from BlueConicCommitLog

    - parameter coder: The coder to use for serializing this instance
    */
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(self._entries, forKey: Constants.CommitLog.ENTRIES_KEY)
    }

    /**
    Sets the values for the property with the specified name.

    - parameter name: The property name
    - parameter values: The String array containing the new values
    */
    func setProperties(name: String, values: [String]) {
        if name == "" || values.count == 0 {
            return
        }

        // Check if the PropertyCommitEntry already exists, if so override the values
        if let exitingEntry = getPropertyCommitEntry(name) {
            exitingEntry.setValues(values)
        } else {
            // Create a new set property entry with the specified values
            let entry = BlueConicPropertyCommitEntry(propertyIdentifier: name, type: OperationType.SET, values: values)
            self._entries.append(entry)
        }

        // Store a new entry and overwrite any existing entry
        self.setLastUpdate()
    }

    /**
    Adds values to the property with the specified name.

    - parameter name: The property name
    - parameter values: The String array containing the additional values
    */
    func addProperties(name: String, values: [String]) {
        if name == "" || values.count == 0 {
            return
        }

        // Check if the PropertyCommitEntry already exists, if so then ADD the value to the entry
        if let existingEntry = getPropertyCommitEntry(name) {
            let existingValues: [String] = existingEntry.getValues()
            for value in values {
                if !existingValues.contains(value) {
                    existingEntry.addValue(value)
                }
            }
        } else {
            // Create a new add PropertyCommitEntry with the specified values
            let entry = BlueConicPropertyCommitEntry(propertyIdentifier: name, type: OperationType.ADD, values: values)
            self._entries.append(entry)
        }
        self.setLastUpdate()
    }

    /**
    Add a created even to the entries, based on event-type and interactionId

    - parameter eventType: The eventype, one of {VIEW, CLICK, CONVERSION}
    - parameter interactionid: The position identifier of an element in the app
    */
    func createEvent(eventType: EventType, interactionId: String) {
        if interactionId == "" {
            return
        }
        // Update the event.
        self.updateEvent(eventType, interactionId: interactionId, amount: 1)

        self.setLastUpdate()
    }
    /**
    Update event, based on event-type and interactionId.
    Checks if the event already exists, then it will increase the count.
    else it will add a new event commit entry.

    - parameter eventType: The eventype, one of {VIEW, CLICK, CONVERSION}
    - parameter interactionid: The position identifier of an element in the app
    */
    private func updateEvent(eventType: EventType, interactionId: String, amount: Int) {
        // Check if the EventCommitEntry already exists if so then increase the count of the entry
        if let existingEntry = getEventCommitEntry(eventType, interactionId: interactionId) {
            existingEntry.increaseCount(amount)
        } else {
            // Create a new event entry and set the count to 1
            let newEntry = BlueConicEventCommitEntry(eventType: eventType, interactionId: interactionId)
            if (amount > 1) {
                newEntry.increaseCount(amount-1)
            }
            self._entries.append(newEntry)
        }
    }

    /**
    Returns the dictionary of operations in the commitlog.

    - parameter type: The of the operation, add or set
    - returns: The dicionary of matching entries, being a map of Strings to arrays of Strings.
    */
    func getProperties(type: OperationType) -> Dictionary<String, BlueConicCommitEntry> {
        var result = Dictionary<String, BlueConicCommitEntry>()
        for entry in self._entries {
            // Only add the Property commit entries with the correct type
            if let entry = entry as? BlueConicPropertyCommitEntry where entry.getType() == type.rawValue {
                result[entry.getId()] = entry
            }
        }
        return result
    }

    /**
    Returns all Created events in the commitlog.

    - returns: list with all BlueConicEventCommitEntries
    */
    func getEvents() -> [BlueConicCommitEntry] {
        var result = [BlueConicCommitEntry]()
        for entry in self._entries {
            // Only add the Event commit entries
            if entry is BlueConicEventCommitEntry {
                result.append(entry)
            }
        }
        return result
    }
    /**
    Returns all the entries in the commitlog.
    
    - returns: list with all BlueConicEventCommitEntries
    */
    func getEntries() -> [BlueConicCommitEntry] {
        return self._entries
    }

    /**
    Returns a BlueConicPropertyCommitEntry when there is already an entry in the commmitlog, if not then return nil.

    - parameter propertyId:: identifier of a profile property
    - returns: BlueConicPropertyCommitEntry or nil
    */
    func getPropertyCommitEntry(propertyId: String) -> BlueConicPropertyCommitEntry? {
        if propertyId == "" {
            return nil
        }

        // Check if an entry is a PropertyCommitEntry and if the id is equal to propertyId
        for commitEntry in self._entries {
            if let entry = commitEntry as? BlueConicPropertyCommitEntry where entry.getId() == propertyId {
                return entry
            }
        }
        return nil
    }

    /**
    Returns a BlueConicEventCommitEntry when there is already an entry in the commmitlog, if not the return nil.
    
    - parameter eventType:: could be {VIEW, CLICK, CONVERSION}
    - parameter interactionId:: position identifier of the element in the app
    - returns: BlueConicEventCommitEntry or nil
    */
    func getEventCommitEntry(eventType: EventType, interactionId: String) -> BlueConicEventCommitEntry? {
        if interactionId == "" {
            return nil
        }

        // Check if an entry is a EventCommitEntry and if the type is equals to eventType
        for commitEntry in self._entries {
            if let entry: BlueConicEventCommitEntry = commitEntry as? BlueConicEventCommitEntry {
                if entry.getId() == interactionId  && entry.getType() == eventType.rawValue {
                    return entry as BlueConicEventCommitEntry
                }
            }
        }
        return nil
    }

    /**
    Clears all entries in the commit log.
    */
    func clearAll(){
        self._entries.removeAll()
    }

    /**
    Merge the commitlogs, the parameter is the newest commitlog,
    so setters will be override the old set values.
    */
    func mergeCommitLog(commitLog: BlueConicCommitLog) {
        // Return if there are no entries to merge
        if commitLog.getEntries().count == 0 {
            return
        }

        // Merge the commitlog entries if both lists contain entries.
        for entry in commitLog.getEntries() {
            // Add Property commit entries
            if entry is BlueConicPropertyCommitEntry {
                if entry.getType() == OperationType.SET.rawValue {
                    self.setProperties(entry.getId(), values: (entry as! BlueConicPropertyCommitEntry).getValues())
                } else if entry.getType() == OperationType.ADD.rawValue {
                    self.addProperties(entry.getId(), values: (entry as! BlueConicPropertyCommitEntry).getValues())
                }
            // Add Event commit entries
            } else if entry is BlueConicEventCommitEntry {
                self.updateEvent(EventType(rawValue: entry.getType())!, interactionId: entry.getId(), amount: (entry as! BlueConicEventCommitEntry).getCount())
            }
        }
        commitLog.clearAll()
    }

    /**
    Reads the modified flag and resets it.

    - returns: The value of the modified flag before it was reset.
    */
    func checkModified() -> Bool {
        let result: Bool = _modified
        _modified =  false
        return result
    }

    /**
    Set the modified value to true, so the updater knows the commit log has changed
    */
    func setLastUpdate() {
        self._modified = true
    }
}

//
//  BlueConicCommitEntry
//
@objc protocol BlueConicCommitEntry: NSCoding {
    // NSCoding implements
    init(coder decoder: NSCoder)
    func encodeWithCoder(aCoder: NSCoder)
    // Entry implements
    func getType() -> String
    func getId() -> String
}

//
//  BlueConicPropertyCommitEntry
//
class BlueConicPropertyCommitEntry: NSObject, BlueConicCommitEntry {
    private var _type: OperationType
    private var _values = [String]()
    private var _propertyIdentifier: String = ""

    /**
    Constructor.

    - parameter propertyIdentifier: The property identifier.
    - parameter type:               The type of operation.
    - parameter values:             The values.
    */
    init(propertyIdentifier: String, type: OperationType, values: [String]) {
        self._propertyIdentifier = propertyIdentifier
        self._type = type

        // Add objects from Array
        self._values = values
    }

    /**
    Implementation of NSCoding
    init() with a Coder set on the entries for BlueConicPropertyCommitEntry
    */
    required convenience init(coder decoder: NSCoder) {
        let str = decoder.decodeObjectForKey(Constants.CommitLog.TYPE_KEY) as! String
        let type: OperationType? = OperationType(rawValue: str)
        let identifier : String  = decoder.decodeObjectForKey(Constants.CommitLog.ID_KEY) as! String
        let values = decoder.decodeObjectForKey(Constants.CommitLog.VALUES_KEY) as! [String]
        self.init(propertyIdentifier: identifier, type: type!, values: values)
    }

    /**
    Implementation of NSCoding
    encode with Coder to get the entries from BlueConicCommitLog
    */
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(self.getId(), forKey: Constants.CommitLog.ID_KEY)
        coder.encodeObject(self.getType(), forKey: Constants.CommitLog.TYPE_KEY)
        coder.encodeObject(self.getValues(), forKey: Constants.CommitLog.VALUES_KEY)
    }

    /**
    Returns the Identifier of a Property

    - returns: The id of a property, this value is a String
    */
    func getId() -> String {
        return self._propertyIdentifier
    }

    /**
    Returns the type of operation.

    - returns: The type of operation. This can be {'add', 'set'}.
    */
    func getType() -> String {
        return self._type.rawValue
    }

    /**
    Returns the values.

    - returns: The values.
    */
    func getValues() -> [String] {
        return self._values
    }

    /**
    Set the values

    - parameter values: An array of property values
    */
    func setValues(values: [String]) {
        if values.count > 0 {
            self._values = values
        }
    }

    /**
    Add a value

    - parameter value: A property value
    */
    func addValue(value: String) {
        self._values.append(value)
    }

}

//
//  BlueConicEventCommitEntry
//
class BlueConicEventCommitEntry: NSObject, BlueConicCommitEntry {
    private var _type: EventType
    private var _interactionId: String = ""
    private var _count: Int = 1

    /**
    Constructor.

    - parameter eventType:     A EventType enum {VIEW, CLICK, CONVERSION}.
    - parameter interactionId: The Id of an interacion.
    */
    init(eventType: EventType, interactionId: String) {
        self._type = eventType
        self._interactionId = interactionId
    }

    /**
    Implementation of NSCoding
    init() with a Coder set on the entries for BlueConicEventCommitEntry
    */
    required convenience init(coder decoder: NSCoder) {
        let id: String = decoder.decodeObjectForKey(Constants.CommitLog.Event.ID_KEY) as! String
        let str = decoder.decodeObjectForKey(Constants.CommitLog.Event.TYPE_KEY) as! String
        let count = decoder.decodeObjectForKey(Constants.CommitLog.Event.COUNT_KEY) as! String
        let type: EventType? = EventType(rawValue: str)
        self.init(eventType: type!,interactionId: id)
        self._count = NSString(string: count).integerValue
    }

    /**
    Implementation of NSCoding
    encode with Coder to get the entries from BlueConicEventCommitEntry
    */
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(getId(), forKey: Constants.CommitLog.Event.ID_KEY)
        coder.encodeObject(getType(), forKey: Constants.CommitLog.Event.TYPE_KEY)
        coder.encodeObject(String(getCount()), forKey: Constants.CommitLog.Event.COUNT_KEY)
    }

    /**
    Returns the interactions identifier

    - returns: The id of a interaction
    */
    func getId() -> String {
        return self._interactionId
    }

    /**
    Returns the type of the event

    - returns: The type of the event, This can be { "VIEW", "CLICK",  "CONVERSION" }
    */
    func getType() -> String {
        return self._type.rawValue
    }

    /**
    Returns the current count of the event

    - returns: A count how many times this event is called.
    */
    func getCount() -> Int {
        return self._count
    }

    /**
    Increasing the count
    - parameter amount:  The amount of
    */
    func increaseCount(amount: Int) {
        self._count = self._count + amount
    }
}
