/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

public class EngagementRankingListener: Plugin {

    private var _client: BlueConicClient?
    private var _context: InteractionContext?
    private var _engagementService: EngagementService?

    /**
    Default initializer for a blueconic plugin
    - parameter  client:  An instance of the BlueConicClient
    - parameter  context:  An instance of the InteractionContext
    */
    public override convenience init(client: BlueConicClient, context: InteractionContext) {
        self.init()
        self._client = client
        self._context = context
    }

    /**
    OnLoad function for blueconic plugin.
    This starts the plugin.
    */

    public override func onLoad() {
        if self._client == nil {
            return
        }

        if let context = self._context,
            let interestsDictionary = ListenerUtil.getDictionaryFromParameters(context,key: "interests"),
            let engagementRules = ListenerUtil.getDictionaryFromParameters(context,key:"engagement_rules"),
            let property = ListenerUtil.getProfilePropertyFromParameters(context.getParameters()) {
                let interests: [String]? = interestsDictionary["values"] as? [String]
                let decay = Int(ListenerUtil.getValueFromParameters(context, key: "decay"))

                BlueConicEventFactory.getInstance().cleanup()
                self._engagementService = EngagementService(client: self._client!, context: context, propertyName: property, decay: decay, isInterest: true, allInterests: interests)
                if let rules = engagementRules["rules"] {
                    self._engagementService?.applyRules(rules);
                }

                // Check if there are changes in the engagementservice
                if self._engagementService != nil  && self._engagementService!.isChanged() {
                    // Store the internal JSON string or the changes to the profile
                    self._engagementService?.save();
                }

        }
    }

	public override func onDestroy(){
		BlueConicEventFactory.getInstance().clearEventHandlers(self._context?.getInteractionId())
	}

}