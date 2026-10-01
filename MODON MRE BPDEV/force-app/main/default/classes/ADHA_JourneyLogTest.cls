/**********************************************************************************************************************
* Name               : ADHA_JourneyLogTest
* Description        : Covers the beneficiary audit trail. The point of most of these is the swallowing: this class
*                      exists to record what happened, and it must never be the reason a journey fails.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_JourneyLogTest {

    @TestSetup
    static void setup() {
        insert new ADHA_Applicant__c(
            Application_Number__c = 'L0000001',
            Emirates_ID__c = '784-1991-1111111-1',
            Customer_Name__c = 'Log Applicant',
            Mobile_Number__c = '+971500000009',
            Service_Type__c = 'House Purchase Loan',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1500000,
            Journey_Stage__c = 'Logged In',
            Current_Attempt__c = 1
        );
    }

    private static ADHA_Applicant__c applicant() {
        return [SELECT Id FROM ADHA_Applicant__c LIMIT 1];
    }

    @isTest
    static void aSingleEventLandsAgainstTheBeneficiary() {
        Id applicantId = applicant().Id;

        Test.startTest();
        ADHA_JourneyLog.log(applicantId, null, ADHA_JourneyLog.SIGNED_IN, 'Stage Logged In');
        Test.stopTest();

        List<Task> rows = [SELECT Subject, WhatId, Status, Description FROM Task WHERE WhatId = :applicantId];
        System.assertEquals(1, rows.size(), 'One event should write one task');
        System.assertEquals('Baniyas: Signed in', rows[0].Subject, 'Subject should be prefixed and readable');
        System.assertEquals('Completed', rows[0].Status, 'A journey event has already happened');
        System.assert(rows[0].Description.contains('Stage Logged In'), 'Detail should survive');
    }

    @isTest
    static void theReservationIsNamedInTheBody() {
        Id applicantId = applicant().Id;
        ADHA_Reservation__c res = new ADHA_Reservation__c(Applicant__c = applicantId, Status__c = 'Held');
        insert res;

        Test.startTest();
        ADHA_JourneyLog.log(applicantId, res.Id, ADHA_JourneyLog.VILLA_HELD, 'Villa WB4_03-99');
        Test.stopTest();

        Task row = [SELECT Description FROM Task WHERE WhatId = :applicantId LIMIT 1];
        System.assert(row.Description.contains('Villa WB4_03-99'), 'Detail should survive');
        System.assert(row.Description.contains(String.valueOf(res.Id)), 'Reservation should be traceable');
    }

    @isTest
    static void manyEventsCostOneStatement() {
        Id applicantId = applicant().Id;
        List<ADHA_JourneyLog.Entry> batch = new List<ADHA_JourneyLog.Entry>();
        for (Integer i = 0; i < 50; i++) {
            batch.add(new ADHA_JourneyLog.Entry(applicantId, null, ADHA_JourneyLog.SLA_EXPIRED, 'Row ' + i));
        }

        Test.startTest();
        Integer before = Limits.getDmlStatements();
        ADHA_JourneyLog.log(batch);
        Integer used = Limits.getDmlStatements() - before;
        Test.stopTest();

        System.assertEquals(1, used, 'A sweeper releasing 50 rows must not spend 50 statements');
        System.assertEquals(50, [SELECT COUNT() FROM Task WHERE WhatId = :applicantId], 'All rows should land');
    }

    @isTest
    static void anEntryWithoutABeneficiaryIsDroppedNotThrown() {
        Test.startTest();
        ADHA_JourneyLog.log(null, null, ADHA_JourneyLog.SIGNED_IN, 'orphan');
        ADHA_JourneyLog.log(applicant().Id, null, null, 'no event');
        ADHA_JourneyLog.log(new List<ADHA_JourneyLog.Entry>());
        ADHA_JourneyLog.log((List<ADHA_JourneyLog.Entry>) null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Task], 'Nothing writable, so nothing written');
    }

    /** The whole reason this class swallows: an unwritable audit row must not take the journey with it. */
    @isTest
    static void aRowTooLongToSaveDoesNotThrow() {
        Id applicantId = applicant().Id;
        String huge = 'x'.repeat(400);

        Test.startTest();
        ADHA_JourneyLog.log(applicantId, null, huge, huge.repeat(100));
        Test.stopTest();

        // Whether it saved is not the assertion. That it did not throw is.
        System.assert(true, 'Reached, so nothing propagated');
    }

    @isTest
    static void signingInWritesItsOwnTrail() {
        ADHA_Applicant__c app = [
            SELECT Id, Journey_Stage__c, Current_Attempt__c, First_Verified_Login__c
            FROM ADHA_Applicant__c LIMIT 1
        ];

        Test.startTest();
        ADHA_JourneyLog.log(app.Id, null, ADHA_JourneyLog.SIGNED_IN, 'Stage ' + app.Journey_Stage__c);
        Test.stopTest();

        System.assertEquals(
            1, [SELECT COUNT() FROM Task WHERE WhatId = :app.Id AND Subject = 'Baniyas: Signed in'],
            'Sign-in should be visible on the beneficiary'
        );
    }

    /** The villa has to land on the lookup, not just the description: a report can group on a
     *  lookup and not on a substring. */
    @isTest
    static void aVillaEventIsGroupableNotJustReadable() {
        Id applicantId = applicant().Id;
        ADHA_Unit__c unit = new ADHA_Unit__c(
            Plot_UID__c = 'LOG-1', Category_Type__c = 'A', Eligible_Service__c = 'House Grant',
            Villa_Type__c = 'Modern', Community__c = 'Wb4_03', Status__c = 'Available',
            Expose_To__c = 'Public', Masterplan_Number__c = 950, Price__c = 1800000
        );
        insert unit;

        Test.startTest();
        ADHA_JourneyLog.log(
            applicantId, null, unit.Id, ADHA_JourneyLog.VILLA_EXPLORED, 'Villa LOG-1'
        );
        Test.stopTest();

        Task row = [SELECT Subject, ADHA_Unit__c, Description FROM Task WHERE WhatId = :applicantId LIMIT 1];
        System.assertEquals('Baniyas: Villa explored', row.Subject, 'Readable in the timeline');
        System.assertEquals(unit.Id, row.ADHA_Unit__c, 'And groupable in a report');
        System.assert(row.Description.contains('LOG-1'), 'The plot still reads on the row itself');
    }

    /** Events that are not about a villa must leave the lookup alone rather than guessing. */
    @isTest
    static void anEventWithNoVillaLeavesTheLookupEmpty() {
        Id applicantId = applicant().Id;

        Test.startTest();
        ADHA_JourneyLog.log(applicantId, null, ADHA_JourneyLog.SIGNED_IN, 'Stage Logged In');
        Test.stopTest();

        System.assertEquals(
            null, [SELECT ADHA_Unit__c FROM Task WHERE WhatId = :applicantId LIMIT 1].ADHA_Unit__c,
            'Signing in is not about a villa'
        );
    }
}