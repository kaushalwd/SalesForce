/**********************************************************************************************************************
* Name               : CommissionLineReviewController                                                        
* Description        : This class is used to handle the External Commission Review & Approval by broker team
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           dinesh.selvam@modon.com             12/04/2026      Initial Draft
* 2.0           DSelvam                             20/04/2026      Added to show "Approved" commissionLines in the review screen
* 3.0           DSelvam                             28/04/2026      Added the filter to show all the external lines in the screen
**********************************************************************************************************************/
public with sharing class CommissionLineReviewController {
    public class PageResult {
        @AuraEnabled public List<Commission_Line__c> records;
        @AuraEnabled public Integer total;
        public PageResult(List<Commission_Line__c> records, Integer total) {
            this.records = records;
            this.total = total;
        }
    }

    @AuraEnabled
    public static PageResult fetchPage(Integer pageSize, Integer pageNumber, String status, String unitSearch) {
        if (pageSize == null || pageSize <= 0) pageSize = 10;
        if (pageNumber == null || pageNumber <= 0) pageNumber = 1;
    
        Integer offsetSize = (pageNumber - 1) * pageSize;
    
        // Status filter (only allow these two, default to Internal Review In-Progress) /** 3.0 Added all available status filter **/
       List<String> allowedStatuses = System.Label.CommissionExternalAllowedStatus.contains(',') ? System.Label.CommissionExternalAllowedStatus.split(',') : new List<String>{System.Label.CommissionExternalAllowedStatus};
       Set<String> targetStatus;

        if (status == 'All' || String.isBlank(status)) {
            targetStatus = new Set<String>(allowedStatuses); /** 3.0 Added all available status filter **/
        } else {
            targetStatus = new Set<String>{ status };
        }
    
        // Unit search (LIKE)
        String unitLike = null;
        if (!String.isBlank(unitSearch)) {
            unitLike = '%' + unitSearch.trim() + '%';
        }
    
        Integer totalCount;
        List<Commission_Line__c> rows;
    
        if (unitLike == null) {
            totalCount = [
                SELECT COUNT()
                FROM Commission_Line__c
                WHERE Status__c  IN:targetStatus
                AND Commission_Line_Type__c = 'External'
            ];
              rows = [
                    SELECT Id, Name, Status__c, CreatedDate, Unit__c, Down_Payment_Status__c, ADM_Fee_Status__c,
                           Compliance_Status__c, Total_Unit_Price__c, Commission_Amount__c, Is_PDC_Collected__c,SPADocumentId__c,
                           BrokerAgencyFRM__c, Booking_Date__c, Payment_Eligible_Date__c,Commission_Percent__c,SPA_Status__c
                    FROM Commission_Line__c
                    WHERE Status__c IN:targetStatus
                    AND Commission_Line_Type__c = 'External'
                    ORDER BY CreatedDate DESC
                    LIMIT :pageSize
                    OFFSET :offsetSize
                ]; 
        } else {
            totalCount = [
                SELECT COUNT()
                FROM Commission_Line__c
                WHERE Status__c IN:targetStatus
                AND Commission_Line_Type__c = 'External'
                AND Unit__c LIKE :unitLike
            ];
    
            rows = [
                SELECT Id, Name, Status__c, CreatedDate, Unit__c, Down_Payment_Status__c, ADM_Fee_Status__c,
                       Compliance_Status__c, Total_Unit_Price__c, Commission_Amount__c, Is_PDC_Collected__c,
                       BrokerAgencyFRM__c, Booking_Date__c, Payment_Eligible_Date__c
                FROM Commission_Line__c
                WHERE Status__c IN:targetStatus
                AND Commission_Line_Type__c = 'External'
                AND Unit__c LIKE :unitLike
                ORDER BY CreatedDate DESC
                LIMIT :pageSize
                OFFSET :offsetSize
            ];
        }
    
        return new PageResult(rows, totalCount);
    }

    @AuraEnabled
    public static void approve(List<Id> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) return;
		List<Commission_Audit__c> cAuditList = new List<Commission_Audit__c>();
        List<Commission_Line__c> toUpdate = [
            SELECT Id, Status__c
            FROM Commission_Line__c
            WHERE Id IN :recordIds
        ];

        for (Commission_Line__c r : toUpdate) {
            // Only approve if it’s still in the target status (avoid race conditions)
            if (r.Status__c == 'Internal Review In-Progress') {
                r.Status__c = 'Ready To Process';
                r.Comments__c = '';
                // Optional audit fields:
                // r.Approved_By__c = UserInfo.getUserId();
                // r.Approved_On__c = System.now();
            }
        }

        // Optional: enforce FLS (recommended in strict orgs)
       // SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, toUpdate);
        update toUpdate;
        if(!cAuditList.isEmpty()){
            insert cAuditList;
        }
    }

    @AuraEnabled
    public static void reject(Id recordId, String reason) {
        if (recordId == null) return;

        Commission_Line__c r = [
            SELECT Id, Status__c
            FROM Commission_Line__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (r.Status__c != 'Internal Review In-Progress') return;

        r.Status__c = 'Rejected';
        r.Comments__c = reason;
        // Optional fields:
        // r.Rejection_Reason__c = reason;
        // r.Rejected_By__c = UserInfo.getUserId();
        // r.Rejected_On__c = System.now();
        update r;
        //SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<Commission_Line__c>{ r });
        //update decision.getRecords();
    }
    public static Commission_Audit__c createCommissionAudit(Id commissionLineId,String status,Id userId,String comments,String PreviousSts){
        Commission_Audit__c cAudit = new Commission_Audit__c();
        cAudit.Commission_Line__c = commissionLineId;
        cAudit.Status__c = status;
        cAudit.Approve_Reject_By__c = userId;
        cAudit.Approval_Rejected_Date__c = System.today();
        cAudit.Comments__c = comments;
        cAudit.Previous_Status__c = PreviousSts;
        return cAudit;
    }
    public static void handleCommissionStsChange(List<Commission_Line__c> newList, Map<Id,Commission_Line__c> oldMap){
        List<Commission_Audit__c> cAuditList = new List<Commission_Audit__c>();
		for(Commission_Line__c cli: newList){
            Commission_Line__c oldData =  oldMap <> null ? oldMap.get(cli.Id) : null;
            if(cli.Status__c <> null && (oldData == null ||(oldData <> null && oldData.Status__c <> cli.Status__c))){
               cAuditList.add(createCommissionAudit(cli.Id,cli.Status__c,UserInfo.getUserId(),cli.Comments__c,oldData <> null ? oldData.Status__c :''));   
            }
        }
        if(!cAuditList.isEmpty()){
            insert cAuditList;
        }
    }
    @AuraEnabled
    public static void createExternalCommissions(Id recordId,decimal commissionPercent,String comments){ 
        Id soId = [SELECT Id,Sales_Order__c FROM Commission_Line__c WHERE Id=:recordId LIMIT 1].Sales_Order__c;
        List<SalesOrder__c> salesOrderList = [SELECT Id,ownerId,Down_Payment_Status__c,SPAStatus__c,ExternalCommissionPaidPercent__c FROM SalesOrder__c WHERE Id=:soId];
        if(recordId <> null){
           Commission_Line__c cli = new Commission_Line__c();
            cli.Id = recordId;
            cli.Comments__c = comments;
            update cli;
        }
        CommissionLogicHandler.createExternalCommissionsHelper(salesOrderList,recordId,commissionPercent,true);
    }
    public static void updateSPADocId(List<sObject> newList, Map<Id,sObject> oldMap){
        Set<Id> signedSpaId = new Set<Id>();
        for(Documents__c doc: (List<Documents__c>)newList){
            Documents__c oldData = oldMap <> null ? (Documents__c)oldMap.get(doc.Id) : null;
            if(doc.Name == 'Signed SPA (Modon)' && doc.Status__c == 'Uploaded' && (oldData == null ||(oldData <> null && oldData.Status__c <> doc.Status__c))){
               signedSpaId.add(doc.Id); 
            }
        }
        if(!signedSpaId.isEmpty()){
            Map<Id, Id> docToContentDocId = new Map<Id, Id>();
            Map<Id, Id> docToSOId = new Map<Id, Id>();
            for(Documents__c doc:[SELECT Id,SalesOrder__c FROM Documents__c WHERE Id IN:signedSpaId]){
                docToSOId.put(doc.SalesOrder__c,doc.Id);
            }
            for (ContentDocumentLink cdl : [
              SELECT LinkedEntityId, ContentDocumentId
              FROM ContentDocumentLink
              WHERE LinkedEntityId IN :signedSpaId
              ORDER BY SystemModstamp DESC
            ]) {
                docToContentDocId.put(cdl.LinkedEntityId,cdl.ContentDocumentId);
            }
            if(!docToSOId.isEmpty()){
                List<Commission_Line__c> commissionLineUpd = new List<Commission_Line__c>();
                for(Commission_Line__c com:[SELECT Id,Sales_Order__c
                FROM Commission_Line__c
                WHERE Sales_Order__c IN:docToSOId.keySet()
                AND Commission_Line_Type__c = 'External']){
                    if(docToContentDocId.containsKey(docToSOId.get(com.Sales_Order__c))){
                        Commission_Line__c comObj = new Commission_Line__c();
                        comObj.Id = com.Id;
                        comObj.SPADocumentId__c = docToContentDocId.get(docToSOId.get(com.Sales_Order__c));
                        commissionLineUpd.add(comObj);
                    }
                }
                if(!commissionLineUpd.isEmpty()){
                    update commissionLineUpd;
                }
            }
        }
    }
    /**3.0 Added the filter to show all the external lines in the screen**/
    @AuraEnabled(cacheable=true)
    public static List<String> getAllowedStatuses() {
        List<String> allowedStatuses = new List<String>();
    
        for (String statusVal : System.Label.CommissionExternalAllowedStatus.split(',')) {
            if (String.isNotBlank(statusVal)) {
                allowedStatuses.add(statusVal.trim());
            }
        }
    
        return allowedStatuses;
    }
}