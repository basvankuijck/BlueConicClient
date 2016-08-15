/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

class BlueConicCache: NSObject, NSCoding {
    private var _properties: Dictionary<String, [String]> = [:]
    private var _domainGroup: String?
    private var _modified: Bool = false

    /**
    Default init() for BlueConicCache
    */
    override init() {
        super.init()
        self._properties = Dictionary<String, [String]>()
        self._modified = true
    }

    /**
    init() with a Coder set on the entries for BlueConicCache
    */
    required convenience init?(coder decoder: NSCoder) {
        self.init()
        self._properties = decoder.decodeObjectForKey(Constants.PROPERTIES) as! Dictionary<String, [String]>
        self._domainGroup = decoder.decodeObjectForKey(Constants.DOMAINGROUP) as? String
    }

    /**
        Encode with Coder to get the entries from BlueConicCache
    */
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(self._properties, forKey: Constants.PROPERTIES)
        coder.encodeObject(self._domainGroup, forKey: Constants.DOMAINGROUP)
    }

    /**
    Returns the domain group.
        
    - returns: the domain group.
    */
    func getDomainGroup() -> String? {
        return self._domainGroup
    }

    /**
    Setter for the domain group.
    - parameter domainGroup: The domain group to set.
    */
    func setDomainGroup(domainGroup: String) {
        self._domainGroup = domainGroup
        setLastUpdate()
    }

    /**
    Returns the first value for a given profile property.

    - parameter property: The name of the profile property
    - returns: The first value or empty if no value was present.
    */
    func getProfileValue(property: String) -> String {
        if let matches = self._properties[property] where matches.count > 0 {
            return matches[0]
        }
        return ""
    }

    /**
    Returns the values for a given profile property.
    
    - parameter property: The name of the profile property
    - returns: A collection containing the values.
    */
    func getProfileValues(property: String)-> [String]? {
        return self._properties[property]
    }

    /**
    Returns all values currently in this local cache.

    - returns: The dictionary mapping propery name String on the corresponding array of String values.
    */
    func getProperties() -> Dictionary<String, [String]> {
        return self._properties
    }

    /**
    Adds property values to the profile cache. The values from the collection are added to the profile.

    - parameter name: the profile property to add the values for
    - parameter values: The property values to add to the profile cache.
    */
    func addProperties(name: String, values: [String]) {
        // Check if name is empty/ values may be an empty array
        if name == "" {
            // Do nothing
            return
        }

        // Check whether properties exist with this name
        var newValues = [String]()
        if let existing = self._properties[name] where existing.count > 0 {
            newValues = existing
        }

        // Add the new values to the array
        for value in values{
            if !newValues.contains(value) {
                newValues.append(value)
            }
        }

        // Create immutable objects to store in the Cache
        let immutableValue = newValues

        // Update the Cache
        self._properties[name] = immutableValue

        // Set the modified flag
        self.setLastUpdate()
    }

    /**
    Sets property values in the profile cache, existing values will be removed.

    - parameter name: the profile property to add the values for
    - parameter values: The property values to set for the profile cache.
    */
    func setProperties(name: String, values: [String]) {
        // Check if name is empty/ values may be an empty array
        if name == "" {
            // Do nothing
            return
        }

        self._properties[name] = BlueConicCache.filterEmpty(values)

        self.setLastUpdate()
    }

    /**
    Sets property values in the profile cache, existing values will be removed.
    - parameter properties: The new property values to set for the profile cache. This dictionary maps Strings on String arrays.
    */
    func setProperties(properties: Dictionary<String, [String]>) {
        for (key, value) in properties {
            setProperties(key as String, values: value)
        }
    }
    /**
    Filter out the empty strings in the array
    */
    static func filterEmpty(values: [String]) -> [String] {
        if values.count == 0 {
            return [];
        }

        var result = [String]()
        for value in values {
            if value != "" {
                result.append(value)
            }
        }
        return result
    }

    /**
    Clears all entries from this local cache.
    */
    func clear() {
        self._properties.removeAll()
        self.setLastUpdate()
    }

    /**
    Get the hash from all cached properties.
    */
    func getHash() -> String {
        return ProfileHash.getHash(self._properties)
    }

    /**
    Set the modified flag.
    */
    func setLastUpdate() {
        self._modified = true
    }

    /**
    Reads the modified flag and resets it.
    - returns: The value of the modified flag before it was reset.
    */
    func checkModified() -> Bool {
        let result = _modified
        _modified = false
        return result
    }
}