/**
 * Unit tests for MODON's SmsTextBuilder (GSM segment fitting, greeting name, short expiry).
 * Pure functions: no data, no configuration, no callouts. Written so the package's coverage does
 * not depend on the org's Outbound Message Config records (SCW-094, 13 Sep 2026).
 * @author Aurelix
 */
@isTest
private class SmsTextBuilderTest {

    private static String repeat(String s, Integer n) {
        String out = '';
        for (Integer i = 0; i < n; i++) { out += s; }
        return out;
    }

    @isTest
    static void fitPicksPrimaryWhenItFitsOneSegment() {
        String primary = repeat('a', 160);
        System.assertEquals(primary, SmsTextBuilder.fit(primary, 'short'), 'a 160-septet primary fits and is sent');
    }

    @isTest
    static void fitFallsBackWhenPrimaryIsTooLong() {
        String primary = repeat('a', 161);
        System.assertEquals('short', SmsTextBuilder.fit(primary, 'short'), 'the fallback goes when the primary needs a second segment');
    }

    @isTest
    static void fitKeepsPrimaryWhenNeitherFits() {
        String primary = repeat('a', 200);
        String fallback = repeat('b', 170);
        System.assertEquals(primary, SmsTextBuilder.fit(primary, fallback), 'a split message beats no message');
    }

    @isTest
    static void fitHandlesBlankInputs() {
        System.assertEquals(null, SmsTextBuilder.fit(null, null));
        System.assertEquals(null, SmsTextBuilder.fit('', ' '));
        System.assertEquals('fallback', SmsTextBuilder.fit('  ', 'fallback'), 'a blank primary yields the fallback');
        System.assertEquals('only', SmsTextBuilder.fit('only', null), 'no fallback needed when the primary fits');
    }

    @isTest
    static void fitCountsExtensionCharactersTwice() {
        // 80 euro signs = 160 septets (fits); 81 = 162 (does not)
        System.assertEquals(repeat('€', 80), SmsTextBuilder.fit(repeat('€', 80), 'fb'));
        System.assertEquals('fb', SmsTextBuilder.fit(repeat('€', 81), 'fb'));
    }

    @isTest
    static void firstNameSkipsSalutationsAndKeepsGsmNames() {
        System.assertEquals('Ahmed', SmsTextBuilder.firstName('Mr. Ahmed Al Mansoori'));
        System.assertEquals('Fatima', SmsTextBuilder.firstName('  Dr   Fatima  '));
        System.assertEquals('Ahmed', SmsTextBuilder.firstName('Sheikh Ahmed'));
        System.assertEquals('O\'Brien', SmsTextBuilder.firstName('O’Brien Kelly'), 'typographic apostrophe mapped onto GSM');
    }

    @isTest
    static void firstNameFallsBackForBlankSalutationOnlyOrNonGsm() {
        System.assertEquals(SmsTextBuilder.FALLBACK_NAME, SmsTextBuilder.firstName(null));
        System.assertEquals(SmsTextBuilder.FALLBACK_NAME, SmsTextBuilder.firstName('   '));
        System.assertEquals(SmsTextBuilder.FALLBACK_NAME, SmsTextBuilder.firstName('Mr.'), 'a salutation alone is no name');
        System.assertEquals(SmsTextBuilder.FALLBACK_NAME, SmsTextBuilder.firstName('محمد علي'), 'a name outside the GSM alphabet is never mangled');
    }

    @isTest
    static void shortExpiryFormatsWithEnglishMonth() {
        Datetime d = Datetime.newInstance(2026, 9, 11, 14, 51, 0);
        String s = SmsTextBuilder.shortExpiry(d);
        System.assert(s.contains('Sep'), 'English month expected: ' + s);
        System.assert(s.contains('14:51') || s.contains(':'), 'time expected: ' + s);
        System.assertEquals(null, SmsTextBuilder.shortExpiry(null));
    }

    @isTest
    static void toGsmMapsTypographyAndDropsTheRest() {
        System.assertEquals('', SmsTextBuilder.toGsm(null));
        System.assertEquals('"Hi" - it\'s ... ok', SmsTextBuilder.toGsm('“Hi” – it’s … ok'));
        System.assertEquals('Pay 5€ now', SmsTextBuilder.toGsm('Pay 5€ now'), 'the euro sign is a GSM extension character and stays');
        System.assertEquals('Hello ', SmsTextBuilder.toGsm('Hello 😀'), 'an emoji has no GSM equivalent and is dropped');
        System.assertEquals('https://x.y/z?a=1&b=2', SmsTextBuilder.toGsm('https://x.y/z?a=1&b=2'), 'a URL is untouched');
    }

    @isTest
    static void gsmLengthCountsSeptets() {
        System.assertEquals(0, SmsTextBuilder.gsmLength(null));
        System.assertEquals(0, SmsTextBuilder.gsmLength(''));
        System.assertEquals(5, SmsTextBuilder.gsmLength('hello'));
        System.assertEquals(3, SmsTextBuilder.gsmLength('a€'), 'extension characters cost two septets');
        System.assertEquals(4, SmsTextBuilder.gsmLength('{}'), 'braces are extension characters');
    }
}