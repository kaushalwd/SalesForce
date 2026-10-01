/**********************************************************************************************************************
* Name               : ContentDocumentLinkTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the content document link record.
* Usage              : Called by system processes on content document link record create, update, delete, undelete
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com    10 Jan 2024     Initial Draft           
* 1.1           Rushi Patel                 18 Aug 2026     Added before delete, after delete, after undelete events
******************************************************************************************************************/
trigger ContentDocumentLinkTrigger on ContentDocumentLink (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    new ContentDocumentLinkTriggerHandler().run('ContentDocumentLink');
}