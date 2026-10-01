/**********************************************************************************************************************
* Name               : UtilitiesTest
* Description        : Test class for Utilities.
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           ActiveMinds      02 Jun 2026     Initial Draft
* 1.1           Narendra Agrawal 29 Jun 2026     Added tests for amountInWords with standard and large values
******************************************************************************************************************/
@isTest
public class UtilitiesTest {

    @isTest
    static void testAmountInWords() {
        // Standard small values
        String result = Utilities.amountInWords(125.50, 'Pound', 'Piastres');
        Assert.areEqual('ONE HUNDRED TWENTY-FIVE POUND AND FIFTY PIASTRES ONLY', result);

        // Whole numbers (no subunit words)
        String whole = Utilities.amountInWords(200.00, 'Pound', 'Piastres');
        Assert.areEqual('TWO HUNDRED POUND ONLY', whole);

        // Large values exceeding Integer.MAX_VALUE
        String large = Utilities.amountInWords(10000000000.75, 'Pound', 'Piastres');
        Assert.areEqual('TEN BILLION POUND AND SEVENTY-FIVE PIASTRES ONLY', large);

        // Null value returns blank string
        String nullRes = Utilities.amountInWords(null, 'Pound', 'Piastres');
        Assert.areEqual('', nullRes);
    }
}