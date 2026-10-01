@isTest
public class DocuSignEnvelopeStatusTriggerHelperTest {
    
    @testSetup
    static void setupTestData() {
        // Documents for nullifyDocumentEnvelopeId testing
        Documents__c doc1 = new Documents__c(Name = 'Reservation Form', EnvelopID__c = '12345');
        Documents__c doc2 = new Documents__c(Name = 'Broker Form', EnvelopID__c = '67890');
        
        
         List<SalesOrder__c> soList = new List<SalesOrder__c>{
            new SalesOrder__c(Status__c = 'In Progress'),
            new SalesOrder__c(Status__c = 'In Progress')
        };
        insert soList;
        
        // Create EnvelopeStatus records linked to Sales Orders
        List<dfsle__EnvelopeStatus__c> envelopeStatuses = new List<dfsle__EnvelopeStatus__c>{
            new dfsle__EnvelopeStatus__c(
                dfsle__SourceId__c = soList[0].Id,
                dfsle__Status__c = 'Sent',
                dfsle__Reason__c = 'Initial send'
            ),
            new dfsle__EnvelopeStatus__c(
                dfsle__SourceId__c = soList[1].Id,
                dfsle__Status__c = 'Completed',
                dfsle__Reason__c = 'All good'
            )
        };
        insert envelopeStatuses;
        system.debug('envelopeStatuses-->>'+envelopeStatuses);
        
        // Query the record again to be sure
dfsle__EnvelopeStatus__c envToUpdate = [
    SELECT Id, dfsle__Status__c
    FROM dfsle__EnvelopeStatus__c
    WHERE Id = :envelopeStatuses[0].Id
    LIMIT 1
];
        
        system.debug('envToUpdate-->>'+envToUpdate);
        
        envToUpdate.id = envelopeStatuses[0].Id;
        envToUpdate.dfsle__Status__c = 'voided';
        update envToUpdate;
        insert new List<Documents__c> { doc1, doc2 };

        dfsle__EnvelopeStatus__c envelopeStatus1 = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = doc1.Id,
            dfsle__Status__c = 'Sent'
        );
        dfsle__EnvelopeStatus__c envelopeStatus2 = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = doc2.Id,
            dfsle__Status__c = 'Voided'
        );
        
        insert new List<dfsle__EnvelopeStatus__c> { envelopeStatus1, envelopeStatus2 };
    }

    @isTest
    static void testUpdateSOSPAStatus() {
        // Fetch the test data
        List<dfsle__EnvelopeStatus__c> envelopeList = [
            SELECT Id, dfsle__SourceId__c, dfsle__Status__c, dfsle__Reason__c 
            FROM dfsle__EnvelopeStatus__c 
            WHERE dfsle__SourceId__c != null 
            LIMIT 2
        ];

        // Simulate update to trigger voided condition
        for (dfsle__EnvelopeStatus__c env : envelopeList) {
            env.dfsle__Status__c = 'Voided';
            env.dfsle__Reason__c = 'Customer canceled';
        }

        // Create old map (simulate old values before update)
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        for (dfsle__EnvelopeStatus__c env : envelopeList) {
            dfsle__EnvelopeStatus__c oldEnv = env.clone(false, true, false, false);
            oldEnv.dfsle__Status__c = 'Sent';
            oldEnv.dfsle__Reason__c = null;
            oldMap.put(env.Id, oldEnv);
        }

        Test.startTest();
        // Call the method manually since it's a helper (not a trigger)
        //DocuSignEnvelopeStatusTriggerHelper.hasRun = false; // Reset static flag
        DocuSignEnvelopeStatusTriggerHelper.updateSOSPAStatus(envelopeList, oldMap);
        Test.stopTest();

        // Validate that Sales Orders are updated properly
        List<SalesOrder__c> updatedSOs = [
            SELECT Id, SPAStatus__c, SPAVoidedReason__c, NumberofTimesSPAVoided__c 
            FROM SalesOrder__c
        ];

        System.assertNotEquals(0, updatedSOs.size(), 'Sales Orders should be updated');
        for (SalesOrder__c so : updatedSOs) {
            System.assertEquals('SPA Voided', so.SPAStatus__c, 'SPAStatus__c should be SPA Voided');
            System.assert(so.SPAVoidedReason__c.contains('Customer canceled'), 'Reason should include "Customer canceled"');
            //System.assertEquals(1, so.NumberofTimesSPAVoided__c, 'NumberofTimesSPAVoided__c should be incremented to 1');
        }

        // Verify recursion prevention (should skip execution)
//        Test.startTest();
        DocuSignEnvelopeStatusTriggerHelper.updateSOSPAStatus(envelopeList, oldMap);
//        Test.stopTest();
    }


    @isTest
    static void testNullifyDocumentEnvelopeId_ValidCase() {
        List<dfsle__EnvelopeStatus__c> newList = [SELECT Id, dfsle__SourceId__c, dfsle__Status__c FROM dfsle__EnvelopeStatus__c LIMIT 1];

        Map<Id, dfsle__EnvelopeStatus__c> oldMap = new Map<Id, dfsle__EnvelopeStatus__c>();
        for (dfsle__EnvelopeStatus__c envStatus : newList) {
            oldMap.put(envStatus.Id, new dfsle__EnvelopeStatus__c(
                Id = envStatus.Id,
                dfsle__SourceId__c = envStatus.dfsle__SourceId__c,
                dfsle__Status__c = 'Sent' 
            ));
        }

        Test.startTest();
        DocuSignEnvelopeStatusTriggerHelper.nullifyDocumentEnvelopeId(newList, oldMap);
        Test.stopTest();
    }

  


    
    
       @isTest
    static void testUpdateOfferRecordApproved() {
        // Create the master offer promotion
        OffersPromotions__c offerPromotion = new OffersPromotions__c(
            Name = 'Test1',
            OfferName__c = 'Test1',
            StartDate__c = System.today() + 1,
            EndDate__c = System.today() + 30,
            Approval_Status__c = 'Approved',
            SalesEventCampaignName__c = 'Test1'
        );
        insert offerPromotion;

        // Create and insert offer lines
        List<OfferLines__c> offerLines = new List<OfferLines__c>{
            new OfferLines__c(
                OfferName__c = offerPromotion.Id,
                OfferType__c = 'Waiver',
                OfferOn__c = 'ADM Fees',
                OfferValueType__c = '%',
                OfferValue__c = 1,
                Offer_Line_Approval_Status__c = 'Approved',
                Is_Default_Offer__c = true,
                IsActive__c = true
            ),
            new OfferLines__c(
                OfferName__c = offerPromotion.Id,
                OfferType__c = 'Waiver',
                OfferOn__c = 'ADM Fees',
                OfferValueType__c = '%',
                OfferValue__c = 1,
                Offer_Line_Approval_Status__c = 'Submitted',
                Is_Default_Offer__c = true,
                IsActive__c = true
            ),
            new OfferLines__c(
                OfferName__c = offerPromotion.Id,
                OfferType__c = 'Waiver',
                OfferOn__c = 'ADM Fees',
                OfferValueType__c = '%',
                OfferValue__c = 1,
                Offer_Line_Approval_Status__c = 'Rejected',
                Is_Default_Offer__c = true,
                IsActive__c = true
            )
        };
        insert offerLines;

        // Use variables for easy referencing
        OfferLines__c offerLine1 = offerLines[0];
        OfferLines__c offerLine2 = offerLines[1];
        OfferLines__c offerLine3 = offerLines[2];

        // Create envelope statuses
        dfsle__EnvelopeStatus__c env1 = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = offerLine1.Id,
            dfsle__Status__c = 'Completed'
        );
        dfsle__EnvelopeStatus__c env2 = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = offerLine2.Id,
            dfsle__Status__c = 'Sent'
        );
        dfsle__EnvelopeStatus__c env3 = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = offerLine3.Id,
            dfsle__Status__c = 'Voided'
        );
        insert new List<dfsle__EnvelopeStatus__c> { env1, env2, env3 };

        List<dfsle__EnvelopeStatus__c> newList = [
            SELECT Id, dfsle__SourceId__c, dfsle__Status__c 
            FROM dfsle__EnvelopeStatus__c 
            WHERE dfsle__SourceId__c IN :new List<Id>{offerLine1.Id, offerLine2.Id, offerLine3.Id}
        ];

        Test.startTest();
        DocuSignEnvelopeStatusTriggerHelper.updateOfferRecordApproved(newList, null);
        Test.stopTest();

        // Assert expected status updates
        List<OfferLines__c> updatedLines = [
            SELECT Id, Offer_Line_Approval_Status__c 
            FROM OfferLines__c 
            WHERE Id IN :new List<Id>{offerLine1.Id, offerLine2.Id, offerLine3.Id}
        ];

        Map<Id, String> expectedStatus = new Map<Id, String>{
            offerLine1.Id => 'Approved',
            offerLine2.Id => 'Submitted',
            offerLine3.Id => 'Rejected'
        };

        for (OfferLines__c line : updatedLines) {
            System.assertEquals(expectedStatus.get(line.Id), line.Offer_Line_Approval_Status__c, 'Incorrect status for Offer Line');
        }
    }
    
}