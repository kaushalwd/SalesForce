/**
 * RelixRequestValidatorTest - Dalil's request limits, checked at their boundaries (SCW-181).
 */
@IsTest
private class RelixRequestValidatorTest {

    private static RelixRequestValidator.Input good() {
        RelixRequestValidator.Input i = new RelixRequestValidator.Input();
        i.persona = 'INDIVIDUAL_EXPAT';
        i.propertyRef = 'UNIT-A-101';
        i.callbackUrl = 'https://example.invalid/relixcallback/services/apexrest/relix/callback/abc';
        i.buyerName = 'Sample Buyer';
        i.email = 'buyer@example.com';
        i.phone = '0501234567';
        i.amount = 1250000;
        i.currencyCode = 'AED';
        return i;
    }

    @IsTest
    static void aGoodRequestPassesAndNormalisesThePhone() {
        RelixRequestValidator.Outcome o = RelixRequestValidator.validate(good());
        System.assert(o.isValid(), 'Problems: ' + o.problems);
        System.assertEquals('+971501234567', o.phoneE164);
        System.assertEquals(true, o.sendTransaction);
    }

    @IsTest
    static void phoneShapesMetInModonDataAllBecomeE164() {
        System.assertEquals('+971501234567', RelixRequestValidator.normalisePhone('050 123 4567'));
        System.assertEquals('+971501234567', RelixRequestValidator.normalisePhone('00971501234567'));
        System.assertEquals('+971501234567', RelixRequestValidator.normalisePhone('+971 50-123-4567'));
        System.assertEquals('+971501234567', RelixRequestValidator.normalisePhone('971501234567'));
        System.assertEquals('+447700900123', RelixRequestValidator.normalisePhone('+44 7700 900123'));
        System.assertEquals(null, RelixRequestValidator.normalisePhone('abc'));
        System.assertEquals(null, RelixRequestValidator.normalisePhone(''));
        System.assertEquals(null, RelixRequestValidator.normalisePhone('+12'));
    }

    @IsTest
    static void nameBoundaryIs200() {
        RelixRequestValidator.Input i = good();
        i.buyerName = 'a'.repeat(200);
        System.assert(RelixRequestValidator.validate(i).isValid());
        i.buyerName = 'a'.repeat(201);
        System.assert(!RelixRequestValidator.validate(i).isValid());
        i.buyerName = '   ';
        System.assert(!RelixRequestValidator.validate(i).isValid());
    }

    @IsTest
    static void emailBoundaryIs254AndShapeIsChecked() {
        RelixRequestValidator.Input i = good();
        i.email = 'a'.repeat(242) + '@example.com';   // 254
        System.assert(RelixRequestValidator.validate(i).isValid());
        i.email = 'a'.repeat(243) + '@example.com';   // 255
        System.assert(!RelixRequestValidator.validate(i).isValid());
        i.email = 'not an email';
        System.assert(!RelixRequestValidator.validate(i).isValid());
        i.email = null;
        System.assert(!RelixRequestValidator.validate(i).isValid());
    }

    @IsTest
    static void callbackMustBeAbsoluteAndAtMost500() {
        RelixRequestValidator.Input i = good();
        i.callbackUrl = 'https://x.io/' + 'a'.repeat(487);   // 500
        System.assert(RelixRequestValidator.validate(i).isValid());
        i.callbackUrl = 'https://x.io/' + 'a'.repeat(488);   // 501
        System.assert(!RelixRequestValidator.validate(i).isValid());
        i.callbackUrl = 'ftp://x.io/cb';
        System.assert(!RelixRequestValidator.validate(i).isValid());
        i.callbackUrl = 'http://x.io/cb';
        System.assert(!RelixRequestValidator.validate(i).isValid(), 'the token must never travel over plain http');
        i.callbackUrl = null;   // no callback configured is allowed
        System.assert(RelixRequestValidator.validate(i).isValid());
    }

    @IsTest
    static void transactionIsWholeOrAbsent() {
        RelixRequestValidator.Input i = good();
        i.amount = null;
        RelixRequestValidator.Outcome o = RelixRequestValidator.validate(i);
        System.assert(o.isValid());
        System.assertEquals(false, o.sendTransaction);
        i.amount = 0;
        System.assert(!RelixRequestValidator.validate(i).isValid());
        i.amount = 5;
        i.currencyCode = 'aed';
        System.assert(!RelixRequestValidator.validate(i).isValid());
        i.currencyCode = 'AED';
        System.assert(RelixRequestValidator.validate(i).isValid());
    }

    @IsTest
    static void personaAndPropertyAreRequired() {
        RelixRequestValidator.Input i = good();
        i.persona = 'IDV';
        System.assert(!RelixRequestValidator.validate(i).isValid());
        i = good();
        i.propertyRef = ' ';
        System.assert(!RelixRequestValidator.validate(i).isValid());
        System.assert(!RelixRequestValidator.validate(null).isValid());
    }
}