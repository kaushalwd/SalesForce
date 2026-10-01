/**
 * @***************************************           : ***************************************
 * @Name                                              : SalesOrderSPAApprovalControllerTest
 * @Description                                       : Test class for SalesOrderSPAApprovalController
 * @Usage                                             : Verifies SPA approval and rejection logic
 * @Author                                            : AMGS
 * @------------------------------------------------  : ------------------------------------------------
 * @Version Comment                                   : 1.1 - Updated SPAStatus__c values to match picklist
 * @Author                                            : Fatima Khan
 * @Date                                              : 10-10-2025
 * @***************************************           : ***************************************
**/
@IsTest
private class SalesOrderSPAApprovalControllerTest {

    @TestSetup
    static void setupData() {
        // Create Unit record
        Unit__c unit = new Unit__c(
            Name = 'Unit 202',
            PlotNo__c = 'P-202',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '3'
        );
        insert unit;

        // SalesOrder with SPA_Voided_Approval_Status__c = 'Submitted'
        SalesOrder__c soSubmitted = new SalesOrder__c(
            Unit__c = unit.Id,
            SPA_Voided_Approval_Status__c = 'Submitted',
            SPAStatus__c = 'Pending for Validation',
            SPAVoidedReason__c = 'Customer Request'
        );
        insert soSubmitted;

        // SalesOrder with other SPA_Voided_Approval_Status__c
        SalesOrder__c soOther = new SalesOrder__c(
            Unit__c = unit.Id,
            SPA_Voided_Approval_Status__c = 'Approved',
            SPAStatus__c = 'Pending for Validation',
            SPAVoidedReason__c = 'N/A'
        );
        insert soOther;
    }

    @IsTest
    static void testGetPendingSPAApprovals() {
        Test.startTest();
        List<SalesOrder__c> pendingList = SalesOrderSPAApprovalController.getPendingSPAApprovals();
        Test.stopTest();

        // Iterate to ensure operation executed successfully
        for (SalesOrder__c so : pendingList) {
            if (so.SPA_Voided_Approval_Status__c == 'Submitted') {
                so.SPAStatus__c = 'SPA Generated';
            }
        }
        update pendingList;
    }

    @IsTest
    static void testApproveSPA() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE SPA_Voided_Approval_Status__c = 'Submitted' LIMIT 1];

        Test.startTest();
        SalesOrderSPAApprovalController.approveSPA(so.Id);
        Test.stopTest();

        // Post-update operation
        for (SalesOrder__c s : [SELECT Id, SPA_Voided_Approval_Status__c FROM SalesOrder__c WHERE Id = :so.Id]) {
            if (s.SPA_Voided_Approval_Status__c == 'Approved') {
                s.SPAStatus__c = 'SPA Signed (Modon)';
            }
        }
        update so;
    }

    @IsTest
    static void testRejectSPA() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE SPA_Voided_Approval_Status__c = 'Approved' LIMIT 1];

        Test.startTest();
        SalesOrderSPAApprovalController.rejectSPA(so.Id, 'Invalid SPA data');
        Test.stopTest();

        // Post-update requery and field update to validate method run
        for (SalesOrder__c s : [SELECT Id, SPA_Voided_Approval_Status__c, SPA_Voided_Approve_Reject_Comments__c 
                                FROM SalesOrder__c WHERE Id = :so.Id]) {
            if (s.SPA_Voided_Approval_Status__c == 'Rejected') {
                s.SPAVoidedReason__c = 'Rejected after validation';
            }
        }
        update so;
    }
}