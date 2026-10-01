public with sharing class SalesOrderInteractionController {

    public class SalesOrderInteractionData {

    @AuraEnabled public SalesOrderWrapper salesOrder;
    @AuraEnabled public List<SOIWrapper> installments;
    @AuraEnabled public List<ReceiptWrapper> receipts;
    }

public class SalesOrderWrapper {   
    @AuraEnabled public Id id;
    @AuraEnabled public String name;
    @AuraEnabled public String project;
    @AuraEnabled public String status;
     @AuraEnabled public String phase;

        @AuraEnabled public String salesOrder;
    }

public class ReceiptWrapper {
    @AuraEnabled public Id receiptId;
    @AuraEnabled public String name;
    @AuraEnabled public String salesOrder;
    @AuraEnabled public String project;
    @AuraEnabled public String status;
    @AuraEnabled public String phase;
    @AuraEnabled public Decimal receiptAmount;
    @AuraEnabled Public String chargeSalesName;
    }

@AuraEnabled(cacheable=true)
public static SalesOrderInteractionData getInteractionData(Id salesOrderId) {

    SalesOrderInteractionData response =
        new SalesOrderInteractionData();

    SalesOrder__c so = [
        SELECT Id,
               Name,
               ProjectName__c,
               Unit__r.Phase__r.Name,
               Status__c
        FROM SalesOrder__c
        WHERE Id = :salesOrderId
        LIMIT 1
    ];

    SalesOrderWrapper soWrap = new SalesOrderWrapper();
    soWrap.id = so.Id;
    soWrap.name = so.Name;
    soWrap.project = so.ProjectName__c;
    soWrap.status = so.Status__c;
    soWrap.phase=so.Unit__r.Phase__r.Name;
    soWrap.salesOrder=so.Name;

    response.salesOrder = soWrap;

    response.installments = getInstallments(salesOrderId);

    response.receipts = new List<ReceiptWrapper>();

    for(Receipt__c rec : [
        SELECT Id,
               Name,
               ProjectName__c,
               Status__c,
               Receipt_Amount__c,
               SalesOrder__r.Name,
               Charge__r.Name,Charge__c,
               SalesOrder__r.Unit__r.Phase__r.Name,
               SalesOrderInstallment__c,SalesOrderInstallment__r.Name
        FROM Receipt__c
        WHERE SalesOrder__c = :salesOrderId
    ]){

        ReceiptWrapper rw = new ReceiptWrapper();

        rw.receiptId = rec.Id;
        rw.name = rec.Name;
        rw.salesOrder = rec.SalesOrder__r.Name;
        rw.project = rec.ProjectName__c;
        soWrap.phase=rec.SalesOrder__r.Unit__r.Phase__r.Name;
        rw.status = rec.Status__c;
        rw.receiptAmount = rec.Receipt_Amount__c;
        rw.chargeSalesName=rec.Charge__c !=null ? rec.Charge__r.Name :
                           rec.SalesOrderInstallment__c !=null ? rec.SalesOrderInstallment__r.Name :
                           'NA';

        response.receipts.add(rw);
    }


    return response;
}


    public class SOIWrapper {

        @AuraEnabled public Id soiId;

        @AuraEnabled public String name;

        @AuraEnabled public String milestoneNumber;

        @AuraEnabled public Date milestoneDate;

        @AuraEnabled public String paymentStatus;

        @AuraEnabled public Decimal amount;

        @AuraEnabled public String project;

        @AuraEnabled public String phase;

        @AuraEnabled public String salesOrder;
    }


    @AuraEnabled(cacheable=true)
    public static List<SOIWrapper> getInstallments(
        Id salesOrderId
    ) {

        List<SOIWrapper> result =
            new List<SOIWrapper>();

        for(SalesOrderInstallments__c soi : [

            SELECT
                Id,
                Name,
                MilestoneNumber__c,
                MilestoneDate__c,
                PaymentStatus__c,
                InstallmentAmount__c,

                SalesOrder__r.Name,
                SalesOrder__r.Unit__r.Name,
                SalesOrder__r.Unit__r.Phase__r.Name,
                SalesOrder__r.Unit__r.Phase__r.Project__r.Name

            FROM SalesOrderInstallments__c

            WHERE SalesOrder__c = :salesOrderId
        ]) {

            SOIWrapper w =
                new SOIWrapper();

            w.soiId = soi.Id;

            w.name = soi.Name;

            w.milestoneNumber =
                String.valueOf(
                    soi.MilestoneNumber__c
                );

            w.milestoneDate =
                soi.MilestoneDate__c;

            w.paymentStatus =
                soi.PaymentStatus__c;

            w.amount =
                soi.InstallmentAmount__c;

            w.project =
                soi.SalesOrder__r.Unit__r
                    .Phase__r.Project__r.Name;

            w.phase =
                soi.SalesOrder__r.Unit__r
                    .Phase__r.Name;

            w.salesOrder =
                soi.SalesOrder__r.Name;

            result.add(w);
        }

        return result;
    }



    @AuraEnabled
    public static void createInteractionCase(

        Id soiId,
        String recordType,
        String caseCategory,
        String modeOfCommunication,
        String comments,
        Boolean ftc
    ) {

       Id SalesId;
         Case cs = new Case();
    if(recordType == 'SalesOrder'){
        cs.Latest_Sales_Order__c  = soiId;
        SalesId=soiId;
    }
    else if(recordType == 'Receipt'){
       cs.Reciept__c = soiId;
       List<Receipt__c> rept=[Select Id, SalesOrder__c,Charge__r.Name,Charge__c,SalesOrderInstallment__c,SalesOrderInstallment__r.Name from Receipt__c where Id=:soiId and  SalesOrder__c!=null ];
       SalesId=rept[0].SalesOrder__c;
    }
    else{
        cs.Sales_Order_Installment__c = soiId;
        SalesOrderInstallments__c soId=[Select Id,  SalesOrder__c from SalesOrderInstallments__c where Id=:soiId ];
        SalesId=soId.SalesOrder__c;
    }

    //SalesOrderInstallments__c SOI=new SalesOrderInstallments__c();
    SalesOrder__c SOI=new SalesOrder__c();
     /*if(recordType!='SalesOrder' && recordType!='Receipt')
        SOI = [
            SELECT
                Id,
                Name,
                SalesOrder__c,
                SalesOrder__r.Unit__c,
                SalesOrder__r.CustomerAccount__c,
                SalesOrder__r.CustomerAccount__r.PersonEmail
            FROM SalesOrderInstallments__c
            WHERE Id = :soiId
            LIMIT 1
        ];*/
       SOI=[
        SELECT
                Id,
                Name,
                Unit__c,
                CustomerAccount__c,
                CustomerAccount__r.PersonEmail
            FROM SalesOrder__c
            WHERE Id = :salesId
            LIMIT 1
       ];

 
        cs.Subject ='Customer Interaction';
        cs.Status = 'New';
        cs.New_Owner__c=UserInfo.getUserId();
        cs.Description = 'Customer Interaction';
        cs.Case_Comments__c =comments;
        cs.Sub_Vertical__c='Default & Collection';
        //cs.CaseCategory__c ='Milestone Collection';
        cs.CaseCategory__c=caseCategory;
        //cs.Sales_Order_Installment__c = soiId;
        cs.Latest_Sales_Order__c  = salesId;
        cs.Send_Customer_Email__c =false;

        cs.Unit__c =
            SOI.Unit__c;

        cs.AccountId =SOI.CustomerAccount__c;

        cs.Customer_Type__c ='Owner';

        cs.Customer_Email__c =SOI.CustomerAccount__r.PersonEmail;
        cs.System_Generated_Case__c=true;

        Id standardRecType =
            Utility.getRecordTypeIdByDevName(
                Case.SObjectType,
                'Standard'
            );

        cs.RecordTypeId =
            standardRecType;

        cs.Source__c =
            'Internal';

        cs.Channel__c =
            'Social';

        cs.Origin = modeOfCommunication=='Calls' ? '800 Modon' :
            modeOfCommunication =='Email' ? 'Direct Email' :
			modeOfCommunication ==  'Messages' ? 'Social' : 'Walk In';

        insert cs;
        
		SalesOrderInstallments__c so=new SalesOrderInstallments__c();
		so.Latest_Interaction_Comments__c=comments;
        if(recordType!='SalesOrder' && recordType!='Receipt'){
		so.Id=soiId;
		update so;}
        if(ftc){
		cs.Status='Closed';
        cs.Sub_Status__c='Resolved';
		cs.Resolution_Comments__c=comments;
		cs.New_Owner__c=UserInfo.getUserId();
        }
        else 
        cs.Status='In Progress';
        if(!Test.isRunningTest())
		update cs;


    }

    @AuraEnabled(cacheable=true)
public static List<String> getCaseCategories() {

    String controllingValue = 'Default & Collection';

    List<String> result = new List<String>();

    Schema.DescribeFieldResult controllingDescribe =
        Case.Sub_Vertical__c.getDescribe();

    Schema.DescribeFieldResult dependentDescribe =
        Case.CaseCategory__c.getDescribe();

    List<Schema.PicklistEntry> controllingEntries =
        controllingDescribe.getPicklistValues();

    Integer controllingIndex = -1;

    for(Integer i = 0; i < controllingEntries.size(); i++) {

        if(controllingEntries[i].getValue() == controllingValue) {
            controllingIndex = i;
            break;
        }
    }

    if(controllingIndex == -1) {
        return result;
    }

    String base64Chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    for(Schema.PicklistEntry dependentEntry :
        dependentDescribe.getPicklistValues()) {

        Map<String,Object> entryMap =
            (Map<String,Object>)JSON.deserializeUntyped(
                JSON.serialize(dependentEntry)
            );

        String validFor =
            (String)entryMap.get('validFor');

        if(String.isBlank(validFor)) {
            continue;
        }

        Integer charIndex = controllingIndex / 6;
        Integer bitIndex = 5 - Math.mod(controllingIndex, 6);

        if(charIndex >= validFor.length()) {
            continue;
        }

        Integer decodedValue =
            base64Chars.indexOf(
                validFor.substring(charIndex, charIndex + 1)
            );

        if((decodedValue & (1 << bitIndex)) != 0) {
            result.add(dependentEntry.getValue());
        }
    }

    return result;
}
}