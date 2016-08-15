/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

/*
static constants defined here
*/
struct Constants {
    //Default constants: Not labeled to a group or basic variables.
    static let PLIST: String = "plist"
    static let HOST_NAME: String = "bc_server_url"

    static let DEBUG_MODE: String = "bc_debug"
    static let METHOD: String = "method"
    static let RESULT: String = "result"
    static let PROPERTIES: String = "properties"
    static let DOMAINGROUP: String = "domain"
    static let DOMAINGROUPID: String = "domainGroupId"
    static let ID: String = "id"
    static let PARAMS: String = "params"
    static let ID_PREFIX: String = "#"
    static let LOCATION_PREFIX: String = "/"

    static let BLUECONIC_VERSION: String = "2.1.7"
    static let BLUECONIC_NAME: String = "BlueConic iOS SDK " + BLUECONIC_VERSION

    // Debug
    struct Debug {
        static let DEBUG_CLIENT: String = "BC_CLIENT:"
        static let DEBUG_CONNECTOR: String = "BC_CONNECTOR:"
    }


    //Files constants:
    struct Files {
        static let COMMITLOG: String = "commitlog.data"
        static let REQUEST_COMMITLOG: String = "requestcommitlog.data"
        static let CACHE: String = "cache.data"
        static let ID: String = "id.data"
        static let LABELS: String = "labels.data"
        static let BLUECONIC_DIR: String = "blueconic"
    }

    //Rest Calls constants: Eventually we could split it up even more. Like: RestCalls.Profile.getProfile
    struct Calls{
        static let JSON_VALUE: String = "json"
        static let JSON_KEY: String = "alt"

        static let ADD_PROPERTIES: String = "addProperties"
        static let SET_PROPERTIES: String = "setProperties"
        static let GET_PROFILE: String = "getProfile"
        static let GET_PROPERTIES: String = "getProperties"
        static let GET_PROPERTY_LABELS: String = "getPropertyLabels"
        static let CREATE_EVENT: String = "createEvent"
    }

    struct ProfileProperties {
        static let ID: String = "profileId"
        static let PARAMETER_KEY: String = "forceCreate"
        static let PARAMETER_VALUE: String = "true"
    }

    struct Interactions {
        static let ID: String = "id"
        static let CLASS: String = "pluginClass"
        static let LOCALE: String = "locale"
        static let DEFAULT_LOCALE: String = "defaultLocale"
        static let TYPE: String = "myInteractionTypeId"
        static let PARAMETER_KEY: String = "type"
        static let PARAMETER_VALUE: String = "PAGEVIEW"
        static let INTERACTION_KEY: String = "interaction"
        static let INTERACTIONS_KEY: String = "interactions"
        static let POSITION_KEY: String = "position"
        static let PARAMETERS: String = "parameters"
    }

    struct Connections {
        static let ID: String = "id"
        static let PARAMETERS: String = "parameters"
        static let PARAMETER: String = "parameter"
        static let CONNECTIONS_KEY: String = "connections"
    }

    struct CommitLog {
        static let ENTRIES_KEY: String = "entries"
        static let VALUES_KEY: String = "values"
        static let TYPE_KEY: String = "type"
        static let ID_KEY: String = "identifier"

        struct Event {
            static let TYPE_KEY: String = "eventtype"
            static let ID_KEY: String = "eventidentifier"
            static let COUNT_KEY: String = "eventcount"
            static let PAGEVIEW = "PAGEVIEW"
            static let CLICK = "CLICK"
            static let VIEW = "VIEW"
            static let CONVERSION = "CONVERSION"
        }
    }

    struct Connector {
        static let DOMAIN_VALUE: String = "DEFAULT"
        static let USER_AGENT_FIELD: String = "User-Agent"
        static let PROFILE_ID_FIELD: String = "BCSessionID"

        static let CONTENT_TYPE_VALUE: String = "application/x-www-form-urlencoded; charset=utf-8"
        static let CONTENT_TYPE_FIELD: String = "Content-Type"
        static let ACCEPT_ENCODING_FIELD: String = "Accept-Encoding"
        static let ACCEPT_ENCODING_VALUE: String = "gzip"
        static let REFERRER: String = "referer"
    }

    // Seassion constants:
    struct Session {
        static let TIMEOUT: Double = 6 * 10 * 1000
        static let LENGTH_KEY: String = "mobile_app_sessionlength"
    }

    //Mobile App constants:
    struct MobileApp {
        static let ID = "mobile_app_id"
        static let NAME = "mobile_app_name"
        static let NAME_VERSION = "mobile_app_nameversion"
        static let OS = "mobile_app_os"
        static let OS_VERSION = "mobile_app_osversion"
        static let VENDOR = "mobile_app_vendor"
        static let MODEL = "mobile_app_model"
        static let RESOLUTION = "mobile_app_resolution"
        static let PAGEVIEWS = "mobile_app_pageviews"

        static let BUNDLE_IDENTIFIER = "CFBundleIdentifier"
        static let BUNDLE_NAME = "CFBundleDisplayName"
        static let SWIFT_BUNDLE_NAME = "CFBundleName"
        static let BUNDLE_VERSION = "CFBundleShortVersionString"
    }
}
