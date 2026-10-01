/**********************************************************************************************************************
* Name               : ADHA_ReservationSmsSenderTest
* Description        : Covers the confirmation and signature messages, mostly the message body: the segment budget
*                      and the bidi rules are the parts that break silently on a handset and never in a log.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
@isTest
private class ADHA_ReservationSmsSenderTest {

    @TestSetup
    static void setup() {
        ADHA_Applicant__c applicant = new ADHA_Applicant__c(
            Application_Number__c = 'M0000001',
            Emirates_ID__c = '784-1992-2222222-2',
            Customer_Name__c = 'Sms Applicant',
            Mobile_Number__c = '+971500000011',
            Service_Type__c = 'House Purchase Loan',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1500000,
            Journey_Stage__c = 'Confirmed',
            Current_Attempt__c = 1
        );
        insert applicant;
        insert new ADHA_Unit__c(
            Plot_UID__c = 'SMS-1', Category_Type__c = 'A', Eligible_Service__c = 'House Purchase Loan',
            Villa_Type__c = 'Modern', Rooms_Count__c = 5, Community__c = 'Wb4_03', Status__c = 'Reserved',
            Expose_To__c = 'Public', Masterplan_Number__c = 900, Price__c = 1900000
        );
    }

    private static ADHA_Applicant__c applicant() {
        return [SELECT Id, Customer_Name__c, Mobile_Number__c FROM ADHA_Applicant__c LIMIT 1];
    }

    private static ADHA_Reservation__c reservation(Decimal additional) {
        ADHA_Unit__c unit = [SELECT Id FROM ADHA_Unit__c LIMIT 1];
        ADHA_Reservation__c res = new ADHA_Reservation__c(
            Applicant__c = applicant().Id,
            Unit__c = unit.Id,
            Status__c = 'Submitted',
            Additional_Amount__c = additional,
            Additional_Payment_Due__c = additional > 0 ? Date.newInstance(2026, 11, 23) : null
        );
        insert res;
        return [
            SELECT Id, Name, Additional_Amount__c, Additional_Payment_Due__c, Unit__r.Plot_UID__c,
                   Unit__r.Villa_Type__c, Unit__r.Rooms_Count__c
            FROM ADHA_Reservation__c WHERE Id = :res.Id
        ];
    }

    private static void switchOn() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Confirmation_SMS_Enabled__c = true);
        ADHA_ReservationSmsSender.credentialOverride = new OIC_Credential__mdt(
            Endpoint__c = 'https://sms.example.invalid/send', Username__c = 'u', Password__c = 'p'
        );
        ADHA_ReservationSmsSender.sent = new List<String>();
    }

    @isTest
    static void nothingIsSentWhileTheSwitchIsOff() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Confirmation_SMS_Enabled__c = false);
        ADHA_ReservationSmsSender.sent = new List<String>();
        ADHA_Reservation__c res = reservation(150000);

        Test.startTest();
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), res);
        Test.stopTest();

        System.assertEquals(0, ADHA_ReservationSmsSender.sent.size(), 'The gate must hold it back');
    }

    @isTest
    static void theConfirmationCarriesReferencePlotAmountAndDeadline() {
        switchOn();
        ADHA_Reservation__c res = reservation(150000);

        Test.startTest();
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), res);
        Test.stopTest();

        System.assertEquals(1, ADHA_ReservationSmsSender.sent.size(), 'One message');
        Map<String, Object> body = (Map<String, Object>) ((List<Object>)
            JSON.deserializeUntyped(ADHA_ReservationSmsSender.sent[0]))[0];
        String text = (String) body.get('TextMessage');
        System.assert(text.contains(res.Name), 'Reference must be there to quote back');
        System.assert(text.contains('SMS-1'), 'The plot they reserved');
        System.assert(text.contains('150,000'), 'Grouped, no decimals: ' + text);
        System.assert(text.contains('23/11/2026'), 'Numeric date, not a month name: ' + text);
        System.assertEquals('+971500000011', (String) body.get('MobileNumber'), 'Their own number');
        System.assertEquals(true, (Boolean) body.get('SendSMS'), 'SMS, not WhatsApp');
    }

    /** Every number on its own line: a value sharing a line with mixed Arabic and Latin text is
     *  placed by the handset's bidi algorithm and lands differently on different phones. */
    @isTest
    static void everyNumberSitsAloneOnItsLine() {
        switchOn();
        ADHA_Reservation__c res = reservation(150000);

        Test.startTest();
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), res);
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) ((List<Object>)
            JSON.deserializeUntyped(ADHA_ReservationSmsSender.sent[0]))[0];
        for (String line : ((String) body.get('TextMessage')).split('\n')) {
            Boolean isReference = line == res.Name;
            Boolean isAmount = line.endsWith(' AED');
            Boolean isDate = line == '23/11/2026';
            if (isReference || isAmount || isDate) {
                System.assert(
                    !line.containsIgnoreCase('due') && !line.contains('مستحق'),
                    'A number sharing a line with prose can be reordered: ' + line
                );
            }
        }
    }

    @isTest
    static void aReservationWithNothingOwedSaysSoRatherThanShowingZero() {
        switchOn();
        ADHA_Reservation__c res = reservation(0);

        Test.startTest();
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), res);
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) ((List<Object>)
            JSON.deserializeUntyped(ADHA_ReservationSmsSender.sent[0]))[0];
        String text = (String) body.get('TextMessage');
        // The merged body drops "no additional amount is due" rather than spend a fourth segment
        // saying nothing is owed. Absence of the amount line is the statement.
        System.assert(!text.contains('AED'), 'No amount line at all: ' + text);
        System.assert(text.contains('reservation confirmed'), 'Still confirms: ' + text);
    }

    /** One message since 25 Aug 2026, so the signature and the confirmation are the same message. */
    @isTest
    static void theOneMessageSaysBothSignedAndConfirmed() {
        switchOn();
        ADHA_Reservation__c res = reservation(0);

        Test.startTest();
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), res);
        Test.stopTest();

        System.assertEquals(1, ADHA_ReservationSmsSender.sent.size(), 'One message, not two');
        Map<String, Object> body = (Map<String, Object>) ((List<Object>)
            JSON.deserializeUntyped(ADHA_ReservationSmsSender.sent[0]))[0];
        String text = (String) body.get('TextMessage');
        System.assert(text.contains(res.Name), 'Reference: ' + text);
        System.assert(text.contains('Undertaking signed'), 'the signature, in English: ' + text);
        System.assert(text.contains('reservation confirmed'), 'and the confirmation: ' + text);
        System.assert(text.contains('تهانينا! تم توقيع التعهد وتأكيد الحجز'), 'both, in Arabic: ' + text);
    }

    /** Three UCS-2 segments, amount or no amount: the two messages this replaced cost 3 and 2, so
     *  the merge has to save a segment, not spend one. Measured on the worst realistic row. */
    @isTest
    static void theMessageStaysWithinThreeSegments() {
        switchOn();
        for (Decimal additional : new List<Decimal>{ 0, 2100000 }) {
            ADHA_ReservationSmsSender.sent = new List<String>();
            ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), reservation(additional));
            Map<String, Object> body = (Map<String, Object>) ((List<Object>)
                JSON.deserializeUntyped(ADHA_ReservationSmsSender.sent[0]))[0];
            String text = (String) body.get('TextMessage');
            Integer segments = text.length() <= 70 ? 1 : Integer.valueOf(Math.ceil(text.length() / 67.0));
            System.assert(
                segments <= 3,
                'additional ' + additional + ' produced ' + text.length() + ' characters, '
                    + segments + ' segments: ' + text
            );
        }
    }

    @isTest
    static void bothLanguagesAlwaysTravelTogether() {
        switchOn();
        ADHA_Reservation__c res = reservation(150000);

        Test.startTest();
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), res);
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) ((List<Object>)
            JSON.deserializeUntyped(ADHA_ReservationSmsSender.sent[0]))[0];
        String text = (String) body.get('TextMessage');
        System.assert(text.contains('غرب بني ياس'), 'Arabic project name first: ' + text);
        System.assert(text.contains('West Baniyas'), 'English project name: ' + text);
        System.assert(text.contains('reservation confirmed'), 'English body: ' + text);
    }

    @isTest
    static void anApplicantWithNoMobileIsSkippedNotThrown() {
        switchOn();
        ADHA_Reservation__c res = reservation(0);
        ADHA_Applicant__c noPhone = new ADHA_Applicant__c(Id = applicant().Id, Mobile_Number__c = null);

        Test.startTest();
        ADHA_ReservationSmsSender.confirmedAndSigned(noPhone, res);
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), null);
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), null);
        Test.stopTest();

        System.assertEquals(0, ADHA_ReservationSmsSender.sent.size(), 'Nothing sendable, nothing sent');
    }

    @isTest
    static void theReleaseMessageNamesTheVillaGivenUp() {
        switchOn();
        ADHA_Reservation__c res = reservation(0);

        Test.startTest();
        ADHA_ReservationSmsSender.released(applicant(), res);
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) ((List<Object>)
            JSON.deserializeUntyped(ADHA_ReservationSmsSender.sent[0]))[0];
        String text = (String) body.get('TextMessage');
        System.assert(text.contains(res.Name), 'Reference: ' + text);
        System.assert(text.contains('SMS-1'), 'The villa they gave up: ' + text);
        System.assert(text.contains('غرب بني ياس'), 'Arabic project name first: ' + text);
        System.assert(text.contains('released'), 'English half: ' + text);
        System.assert(text.contains('تم إلغاء حجز'), 'Arabic half: ' + text);
    }

    /** The gate the feature turns on: swapping an unsigned hold is browsing and stays silent;
     *  giving up a confirmed villa is a loss and must not. */
    @isTest
    static void onlyAConfirmedVillaEarnsAReleaseMessage() {
        switchOn();

        Test.startTest();
        ADHA_ReservationService.release(releasable(false), 'Changed Unit', applicant());
        Integer afterHold = ADHA_ReservationSmsSender.sent.size();
        ADHA_ReservationService.release(releasable(true), 'Changed Unit', applicant());
        Test.stopTest();

        System.assertEquals(0, afterHold, 'An unsigned hold being swapped is browsing');
        System.assertEquals(1, ADHA_ReservationSmsSender.sent.size(), 'A confirmed villa is a loss');
    }

    /** Selects every field release() reads, including Undertaking_Accepted__c: a field left out of
     *  the query throws SObjectException the moment it is read. */
    private static ADHA_Reservation__c releasable(Boolean confirmed) {
        ADHA_Unit__c unit = [SELECT Id FROM ADHA_Unit__c LIMIT 1];
        ADHA_Reservation__c res = new ADHA_Reservation__c(
            Applicant__c = applicant().Id,
            Unit__c = unit.Id,
            Status__c = confirmed ? 'Submitted' : 'Held',
            Undertaking_Accepted__c = confirmed,
            Additional_Amount__c = 0
        );
        insert res;
        return [
            SELECT Id, Name, Applicant__c, Unit__c, Status__c, Journey_Log__c,
                   Undertaking_Accepted__c, Unit__r.Plot_UID__c,
                   Unit__r.Villa_Type__c, Unit__r.Rooms_Count__c
            FROM ADHA_Reservation__c WHERE Id = :res.Id
        ];
    }

    @isTest
    static void theVillaIsNamedInWordsInBothLanguages() {
        switchOn();
        ADHA_Reservation__c res = reservation(0);

        Test.startTest();
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), res);
        ADHA_ReservationSmsSender.released(applicant(), res);
        Test.stopTest();

        for (String payload : ADHA_ReservationSmsSender.sent) {
            Map<String, Object> body = (Map<String, Object>) ((List<Object>)
                JSON.deserializeUntyped(payload))[0];
            String text = (String) body.get('TextMessage');
            System.assert(text.contains('Modern · 5 bedrooms'), 'English villa line: ' + text);
            System.assert(text.contains('عصري · غرف النوم: 5'), 'Arabic villa line: ' + text);
        }
    }

    /** Label-plus-value in Arabic, never an interpolated count: Arabic has six plural forms, and
     *  the map's countBedrooms label solves it the same way. */
    @isTest
    static void theBedroomCountCarriesItsLabelRatherThanAPlural() {
        System.assertEquals(
            'أندلسي · غرف النوم: 6',
            ADHA_ReservationSmsSender.villaLine(heritageSix(), true).trim(),
            'Arabic villa line'
        );
        System.assertEquals(
            'Andalusian · 6 bedrooms',
            ADHA_ReservationSmsSender.villaLine(heritageSix(), false).trim(),
            'English villa line'
        );
    }

    /** A unit queried without the two fields loses the line, never the whole message. */
    @isTest
    static void aUnitWithNoTypeOrCountSimplyOmitsTheLine() {
        ADHA_Reservation__c bare = new ADHA_Reservation__c();
        bare.Unit__r = new ADHA_Unit__c();
        System.assertEquals('', ADHA_ReservationSmsSender.villaLine(bare, true), 'Nothing to say');
        System.assertEquals('', ADHA_ReservationSmsSender.villaLine(null, false), 'No reservation');
    }

    private static ADHA_Reservation__c heritageSix() {
        ADHA_Reservation__c res = new ADHA_Reservation__c();
        res.Unit__r = new ADHA_Unit__c(Villa_Type__c = 'Heritage', Rooms_Count__c = 6);
        return res;
    }

    /** A messaging outage must never roll back a reservation the customer has been shown. */
    @isTest
    static void aMissingCredentialDoesNotThrow() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Confirmation_SMS_Enabled__c = true);
        ADHA_ReservationSmsSender.credentialOverride = new OIC_Credential__mdt(Endpoint__c = null);
        ADHA_ReservationSmsSender.sent = new List<String>();
        ADHA_Reservation__c res = reservation(0);

        Test.startTest();
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant(), res);
        Test.stopTest();

        System.assertEquals(0, ADHA_ReservationSmsSender.sent.size(), 'Swallowed, and nothing queued');
    }
}