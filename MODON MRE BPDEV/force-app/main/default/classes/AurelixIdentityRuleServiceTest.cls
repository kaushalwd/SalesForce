/**
 * AurelixIdentityRuleServiceTest - the residency table and the state of one record.
 *
 * Version  Author       Date         Detail
 * 1.2      Aurelix Dev  27 Sep 2026  Service 1.2 (MODON's Lead rules): the table tests assert what is shown and what
 *                                    is owed (a Non-Resident's passport number only); the matrix owes only that,
 *                                    plus entered dates that are unusable; an expiry of today is usable; new
 *                                    residentOwesNothingAndNonResidentOwesOnlyThePassportNumber.
 * 1.1      Aurelix Dev  27 Sep 2026  Passport expiry is optional (service 1.1): a blank one carries no
 *                                    reason, an expired one still does. The matrix and the Contact reader
 *                                    expect that; passportExpiryIsOptionalButMustBeUsable proves both.
 * 1.0      Aurelix Dev  17 Sep 2026  MSC-174 (B2). The matrix the brief asks for - two residencies
 *                                    x Emirates ID present/absent x passport present/absent x
 *                                    valid/expired dates - runs against in-memory DTOs through the
 *                                    @TestVisible evaluate, because the org's own format rules
 *                                    would refuse to STORE the invalid shapes half the matrix is
 *                                    about. Two DML tests cover the Account and Contact readers.
 *                                    Real MODON classes throughout (CustomerKYCHandler for the
 *                                    Emirates ID shape); no stubs.
 */
@IsTest
private class AurelixIdentityRuleServiceTest {

    private static final String GOOD_EID = '784-1990-1234567-1';

