@isTest
public class UtilityTest {
@isTest
    static void allMethodsTest() {
        
        String returnValue = Utility.getRandomString(5);
        system.debug('returnValue ' + returnValue);       
        Schema.SObjectType sObjType = Account.sObjectType;
        String fieldsList = Utility.getAllFields('Case');
        Id recTypeId = Utility.getRecordTypeIdByDevName(sObjType, 'PersonAccount');
        Id recTypeId2 = Utility.getRecordTypeIdByName(sObjType, 'Person Account');
        Schema.SObjectType sObjTypeCase = Case.sObjectType;
        Map<String, String> picklistValues = Utility.getPicklistValues(sObjTypeCase, 'Origin');
        //Boolean isChanged = Utility.checkAnyFieldChange('Case', 'Case');
        Id groupID = [select id from group where type ='queue' and name ='Duplicate Queue' limit 1].Id;
        List<String> emailsList =  Utility.getUserEmailsFromPublicGroupId(groupID);
        Set<Id> idSet = new Set<Id>();
        idSet.add(groupID); 
        emailsList =  Utility.getUserEmailsFromPublicGroupIds(idSet);
        String formattedEmiratesId = Utility.formatEmiratesId('784123412345671');
        system.debug('formattedEmiratesId ' + formattedEmiratesId);
        string formattedPhoneNumber = Utility.formatPhoneNumber('971', '501234567');
        Utility.getObjectNameFromId(String.valueOf(userinfo.getuserid()));
        system.debug('formattedPhoneNumber ' + formattedPhoneNumber);
        set<id> newt = new set<Id>();
        newt.Add(userinfo.getuserid());
        
        UserService useS = new UserService();
        List<User> useList =useS.getUsersByIds(newt);
        Boolean useremil =useS.hasBypassEmail();
        Boolean userInteg =useS.hasBypassIntegration();
        Boolean userBypass = useS.hasBypassTrigger();
        
        /*// Get test data from TestDataFactory
        Map<String, Id> ids = TestDataFactory.createTestData();
		Id testCaseId = ids.get('TestCase');  // Case record Id
        Id testCase1Id = ids.get('testCase1');
        List<Case> casesToUpdate = [SELECT Id,IsDeleted,MasterRecordId,CaseNumber,ContactId,AccountId,AssetId,ProductId,EntitlementId,SourceId,BusinessHoursId,ParentId,SuppliedName
                                    ,SuppliedEmail,SuppliedPhone,SuppliedCompany,Type,RecordTypeId,Status,Reason,Origin,Language,Subject,Priority,Description,IsClosed,ClosedDate
                                    ,IsEscalated,CurrencyIsoCode,OwnerId,IsClosedOnCreate,SlaStartDate,SlaExitDate,IsStopped,StopStartDate,CreatedDate,CreatedById,LastModifiedDate
                                    ,LastModifiedById,SystemModstamp,ContactPhone,ContactMobile,ContactEmail,ContactFax,Comments,LastViewedDate,LastReferencedDate
                                    //,ConnectionReceivedId,ConnectionSentId
                                    ,ServiceContractId,MilestoneStatus,Approval_Status__c,CaseCategory__c,CaseType__c,Language_Preference__c,Manager_Email__c
                                    ,Manager_Name__c,New_Case_Category__c,Owner_Name__c,Account_Manager_Email__c,Account_Name__c,Breached__c,Case_Approver__c,Customer_Email__c
                                    ,Customer_Name__c,Customer_Phone__c,Duplicate_Cases__c,Emirates_Id__c,Masked_Emirates_Id__c,New_Owner_Email__c,New_Owner__c,Owner_Email__c
                                    ,Previous_Owner_Email__c,Previous_Owner__c,Primary_Assignee__c,Primary_Owner_Name__c,Privileged_Visitor__c,Requestor_Email__c,Requestor_Name__c
                                    ,Requestor_Phone__c,Resolution_Comments__c,Resolved_Date__c,RunningTestClass__c,SR_Number__c,Secondary_Details_Provided__c,SurveyLink__c,Task_Notes__c
                                    ,Time_Limit__c,Time__c,Transfer_Comments__c,Unit__c,Visit_Date__c,Warning__c,CaseSubCategory__c,New_Case_SubCategory__c,New_Owner_Name__c
                                    ,Previous_Owner_Name__c,Is_Closed_CustomerEmail_Sent__c,Previous_Department__c,SendEmail_CaseClosed__c,SendEmail_CaseCreated__c,SendEmail_DeptartmentTransfer__c
                                    ,SendEmail_DuplicateCase__c,SendEmail_NonBusinessHours__c,TransferComments__c,Current_Owner__c,Current_Owner_Name__c
                                    			FROM Case WHERE Id IN :new Set<Id>{testCaseId, testCase1Id} limit 1];
        Boolean isChanged = Utility.checkAnyFieldChange(casesToUpdate[0], casesToUpdate[0]);
        */
    }
}