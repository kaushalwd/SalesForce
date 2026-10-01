/**
 * SalesConsoleController's copy of MODON's EOI booking gates (1.69), proved branch by branch.
 *
 * Version  Author       Date         Detail
 * 1.3      Aurelix Dev  22 Sep 2026  SalesConsoleController 1.73: sameBedrooms is the engine's number-only
 *                                    compare (UnitSearchLwcController.bedroomsMatch, v16.0), and
 *                                    receiptIsFree its v16.2 rule (no order, or a Cancelled or Voided
 *                                    one). Both proved on values; plus an EOI spelt "5 BR" passing Gate 2
 *                                    for a "5" unit. Previous version: _backup/2026-09-22_081155 (WL-019).
 * 1.2      Aurelix Dev  21 Sep 2026  SalesConsoleController 1.72: the EOI match is on bedrooms only
 *                                    (MODON's answer to open question 9). unit() no longer takes a
 *                                    typology, the refusal is "EOI Bedrooms Mismatch", and three new
 *                                    cases prove that an EOI whose typology differs but whose bedrooms
 *                                    match is accepted, both at Gate 2 and for the chosen EOI, and that
 *                                    a unit with no bedrooms is named as N/A. Previous version:
 *                                    _backup/2026-09-21_233502 (WL-017).
 * 1.1      Aurelix Dev  21 Sep 2026  P8: consoleWording, the refusals' vocabulary.
 * 1.0      Aurelix Dev  21 Sep 2026  Initial. decideEoiGate is the staff app's rule with nothing
 *                                    read from the database, so every gate is exercised here on
 *                                    values alone: no phase, unit, opportunity or EOI is created,
 *                                    and nothing depends on what the org happens to hold. Each
 *                                    expected sentence is the staff app's own (unitSearchLwc,
 *                                    "EOI v2.1"), so a drift in either copy fails here.
 */
@isTest
private class SalesConsoleEoiGateTest {

    private static final Id UNIT_A = Id.valueOf('a03VG00001QGkxkYAD');
    private static final Id UNIT_B = Id.valueOf('a03VG00001QGkxpYAD');
    private static final Id EOI_1 = Id.valueOf('a0eVG000005IiJ5YAK');
    private static final Id EOI_2 = Id.valueOf('a0eVG000005IiJ4YAK');
    private static final String LABEL_ON = 'true';
    private static final String BEDROOMS_MISMATCH = 'EOI Bedrooms Mismatch';

    private static SalesConsoleController.EoiGateUnit unit(Id id, String name, String beds,
                                                           Boolean required, Boolean strict) {
        SalesConsoleController.EoiGateUnit u = new SalesConsoleController.EoiGateUnit();
        u.unitId = id;
        u.name = name;
        u.bedrooms = beds;
        u.eoiRequired = required;
        u.eoiStrictRequired = strict;
        return u;
    }

    private static Map<String, String> meta(Boolean bypass, Boolean hasAnyEoi) {
        return new Map<String, String>{
            'type' => 'meta', 'bypass' => String.valueOf(bypass),
            'allowAnyStatus' => 'false', 'hasAnyEOI' => String.valueOf(hasAnyEoi)
        };
    }

    private static Map<String, String> eoi(Id id, String typ, String beds) {
        return new Map<String, String>{
            'label' => 'EOI', 'value' => String.valueOf(id),
            'unitTypology' => typ, 'bedrooms' => beds, 'hasReceipt' => 'true'
        };
    }

    private static SalesConsoleController.EoiGateDTO decide(
        List<SalesConsoleController.EoiGateUnit> units, List<Map<String, String>> rows,
        String engineError, String label, Map<String, String> mapping, Boolean checkMapping
    ) {
        return SalesConsoleController.decideEoiGate(units, rows, engineError, label, mapping, checkMapping);
    }

