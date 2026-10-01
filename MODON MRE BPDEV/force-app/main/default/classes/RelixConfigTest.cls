/**
 * RelixConfigTest - the Relix settings: switches, the clamped numbers, the callback base and the test
 * recipients (docs/relix, 07 section 1).
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  26 Sep 2026  Review fix (C-15, K6). Every getter through the @TestVisible overrides, so no org
 *                                    value leaks in: the default when blank, the clamp below the minimum and above
 *                                    the maximum, an invalid value, the 3,000,000 ceiling of RELIX_DOC_MAX_BYTES.
 */
@IsTest
private class RelixConfigTest {

    private static final String BLANK = '';
    private static final String INVALID = 'not a number';

    // Sets one value and reads it back through the getter named by key.
    private static Integer read(String key, String value) {
        RelixConfig.valueOverride.put(key, value);
        switch on key {
            when 'RELIX_POLL_MINUTES' {
                return RelixConfig.pollMinutes();
            }
            when 'RELIX_POLL_MAX_READS' {
                return RelixConfig.pollMaxReads();
            }
            when 'RELIX_DOC_MAX_BYTES' {
                return RelixConfig.docMaxBytes();
            }
            when 'RELIX_NOT_READY_HOURS' {
                return RelixConfig.notReadyHours();
            }
            when else {
                return RelixConfig.readJobsPerRun();
            }
        }
    }

    @IsTest
    static void everyNumberHasADefaultAMinimumAndAMaximum() {
        // key => default, below the minimum -> minimum, above the maximum -> maximum
        Map<String, List<Integer>> rules = new Map<String, List<Integer>>{
            'RELIX_POLL_MINUTES' => new List<Integer>{ 15, 5, 1440 },
            'RELIX_POLL_MAX_READS' => new List<Integer>{ 40, 1, 80 },
            'RELIX_DOC_MAX_BYTES' => new List<Integer>{ 2500000, 1000, 3000000 },
            'RELIX_NOT_READY_HOURS' => new List<Integer>{ 24, 1, 168 },
            'RELIX_READ_JOBS' => new List<Integer>{ 4, 1, 10 }
        };

        Test.startTest();
        for (String key : rules.keySet()) {
            List<Integer> rule = rules.get(key);
            Assert.areEqual(rule[0], read(key, BLANK), key + ': blank gives the default');
            Assert.areEqual(rule[0], read(key, INVALID), key + ': an invalid value gives the default');
            Assert.areEqual(rule[1], read(key, '0'), key + ': below the minimum gives the minimum');
            Assert.areEqual(rule[2], read(key, '999999999'), key + ': above the maximum gives the maximum');
            Assert.areEqual(rule[1] + 1, read(key, ' ' + String.valueOf(rule[1] + 1) + ' '), key + ': a value in range is kept');
        }
        Test.stopTest();
    }

    @IsTest
    static void theDocumentCapNeverExceedsWhatTheHeapHolds() {
        Test.startTest();
        Integer asked = read('RELIX_DOC_MAX_BYTES', '5000000');
        Integer fits = read('RELIX_DOC_MAX_BYTES', '2999999');
        Test.stopTest();

        Assert.areEqual(RelixConfig.DOC_MAX_BYTES_CEILING, asked, '5,000,000 is cut to 3,000,000 (K6, L-01)');
        Assert.areEqual(3000000, RelixConfig.DOC_MAX_BYTES_CEILING, 'the ceiling itself');
        Assert.areEqual(2999999, fits, 'a value under the ceiling is kept');
    }

    @IsTest
    static void switchesFollowTheirRows() {
        Test.startTest();
        for (String key : new List<String>{ 'RELIX_KYC', 'RELIX_WRITE_KYC_DATE', 'RELIX_WRITE_IDENTITY', 'RELIX_DOWNLOAD_DOCS' }) {
            RelixConfig.activeOverride.put(key, true);
        }
        Boolean allOn = RelixConfig.isEnabled() && RelixConfig.writesKycDate()
            && RelixConfig.writesIdentity() && RelixConfig.downloadsDocs();
        for (String key : new List<String>{ 'RELIX_KYC', 'RELIX_WRITE_KYC_DATE', 'RELIX_WRITE_IDENTITY', 'RELIX_DOWNLOAD_DOCS' }) {
            RelixConfig.activeOverride.put(key, false);
        }
        Boolean anyOn = RelixConfig.isEnabled() || RelixConfig.writesKycDate()
            || RelixConfig.writesIdentity() || RelixConfig.downloadsDocs();
        Test.stopTest();

        Assert.isTrue(allOn, 'each switch reads its own row');
        Assert.isFalse(anyOn, 'and each can be turned off');
    }

    @IsTest
    static void theCallbackBaseMustBeHttps() {
        Test.startTest();
        RelixConfig.valueOverride.put('RELIX_CALLBACK_BASE', ' https://example.invalid/relixcallback// ');
        String https = RelixConfig.callbackBase();
        RelixConfig.valueOverride.put('RELIX_CALLBACK_BASE', 'http://example.invalid/relixcallback');
        String http = RelixConfig.callbackBase();
        RelixConfig.valueOverride.put('RELIX_CALLBACK_BASE', BLANK);
        String none = RelixConfig.callbackBase();
        Test.stopTest();

        Assert.areEqual('https://example.invalid/relixcallback', https, 'trimmed, trailing slashes removed');
        Assert.isNull(http, 'the callback token never travels over plain http');
        Assert.isNull(none, 'blank: no callbackUrl is sent');
    }

    @IsTest
    static void testRecipientsAreALowerCaseSet() {
        Test.startTest();
        RelixConfig.valueOverride.put('RELIX_TEST_RECIPIENTS', ' One@Example.com, ,two@example.com ');
        Set<String> listed = RelixConfig.testRecipients();
        RelixConfig.valueOverride.put('RELIX_TEST_RECIPIENTS', BLANK);
        Set<String> none = RelixConfig.testRecipients();
        Test.stopTest();

        Assert.areEqual(new Set<String>{ 'one@example.com', 'two@example.com' }, listed, 'trimmed, lower case, blanks dropped');
        Assert.isTrue(none.isEmpty(), 'blank: nobody');
    }

    @IsTest
    static void theSandboxFlagComesFromTheOrgUnlessOverridden() {
        Test.startTest();
        RelixConfig.sandboxOverride = true;
        Boolean overridden = RelixConfig.isSandbox();
        RelixConfig.sandboxOverride = null;
        Boolean fromOrg = RelixConfig.isSandbox();
        Test.stopTest();

        Assert.isTrue(overridden, 'the test override wins');
        Assert.areEqual([SELECT IsSandbox FROM Organization WITH SYSTEM_MODE LIMIT 1].IsSandbox, fromOrg, 'otherwise the org says');
    }
}