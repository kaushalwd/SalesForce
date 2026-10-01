/**
 * RelixLoggerTest - the scrubbing and the whitelisted Logger__c write (SCW-181).
 */
@IsTest
private class RelixLoggerTest {

    @IsTest
    static void cleanRemovesEmailsAndLongNumbers() {
        String out = RelixLogger.clean('Sent to buyer@example.com on +971 50 123 4567, status 200, EID 784-1990-1234567-1.');
        System.assert(!out.contains('example.com'), out);
        System.assert(!out.contains('1234567'), out);
        System.assert(out.contains('[email]'), out);
        System.assert(out.contains('status 200'), out);
        System.assertEquals(null, RelixLogger.clean(null));
        System.assertEquals(1000, RelixLogger.clean('x'.repeat(2000)).length());
    }

    @IsTest
    static void calloutAndFailureWriteWhitelistedRows() {
        RelixLogger.callout('getCase', 'Case not found for x@y.z', 404, 'not_found', 'RX-ERROR-12', null);
        RelixLogger.failure('signal', 'boom', null);
        List<Logger__c> rows = [
            SELECT LogType__c, Area__c, MethodName__c, Message__c, Integration_Status_Code__c, ExecutingProcessName__c,
                   Integration_Request_Body__c, Integration_Response_Body__c, StackTrace__c
            FROM Logger__c WHERE ExecutingProcessName__c = :RelixLogger.PROCESS ORDER BY MethodName__c
        ];
        System.assertEquals(2, rows.size());
        Logger__c c = rows[0].MethodName__c == 'getCase' ? rows[0] : rows[1];
        System.assertEquals('Callout Log', c.LogType__c);
        System.assertEquals('KYC', c.Area__c);
        System.assertEquals('404', c.Integration_Status_Code__c);
        System.assert(c.Message__c.startsWith('[not_found]'), c.Message__c);
        System.assert(c.Message__c.contains('RX-ERROR-12'));
        System.assert(!c.Message__c.contains('x@y.z'));
        System.assertEquals(null, c.Integration_Request_Body__c);
        System.assertEquals(null, c.Integration_Response_Body__c);
        System.assertEquals(null, c.StackTrace__c);
    }
}