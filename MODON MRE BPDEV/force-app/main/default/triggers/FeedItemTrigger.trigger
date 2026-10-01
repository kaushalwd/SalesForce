/**********************************************************************************************************************
* Name               : FeedItemTrigger                                                  
* Description        : This trigger is used handle FeedItem triggering scenarios
* Usage              : This trigger is used handle FeedItem triggering scenarios
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      24 Feb 2026     Initial Draft 
***********************************************************************************************************************/
trigger FeedItemTrigger on FeedItem (before insert, before update, before delete, after insert, after update, after delete) { // FeedItem does not support undelete.So not added to the list
    TriggerDispatcher.run(new FeedItemTriggerHandler());
}