    @isTest
    static void aPhaseThatNeedsNoEoiIsNeverAsked() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{ unit(UNIT_A, 'GV-1', '6', false, false) },
            null, 'anything', 'true', null, true);
        System.assertEquals(true, g.ok, 'Every gate is guarded by the phase flag, as in the staff app.');
    }

    @isTest
    static void gate0TheEngineRefusalIsShownInItsOwnWords() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{ unit(UNIT_A, 'TH-1', '3', true, false) },
            new List<Map<String, String>>(), 'EOI must be Completed with a Cleared Receipt to book.', 'false', null, false);
        System.assertEquals(false, g.ok);
        System.assertEquals('EOI Validation', g.title);
        System.assertEquals('EOI must be Completed with a Cleared Receipt to book.', g.message);
    }

    @isTest
    static void gate1AStrictPhaseRefusesWithNoEoi() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{ unit(UNIT_A, 'Wadeem-020', '1', true, true) },
            new List<Map<String, String>>{ meta(false, false) }, null, 'false', null, false);
        System.assertEquals(false, g.ok);
        System.assertEquals('EOI Required', g.title);
        System.assertEquals('Only a Completed EOI is allowed to book this unit.', g.message);
    }

    @isTest
    static void gate1ANonStrictPhaseBooksWithoutAnEoiWhenTheOpportunityHasNone() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{ unit(UNIT_A, 'TH-132', '3', true, false) },
            new List<Map<String, String>>{ meta(false, false) }, null, 'false', null, true);
        System.assertEquals(true, g.ok, 'Sales App v8.0: no EOI at all and not strict = book without one.');
    }

    @isTest
    static void gate1ANonStrictPhaseRefusesWhenEoisExistButNoneQualifies() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{ unit(UNIT_A, 'TH-132', '3', true, false) },
            new List<Map<String, String>>{ meta(false, true) }, null, 'false', null, false);
        System.assertEquals(false, g.ok);
        System.assertEquals('Only a Completed EOI is allowed to book this unit.', g.message);
    }

    @isTest
    static void gate2AUnitWithOtherBedroomsIsRefusedWhenTheLabelIsOn() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{ unit(UNIT_A, 'GV-149', '6', true, false) },
            new List<Map<String, String>>{ meta(false, true), eoi(EOI_1, 'Townhouse', '4') },
            null, LABEL_ON, null, false);
        Assert.isFalse(g.ok, 'A 6-bedroom unit against a 4-bedroom EOI is refused.');
        Assert.areEqual(BEDROOMS_MISMATCH, g.title, 'The refusal names bedrooms, not typology.');
        Assert.areEqual('Cannot proceed. Unit "GV-149" (Bedrooms: 6) does not match any available EOI. '
            + 'Please select a unit with the same number of bedrooms as your EOI.',
            g.message, 'The refusal sentence the rep reads.');
    }

    @isTest
    static void gate2TypologyIsIgnoredWhenTheBedroomsMatch() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{ unit(UNIT_A, 'GV-149', '6', true, false) },
            new List<Map<String, String>>{ meta(false, true), eoi(EOI_1, 'Fairway Villas', '6') },
            null, LABEL_ON, null, false);
        Assert.isTrue(g.ok, 'Bedrooms decide. "Fairway Villas" on the EOI against a '
            + '"Fairway Villa" unit must not block a 6-bedroom booking.');
    }

    @isTest
    static void gate2AnEoiSpeltWithAUnitStillMatchesTheNumber() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{ unit(UNIT_A, 'GV-149', '5', true, false) },
            new List<Map<String, String>>{ meta(false, true), eoi(EOI_1, null, '5 BR') },
            null, LABEL_ON, null, false);
        Assert.isTrue(g.ok, 'Engine v16.0: "5 BR" on the EOI is a 5-bedroom unit.');
    }

    @isTest
    static void sameBedroomsIsTheEnginesNumberCompare() {
        Assert.isTrue(SalesConsoleController.sameBedrooms('5 Bedrooms', '5'), 'The number decides.');
        Assert.isTrue(SalesConsoleController.sameBedrooms('5', '5 BR'), 'Either side may carry a word.');
        Assert.isFalse(SalesConsoleController.sameBedrooms('4', '5'), 'Different numbers never match.');
        Assert.isTrue(SalesConsoleController.sameBedrooms('Studio', ' studio'), 'No digit: trimmed text, any case.');
        Assert.isFalse(SalesConsoleController.sameBedrooms('5', ''), 'A number never matches a blank.');
        Assert.isTrue(SalesConsoleController.sameBedrooms(null, ''), 'Two blanks are the same, as in the engine.');
    }

    @isTest
    static void aReceiptIsFreeOnNoOrderOrOnADeadOne() {
        Id order = Id.valueOf(
            SalesOrder__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix() + '000000001AAA');
        Assert.isTrue(SalesConsoleController.receiptIsFree(null, null), 'Not on any order: free.');
        Assert.isTrue(SalesConsoleController.receiptIsFree(order, 'Voided'), 'Its order was voided: free again.');
        Assert.isTrue(SalesConsoleController.receiptIsFree(order, 'Cancelled'), 'Its order was cancelled: free again.');
        Assert.isFalse(SalesConsoleController.receiptIsFree(order, 'New'), 'Held by a live order: spent.');
    }

    @isTest
    static void gate2AUnitWithNoBedroomsIsNamedAsNotAvailable() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{ unit(UNIT_A, 'PL-7', '', true, false) },
            new List<Map<String, String>>{ meta(false, true), eoi(EOI_1, null, '5') },
            null, LABEL_ON, null, false);
        Assert.isFalse(g.ok, 'A unit with no bedrooms does not match a 5-bedroom EOI.');
        Assert.isTrue(g.message.contains('(Bedrooms: N/A)'), 'A blank bedroom count reads N/A: ' + g.message);
    }

    @isTest
    static void gate2TheLabelOffOrTheOpportunityBypassSkipsTheMatch() {
        List<SalesConsoleController.EoiGateUnit> units = new List<SalesConsoleController.EoiGateUnit>{
            unit(UNIT_A, 'GV-149', '6', true, false)
        };
        List<Map<String, String>> byLabel = new List<Map<String, String>>{ meta(false, true), eoi(EOI_1, 'Townhouse', '4') };
        System.assertEquals(true, decide(units, byLabel, null, 'false', null, false).ok,
            'Label false = bypass, today\'s DEV setting.');
        List<Map<String, String>> byOpp = new List<Map<String, String>>{ meta(true, true), eoi(EOI_1, 'Townhouse', '4') };
        System.assertEquals(true, decide(units, byOpp, null, 'true', null, false).ok,
            'Bypass_EOI_Typology_Check__c on the opportunity wins over the label.');
    }

    @isTest
    static void gate3TwoUnitsCannotRideOneEoi() {
        SalesConsoleController.EoiGateDTO g = decide(
            new List<SalesConsoleController.EoiGateUnit>{
                unit(UNIT_A, 'GV-144', '6', true, false),
                unit(UNIT_B, 'GV-149', '6', true, false)
            },
            new List<Map<String, String>>{ meta(false, true), eoi(EOI_1, 'Fairway Villa', '6') },
            null, 'false', null, false);
        System.assertEquals(false, g.ok, 'This basket went through before 1.69.');
        System.assertEquals('Number of units selected (2) cannot exceed the number of available EOIs (1).', g.message);
    }

    @isTest
    static void everyUnitCarriesItsOwnEoiOnceEoisAreInPlay() {
        List<SalesConsoleController.EoiGateUnit> units = new List<SalesConsoleController.EoiGateUnit>{
            unit(UNIT_A, 'GV-144', '6', true, false),
            unit(UNIT_B, 'GV-149', '6', true, false)
        };
        List<Map<String, String>> rows = new List<Map<String, String>>{
            meta(false, true), eoi(EOI_1, 'Fairway Villa', '6'), eoi(EOI_2, 'Fairway Villa', '6')
        };
        SalesConsoleController.EoiGateDTO missing = decide(units, rows, null, 'false',
            new Map<String, String>{ String.valueOf(UNIT_A) => String.valueOf(EOI_1) }, true);
        System.assertEquals(false, missing.ok);
        System.assertEquals('Please select an EOI for unit GV-149 before proceeding.', missing.message);

        SalesConsoleController.EoiGateDTO dup = decide(units, rows, null, 'false',
            new Map<String, String>{ String.valueOf(UNIT_A) => String.valueOf(EOI_1), String.valueOf(UNIT_B) => String.valueOf(EOI_1) }, true);
        System.assertEquals(false, dup.ok);
        System.assertEquals('Duplicate EOI', dup.title);

        SalesConsoleController.EoiGateDTO fine = decide(units, rows, null, 'false',
            new Map<String, String>{ String.valueOf(UNIT_A) => String.valueOf(EOI_1), String.valueOf(UNIT_B) => String.valueOf(EOI_2) }, true);
        System.assertEquals(true, fine.ok, 'Two units, two EOIs, one each.');
    }

    @isTest
    static void aChosenEoiMustHaveTheUnitsBedroomsWhenTheMatchIsOn() {
        List<SalesConsoleController.EoiGateUnit> units = new List<SalesConsoleController.EoiGateUnit>{
            unit(UNIT_A, 'GV-144', '6', true, false)
        };
        List<Map<String, String>> rows = new List<Map<String, String>>{
            meta(false, true), eoi(EOI_1, 'Fairway Villa', '6'), eoi(EOI_2, 'Townhouse', '3')
        };
        SalesConsoleController.EoiGateDTO g = decide(units, rows, null, LABEL_ON,
            new Map<String, String>{ String.valueOf(UNIT_A) => String.valueOf(EOI_2) }, true);
        Assert.isFalse(g.ok, 'A 3-bedroom EOI cannot pay for a 6-bedroom unit.');
        Assert.areEqual(BEDROOMS_MISMATCH, g.title, 'The chosen EOI is refused on bedrooms.');
    }

    @isTest
    static void aChosenEoiWithTheSameBedroomsAndAnotherTypologyIsAccepted() {
        List<SalesConsoleController.EoiGateUnit> units = new List<SalesConsoleController.EoiGateUnit>{
            unit(UNIT_A, 'GV-144', '6', true, false)
        };
        List<Map<String, String>> rows = new List<Map<String, String>>{
            meta(false, true), eoi(EOI_1, 'Front Row Premium Villa', '6')
        };
        SalesConsoleController.EoiGateDTO g = decide(units, rows, null, LABEL_ON,
            new Map<String, String>{ String.valueOf(UNIT_A) => String.valueOf(EOI_1) }, true);
        Assert.isTrue(g.ok, 'Same bedrooms, different typology: accepted when the match is on.');
    }

    /** P8 (SalesConsoleController 1.70): MODON's refusals in the console's words. */
    @isTest
    static void refusalsSpeakOfBookingsAndCustomersNotOpportunities() {
        System.assertEquals('Sales order already in progress for this booking.',
            SalesConsoleController.consoleWording('Sales order already in progress for this opportunity.'));
        System.assertEquals('Customer is not set on this booking. Please add one.',
            SalesConsoleController.consoleWording('Primary Contact is not set on this Opportunity. Please add one.'));
        System.assertEquals('KYC is not completed for the customer.',
            SalesConsoleController.consoleWording('KYC is not completed for the Primary Contact.'));
        System.assertEquals('Open a booking first.',
            SalesConsoleController.consoleWording('Open an opportunity first.'));
        System.assertEquals('Only a Completed EOI is allowed to book this unit.',
            SalesConsoleController.consoleWording('Only a Completed EOI is allowed to book this unit.'),
            'A sentence with nothing to reword is returned as it came.');
        System.assertEquals(null, SalesConsoleController.consoleWording(null));
    }

    @isTest
    static void theServerEntryAnswersYesWhenThereIsNothingToCheck() {
        System.assertEquals(true, SalesConsoleController.checkEoiGate(null, new List<Id>(), null).ok);
        System.assertEquals(true, SalesConsoleController.checkEoiGate(null, null, null).ok);
    }
}