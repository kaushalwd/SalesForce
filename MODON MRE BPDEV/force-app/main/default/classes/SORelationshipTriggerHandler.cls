/**********************************************************************************************************************
* Name               : SORelationshipTriggerHandler                                                        
* Description        : This class is used to handle all the SO Relationship trigger events
* Usage              : Called from SORelationshipTrigger
* Created By         : MODON IT                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           MODON IT 					        7 Aug 2026     Initial Draft
**********************************************************************************************************************/
public without sharing class SORelationshipTriggerHandler extends TriggerHandler {

    // Test-only hook to force a genuine unhandled exception, so SORelationshipTrigger's
    // try/catch(Exception)/LoggerService.save/rethrow block can be covered. addError()-based
    // validation failures never reach that catch block since the platform throws those
    // DmlExceptions to the DML caller after the trigger has already finished executing.
    @TestVisible
    private static Boolean forceExceptionForTest = false;

    public class ForcedTestException extends Exception {}

    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap) {
        if (Test.isRunningTest() && forceExceptionForTest) {
            throw new ForcedTestException('Forced exception for SORelationshipTrigger exception-handling test coverage');
        }
        SORelationshipTriggerHelper.createDocumentRecords(newList);
        SORelationshipTriggerHelper.validateNOCLetterDocument(newList, null);
    }
    
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        SORelationshipTriggerHelper.validateDuplicateRelationship(newList);
    }

    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        SORelationshipTriggerHelper.validateNOCLetterDocument(newList, oldMap);
    }

    //*** After Update Action ***//
    public override void afterUpdateMethod(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) {
        SORelationshipTriggerHelper.createCustomerRelationshipCallout(newList, oldMap);
    }

}