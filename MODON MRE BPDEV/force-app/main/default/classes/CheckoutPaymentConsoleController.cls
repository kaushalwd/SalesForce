/**********************************************************************************************
 * Name           : CheckoutPaymentConsoleController
 * Description     : Controller for the checkoutPaymentConsole LWC (list, actions, create-link-from-record).
 * Usage           : checkoutPaymentConsole LWC.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    25 Jun 2026    Initial version.
 * 1.1        Rushi Patel       11 Sep 2026    Console "Send Link" action. Two paths, both new:
 *                                             resendPaymentLink re-sends a still-payable link,
 *                                             regeneratePaymentLink mints a replacement for an
 *                                             expired one. Changes are marked // v1.1 inline.
 * 1.2        Rushi Patel       12 Sep 2026    getPayments now selects Dashboard_Status__c, the new
 *                                             formula field the console reads as EOI Status. The
 *                                             mapping moved out of the LWC so reports and list
 *                                             views show the same value.
 * 1.3        Prateek Bansal    14 Sep 2026    EOI links charge EOI_Amount_AED__c; the unused allocation field is dropped.
 * 1.4        Prateek Bansal    15 Sep 2026    Refresh writes the payment attempts the poll saw.
 * 1.5        Prateek Bansal    23 Sep 2026    List limit 500 to 2000; 508 rows had begun hiding the oldest.
 **********************************************************************************************/
