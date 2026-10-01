/**
 * ContactEmailMessagesAPI
 * -----------------------------------------------------------------------------
 * GET /services/apexrest/contact-emails/v1/{recordId}
 * GET /services/apexrest/contact-emails/v1?contactId={contactId}
 * GET /services/apexrest/contact-emails/v1?accountId={accountId}
 *
 * Accepts either an Account Id (001...) or a Contact Id (003...):
 *   - Account Id  : must be a Person Account; its PersonContactId is used to
 *                   look up email messages. Organization Accounts are rejected
 *                   since they can have multiple Contacts (ambiguous target).
 *   - Contact Id  : used directly, regardless of whether the Contact sits
 *                   under an Organization Account or a Person Account.
 *
 * Either way, returns the latest 5 EmailMessage records the resolved Contact
 * received (RelationType = 'ToAddress' on EmailMessageRelation).
 */
@RestResource(urlMapping='/contact-emails/v1/*')
global with sharing class ContactEmailMessagesAPI {

    /* ============================ WRAPPERS ============================ */

    global class ServiceResponse {
        global String  status;
        global String  message;
        global String  contactId;
        global String  accountId;
        global String  accountName;
        global String  accountType;
        global Integer recordCount = 0;
        global List<EmailMessageDTO> emailMessages = new List<EmailMessageDTO>();
    }

    global class EmailMessageDTO {
        global String   emailMessageId;
        global String   subject;
        global String   htmlBody;
        global String   textBody;
        global Datetime messageDate;
    }

    /* ============================ ENTRY POINT ============================ */

    @HttpGet
    global static void doGet() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json; charset=UTF-8');

        ServiceResponse out = new ServiceResponse();

        try {
            String inputId = getInputId();

            if (String.isBlank(inputId)) {
                send(res, 400, out, 'ERROR',
                     'An Account Id (001...) or Contact Id (003...) is required, '
                     + 'e.g. /contact-emails/v1/003XXXXXXXXXXXXAAA');
                return;
            }

            Id recordId;
            try {
                recordId = Id.valueOf(inputId);
            } catch (Exception badId) {
                send(res, 400, out, 'ERROR', 'Not a valid Salesforce Id: ' + inputId);
                return;
            }

            Schema.SObjectType sObjType = recordId.getSObjectType();
            String contactId;

            if (sObjType == Contact.SObjectType) {
                contactId = recordId;

            } else if (sObjType == Account.SObjectType) {
                List<Account> accounts = [
                    SELECT Id, Name, IsPersonAccount, PersonContactId
                    FROM Account
                    WHERE Id = :recordId
                    LIMIT 1
                ];

                if (accounts.isEmpty()) {
                    send(res, 404, out, 'ERROR', 'No Account found for Id ' + recordId);
                    return;
                }

                Account acc = accounts[0];
                if (!acc.IsPersonAccount || acc.PersonContactId == null) {
                    send(res, 400, out, 'ERROR',
                         'Account ' + recordId + ' is an Organization Account. '
                         + 'Pass its Contact Id instead of the Account Id.');
                    return;
                }
                contactId = acc.PersonContactId;

            } else {
                send(res, 400, out, 'ERROR',
                     'Unsupported Id type for ' + recordId + '. Expected an Account or Contact Id.');
                return;
            }

            List<Contact> contacts = [
                SELECT Id, AccountId, Account.Name, Account.IsPersonAccount
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];

            if (contacts.isEmpty()) {
                send(res, 404, out, 'ERROR', 'No Contact found for Id ' + contactId);
                return;
            }

            Contact con = contacts[0];
            out.contactId   = con.Id;
            out.accountId   = con.AccountId;
            out.accountName = con.Account != null ? con.Account.Name : null;
            out.accountType = (con.Account != null && con.Account.IsPersonAccount)
                               ? 'Person Account'
                               : 'Organization Account';

            List<EmailMessage> emails = [
                SELECT Id, Subject, HtmlBody, TextBody, MessageDate
                FROM EmailMessage
                WHERE Id IN (
                    SELECT EmailMessageId
                    FROM EmailMessageRelation
                    WHERE RelationId = :contactId
                    AND RelationType = 'ToAddress'
                )
                ORDER BY MessageDate DESC
                LIMIT 5
            ];

            for (EmailMessage em : emails) {
                out.emailMessages.add(buildDTO(em));
            }

            out.status      = 'SUCCESS';
            out.message     = emails.isEmpty()
                              ? 'No email messages found for this Contact.'
                              : 'Email message(s) retrieved successfully.';
            out.recordCount = out.emailMessages.size();

            res.statusCode   = 200;
            res.responseBody = Blob.valueOf(JSON.serializePretty(out, true));

        } catch (Exception e) {
            send(res, 500, out, 'ERROR',
                 'Unexpected error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
        }
    }

    /* ============================ MAPPING ============================ */

    private static EmailMessageDTO buildDTO(EmailMessage em) {
        EmailMessageDTO d = new EmailMessageDTO();
        d.emailMessageId = em.Id;
        d.subject        = em.Subject;
        d.htmlBody       = em.HtmlBody;
        d.textBody       = em.TextBody;
        d.messageDate    = em.MessageDate;
        return d;
    }

    /* ============================ HELPERS ============================ */

    /**
     * Accepts an Account Id or Contact Id as a trailing URL segment, or as a
     * "contactId"/"accountId"/"id" query parameter.
     */
    private static String getInputId() {
        RestRequest req = RestContext.request;
        if (req == null) { return null; }

        for (String paramName : new List<String>{'contactId', 'accountId', 'id'}) {
            String param = req.params.get(paramName);
            if (String.isNotBlank(param)) { return param.trim(); }
        }

        if (String.isNotBlank(req.requestURI)) {
            List<String> segments = req.requestURI.split('/');
            String last = segments.get(segments.size() - 1);
            if (String.isNotBlank(last) && !last.equalsIgnoreCase('v1')
                && !last.equalsIgnoreCase('contact-emails')) {
                return last.trim();
            }
        }
        return null;
    }

    private static void send(RestResponse res, Integer code, ServiceResponse out,
                             String status, String message) {
        out.status  = status;
        out.message = message;
        res.statusCode   = code;
        res.responseBody = Blob.valueOf(JSON.serializePretty(out, true));
    }
}