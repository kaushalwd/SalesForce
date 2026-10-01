/**********************************************************************************************************************
* Name               : NumberToTextTest
* Description        : Test class for NumberToText.
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           ActiveMinds      02 Jun 2026     Initial Draft
* 1.1           Narendra Agrawal 29 Jun 2026     Added tests for convert methods with integers, longs, and large digit strings
******************************************************************************************************************/
@isTest
public class NumberToTextTest {

    @isTest
    static void testConvertInteger() {
        Assert.areEqual('Zero', NumberToText.convert(0));
        Assert.areEqual('One', NumberToText.convert(1));
        Assert.areEqual('Nineteen', NumberToText.convert(19));
        Assert.areEqual('Twenty', NumberToText.convert(20));
        Assert.areEqual('Twenty-One', NumberToText.convert(21));
        Assert.areEqual('Ninety-Nine', NumberToText.convert(99));
        Assert.areEqual('One Hundred', NumberToText.convert(100));
        Assert.areEqual('One Hundred Five', NumberToText.convert(105));
        Assert.areEqual('One Hundred Twenty-Five', NumberToText.convert(125));
        Assert.areEqual('Nine Hundred Ninety-Nine', NumberToText.convert(999));
        Assert.areEqual('One Thousand', NumberToText.convert(1000));
        Assert.areEqual('One Thousand Two Hundred Thirty-Four', NumberToText.convert(1234));
    }

    @isTest
    static void testConvertLong() {
        Assert.areEqual('One Million', NumberToText.convert(1000000L));
        Assert.areEqual('One Billion', NumberToText.convert(1000000000L));
    }

    @isTest
    static void testConvertString() {
        Assert.areEqual('Zero', NumberToText.convert(''));
        Assert.areEqual('Zero', NumberToText.convert('0'));
        Assert.areEqual('Zero', NumberToText.convert('0000'));
        Assert.areEqual('negative One Hundred', NumberToText.convert('-100'));
        
        // Large values exceeding Integer.MAX_VALUE
        Assert.areEqual('Ten Billion', NumberToText.convert('10000000000'));
        Assert.areEqual('One Trillion', NumberToText.convert('1000000000000'));
        Assert.areEqual('One Quadrillion', NumberToText.convert('1000000000000000'));
    }
}