public with sharing class CheckoutPaymentConsoleController {

    @AuraEnabled
    public static List<Checkout_Payment__c> getPayments(String status, Integer days, Id parentId) {
        Integer lookback = (days == null || days <= 0) ? 30 : days;
        Datetime cutoff = System.now().addDays(-lookback);
        // SOQL injection fix: status filter bound via queryWithBinds (no string concat of values).
        Map<String, Object> binds = new Map<String, Object>{ 'cutoff' => cutoff };
        String soql =
            'SELECT Id, Name, Status__c, Capture_Mode__c, Amount__c, Currency_Code__c, Payment_Id__c, ' +
            'Payment_Link_Id__c, Payment_Link_Url__c, Reference__c, Customer_Name__c, Customer_Email__c, ' +
            'Card_Scheme__c, Card_Last4__c, Issuer__c, Last_Checkout_Status__c, Last_Polled__c, Expires_On__c, CreatedDate, ' +
            'Dashboard_Status__c, ' + // v1.2 - sales-facing status, mapped by formula not by code
            'Expression_of_Interest__c, Expression_of_Interest__r.EOIId__c ' +
            'FROM Checkout_Payment__c WHERE CreatedDate >= :cutoff';
        
        if (parentId != null) {
            soql += ' AND Related_Record_Id__c = :parentId';
            binds.put('parentId', parentId);
        }
        
        if (String.isNotBlank(status) && status != 'All') {
            soql += ' AND Status__c = :status';
            binds.put('status', status);
        }
        // v1.5 - the console silently dropped the oldest rows once the window held more than the
        // limit, and said nothing. 508 rows inside 30 days hid CP-00000 to CP-00007.
        soql += ' ORDER BY CreatedDate DESC LIMIT 2000';
        return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
    }

    @AuraEnabled
    public static Checkout_Payment__c refreshStatus(Id recordId) {
        Checkout_Payment__c cp = load(recordId);
        CheckoutPaymentLinkService.applyLatestStatus(cp);
        update cp;
        CheckoutPaymentLinkService.flushAttempts();
        return reload(recordId);
    }

    @AuraEnabled
    public static Checkout_Payment__c capturePayment(Id recordId, Decimal amount) {
        return runAction(recordId, 'capture', amount);
    }

    @AuraEnabled
    public static Checkout_Payment__c refundPayment(Id recordId, Decimal amount) {
        return runAction(recordId, 'refund', amount);
    }

    @AuraEnabled
    public static Checkout_Payment__c voidPayment(Id recordId) {
        return runAction(recordId, 'void', null);
    }

    // v1.1 - NEW. Console "Send Link" for an expired link.
    /**
     * Console "Send Link" action for an EXPIRED link. Checkout.com has no way to extend or
     * reactivate an expired link, so a fresh one is minted from the old row's details - the
     * user is never asked to re-enter anything.
     *
     * A NEW Checkout_Payment__c is created rather than the expired row being updated, because
     * CheckoutPaymentPoller.start() only picks up rows whose CreatedDate is inside its lookback
     * window. Updating an old row would leave it permanently unpolled, so a captured payment
     * would never materialise its EOI.
     *
     * The after-insert trigger sends the link to the customer, so nothing is sent explicitly here.
     */
    @AuraEnabled
    public static Id regeneratePaymentLink(Id recordId) {
        Checkout_Payment__c prior = [
            SELECT Id, Status__c, Amount__c, Currency_Code__c, Capture_Mode__c,
                   Customer_Name__c, Customer_Email__c, Customer_Phone__c,
                   Related_Record_Id__c, Expression_of_Interest__c, Sales_Order_Installment__c,
                   EOI_Creation_Payload__c, Payment_Purpose__c
            FROM Checkout_Payment__c WHERE Id = :recordId LIMIT 1
        ];
        if (prior.Status__c != 'Expired') {
            throw new AuraHandledException('Only an expired payment link can be regenerated.');
        }
        if (prior.Amount__c == null || prior.Amount__c <= 0) {
            throw new AuraHandledException('This payment has no amount, so no link can be created.');
        }
        if (String.isBlank(prior.Customer_Email__c)) {
            throw new AuraHandledException('This payment has no customer email to send the new link to.');
        }

        CheckoutPaymentLinkService.Result r = String.isNotBlank(prior.EOI_Creation_Payload__c)
            ? regenerateFromEoiPayload(prior)
            : regenerateFromRow(prior);

        if (r == null || !r.isSuccess || r.paymentRecordId == null) {
            throw new AuraHandledException(
                r == null || String.isBlank(r.message) ? 'Could not create the payment link.' : r.message
            );
        }
        return r.paymentRecordId;
    }

    // v1.1 - NEW. EOI branch of regeneratePaymentLink.
    /**
     * Pay-first EOI link: EOI_Creation_Payload__c holds the exact JSON the eoiHomeJourney LWC sent,
     * so replaying it through the journey's own entry point reproduces the original link byte for
     * byte - same request shape, same customer resolution off the Opportunity, same stored payload.
     */
    private static CheckoutPaymentLinkService.Result regenerateFromEoiPayload(Checkout_Payment__c prior) {
        return EoiCheckoutPaymentController.sendPaymentLink(prior.EOI_Creation_Payload__c);
    }

    // v1.1 - NEW. Non-EOI branch of regeneratePaymentLink.
    /**
     * Console-created link (EOI balance / Sales Order installment): there is no journey payload to
     * replay, so the request is rebuilt from what the row itself stored.
     */
    private static CheckoutPaymentLinkService.Result regenerateFromRow(Checkout_Payment__c prior) {
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = prior.Amount__c;
        req.currencyCode = prior.Currency_Code__c;
        req.capture = prior.Capture_Mode__c != 'Authorize';
        req.customerName = prior.Customer_Name__c;
        req.customerEmail = prior.Customer_Email__c;
        req.customerPhoneNumber = prior.Customer_Phone__c;
        req.relatedRecordId = prior.Related_Record_Id__c;
        req.expressionOfInterestId = prior.Expression_of_Interest__c;
        req.salesOrderInstallmentId = prior.Sales_Order_Installment__c;
        req.description = prior.Payment_Purpose__c;
        // The console raises this on the customer's behalf, so the link message must go out.
        req.portalInitiated = false;
        // reference and expirySeconds are deliberately left unset: a fresh reference keeps the new
        // link's payments from colliding with the old one's, and the expiry falls back to config.
        return CheckoutPaymentLinkService.createLink(req);
    }

    // v1.1 - NEW. Console "Send Link" for a still-payable link.
    /**
     * Console "Send Link" action - re-sends the stored payment link to the customer.
     * No callout and no DML: the same URL and the same expiry go out again, so re-sending
     * can never move the clock. The service only queues payable rows with a link URL.
     */
    @AuraEnabled
    public static Integer resendPaymentLink(Id recordId) {
        Integer queued = CheckoutNotificationService.resendLink(new Set<Id>{ recordId });
        if (queued == 0) {
            throw new AuraHandledException(
                'This payment link could not be sent. The link must still be payable and have a link URL.'
            );
        }
        return queued;
    }

    private static Checkout_Payment__c runAction(Id recordId, String action, Decimal amount) {
        Checkout_Payment__c cp = load(recordId);
        if (String.isBlank(cp.Payment_Id__c)) {
            throw new AuraHandledException('This payment has no payment id yet - the customer has not paid the link.');
        }
        CheckoutPaymentLinkService.Result r;
        if (action == 'capture')      r = CheckoutPaymentLinkService.capturePayment(cp.Payment_Id__c, amount, cp.Currency_Code__c);
        else if (action == 'refund')  r = CheckoutPaymentLinkService.refundPayment(cp.Payment_Id__c, amount, cp.Currency_Code__c);
        else                          r = CheckoutPaymentLinkService.voidPayment(cp.Payment_Id__c);
        if (r == null || !r.isSuccess) {
            throw new AuraHandledException(r == null ? 'No response' : r.message);
        }
        return reload(recordId);
    }

    private static Checkout_Payment__c load(Id recordId) {
        return [
            SELECT Id, Reference__c, Payment_Id__c, Payment_Link_Id__c, Currency_Code__c, Status__c, Card_Last4__c,
                   Card_Scheme__c, Last_Checkout_Status__c, Last_Polled__c, Raw_Payload__c, Error_Message__c,
                   Expires_On__c
            FROM Checkout_Payment__c WHERE Id = :recordId LIMIT 1
        ];
    }

    private static Checkout_Payment__c reload(Id recordId) {
        return [
            SELECT Id, Name, Status__c, Capture_Mode__c, Amount__c, Currency_Code__c, Payment_Id__c,
                   Payment_Link_Id__c, Payment_Link_Url__c, Reference__c, Customer_Name__c, Customer_Email__c,
                   Card_Scheme__c, Card_Last4__c, Issuer__c, Last_Checkout_Status__c, Last_Polled__c, Expires_On__c, CreatedDate
            FROM Checkout_Payment__c WHERE Id = :recordId LIMIT 1
        ];
    }

    // ── Create a link from a business record (EOI / Sales Order Installment) ─────
    @AuraEnabled
    public static List<PayableOption> getPayableRecords(String sourceType, String searchKey) {
        // Bind-safe LIKE pattern (escapeSingleQuotes not needed / harmful when using binds).
        String searchLike = '%' + (searchKey == null ? '' : searchKey.trim()) + '%';
        List<PayableOption> options = new List<PayableOption>();

        if (sourceType == 'EOI') {
            for (Expressionofinterest__c e : [
                SELECT Id, Name, ProjectName__c, EOI_Amount_AED__c, CurrencyIsoCode, Customer_Email__c,
                       Contact__r.Name, Account__r.Name
                FROM Expressionofinterest__c
                WHERE EOI_Amount_AED__c > 0
                  AND (Name LIKE :searchLike OR ProjectName__c LIKE :searchLike OR Customer_Email__c LIKE :searchLike)
                ORDER BY LastModifiedDate DESC
                LIMIT 50
            ]) {
                PayableOption o = new PayableOption();
                o.recordId = e.Id;
                o.title = e.Name + (String.isNotBlank(e.ProjectName__c) ? ' · ' + e.ProjectName__c : '');
                o.subtitle = e.Customer_Email__c;
                o.amount = e.EOI_Amount_AED__c;
                o.currencyCode = e.CurrencyIsoCode;
                o.customerEmail = e.Customer_Email__c;
                o.customerName = e.Contact__r != null ? e.Contact__r.Name : (e.Account__r != null ? e.Account__r.Name : null);
                options.add(o);
            }
        } else if (sourceType == 'SO') {
            for (SalesOrderInstallments__c i : [
                SELECT Id, Name, Milestone_Name__c, MilestoneDate__c, Balance_Amount__c, CurrencyIsoCode,
                       SalesOrder__r.Name, SalesOrder__r.FormulaEmail__c, SalesOrder__r.FormulaAccountName__c
                FROM SalesOrderInstallments__c
                WHERE PaymentStatus__c IN ('Not Paid', 'Partially Paid')
                  AND Balance_Amount__c > 0
                  AND (Name LIKE :searchLike OR SalesOrder__r.Name LIKE :searchLike)
                ORDER BY MilestoneDate__c ASC NULLS LAST
                LIMIT 50
            ]) {
                PayableOption o = new PayableOption();
                o.recordId = i.Id;
                o.title = (i.SalesOrder__r != null ? i.SalesOrder__r.Name + ' · ' : '') +
                          (String.isNotBlank(i.Milestone_Name__c) ? i.Milestone_Name__c : i.Name);
                o.subtitle = i.MilestoneDate__c != null ? 'Due ' + String.valueOf(i.MilestoneDate__c) : i.Name;
                o.amount = i.Balance_Amount__c;
                o.currencyCode = i.CurrencyIsoCode;
                o.customerEmail = i.SalesOrder__r != null ? i.SalesOrder__r.FormulaEmail__c : null;
                o.customerName = i.SalesOrder__r != null ? i.SalesOrder__r.FormulaAccountName__c : null;
                options.add(o);
            }
        }
        return options;
    }

    @AuraEnabled
    public static CheckoutPaymentLinkService.Result createLinkFromRecord(String sourceType, Id recordId, Integer expirySeconds, Boolean capture) {
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.expirySeconds = expirySeconds;
        req.capture = capture;

        if (sourceType == 'EOI') {
            Expressionofinterest__c e = [
                SELECT Id, Name, ProjectName__c, EOI_Amount_AED__c, CurrencyIsoCode, Customer_Email__c,
                       Contact__r.Name, Contact__r.MobilePhone, Contact__r.Phone, Account__r.Name, Account__r.Phone
                FROM Expressionofinterest__c WHERE Id = :recordId LIMIT 1
            ];
            if (e.EOI_Amount_AED__c == null || e.EOI_Amount_AED__c <= 0) {
                throw new AuraHandledException('This EOI has no outstanding balance.');
            }
            req.amount = e.EOI_Amount_AED__c;
            req.currencyCode = e.CurrencyIsoCode;
            req.customerEmail = e.Customer_Email__c;
            req.customerName = e.Contact__r != null ? e.Contact__r.Name : (e.Account__r != null ? e.Account__r.Name : null);
            req.customerPhoneNumber = e.Contact__r != null && String.isNotBlank(e.Contact__r.MobilePhone) ? e.Contact__r.MobilePhone
                : (e.Contact__r != null && String.isNotBlank(e.Contact__r.Phone) ? e.Contact__r.Phone
                : (e.Account__r != null ? e.Account__r.Phone : null));
            req.description = 'EOI ' + e.Name + (String.isNotBlank(e.ProjectName__c) ? ' - ' + e.ProjectName__c : '');
            req.expressionOfInterestId = e.Id;
            req.relatedRecordId = e.Id;

            CheckoutPaymentLinkService.Product ep = new CheckoutPaymentLinkService.Product();
            ep.name = 'EOI ' + e.Name + (String.isNotBlank(e.ProjectName__c) ? ' – ' + e.ProjectName__c : '');
            ep.quantity = 1;
            ep.price = e.EOI_Amount_AED__c;
            req.products = new List<CheckoutPaymentLinkService.Product>{ ep };
        } else if (sourceType == 'SO') {
            SalesOrderInstallments__c i = [
                SELECT Id, Name, Milestone_Name__c, Instalment_Number__c, MilestoneDate__c,
                       Balance_Amount__c, CurrencyIsoCode, SalesOrder__r.Name, SalesOrder__r.ProjectName__c,
                       SalesOrder__r.Unit_Name__c, SalesOrder__r.FormulaEmail__c, SalesOrder__r.FormulaAccountName__c,
                       SalesOrder__r.PrimaryContact__r.MobilePhone, SalesOrder__r.PrimaryContact__r.Phone,
                       SalesOrder__r.CustomerAccount__r.Phone
                FROM SalesOrderInstallments__c WHERE Id = :recordId LIMIT 1
            ];
            if (i.Balance_Amount__c == null || i.Balance_Amount__c <= 0) {
                throw new AuraHandledException('This installment has no outstanding balance.');
            }
            req.amount = i.Balance_Amount__c;
            req.currencyCode = i.CurrencyIsoCode;
            req.customerEmail = i.SalesOrder__r != null ? i.SalesOrder__r.FormulaEmail__c : null;
            req.customerName = i.SalesOrder__r != null ? i.SalesOrder__r.FormulaAccountName__c : null;
            if (i.SalesOrder__r != null) {
                req.customerPhoneNumber =
                    i.SalesOrder__r.PrimaryContact__r != null && String.isNotBlank(i.SalesOrder__r.PrimaryContact__r.MobilePhone) ? i.SalesOrder__r.PrimaryContact__r.MobilePhone
                    : (i.SalesOrder__r.PrimaryContact__r != null && String.isNotBlank(i.SalesOrder__r.PrimaryContact__r.Phone) ? i.SalesOrder__r.PrimaryContact__r.Phone
                    : (i.SalesOrder__r.CustomerAccount__r != null ? i.SalesOrder__r.CustomerAccount__r.Phone : null));
            }
            req.description = (i.SalesOrder__r != null ? 'Sales Order ' + i.SalesOrder__r.Name + ' - ' : '') +
                              (String.isNotBlank(i.Milestone_Name__c) ? i.Milestone_Name__c : i.Name);
            req.salesOrderInstallmentId = i.Id;
            req.relatedRecordId = i.Id;

            // Detailed line item: "Project · Unit | Milestone (Installment N) | SO <name> · due <date>"
            List<String> segs = new List<String>();
            String unitLine = '';
            if (i.SalesOrder__r != null && String.isNotBlank(i.SalesOrder__r.ProjectName__c)) {
                unitLine = i.SalesOrder__r.ProjectName__c;
            }
            if (i.SalesOrder__r != null && String.isNotBlank(i.SalesOrder__r.Unit_Name__c)) {
                unitLine += (unitLine != '' ? ' · ' : '') + i.SalesOrder__r.Unit_Name__c;
            }
            if (unitLine != '') segs.add(unitLine);
            String msLine = String.isNotBlank(i.Milestone_Name__c) ? i.Milestone_Name__c : '';
            if (String.isNotBlank(i.Instalment_Number__c)) {
                msLine += (msLine != '' ? ' ' : '') + '(Installment ' + i.Instalment_Number__c + ')';
            }
            if (msLine != '') segs.add(msLine);
            String soLine = (i.SalesOrder__r != null && String.isNotBlank(i.SalesOrder__r.Name)) ? 'SO ' + i.SalesOrder__r.Name : '';
            if (i.MilestoneDate__c != null) {
                soLine += (soLine != '' ? ' · ' : '') + 'due ' + String.valueOf(i.MilestoneDate__c);
            }
            if (soLine != '') segs.add(soLine);

            CheckoutPaymentLinkService.Product sp = new CheckoutPaymentLinkService.Product();
            sp.name = segs.isEmpty() ? ('Installment ' + i.Name) : String.join(segs, ' | ');
            sp.quantity = 1;
            sp.price = i.Balance_Amount__c;
            req.products = new List<CheckoutPaymentLinkService.Product>{ sp };
        } else {
            throw new AuraHandledException('Unknown source type.');
        }

        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createLink(req);
        if (r == null || !r.isSuccess) {
            throw new AuraHandledException(r == null ? 'No response from Checkout.' : r.message);
        }
        return r;
    }

    public class PayableOption {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String customerEmail;
        @AuraEnabled public String customerName;
    }
}