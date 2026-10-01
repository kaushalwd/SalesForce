/**
 * RelixConfigDefaultAmountTest - RelixConfig.defaultAmount(), the RELIX_DEFAULT_AMOUNT row: which values become the
 * amount of an Account send, and which send none.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  30 Sep 2026  New with the row. Pinned through RelixConfig's test overrides, so the org's own row
 *                                    never leaks in.
 */
@IsTest
private class RelixConfigDefaultAmountTest {

    private static final String ROW = 'RELIX_DEFAULT_AMOUNT';

    private static Decimal amountFor(Boolean active, String value) {
        RelixConfig.activeOverride.put(ROW, active);
        RelixConfig.valueOverride.put(ROW, value);
        return RelixConfig.defaultAmount();
    }

    @IsTest
    static void anActiveRowWithAPositiveNumberIsTheAmount() {
        Test.startTest();
        Decimal one = amountFor(true, '1');
        Decimal spaced = amountFor(true, ' 2500.50 ');
        Test.stopTest();

        Assert.areEqual(1, one.intValue(), 'an active row holding 1 gives 1');
        Assert.areEqual(Decimal.valueOf('2500.50'), spaced, 'spaces are ignored and the decimals kept');
    }

    @IsTest
    static void anInactiveRowGivesNoAmount() {
        Test.startTest();
        Decimal amount = amountFor(false, '1');
        Test.stopTest();

        Assert.isNull(amount, 'a row that is off sends no amount, whatever it holds');
    }

    @IsTest
    static void aBlankZeroNegativeOrNonNumericValueGivesNoAmount() {
        Test.startTest();
        Decimal missing = amountFor(true, null);
        Decimal blank = amountFor(true, '  ');
        Decimal zero = amountFor(true, '0');
        Decimal negative = amountFor(true, '-5');
        Decimal text = amountFor(true, 'one');
        Test.stopTest();

        Assert.isNull(missing, 'no value, no amount');
        Assert.isNull(blank, 'a blank value, no amount');
        Assert.isNull(zero, 'RelixRequestValidator refuses 0, so 0 sends no amount');
        Assert.isNull(negative, 'a negative value sends no amount');
        Assert.isNull(text, 'text is not an amount');
    }
}