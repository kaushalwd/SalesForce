/**
 * RelixLogger - writes Relix integration events to MODON's Logger__c without personal data.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. MODON's LoggerService.createAPILog stores request
 *                                    and response bodies, which for Relix would hold names, emails,
 *                                    phones and identity data; createApexLog stores raw exception
 *                                    text. Neither is used. This class inserts Logger__c rows with a
 *                                    whitelisted set of fields (endpoint, HTTP status, error code,
 *                                    errorRef, our row Id) and a message scrubbed of anything that
 *                                    looks like an email or a long number. The API key can never
 *                                    reach here: it lives in the named credential, not in code.
 *
 * OWNERSHIP. Owner: MODON. Logger__c is MODON's object; rows are inserted, never read or changed.
 */
public without sharing class RelixLogger {

    public static final String PROCESS = 'Relix KYC';
    public static final String AREA = 'KYC';
    private static final Integer MESSAGE_MAX = 1000;

    private static final Pattern LONG_NUMBERS = Pattern.compile('[0-9][0-9 \\-]{6,}[0-9]');

    /** A call answered, well or badly. */
    public static void callout(String method, String message, Integer httpStatus, String errorCode, String errorRef, Id related) {
        write('Callout Log', method, message, httpStatus, errorCode, errorRef, related);
    }

    /** Something on our side failed (a job, a trigger, a write). */
    public static void failure(String method, String message, Id related) {
        write('Service Exception', method, message, null, null, null, related);
    }

    private static void write(String logType, String method, String message, Integer httpStatus,
                              String errorCode, String errorRef, Id related) {
        try {
            String text = clean(message);
            if (String.isNotBlank(errorCode)) { text = '[' + errorCode + '] ' + text; }
            if (String.isNotBlank(errorRef)) { text = text + ' (errorRef ' + errorRef + ')'; }
            Logger__c row = new Logger__c(
                LogType__c = logType,
                Area__c = AREA,
                ExecutingProcessName__c = PROCESS,
                ClassName__c = 'Relix',
                MethodName__c = method,
                Message__c = text,
                Integration_Status_Code__c = httpStatus == null ? null : String.valueOf(httpStatus),
                Related_Record_ID__c = related == null ? null : String.valueOf(related)
            );
            insert row;
        } catch (Exception e) {
            // Logging must never break the work it describes.
            System.debug(LoggingLevel.ERROR, 'RelixLogger could not write: ' + e.getMessage());
        }
    }

    /** Removes email addresses and long digit runs, then truncates. */
    @TestVisible
    private static String clean(String s) {
        if (s == null) { return null; }
        // Bound the input first so no pattern below can run away on a long message.
        String bounded = s.length() > MESSAGE_MAX ? s.substring(0, MESSAGE_MAX) : s;
        // Emails: any whitespace-delimited token holding an @ is dropped (no regex, so no backtracking).
        List<String> words = bounded.split('\\s+');
        for (Integer i = 0; i < words.size(); i++) {
            if (words[i].contains('@')) { words[i] = '[email]'; }
        }
        String out = String.join(words, ' ');
        out = LONG_NUMBERS.matcher(out).replaceAll('[number]');
        return out.length() > MESSAGE_MAX ? out.substring(0, MESSAGE_MAX) : out;
    }
}