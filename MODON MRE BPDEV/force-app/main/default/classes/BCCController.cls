public without sharing class BCCController {
    
    @AuraEnabled
    public static List<Unit__c> getUnits(String phaseId) {
        return [SELECT Id, Name, Type__c, Status__c, Phase__c, Phase__r.Name
                FROM Unit__c
                WHERE Phase__c = :phaseId
                AND Id IN (SELECT Unit__c FROM SalesOrder__c WHERE Unit__r.Phase__c = :phaseId AND Status__c = 'Completed')
                ORDER BY Name];
    }
    
    @AuraEnabled
    public static String sendBCCLetter(List<Id> unitIds) {
        try {
            Database.executeBatch(new SendBCCLetterBatch(unitIds), 1);
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static void createBusinessProcess(Id soId) {
        
        Process_Flow__c pf = [SELECT Id 
                              FROM Process_Flow__c 
                              WHERE Process_Flow_Unique_Name__c = 'Handover Units'
                              AND Active__c = true LIMIT 1] ?? null;
        
        if (pf == null) return;
        
        String bpId = CreateBusinessProcess.createPreRegistration(soId, pf.Id);
        
        try {
            Id.valueOf(bpId);
        } catch (Exception ex) {
            return;
        }
        
        SalesOrder__c so = [SELECT Id, Name, Unit__c, Unit__r.Phase__c
                            FROM SalesOrder__c
                            WHERE Id = :soId
                            LIMIT 1] ?? null;
        
        if (so == null) return;
        
        Handover_Details__c hod = new Handover_Details__c(
            Name = 'HOD - ' + so.Name,
            Business_Process__c = bpId,
            Is_Bcc_Letter_Sent__c = true,
            Bcc_Letter_Sent_Date__c = Date.today()
        );
        insert hod;
        
        update new Business_Process__c(Id = bpId, Handover_Details__c = hod.Id);
        
        Business_Process_Documents__c bpd = [SELECT Id
                                             FROM Business_Process_Documents__c
                                             WHERE Business_Process__c = :bpId
                                             AND Name = 'BCC Letter' LIMIT 1] ?? null;
        if (bpd == null) return;
        
        ContentDocumentLink cdl = [SELECT ContentDocumentId
                                   FROM ContentDocumentLink
                                   WHERE LinkedEntityId = :so.Unit__r.Phase__c
                                   AND ContentDocument.Title LIKE '%BCC Letter%'
                                   ORDER BY ContentDocument.CreatedDate DESC LIMIT 1] ?? null;
        
        if (cdl == null) return;
        
        insert new ContentDocumentLink(
            ContentDocumentId = cdl.ContentDocumentId,
            LinkedEntityId = bpd.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        
        progressToNextStep(bpId);
    }
    
    public static void progressToNextStep (Id bpId) {
        
        Business_Process__c bp = [SELECT Current_Business_Process_Step__c,
                                  Current_Business_Process_Step__r.Sequence__c
                                  FROM Business_Process__c
                                  WHERE Id = :bpId LIMIT 1] ?? null;
        
        if (bp == null) return;
        
        Decimal nextSequence = bp.Current_Business_Process_Step__r.Sequence__c + 1;
        
        List<Business_Process_Step__c> steps = [SELECT Id, Sequence__c
                                                FROM Business_Process_Step__c
                                                WHERE Business_Process__c = :bpId
                                                AND (Id = :bp.Current_Business_Process_Step__c OR Sequence__c = :nextSequence)
                                                ORDER BY Sequence__c ASC
                                                LIMIT 2];
        
        for (Business_Process_Step__c step : steps) {
            if(step.Id == bp.Current_Business_Process_Step__c) {
                step.Status__c = 'Completed';
                 bp.Previous_Business_Process_Step__c = step.Id;
            } else {
                step.Status__c = 'Open';
                bp.Current_Business_Process_Step__c = step.Id;
            }
        }
        
        if (!steps.isEmpty()) {
            update steps;
            update bp;
        } 
    }
    
}