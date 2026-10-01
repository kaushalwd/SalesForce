/**********************************************************************************************************************
* Name               : ContentDocumentTrigger                                                        
* Description        : Trigger on ContentDocument to handle operations on file deletions and updates
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 18 Aug 2026     Initial Draft           
******************************************************************************************************************/
trigger ContentDocumentTrigger on ContentDocument (before delete) {
    new ContentDocumentTriggerHandler().run('ContentDocument');
}