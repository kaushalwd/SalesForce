Global with sharing class HandoverMilestoneService {

    Global class HandoverMilestone {
        @AuraEnabled public Id businessProcessId;
        @AuraEnabled public Id unitId;
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public Id handoverDetailsId;
        @AuraEnabled public List<HandoverMilestoneSection> sections;

        Global HandoverMilestone() {
            sections = new List<HandoverMilestoneSection>();
        }
    }

    Global class HandoverMilestoneSection {
        @AuraEnabled public String sectionName;
        @AuraEnabled public Integer sectionOrder;
        @AuraEnabled public Boolean sectionActivated;
        @AuraEnabled public Id documentId;
    }

    @AuraEnabled(cacheable=true)
    public static HandoverMilestone getHandoverMilestoneByUnit(Id unitId) {
        if (unitId == null) {
            throw new AuraHandledException('Unit Id is required.');
        }

        HandoverMilestone result = new HandoverMilestone();

        List<Business_Process__c> bpList = [
            SELECT Id, Unit__c, Sales_Order__c, Handover_Details__c
            FROM Business_Process__c
            WHERE Unit__c = :unitId
            AND Type__c = 'Handover Units'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (bpList.isEmpty()) {
            return result;
        }

        Business_Process__c bp = bpList[0];

        result.businessProcessId = bp.Id;
        result.unitId = bp.Unit__c;
        result.salesOrderId = bp.Sales_Order__c;
        result.handoverDetailsId = bp.Handover_Details__c;

        Handover_Details__c hd;

        List<Handover_Details__c> hdList = [
            SELECT Id,
                   Business_Process__c,
                   Is_Bcc_Letter_Sent__c,
                   Handover_Phasing_Letter_Sent__c,
                   Home_Orientation_Letter_Date_Sent__c,
                   Customer_Attended_Snagging__c,
                   Customer_Attended_Desnagging__c
            FROM Handover_Details__c
            WHERE Business_Process__c = :bp.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!hdList.isEmpty()) {
            hd = hdList[0];
        }

        Set<String> requiredDocumentNames = new Set<String>{
            'BCC Letter',
            'Handover Phasing Letter',
            'Home Orientation Letter',
            'Customer Snagging Letter',
            'Customer De Snagging Letter (RFO)',
            'Title Deed Copy',
            'Unified Handover Document'
        };

        Map<Id, String> contentDocumentIdToDocName = new Map<Id, String>();

        for (Business_Process_Documents__c doc : [
            SELECT Id, Name,
                   (
                       SELECT Id, ContentDocumentId
                       FROM ContentDocumentLinks
                   )
            FROM Business_Process_Documents__c
            WHERE Business_Process__c = :bp.Id
            AND Name IN :requiredDocumentNames
        ]) {
            for (ContentDocumentLink cdl : doc.ContentDocumentLinks) {
                contentDocumentIdToDocName.put(cdl.ContentDocumentId, doc.Name);
            }
        }

        Map<String, Id> documentNameToLatestContentDocumentId = new Map<String, Id>();

        if (!contentDocumentIdToDocName.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId, CreatedDate
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocumentIdToDocName.keySet()
                AND IsLatest = true
                ORDER BY CreatedDate DESC
            ]) {
                String docName = contentDocumentIdToDocName.get(cv.ContentDocumentId);

                if (!documentNameToLatestContentDocumentId.containsKey(docName)) {
                    documentNameToLatestContentDocumentId.put(docName, cv.ContentDocumentId);
                }
            }
        }

        result.sections.add(
            buildSection(
                'BCC',
                1,
                hd != null && hd.Is_Bcc_Letter_Sent__c,
                documentNameToLatestContentDocumentId.get('BCC Letter')
            )
        );

        result.sections.add(
            buildSection(
                'Handover Phasing',
                2,
                hd != null && hd.Handover_Phasing_Letter_Sent__c,
                documentNameToLatestContentDocumentId.get('Handover Phasing Letter')
            )
        );

        result.sections.add(
            buildSection(
                'Home Orientation',
                3,
                hd != null && hd.Home_Orientation_Letter_Date_Sent__c != null,
                documentNameToLatestContentDocumentId.get('Home Orientation Letter')
            )
        );

        result.sections.add(
            buildSection(
                'Snagging',
                4,
                hd != null && hd.Customer_Attended_Snagging__c,
                documentNameToLatestContentDocumentId.get('Customer Snagging Letter')
            )
        );

        result.sections.add(
            buildSection(
                'De Snagging',
                5,
                hd != null && hd.Customer_Attended_Desnagging__c,
                documentNameToLatestContentDocumentId.get('Customer De Snagging Letter (RFO)')
            )
        );

        result.sections.add(
            buildSection(
                'Title Deed',
                6,
                documentNameToLatestContentDocumentId.containsKey('Title Deed Copy'),
                documentNameToLatestContentDocumentId.get('Title Deed Copy')
            )
        );

        result.sections.add(
            buildSection(
                'Handover Document',
                7,
                documentNameToLatestContentDocumentId.containsKey('Unified Handover Document'),
                documentNameToLatestContentDocumentId.get('Unified Handover Document')
            )
        );

        return result;
    }

    private static HandoverMilestoneSection buildSection(
        String name,
        Integer order,
        Boolean activated,
        Id documentId
    ) {
        HandoverMilestoneSection sec = new HandoverMilestoneSection();
        sec.sectionName = name;
        sec.sectionOrder = order;
        sec.sectionActivated = activated;
        sec.documentId = activated ? documentId : null;
        return sec;
    }
}