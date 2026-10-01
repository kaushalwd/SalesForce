/*
 * Name         : ServiceRequestChecker
 * Description  : Handles ADM validation, Direct Debit checks, Bank details retrieval, and task assignment.
 * Author       : Chandu
 * Created Date : 2026-04-09
 * ------------------------------------------------------
 * Version   Date         Author          		Description
 * 1.0       2026-04-09   Chandu   				Initial Creation
 * 2.0       11-05 2026   Raghu Gajjela			Updated Query of Task
 */

public with sharing class ServiceRequestChecker {
    
    public class ADMResult {
    @AuraEnabled public Boolean hasADM;
    @AuraEnabled public String status;
    @AuraEnabled public Id recordId;
    @AuraEnabled public String name;
}

   @AuraEnabled(cacheable=true)
public static ADMResult hasADMRegistration(Id serviceRequestId) {

    ADMResult result = new ADMResult();
    result.hasADM = false;

    if(serviceRequestId == null){
        return result;
    }

    // Get current SR SalesOrder
    ServiceRequest__c sr = [
        SELECT Id, SalesOrder__c
        FROM ServiceRequest__c
        WHERE Id = :serviceRequestId
        LIMIT 1
    ];

    if(sr.SalesOrder__c == null){
        return result;
    }

    // Fetch ADM SR
    List<ServiceRequest__c> relatedSRs = [
        SELECT Id, Name, Status__c
        FROM ServiceRequest__c
        WHERE SalesOrder__c = :sr.SalesOrder__c
        AND Id != :serviceRequestId
        AND RecordType.DeveloperName = 'Service_Request_Management_ADM'
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    if(!relatedSRs.isEmpty()){
        result.hasADM = true;
        result.status = relatedSRs[0].Status__c;
        result.recordId = relatedSRs[0].Id;
        result.name = relatedSRs[0].Name;
    }

    return result;
}
    
    public class DirectDebitResult {
    @AuraEnabled public Boolean hasDirectDebit;
    @AuraEnabled public Boolean isActive;
    @AuraEnabled public String name;
    @AuraEnabled public Id recordId;
}

@AuraEnabled(cacheable=true)
public static DirectDebitResult checkDirectDebitStatus(Id serviceRequestId) {

    DirectDebitResult result = new DirectDebitResult();
    result.hasDirectDebit = false;
    result.isActive = false;

    if(serviceRequestId == null){
        return result;
    }

    // Get SalesOrder from Service Request
    ServiceRequest__c sr = [
        SELECT Id, SalesOrder__c
        FROM ServiceRequest__c
        WHERE Id = :serviceRequestId
        LIMIT 1
    ];

    if(sr.SalesOrder__c == null){
        return result;
    }

    // Fetch Direct Debit Requests
    List<DirectDebitRequest__c> ddList = [
        SELECT Id, Name, IsActive__c
        FROM DirectDebitRequest__c
        WHERE SalesOrder__c = :sr.SalesOrder__c
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    if(!ddList.isEmpty()){
        result.hasDirectDebit = true;
        result.isActive = ddList[0].IsActive__c;
        result.name = ddList[0].Name;
        result.recordId = ddList[0].Id;
    }

    return result;
}

public class BankDetailsResult {
    @AuraEnabled public Boolean hasData;
    @AuraEnabled public Id salesOrderId;
    @AuraEnabled public String salesOrderName;

    @AuraEnabled public String bankName;
    @AuraEnabled public String branchName;
    @AuraEnabled public String branchType;
    @AuraEnabled public String bankStatus;
    @AuraEnabled public String bankCountry;

    @AuraEnabled public String beneficiaryName;
    @AuraEnabled public String accountNumber;
    @AuraEnabled public String ibanNumber;
    @AuraEnabled public String ibanCountryCode;
    @AuraEnabled public String swiftCode;
}

@AuraEnabled(cacheable=true)
public static BankDetailsResult getBankDetails(Id serviceRequestId) {

    BankDetailsResult result = new BankDetailsResult();
    result.hasData = false;

    if(serviceRequestId == null){
        return result;
    }

    // Get SalesOrder + Account
    ServiceRequest__c sr = [
        SELECT Id, SalesOrder__c,
               SalesOrder__r.CustomerAccount__c
        FROM ServiceRequest__c
        WHERE Id = :serviceRequestId
        LIMIT 1
    ];

    if(sr.SalesOrder__c == null || sr.SalesOrder__r.CustomerAccount__c == null){
        return result;
    }

    // Fetch Account Bank Details
    Account acc = [
        SELECT Id, Name,
               Bank_Name__c,
               Bank_Branch_Name__c,
               Bank_Branch_Type__c,
               Bank_Status__c,
               Bank_Country__c,
               Beneficiary_Name__c,
               Bank_Account_Number__c,
               IBAN_Number__c,
               IBAN_Country_Bank_Code__c,
               Swift_Code__c
        FROM Account
        WHERE Id = :sr.SalesOrder__r.CustomerAccount__c
        LIMIT 1
    ];

    // Check if any data exists
    if(
        acc.Bank_Name__c != null ||
        acc.Bank_Account_Number__c != null ||
        acc.IBAN_Number__c != null
    ){
        result.hasData = true;
    }

    result.salesOrderId = acc.Id; // (optional: rename later if needed)
    result.salesOrderName = acc.Name;

    result.bankName = acc.Bank_Name__c;
    result.branchName = acc.Bank_Branch_Name__c;
    result.branchType = acc.Bank_Branch_Type__c;
    result.bankStatus = acc.Bank_Status__c;
    result.bankCountry = acc.Bank_Country__c;

    result.beneficiaryName = acc.Beneficiary_Name__c;
    result.accountNumber = acc.Bank_Account_Number__c;
    result.ibanNumber = acc.IBAN_Number__c;
    result.ibanCountryCode = acc.IBAN_Country_Bank_Code__c;
    result.swiftCode = acc.Swift_Code__c;

    return result;
}
    
    @AuraEnabled
    public static void assignTasks(Id recordId) {
        if(recordId == null) {
            throw new AuraHandledException('Record Id is required');
        }

       
        List<Task> tasksToUpdate = [
            SELECT Id, OwnerId,Status
            FROM Task
            WHERE WhatId = :recordId AND status != 'Closed']; // V2.0

        if(tasksToUpdate.isEmpty()) {
            return;
        }

        Id currentUserId = UserInfo.getUserId();

        for(Task t : tasksToUpdate) {
            t.OwnerId = currentUserId;
        }

        update tasksToUpdate;
    }

}