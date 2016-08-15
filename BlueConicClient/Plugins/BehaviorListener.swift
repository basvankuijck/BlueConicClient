/*
* $LastChangedBy$
* $LastChangedDate$
* $LastChangedRevision$
* $HeadURL$
*
* Copyright 2014 BlueConic Inc./BlueConic B.V. All rights reserved.
*/

import Foundation

public class BehaviorListener: Plugin {

	private var _client: BlueConicClient?
	private var _context: InteractionContext?

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

		BlueConicEventFactory.getInstance().cleanup()

        if let listenerRules = ListenerUtil.getDictionaryFromParameters(self._context, key:"listener_rules"),
            let interactionId = self._context?.getInteractionId(),
            let rules = listenerRules["rules"] {
                let rulesService = RuleService(listenerId: interactionId)
                rulesService.applyRules(rules)
                rulesService.save()
        }
	}

	public override func onDestroy(){
		BlueConicEventFactory.getInstance().clearEventHandlers(self._context?.getInteractionId())
	}

}