    private static Database.DMLOptions dmlAllowingDuplicates() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        dml.DuplicateRuleHeader.runAsCurrentUser = true;
        return dml;
    }

    private static Id personAccountRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    /** A DTO the way stateFor would have filled it from a record, before evaluate ran. */
    private static AurelixIdentityRuleService.IdentityStateDTO dto(
        String residency, String eid, Date eidExpiry,
        String passport, Date passportIssue, Date passportExpiry
    ) {
        AurelixIdentityRuleService.IdentityStateDTO s =
            new AurelixIdentityRuleService.IdentityStateDTO();
        s.subject            = AurelixIdentityRuleService.SUBJECT_PERSON;
        s.residentStatus     = residency;
        s.eidNumber          = eid;
        s.eidExpiry          = eidExpiry;
        s.passportNumber     = passport;
        s.passportIssueDate  = passportIssue;
        s.passportExpiryDate = passportExpiry;
        s.needs              = AurelixIdentityRuleService.needsFor(residency);
        return s;
    }

    /* ------------------------------------------------------------------ *
     * THE TABLE
     * ------------------------------------------------------------------ */

    @IsTest
    static void residentNeedsEmiratesIdPairAndPassportThree() {
        SalesConsoleLeadController.IdentityNeedDTO n =
            AurelixIdentityRuleService.needsFor('Resident');
        System.assertEquals(true, n.eidNumber, 'Resident: Emirates ID number');
        System.assertEquals(true, n.eidExpiry, 'Resident: Emirates ID expiry');
        System.assertEquals(true, n.passportNumber, 'Resident: passport number - the 17 Sep decision');
        System.assertEquals(true, n.passportIssueDate, 'Resident: passport issue date');
        System.assertEquals(true, n.passportExpiryDate, 'Resident: passport expiry');
        /* 1.2 - shown, not owed */
        System.assertEquals(false, n.eidNumberRequired || n.eidExpiryRequired || n.passportNumberRequired
            || n.passportIssueDateRequired || n.passportExpiryDateRequired,
            'MODON\'s Lead rules owe a Resident nothing.');
    }

    @IsTest
    static void nonResidentNeedsPassportThreeAndNeverAnEmiratesId() {
        SalesConsoleLeadController.IdentityNeedDTO n =
            AurelixIdentityRuleService.needsFor('Non-Resident');
        System.assertEquals(false, n.eidNumber, 'A non-resident is never asked for an Emirates ID');
        System.assertEquals(false, n.eidExpiry, 'Nor its expiry');
        System.assertEquals(true, n.passportNumber, 'Non-Resident: passport number');
        System.assertEquals(true, n.passportIssueDate, 'Non-Resident: passport issue date');
        System.assertEquals(true, n.passportExpiryDate, 'Non-Resident: passport expiry');
        /* 1.2 - Passport_Number_Mandatory_Validation, the only one active */
        System.assertEquals(true, n.passportNumberRequired, 'The passport number is owed.');
        System.assertEquals(false, n.passportIssueDateRequired || n.passportExpiryDateRequired,
            'Its dates are not.');
    }

    @IsTest
    static void blankOrUnknownResidencyNeedsNothingYet() {
        for (String r : new List<String>{ null, '', '   ', 'Tourist' }) {
            SalesConsoleLeadController.IdentityNeedDTO n = AurelixIdentityRuleService.needsFor(r);
            System.assertEquals(false, n.eidNumber || n.eidExpiry || n.passportNumber
                || n.passportIssueDate || n.passportExpiryDate,
                'Residency "' + r + '" must require nothing - it is asked first.');
        }
    }

    @IsTest
    static void tableIsCaseAndWhitespaceTolerant() {
        System.assertEquals(true, AurelixIdentityRuleService.needsFor(' resident ').eidNumber);
        System.assertEquals(true, AurelixIdentityRuleService.needsFor('NON-RESIDENT').passportNumber);
        System.assertEquals(false, AurelixIdentityRuleService.needsFor('NON-RESIDENT').eidNumber);
    }

    /* ------------------------------------------------------------------ *
     * THE MATRIX - residency x EID present/absent x passport present/absent x dates valid/expired
     * ------------------------------------------------------------------ */

    @IsTest
    static void matrixResidencyByEidByPassportByDates() {
        Date valid   = Date.today().addYears(3);
        Date expired = Date.today().addDays(-1);
        Date issued  = Date.today().addYears(-2);
        Integer cases = 0;

        for (String residency : new List<String>{ 'Resident', 'Non-Resident' }) {
            for (Boolean hasEid : new List<Boolean>{ true, false }) {
                for (Boolean hasPassport : new List<Boolean>{ true, false }) {
                    for (Boolean datesValid : new List<Boolean>{ true, false }) {
                        cases++;
                        Date expiry = datesValid ? valid : expired;
                        AurelixIdentityRuleService.IdentityStateDTO s = dto(
                            residency,
                            hasEid ? GOOD_EID : null, hasEid ? expiry : null,
                            hasPassport ? 'P1234567' : null,
                            hasPassport ? issued : null, hasPassport ? expiry : null);
                        AurelixIdentityRuleService.evaluate(s);

                        Boolean resident = residency == 'Resident';
                        /* 1.2 - owed: a Non-Resident's passport number; refused: an entered expiry
                           that has passed (the EID pair is only read for a Resident) */
                        Boolean enteredExpired = !datesValid && ((resident && hasEid) || hasPassport);
                        Boolean expectComplete = (resident || hasPassport) && !enteredExpired;
                        String tag = residency + ' eid=' + hasEid + ' passport=' + hasPassport
                            + ' datesValid=' + datesValid;

                        System.assertEquals(expectComplete, s.complete, 'complete: ' + tag
                            + ' missing=' + s.missing);
                        System.assertEquals(expectComplete, s.missing.isEmpty(),
                            'missing list agrees with complete: ' + tag);

                        if (resident) {
                            System.assertEquals(null, s.eidNumberReason,
                                'eidNumberReason (not owed; GOOD_EID when entered): ' + tag);
                            System.assertEquals(!hasEid ? null : (datesValid ? null : 'expired'),
                                s.eidExpiryReason, 'eidExpiryReason: ' + tag);
                        } else {
                            System.assertEquals(null, s.eidNumberReason,
                                'A non-resident never carries an Emirates ID reason: ' + tag);
                            System.assertEquals(null, s.eidExpiryReason,
                                'nor an Emirates ID expiry reason: ' + tag);
                        }
                        /* 1.1: blank is not owed; expired still is */
                        System.assertEquals(hasPassport && !datesValid ? 'expired' : null,
                            s.passportExpiryReason, 'passportExpiryReason: ' + tag);
                        System.assertEquals(null,
                            s.passportIssueReason, 'passportIssueReason (not owed; issued in the past): ' + tag);
                    }
                }
            }
        }
        System.assertEquals(16, cases, 'The full matrix ran.');
    }

    @IsTest
    static void passportIssueDateInTheFutureIsReported() {
        AurelixIdentityRuleService.IdentityStateDTO s = dto(
            'Non-Resident', null, null, 'P1234567', Date.today().addDays(1), Date.today().addYears(2));
        AurelixIdentityRuleService.evaluate(s);
        System.assertEquals('future', s.passportIssueReason);
        System.assertEquals(false, s.complete);
        System.assertEquals(1, s.missing.size(), 'Only the issue date is owed: ' + s.missing);
    }

    @IsTest
    static void emiratesIdShapeIsCheckedWithModonsOwnRule() {
        AurelixIdentityRuleService.IdentityStateDTO s = dto(
            'Resident', '12345', Date.today().addYears(2),
            'P1234567', Date.today().addYears(-1), Date.today().addYears(2));
        AurelixIdentityRuleService.evaluate(s);
        System.assertEquals('format', s.eidNumberReason,
            'Present but not 784-YYYY-NNNNNNN-C: CustomerKYCHandler.isValidEmiratesId says no.');
        System.assertEquals(false, s.complete);

        AurelixIdentityRuleService.IdentityStateDTO ok = dto(
            'Resident', GOOD_EID, Date.today().addYears(2),
            'P1234567', Date.today().addYears(-1), Date.today().addYears(2));
        AurelixIdentityRuleService.evaluate(ok);
        System.assertEquals(null, ok.eidNumberReason);
        System.assertEquals(true, ok.complete, 'A complete resident: ' + ok.missing);
    }

    @IsTest
    static void blankResidencyIsItselfAGap() {
        AurelixIdentityRuleService.IdentityStateDTO s = dto(null, GOOD_EID, Date.today().addYears(2),
            'P1234567', Date.today().addYears(-1), Date.today().addYears(2));
        AurelixIdentityRuleService.evaluate(s);
        System.assertEquals(false, s.complete);
        System.assertEquals(1, s.missing.size(), 'Only residency is owed: ' + s.missing);
        System.assertEquals(AurelixIdentityRuleService.fieldLabel('Account', 'UAE_Resident_Status__pc'),
            s.missing[0]);
    }

    @IsTest
    static void dateHelpersKeepTheLeadControllersSemantics() {
        /* 1.2 - MODON's "< TODAY()" rules accept today */
        System.assertEquals(true, AurelixIdentityRuleService.usableExpiry(Date.today()),
            'Expiring today is usable, as MODON\'s rules accept it.');
        System.assertEquals(false, AurelixIdentityRuleService.usableExpiry(Date.today().addDays(-1)));
        System.assertEquals(true, AurelixIdentityRuleService.usableExpiry(Date.today().addDays(1)));
        System.assertEquals(false, AurelixIdentityRuleService.usableExpiry(null));
        System.assertEquals(true, AurelixIdentityRuleService.usableIssue(Date.today()),
            'Issued today is fine - not in the future.');
        System.assertEquals(false, AurelixIdentityRuleService.usableIssue(Date.today().addDays(1)));
        System.assertEquals(false, AurelixIdentityRuleService.usableIssue(null));
    }

    @IsTest
    static void fieldLabelFallsBackToTheApiName() {
        System.assertEquals('No_Such_Field__c',
            AurelixIdentityRuleService.fieldLabel('Account', 'No_Such_Field__c'));
        System.assertEquals('X', AurelixIdentityRuleService.fieldLabel('No_Such_Object__c', 'X'));
        System.assertNotEquals('PassportNumber__pc',
            AurelixIdentityRuleService.fieldLabel('Account', 'PassportNumber__pc'),
            'A real field returns its Setup label.');
    }

    /* ------------------------------------------------------------------ *
     * THE READERS - one person Account, one Contact, one company
     * ------------------------------------------------------------------ */

    @IsTest
    static void stateForReadsAPersonAccountOnItsPcFields() {
        Id prt = personAccountRecordTypeId();
        if (prt == null) { return; } // person accounts unavailable: nothing to prove here
        Database.DMLOptions dml = dmlAllowingDuplicates();

        Account person = new Account(FirstName = 'Aurelix', LastName = 'Identity Person',
            RecordTypeId = prt);
        Database.insert(person, dml);
        Account fill = new Account(Id = person.Id,
            UAE_Resident_Status__pc = 'Resident', Nationality__pc = 'India',
            EIDNumber__pc = GOOD_EID, EmiratesIDExpiryDate__pc = Date.today().addYears(2),
            PassportNumber__pc = 'P7654321',
            PassportIssueDate__pc = Date.today().addYears(-1),
            PassportExpiryDate__pc = Date.today().addYears(4));
        Database.update(fill, dml);

        Test.startTest();
        AurelixIdentityRuleService.IdentityStateDTO s = AurelixIdentityRuleService.stateFor(person.Id);
        Test.stopTest();

        System.assertEquals(AurelixIdentityRuleService.SUBJECT_PERSON, s.subject);
        System.assertEquals('Resident', s.residentStatus);
        System.assertEquals(GOOD_EID, s.eidNumber);
        System.assertEquals('P7654321', s.passportNumber);
        System.assertEquals(true, s.needs.passportNumber, 'A resident is shown the passport.');
        System.assertEquals(true, s.complete, 'Everything on file: ' + s.missing);
    }

    @IsTest
    static void stateForReadsAContactOnItsOwnFieldsAndListsWhatIsOwed() {
        Database.DMLOptions dml = dmlAllowingDuplicates();
        Account company = new Account(Name = 'Aurelix Identity Co');
        Database.insert(company, dml);
        Contact poa = new Contact(FirstName = 'Aurelix', LastName = 'Signatory',
            AccountId = company.Id, UAE_Resident_Status__c = 'Non-Resident',
            PassportNumber__c = 'P1111111');
        Database.insert(poa, dml);

        Test.startTest();
        AurelixIdentityRuleService.IdentityStateDTO s = AurelixIdentityRuleService.stateFor(poa.Id);
        AurelixIdentityRuleService.IdentityStateDTO co = AurelixIdentityRuleService.stateFor(company.Id);
        Test.stopTest();

        System.assertEquals(AurelixIdentityRuleService.SUBJECT_CONTACT, s.subject);
        System.assertEquals(false, s.needs.eidNumber, 'Non-resident signatory: no Emirates ID asked.');
        /* 1.2 - the passport number is all MODON owes a Non-Resident */
        System.assertEquals(true, s.complete, 'The passport number is on file: ' + s.missing);
        System.assertEquals(null, s.passportIssueReason, 'The issue date is not owed.');
        System.assertEquals(null, s.passportExpiryReason);
        System.assertEquals(0, s.missing.size(), s.missing + '');

        System.assertEquals(AurelixIdentityRuleService.SUBJECT_COMPANY, co.subject,
            'A company carries no identity of its own.');
        System.assertEquals(false, co.complete);
        System.assertEquals(0, co.missing.size(), 'And invents no requirement for it.');
    }

    /* 1.1 */
    @IsTest
    static void passportExpiryIsOptionalButMustBeUsable() {
        Date issued = Date.today().addYears(-2);

        AurelixIdentityRuleService.IdentityStateDTO blank =
            dto('Non-Resident', null, null, 'P1234567', issued, null);
        AurelixIdentityRuleService.evaluate(blank);
        System.assertEquals(null, blank.passportExpiryReason, 'A blank expiry is not owed.');
        System.assertEquals(true, blank.complete, 'Number and issue date are enough: ' + blank.missing);

        /* 1.2 - today is usable; yesterday is not */
        AurelixIdentityRuleService.IdentityStateDTO today =
            dto('Non-Resident', null, null, 'P1234567', issued, Date.today());
        AurelixIdentityRuleService.evaluate(today);
        System.assertEquals(null, today.passportExpiryReason, 'Expiring today is accepted.');

        AurelixIdentityRuleService.IdentityStateDTO expired =
            dto('Non-Resident', null, null, 'P1234567', issued, Date.today().addDays(-1));
        AurelixIdentityRuleService.evaluate(expired);
        System.assertEquals('expired', expired.passportExpiryReason,
            'An entered expiry must be after today.');
        System.assertEquals(false, expired.complete);
        System.assertEquals(1, expired.missing.size(), expired.missing + '');
    }

    /* 1.2 */
    @IsTest
    static void residentOwesNothingAndNonResidentOwesOnlyThePassportNumber() {
        AurelixIdentityRuleService.IdentityStateDTO resident = dto('Resident', null, null, null, null, null);
        AurelixIdentityRuleService.evaluate(resident);
        System.assertEquals(true, resident.complete, 'A Resident with nothing entered: ' + resident.missing);

        AurelixIdentityRuleService.IdentityStateDTO nonResident = dto('Non-Resident', null, null, null, null, null);
        AurelixIdentityRuleService.evaluate(nonResident);
        System.assertEquals(false, nonResident.complete);
        System.assertEquals(1, nonResident.missing.size(), 'Only the passport number: ' + nonResident.missing);
    }

    @IsTest
    static void stateForWithNoIdOrAForeignIdIsEmptyNotAnError() {
        AurelixIdentityRuleService.IdentityStateDTO none = AurelixIdentityRuleService.stateFor(null);
        System.assertEquals(false, none.complete);
        System.assertEquals(false, none.needs.eidNumber);

        Opportunity o = new Opportunity(Name = 'Not an identity subject',
            StageName = 'Unit Selection', CloseDate = Date.today().addDays(30));
        insert o;
        AurelixIdentityRuleService.IdentityStateDTO other = AurelixIdentityRuleService.stateFor(o.Id);
        System.assertEquals(false, other.complete);
        System.assertEquals(null, other.subject);
    }
}