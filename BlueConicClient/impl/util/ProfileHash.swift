/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation
class ProfileHash {
    struct Static {
        static let SEPARATOR: String = ";"
        static let M: Int = 10000
    }

    /**
    Private constructor.
    */
    init() {
    }

    /**
    Returns the hash for all properties in a map. Entries are separated by a ';'.
    - parameter properties: the properties to get the hash for.
    - returns: a string representation for the hash
    */
    class func getHash(properties: Dictionary<String, [String]>?) -> String {
        if properties == nil {
            return "";
        }
        var result: String = ""
        for (key, value) in properties! {
            result += getHash(key, values: value) + Static.SEPARATOR
        }
        return result
    }

    /**
    Returns the hash value for a single property and its values.
    - parameter id: the profile property id
    - parameter values: the values for this property.
    - returns: a string representation for the hash
    */
    class func getHash(id: String, values: [String]?) -> String {
        if values == nil {
            return ""
        }
        var hash = getHash(id)
        for value in values! {
            hash += getHash(value)
        }
        return "\(hash % Static.M)"
    }


    /**
    Hashing method for a single string.
    - parameter input: the string to hash.
    - returns: the hash
    */
    class func getHash(input: String?) -> Int {
        if input == nil {
            return 0
        }

        let ch = Array((input!).characters)
        var sum = 0
        for value in ch {
            for a in String(value).unicodeScalars {
                sum += Int("\(a.value)")!
            }
        }
        return sum
    }
}