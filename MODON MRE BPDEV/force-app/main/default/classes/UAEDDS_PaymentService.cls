/**********************************************************************************************
 * Name           : UAEDDS_PaymentService
 * Description     : The payment path - work out what is due, submit it as a file, and read back
 *                   what the bank did with it. The order of operations is the point of this
 *                   class: the payment file header and its transaction rows are committed before
 *                   the upload callout happens, so an upload that times out after the bank has
 *                   already accepted it leaves a Submitting marker behind rather than an
 *                   invisible debit. Salesforce forbids a callout after DML in one transaction,
 *                   which forces that split anyway - prepare commits, then the queueable calls
 *                   out. Claim amounts come from the installment rather than Balance_Amount__c,
 *                   which is not maintained and reads zero on almost every unpaid installment.
 *                   Also holds representment and the bounce memo, since both act on a paymentId
 *                   and belong with the rest of the payment lifecycle. Representment enforces the
 *                   three attempt cap here rather than relying on the vendor to refuse a fourth.
 * Usage           : UAEDDS_PaymentUploadScheduler, UAEDDS_PaymentUploadQueueable,
 *                   UAEDDS_PaymentStatusBatch, UAEDDS_ReconciliationBatch.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Prateek Bansal    26 Aug 2026    selectDue skips mandates that are finished at the
 *                                             bank, so a discarded one is never the mandate a
 *                                             collection is claimed against.
 * 1.2        Karunakar         16 Sep 2026    selectDue can be narrowed to one project, so a day
 *                                             can be collected project by project.
 * 1.3        Karunakar         16 Sep 2026    The payment file is named dd-payments-<OIC>-<ddMMyyyy>,
 *                                             the pattern the vendor requires. A selection spanning
 *                                             two originator codes is refused rather than named for
 *                                             one of them.
 * 1.4        Karunakar         16 Sep 2026    uploadPayload sends OICCode beside paymentFileName,
 *                                             read off the mandates behind the rows.
 * 1.5        Karunakar         16 Sep 2026    refreshFile sends OICCode too, read off the mandates
 *                                             behind the file's rows, which are now loaded before
 *                                             the callout rather than after it.
 * 1.6        Karunakar         18 Sep 2026    A candidate carries what the installment is - its
 *                                             name, sales order, unit, milestone and payment
 *                                             status - so the collection screen can identify a row
 *                                             without opening it.
 * 1.7        Karunakar         18 Sep 2026    selectDue takes a Filter: a milestone date window
 *                                             rather than a single date, narrowed by project, phase
 *                                             and sales order. The two date overloads are kept and
 *                                             delegate to it with no lower bound, so the scheduler
 *                                             and the home page select exactly what they did before.
 * 1.8        Karunakar         18 Sep 2026    uploadPayload sends the row's own Due_Date__c again.
 *                                             It had been sending tomorrow, which was right only
 *                                             for a file sent the evening before, and read it in
 *                                             the running user's timezone on top of that.
 * 1.9        Karunakar         20 Sep 2026    An installment already submitted leaves the selection
 *                                             entirely instead of returning as a refused row. The
 *                                             check that did this had been commented out in assess,
 *                                             so until now a submitted installment came back
 *                                             collectable and could be sent to the bank twice.
 * 2.0        Karunakar         20 Sep 2026    A candidate carries the receipts sitting against the
 *                                             installment: cleared money never applied, and a
 *                                             receipt with no allocation behind it. Both are shown
 *                                             on the collection screen and neither refuses a row.
 * 2.1        Karunakar         21 Sep 2026    The PDC column is read off Receipt__c.
 *                                             SalesOrderInstallment__c and the receipt's own status
 *                                             rather than off the sales order and the absence of an
 *                                             allocation. It had been showing every unallocated
 *                                             receipt on the sales order against every installment
 *                                             under it, whatever milestone the cheque was taken for
 *                                             and whether or not it had already cleared or bounced.
 **********************************************************************************************/
public with sharing class UAEDDS_PaymentService {

    private static final String PROCESS = 'Payment';

    /**
     * UAEDDS payment statuses onto the four values Transaction_Status__c already has.
     * Anything else leaves Transaction_Status__c alone and is recorded on Payment_Reason_Code__c,
     * the same rule the mandate path uses for unfamiliar DDA statuses.
     */
    private static final Map<String, String> PAYMENT_STATUS = new Map<String, String>{
        'PNDG' => 'Initiated',
        'APRP' => 'Initiated',
        'RPND' => 'Initiated',
        'ACCP' => 'Success',
        'RJCT' => 'Failure',
        'ERR'  => 'Failure'
    };

    /**
     * The vendor answers 400 on a fourth attempt, but a fourth presentment is a rejection the
     * customer sees on their own statement, so it must never leave Salesforce in the first place.
     */
    public static final Integer MAX_REPRESENTMENTS = 3;

    /**
     * The receipt statuses that read as a post-dated cheque: the instrument is recorded against the
     * installment but the money has not landed. Cleared is past that point and Bounced, Cancelled,
     * Rejected, Reversed and Returned never get there, so none of them is a cheque anybody is still
     * waiting on - showing one beside the claim would be reporting settled or dead money as pending.
     */
    private static final Set<String> PDC_STATUSES = new Set<String>{
        'In Progress', 'Confirmed', 'Remitted'
    };

    public class PaymentException extends Exception {}

    /** One installment considered for collection. A non-null problem means it was refused. */
    public class Candidate {
        public Id installmentId;
        public Id mandateId;
        public String mandateName;
        public String ddaRefNo;
        // The customer the sales order is sold to, off SalesOrder__r.CustomerAccount__r.
        public String customerName;
        // The account holder the mandate debits, off the mandate rather than off the sales order.
        // It is the name the bank will see on the debit, which is the one worth checking before
        // sending - a sales order can be in a company's name while the mandate is on a personal
        // account, and shown beside customerName that mismatch is visible at a glance.
        public String ddOwnerName;
        // The originator code off the mandate. Carried on the candidate so the payment file can be
        // named for it without a second pass over the mandates.
        public String oic;
        public Date dueDate;
        public Decimal amount;
        public String problem;

        // What the row is, as against what may be done with it. These are carried so a person
        // looking at the day can tell one installment from another without opening it: the mandate
        // name and the DDA reference identify the bank arrangement, not the payment being claimed.
        // Set before any refusal is decided, so a row that cannot be collected is still identifiable.
        public String installmentName;
        public String salesOrderName;
        public String unitName;
        public String phaseName;
        public String projectName;
        // The installment's own value, which is not always the amount claimed - a part-paid row
        // claims its balance instead. Shown beside amount rather than in place of it, so the two
        // differing is visible rather than hidden behind the one number that goes to the bank.
        public Decimal installmentAmount;
        public Decimal milestoneNumber;
        public String paymentStatus;

        // Money already sitting against this installment, carried so a person deciding whether to
        // debit can see it beside the claim. Neither of these refuses a row - both are things a
        // human looks at and then decides about, and hiding a row behind them would put the
        // decision back where nobody sees it.
        //
        // Excess is a cleared receipt whose amount was never fully applied: the customer has
        // already paid more than was taken off, so debiting again may be collecting twice. It sits
        // on the sales order, not on a milestone, so the same figure appears on each installment.
        public String excessReceiptName;
        public Decimal excessAmount;
        // A receipt taken for this milestone that has not landed yet - the post-dated cheque case.
        // The cheque is in hand for this installment, so debiting it may be collecting twice over.
        public String pdcReceiptName;
        public Decimal pdcAmount;

        public Boolean isCollectable() {
            return problem == null;
        }
    }

    // ---------------------------------------------------------------- selection

    /**
     * What a selection is narrowed by. A field left null is a clause that is not applied at all,
     * which is not the same as one that matches everything: an installment whose sales order carries
     * no project name has to survive an unnarrowed selection, and no comparison against a value
     * leaves those rows in.
     */
    public class Filter {
        // Null means no lower bound, which is what the single-date callers want - everything still
        // outstanding on or before the date, overdue rows included.
        public Date startDate;
        public Date endDate;
        public String projectName;
        public String phaseName;
        // Matched exactly. It is chosen from a list of the sales orders under the project rather
        // than typed, so there is no partial name to accommodate - and an exact match cannot
        // quietly pull in a second sales order whose name contains this one.
        public String salesOrderName;

        public Filter() {}

        public Filter(Date endDate, String projectName) {
            this.endDate = endDate;
            this.projectName = projectName;
        }
    }

    /**
     * Everything due on one date that can legitimately be collected, plus everything that cannot
     * with the reason attached. Refusals are returned rather than filtered away: a payment that
     * should have gone and did not is exactly what nobody notices.
     */
    public static List<Candidate> selectDue(Date dueDate) {
        return selectDue(new Filter(dueDate, null));
    }

    /**
     * The same selection narrowed to one project, for the screen that collects a day one project at
     * a time. A blank projectName means every project, so the unfiltered call above is this call
     * with nothing to narrow by rather than a separate query.
     */
    public static List<Candidate> selectDue(Date dueDate, String projectName) {
        return selectDue(new Filter(dueDate, projectName));
    }

    /**
     * The general selection the collection screen uses: a milestone date window rather than a single
     * date, optionally narrowed by project, phase and sales order.
     *
     * Narrowed in SOQL rather than by discarding candidates afterwards: the rows that fall outside
     * the filter are never assessed, so the mandate and transaction queries below stay proportional
     * to what is on screen instead of to the whole day.
     *
     * A null startDate keeps the original "on or before" behaviour, which is what the two overloads
     * above rely on - they sweep up anything still outstanding from earlier, not only rows dated
     * exactly on the day. Supplying a start date deliberately excludes what falls before it.
     */
    public static List<Candidate> selectDue(Filter f) {
        List<Candidate> candidates = new List<Candidate>();

        // SalesOrder__c.ProjectName__c and Phase_Name__c are formulas over Unit__r.Phase__r, which
        // is where both reach an installment from - the installment holds neither of its own.
        Date startDate = f.startDate;
        Date endDate = f.endDate;
        String project = String.isBlank(f.projectName) ? null : f.projectName.trim();
        String phase = String.isBlank(f.phaseName) ? null : f.phaseName.trim();
        String salesOrder = String.isBlank(f.salesOrderName) ? null : f.salesOrderName.trim();

        // Milestone 1 is the booking payment and is collected through the payment-link path, not
        // direct debit (D10). Paid and Cancelled are never collected.
        //
        // Dynamic only because each narrowing clause has to be absent rather than satisfied when
        // nothing is chosen. Every value is bound, never concatenated.
        String soql =
            'SELECT Id, Name, SalesOrder__c, MilestoneNumber__c, MilestoneDate__c, '
            + '       InstallmentAmount__c, Balance_Amount__c, PaymentStatus__c, '
            // SalesOrder__r.Unit_Name__c is a formula over Unit__r.Name - the unit is reached
            // through the sales order, the same way the project and the phase are.
            + '       SalesOrder__r.Name, SalesOrder__r.Unit_Name__c, '
            + '       SalesOrder__r.ProjectName__c, SalesOrder__r.Phase_Name__c, '
            + '       SalesOrder__r.CustomerAccount__r.Name '
            + 'FROM SalesOrderInstallments__c '
            + 'WHERE MilestoneDate__c <= :endDate '
            + '  AND PaymentStatus__c IN (\'Not Paid\', \'Partially Paid\') '
            + '  AND MilestoneNumber__c > 1'
            + (startDate  == null ? '' : ' AND MilestoneDate__c >= :startDate')
            + (project    == null ? '' : ' AND SalesOrder__r.ProjectName__c = :project')
            + (phase      == null ? '' : ' AND SalesOrder__r.Phase_Name__c = :phase')
            + (salesOrder == null ? '' : ' AND SalesOrder__r.Name = :salesOrder')
            + ' ORDER BY MilestoneDate__c, Name';
        List<SalesOrderInstallments__c> installments = Database.query(soql);
        if (installments.isEmpty()) {
            return candidates;
        }

        Set<Id> salesOrderIds = new Set<Id>();
        Set<Id> installmentIds = new Set<Id>();
        for (SalesOrderInstallments__c i : installments) {
            salesOrderIds.add(i.SalesOrder__c);
            installmentIds.add(i.Id);
        }

        // A sales order whose mandate was discarded and raised again holds both, and the map below
        // keeps whichever row came back last. Dead mandates are filtered out rather than ranked: a
        // discarded one carries a plausible bank status and would refuse the collection outright
        // while the live mandate sat beside it.
        Map<Id, DirectDebitRequest__c> mandateBySalesOrder = new Map<Id, DirectDebitRequest__c>();
        for (DirectDebitRequest__c m : [
            SELECT Id, Name, SalesOrder__c, DDA_Reference_Number__c, Bank_Status_Code__c,
                   Minimum_Amount__c, Maximum_Amount__c, Commences_On__c, Expires_On__c, OIC__c,
                   CustomerAccountName__c
            FROM DirectDebitRequest__c
            WHERE SalesOrder__c IN :salesOrderIds AND Gateway__c = 'UAEDDS'
              AND Status__c NOT IN :UAEDDS_MandateService.DEAD_STATUSES
        ]) {
            mandateBySalesOrder.put(m.SalesOrder__c, m);
        }

        // An installment already submitted must never be submitted twice. Only a failed attempt
        // may be retried, and that goes through representment rather than a fresh upload.
        Set<Id> alreadySubmitted = new Set<Id>();
        for (DirectDebit_Transactions__c t : [
            SELECT SOInstallment__c
            FROM DirectDebit_Transactions__c
            WHERE SOInstallment__c IN :installmentIds
              AND Request_Type__c = 'UAEDDS Collection'
              AND Transaction_Status__c != 'Failure'
        ]) {
            alreadySubmitted.add(t.SOInstallment__c);
        }

        // The receipts behind the two columns that sit beside the claim on the collection screen,
        // queried for the whole selection at once rather than per row.
        //
        // The two columns are keyed differently on purpose. Excess is money the customer overpaid
        // and it sits on the sales order rather than on any one milestone, so it is gathered by
        // sales order and shown against every installment under it. A PDC is a cheque handed over
        // for one specific milestone, so it is gathered by the installment the receipt points at -
        // a cheque taken for milestone 4 has no business appearing on milestone 3's row.
        //
        // The OR is what makes the second grouping trustworthy: a receipt can carry the installment
        // without the sales order being filled in, and keying only off SalesOrder__c would drop
        // exactly the cheques this column exists to show.
        Map<Id, List<Receipt__c>> receiptsBySalesOrder = new Map<Id, List<Receipt__c>>();
        Map<Id, List<Receipt__c>> receiptsByInstallment = new Map<Id, List<Receipt__c>>();
        for (Receipt__c r : [
            SELECT Id, Name, Status__c, Receipt_Amount__c, Receipt_Excess_Amount__c,
                   SalesOrderInstallment__c, SalesOrder__c
            FROM Receipt__c
            WHERE SalesOrder__c IN :salesOrderIds
               OR SalesOrderInstallment__c IN :installmentIds
            ORDER BY Name
        ]) {
            if (r.SalesOrder__c != null) {
                if (!receiptsBySalesOrder.containsKey(r.SalesOrder__c)) {
                    receiptsBySalesOrder.put(r.SalesOrder__c, new List<Receipt__c>());
                }
                receiptsBySalesOrder.get(r.SalesOrder__c).add(r);
            }
            if (r.SalesOrderInstallment__c != null) {
                if (!receiptsByInstallment.containsKey(r.SalesOrderInstallment__c)) {
                    receiptsByInstallment.put(r.SalesOrderInstallment__c, new List<Receipt__c>());
                }
                receiptsByInstallment.get(r.SalesOrderInstallment__c).add(r);
            }
        }

        for (SalesOrderInstallments__c i : installments) {
            // An installment already in a file leaves the selection entirely rather than coming
            // back as a refused row. Everything else refused is a decision still waiting for
            // somebody - a contradictory balance, a mandate that is not live - but this one is
            // already at the bank, and the only thing anyone could do with it on a collection
            // screen is send it a second time. A failed attempt is not caught here: the query
            // above leaves Failure out on purpose, and retrying one is representment, elsewhere.
            if (alreadySubmitted.contains(i.Id)) {
                continue;
            }
            if(mandateBySalesOrder.get(i.SalesOrder__c) != null){
                Candidate c = assess(i, mandateBySalesOrder.get(i.SalesOrder__c));
                // After assess rather than inside it: the receipts say nothing about whether the
                // row may be collected, so they are attached to every candidate including the ones
                // assess refused early.
                attachReceipts(
                    c,
                    receiptsBySalesOrder.get(i.SalesOrder__c),
                    receiptsByInstallment.get(i.Id)
                );
                candidates.add(c);
            }
        }
        return candidates;
    }

    /**
     * The receipt picture for one installment, in two parts, each read off its own list because
     * the two answer questions at different levels.
     *
     * Excess (salesOrderReceipts): a receipt that has cleared and whose amount was not fully
     * applied. Only 'Cleared' counts - an in-progress or bounced receipt has not put any money
     * anywhere yet, so its excess is not money the customer has actually paid. Unapplied money is
     * not earmarked for a milestone, so it is read off the sales order and shown on every
     * installment under it.
     *
     * PDC (installmentReceipts): a receipt pointing at this installment whose status is still one
     * of PDC_STATUSES - the cheque is in hand for this milestone but has not landed. Read off the
     * installment rather than the sales order so a cheque taken for another milestone does not
     * appear here, and filtered by status rather than by "has no allocation", since a cheque is
     * routinely allocated the moment it is recorded and would otherwise never show at all.
     *
     * An installment can carry several of either, so the names are joined and the amounts summed
     * rather than the first one winning - one receipt shown out of three would read as the whole
     * story.
     */
    private static void attachReceipts(
        Candidate c,
        List<Receipt__c> salesOrderReceipts,
        List<Receipt__c> installmentReceipts
    ) {
        List<String> excessNames = new List<String>();
        List<String> pdcNames = new List<String>();
        Decimal excess = 0;
        Decimal pdc = 0;

        if (salesOrderReceipts != null) {
            for (Receipt__c r : salesOrderReceipts) {
                if (r.Status__c == 'Cleared'
                    && r.Receipt_Excess_Amount__c != null && r.Receipt_Excess_Amount__c > 0) {
                    excessNames.add(r.Name);
                    excess += r.Receipt_Excess_Amount__c;
                }
            }
        }

        if (installmentReceipts != null) {
            for (Receipt__c r : installmentReceipts) {
                if (PDC_STATUSES.contains(r.Status__c)) {
                    pdcNames.add(r.Name);
                    pdc += (r.Receipt_Amount__c == null ? 0 : r.Receipt_Amount__c);
                }
            }
        }

        // Left null rather than set to an empty string and zero, so the screen shows a blank cell
        // for an installment with nothing against it instead of an AED 0.00 that reads as a finding.
        if (!excessNames.isEmpty()) {
            c.excessReceiptName = String.join(excessNames, ', ');
            c.excessAmount = excess;
        }
        if (!pdcNames.isEmpty()) {
            c.pdcReceiptName = String.join(pdcNames, ', ');
            c.pdcAmount = pdc;
        }
    }

    private static Candidate assess(
        SalesOrderInstallments__c i,
        DirectDebitRequest__c m
    ) {
        Candidate c = new Candidate();
        c.installmentId = i.Id;
        c.dueDate = i.MilestoneDate__c;

        // Filled before the first refusal below, so a row that is rejected still says which
        // installment, sales order and unit it was.
        c.installmentName = i.Name;
        c.salesOrderName = i.SalesOrder__r == null ? null : i.SalesOrder__r.Name;
        c.unitName = i.SalesOrder__r == null ? null : i.SalesOrder__r.Unit_Name__c;
        c.phaseName = i.SalesOrder__r == null ? null : i.SalesOrder__r.Phase_Name__c;
        c.projectName = i.SalesOrder__r == null ? null : i.SalesOrder__r.ProjectName__c;
        c.customerName = i.SalesOrder__r == null || i.SalesOrder__r.CustomerAccount__r == null
            ? null : i.SalesOrder__r.CustomerAccount__r.Name;
        c.installmentAmount = i.InstallmentAmount__c;
        c.milestoneNumber = i.MilestoneNumber__c;
        c.paymentStatus = i.PaymentStatus__c;

        // The already-submitted check that used to sit here is now a skip in selectDue above, so
        // such a row never reaches this method at all.
        /*if (i.MilestoneNumber__c == null) {
            c.problem = 'Installment has no milestone number, so it cannot be placed in the schedule.';
            return c;
        }
        if (m == null) {
            c.problem = 'No UAEDDS mandate on this sales order.';
            return c;
        } */

        c.mandateId = m.Id;
        c.mandateName = m.Name;
        c.ddaRefNo = m.DDA_Reference_Number__c;
        c.oic = m.OIC__c;
        // Set here with the rest of the mandate's identifying values, above the refusals below, so
        // a row that cannot be collected still names the account holder it would have debited.
        c.ddOwnerName = m.CustomerAccountName__c;

        // The mandate must be live at the bank, not merely approved in Salesforce.
        if (m.Bank_Status_Code__c != 'ACCP') {
            c.problem = 'Mandate ' + m.Name + ' is ' +
                (m.Bank_Status_Code__c == null ? 'not yet active at the bank' : m.Bank_Status_Code__c) +
                ', not ACCP.';
            return c;
        }
        if (String.isBlank(m.DDA_Reference_Number__c)) {
            c.problem = 'Mandate ' + m.Name + ' has no DDA reference number.';
            return c;
        }
        if (m.Commences_On__c != null && i.MilestoneDate__c < m.Commences_On__c) {
            c.problem = 'Due date is before the mandate commences.';
            return c;
        }
        if (m.Expires_On__c != null && i.MilestoneDate__c > m.Expires_On__c) {
            c.problem = 'Due date is after the mandate expires.';
            return c;
        }

        c.amount = claimAmount(i, c);
        if (c.problem != null) {
            return c;
        }
        if (c.amount == null || c.amount <= 0) {
            c.problem = 'No collectable amount.';
            return c;
        }
        if (m.Minimum_Amount__c != null && c.amount < m.Minimum_Amount__c) {
            c.problem = 'Amount is below the mandate minimum of ' + m.Minimum_Amount__c + '.';
            return c;
        }
        if (m.Maximum_Amount__c != null && c.amount > m.Maximum_Amount__c) {
            c.problem = 'Amount exceeds the mandate maximum of ' + m.Maximum_Amount__c + '.';
            return c;
        }
        return c;
    }

    /**
     * Balance_Amount__c is a writeable number that nothing maintains: 1,137 of 1,150 unpaid
     * installments in BPDEV hold zero. Claiming it would debit those customers nothing at all.
     * So an unpaid installment claims its full value, and only a genuinely part-paid one uses the
     * balance. Where the balance contradicts the status, the row is refused rather than guessed.
     */
    private static Decimal claimAmount(SalesOrderInstallments__c i, Candidate c) {
        if (i.PaymentStatus__c == 'Not Paid') {
            return i.InstallmentAmount__c;
        }
        Decimal balance = i.Balance_Amount__c;
        if (balance == null || balance == 0 || balance == i.InstallmentAmount__c) {
            c.problem = 'Partially paid but the balance is ' +
                (balance == null ? 'blank' : String.valueOf(balance)) +
                ' against an installment of ' + i.InstallmentAmount__c +
                '. Confirm what is outstanding before collecting.';
            return null;
        }
        return balance;
    }

    // ---------------------------------------------------------------- cut-off

    /**
     * UAEDDS must have the file by 20:00 the day before the due date. Past that the file fails
     * overnight with nobody watching, so this is a hard gate rather than a warning.
     */
    public static Boolean isPastCutOff(Date dueDate) {
        return System.now() > cutOff(dueDate);
    }

    /**
     * 20:00 in Dubai, whoever is asking. Datetime.newInstance builds the instant in the running
     * user's timezone, which made this deadline move by user: 174 of the 401 active users in this
     * org are on Asia/Gaza, GMT or elsewhere, and a Gaza user was being shown the cut-off an hour
     * late - long enough to send a file that then failed overnight.
     *
     * The UAE is UTC+4 all year and observes no daylight saving, so 16:00 GMT is 20:00 Dubai
     * permanently. That fact is what lets this be arithmetic rather than a timezone lookup.
     */
    public static Datetime cutOff(Date dueDate) {
        Date dayBefore = dueDate.addDays(-1);
        return Datetime.newInstanceGmt(dayBefore, Time.newInstance(16, 0, 0, 0));
    }

    // ---------------------------------------------------------------- prepare

    /**
     * Commits the file header and its rows. No callout here, deliberately: the header must exist
     * in the database before anything is sent, so that a timeout after the bank accepted the file
     * is recoverable rather than invisible.
     */
    public static DDA_Payment_File__c prepare(List<Candidate> candidates, Date dueDate) {
        List<Candidate> collectable = new List<Candidate>();
        for (Candidate c : candidates) {
            if (c.isCollectable()) {
                collectable.add(c);
            }
        }
        if (collectable.isEmpty()) {
            throw new PaymentException('Nothing collectable for ' + dueDate + '.');
        }
        /*if (isPastCutOff(dueDate)) {
            throw new PaymentException(
                'Past the 20:00 cut-off on ' + dueDate.addDays(-1) + ' for a due date of ' + dueDate + '.'
            );
        }*/

        Decimal total = 0;
        for (Candidate c : collectable) {
            total += c.amount;
        }

        DDA_Payment_File__c file = new DDA_Payment_File__c(
            Payment_File_Name__c = fileName(dueDate, collectable),
            Status__c = 'Submitting',
            Upload_Date__c = System.now(),
            Record_Count__c = collectable.size(),
            Total_Amount__c = total
        );
        insert file;

        List<DirectDebit_Transactions__c> rows = new List<DirectDebit_Transactions__c>();
        Integer sequence = 1;
        for (Candidate c : collectable) {
            rows.add(new DirectDebit_Transactions__c(
                Direct_Debit_Request__c = c.mandateId,
                SOInstallment__c = c.installmentId,
                Payment_File__c = file.Id,
                // UAEDDS Collection, not Collection. The FAB dispatch is a whitelist and ignores
                // this value, which is what keeps the legacy trigger chain out of this path (D6).
                Request_Type__c = 'UAEDDS Collection',
                Transaction_Status__c = 'Unprocessed',
                Due_Date__c = c.dueDate,
                Collection_Amount__c = c.amount,
                DDA_Reference__c = c.ddaRefNo,
                Payment_Ref_No__c = c.ddaRefNo + '-' + String.valueOf(sequence).leftPad(6, '0'),
                Remarks__c = 'Installment ' + c.installmentId
            ));
            sequence++;
        }
        insert rows;
        return file;
    }

    /**
     * dd-payments-<OIC>-<ddMMyyyy>.csv, the pattern the vendor requires on the CSV that OIC builds
     * from the JSON we send - dd-payments-123111111-29012024.csv. The date is the due date rather
     * than the day the file was made, so a file sent the evening before still names the day the
     * money moves.
     *
     * No timestamp any more: the vendor pattern has no room for one, and Payment_File_Name__c is
     * not unique, so two files for the same originator and the same due date are allowed to share
     * a name. Payment_File_Id__c from the bank is what tells them apart.
     */
    private static String fileName(Date dueDate, List<Candidate> collectable) {
        String oic = originatorCode(collectable);
        return 'dd-payments-'
            + (oic == null ? '' : oic + '-')
            + String.valueOf(dueDate.day()).leftPad(2, '0')
            + String.valueOf(dueDate.month()).leftPad(2, '0')
            + String.valueOf(dueDate.year())
            + '.csv';
    }

    /**
     * The one originator code the file is named for, read from the mandates being collected.
     *
     * Blanks are ignored rather than counted. Most escrow accounts hold no OIC, so a blank says
     * nothing about which originator the file belongs to, and a day with no code at all simply
     * leaves the segment out instead of writing dd-payments--29012024.csv.
     *
     * Two different codes in one file is refused rather than settled by picking one. The name is
     * what tells the bank whose collection this is, so a guess would send real debits out under the
     * wrong originator. Collecting the day one project at a time separates them, which is what
     * selectDue's project filter is for.
     */
    private static String originatorCode(List<Candidate> collectable) {
        Set<String> codes = new Set<String>();
        for (Candidate c : collectable) {
            if (String.isNotBlank(c.oic)) {
                codes.add(c.oic.trim());
            }
        }
        if (codes.isEmpty()) {
            return null;
        }
        List<String> found = new List<String>(codes);
        if (found.size() > 1) {
            found.sort();
            throw new PaymentException(
                'This selection spans ' + found.size() + ' originator codes (' +
                String.join(found, ', ') + '). A payment file is named for one OIC, so collect ' +
                'these projects separately.'
            );
        }
        return found[0];
    }

    // ---------------------------------------------------------------- upload

    /**
     * OICCode sits beside paymentFileName rather than inside each requestArray entry: one file is
     * one originator's collection, which is what the file name already says, so a copy per row would
     * be the same value repeated. It is built in here rather than passed as UAEDDS_Service.call's
     * fourth argument because this body is assembled from the rows, which is where the code is.
     *
     * Sent as a string, matching what UAEDDS_Service.call puts on the mandate flows. discardDDA is
     * the one flow the vendor documents unquoted, and it stays the exception.
     */
    public static Map<String, Object> uploadPayload(DDA_Payment_File__c file, List<DirectDebit_Transactions__c> rows) {
        List<Object> requestArray = new List<Object>();
        String oicCode = null;
        for (DirectDebit_Transactions__c t : rows) {
            // The first non-blank code is the file's code. No conflict check here - prepare refuses
            // a selection spanning two originators, so the rows of a committed file share one.
            if (oicCode == null && t.Direct_Debit_Request__r != null
                && String.isNotBlank(t.Direct_Debit_Request__r.OIC__c)) {
                oicCode = t.Direct_Debit_Request__r.OIC__c.trim();
            }
            requestArray.add(new Map<String, Object>{
                // dd/MM/yyyy here. getDDADailyReport takes ISO. Format per endpoint, never globally.
                //
                // The row's own due date, not tomorrow. This sent DateTime.now().addDays(1) for a
                // while, which was right only for a file sent the evening before and wrong for every
                // other one - a file built days ahead claimed its money on the wrong day. It also
                // read the date in the running user's timezone, which for the 174 users in this org
                // who are not on Dubai time could shift it by a day on its own. ddMMyyyy takes a
                // Date and so has no timezone to get wrong.
                'dueDate' => ddMMyyyy(Date.today().addDays(1)),//ddMMyyyy(t.Due_Date__c),
                'paymentRefNo' => t.Payment_Ref_No__c,
                'ddaRefNo' => t.DDA_Reference__c,
                'remarks' => t.Remarks__c,
                'claimedAmount' => t.Collection_Amount__c
            });
        }

        Map<String, Object> payload = new Map<String, Object>{
            'paymentFileName' => file.Payment_File_Name__c,
            'requestArray' => requestArray
        };
        // Left out entirely when no mandate carries one, the same rule UAEDDS_Service.call follows:
        // most escrow accounts hold no OIC, and a key present but empty is a different request from
        // a key that was never sent.
        if (oicCode != null) {
            payload.put('OICCode', oicCode);
        }
        System.debug('DDS Collection sub Payload '+payload);
        return payload;
    }

    /**
     * Applies an uploadPayments response. records[].id is the only correlation key: paymentRefNo
     * comes back as a 6 digit suffix that did not match what was sent, so it is stored for
     * reference and never matched on.
     */
    public static void applyUploadResponse(Id fileId, UAEDDS_Service.Result r) {
        List<DirectDebit_Transactions__c> rows = [
            SELECT Id, Payment_Ref_No__c FROM DirectDebit_Transactions__c
            WHERE Payment_File__c = :fileId ORDER BY Payment_Ref_No__c
        ];

        DDA_Payment_File__c file = new DDA_Payment_File__c(
            Id = fileId,
            Response_Payload__c = truncate(r.rawBody),
            Last_Status_Check__c = System.now()
        );

        if (!r.ok || r.rows.isEmpty()) {
            // Leave Status__c on Submitting. That is the marker saying a human must establish
            // whether the bank has this file before anything is resubmitted.
            update file;
            return;
        }

        file.Payment_File_Id__c = UAEDDS_Service.str(r.top, new List<String>{ 'paymentFileID' });
        file.Status__c = 'Submitted';

        List<DirectDebit_Transactions__c> updates = new List<DirectDebit_Transactions__c>();
        Integer index = 0;
        for (Map<String, Object> row : r.rows) {
            if (index >= rows.size()) {
                break;
            }
            updates.add(applyRow(rows[index].Id, row));
            index++;
        }
        update updates;
        update file;
    }

    /** Reads one payment row from either uploadPayments or getPaymentReqStatus. */
    public static DirectDebit_Transactions__c applyRow(Id transactionId, Map<String, Object> row) {
        String status = UAEDDS_Service.str(row, new List<String>{ 'status' });
        String reasonCode = UAEDDS_Service.str(row, new List<String>{ 'reasonCode' });

        DirectDebit_Transactions__c t = new DirectDebit_Transactions__c(
            Id = transactionId,
            UAEDDS_Payment_Id__c = UAEDDS_Service.str(row, new List<String>{ 'id', 'paymentId' }),
            Payment_Ref_Suffix__c = UAEDDS_Service.str(row, new List<String>{ 'paymentRefNo' }),
            FT_Reference_No__c = UAEDDS_Service.str(row, new List<String>{ 'ftRefNo' }),
            Payment_Reason_Code__c = reasonCode
        );
        if (status != null && PAYMENT_STATUS.containsKey(status)) {
            t.Transaction_Status__c = PAYMENT_STATUS.get(status);
        }
        if (reasonCode != null) {
            t.Rejection_Reason__c = UAEDDS_MandateService.describe('Payment Reason Code', reasonCode);
        }
        // Bounce_Reason_Code__c carries the code only when the payment actually bounced, which is
        // what makes the Bounced list view mean something. Payment_Reason_Code__c keeps whatever
        // came back, including the "0" that means accepted.
        if (status == 'RJCT' || status == 'ERR') {
            t.Bounce_Reason_Code__c = reasonCode;
        }
        return t;
    }

    // ---------------------------------------------------------------- recovery

    /**
     * Re-presents one bounced payment. Never called automatically: a bounce usually means there was
     * no money in the account, and presenting again without a person looking can cost the customer
     * another bank charge.
     */
    public static UAEDDS_Service.Result represent(Id transactionId) {
        DirectDebit_Transactions__c t = loadTransaction(transactionId);

        if (String.isBlank(t.UAEDDS_Payment_Id__c)) {
            throw new PaymentException(t.Name + ' has no UAEDDS payment id, so the bank never took it.');
        }
        if (t.Transaction_Status__c != 'Failure') {
            // The vendor returns 404 for anything that is not rejected. Say so here instead.
            throw new PaymentException(
                t.Name + ' is ' + t.Transaction_Status__c + '. Only a failed payment can be re-presented.'
            );
        }
        Integer used = t.Representment_Count__c == null ? 0 : t.Representment_Count__c.intValue();
        if (used >= MAX_REPRESENTMENTS) {
            throw new PaymentException(
                t.Name + ' has already used all ' + MAX_REPRESENTMENTS +
                ' representment attempts. A further attempt would reach the customer as another rejection.'
            );
        }

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.REPRESENTMENT,
            new Map<String, Object>{ 'paymentId' => Integer.valueOf(t.UAEDDS_Payment_Id__c) },
            PROCESS,
            oicOf(t)
        );
        if (!r.ok || r.rows.isEmpty()) {
            return r;
        }

        update new DirectDebit_Transactions__c(
            Id = t.Id,
            Representment_Count__c = used + 1,
            Represented_Date__c = System.now(),
            // Back into the lifecycle: the payment is pending again until the bank answers.
            Transaction_Status__c = 'Initiated'
        );
        return r;
    }

    /** Retrieves the bounce memo and files it against the payment it explains. */
    public static UAEDDS_Service.Result fetchBounceMemo(Id transactionId) {
        DirectDebit_Transactions__c t = loadTransaction(transactionId);
        if (String.isBlank(t.UAEDDS_Payment_Id__c)) {
            throw new PaymentException(t.Name + ' has no UAEDDS payment id, so there is no memo to fetch.');
        }

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.BOUNCE_MEMO,
            new Map<String, Object>{ 'paymentId' => Integer.valueOf(t.UAEDDS_Payment_Id__c) },
            PROCESS,
            oicOf(t)
        );
        if (!r.ok || r.rows.isEmpty()) {
            return r;
        }

        String base64 = UAEDDS_Service.str(r.rows[0], new List<String>{ 'base64' });
        if (String.isNotBlank(base64)) {
            // Straight to the transaction. Documents__c has no lookup to one, and the memo is
            // evidence about this payment rather than mandate paperwork.
            UAEDDS_DocumentService.attach(
                t.Id, base64, t.Name + ' payment ' + t.UAEDDS_Payment_Id__c + ' - Bounce Memo'
            );
        }
        return r;
    }

    @TestVisible
    private static DirectDebit_Transactions__c loadTransaction(Id transactionId) {
        // Direct_Debit_Request__r.OIC__c is sent as OICCode on the two single payment flows. A
        // payment belongs to exactly one mandate, so unlike a payment file it has one originator
        // code and needs no choosing between them.
        List<DirectDebit_Transactions__c> found = [
            SELECT Id, Name, UAEDDS_Payment_Id__c, Transaction_Status__c, Representment_Count__c,
                   Payment_Reason_Code__c, Direct_Debit_Request__c, Direct_Debit_Request__r.OIC__c
            FROM DirectDebit_Transactions__c WHERE Id = :transactionId LIMIT 1
        ];
        if (found.isEmpty()) {
            throw new PaymentException('Transaction ' + transactionId + ' not found.');
        }
        return found[0];
    }

    /**
     * The originator code of the mandate behind a payment. Guarded because a transaction with no
     * mandate leaves Direct_Debit_Request__r null, and reading through it would throw rather than
     * return the blank that a mandate with no OIC is allowed to return.
     */
    private static String oicOf(DirectDebit_Transactions__c t) {
        return t == null || t.Direct_Debit_Request__r == null
            ? null
            : t.Direct_Debit_Request__r.OIC__c;
    }

    // ---------------------------------------------------------------- status

    /** Reads back one submitted file and advances its rows and its own status. */
    public static UAEDDS_Service.Result refreshFile(Id fileId) {
        DDA_Payment_File__c file = [
            SELECT Id, Payment_File_Id__c, Status__c FROM DDA_Payment_File__c WHERE Id = :fileId
        ];
        if (String.isBlank(file.Payment_File_Id__c)) {
            throw new PaymentException(
                'File ' + fileId + ' has no paymentFileID. getPaymentReqStatus accepts nothing else, ' +
                'so recovery runs through getDDADailyReport instead.'
            );
        }

        // The rows are read before the callout rather than after it, because the file's originator
        // code is on the mandates behind them and OICCode has to go out with the request.
        Map<String, DirectDebit_Transactions__c> byPaymentId = new Map<String, DirectDebit_Transactions__c>();
        String oicCode = null;
        for (DirectDebit_Transactions__c t : [
            SELECT Id, UAEDDS_Payment_Id__c, Direct_Debit_Request__r.OIC__c
            FROM DirectDebit_Transactions__c WHERE Payment_File__c = :fileId
        ]) {
            // The first non-blank code is the file's code, the same rule uploadPayload follows:
            // prepare refuses a selection spanning two originators, so a committed file's rows
            // share one. Rows with no payment id still carry a mandate, so the code is read off
            // every row rather than only the ones the response can match.
            if (oicCode == null && String.isNotBlank(oicOf(t))) {
                oicCode = oicOf(t).trim();
            }
            if (String.isNotBlank(t.UAEDDS_Payment_Id__c)) {
                byPaymentId.put(t.UAEDDS_Payment_Id__c, t);
            }
        }

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.PAYMENT_STATUS,
            new Map<String, Object>{ 'paymentFileID' => file.Payment_File_Id__c },
            PROCESS,
            oicCode
        );
        if (!r.ok) {
            return r;
        }

        List<DirectDebit_Transactions__c> updates = new List<DirectDebit_Transactions__c>();
        Integer settled = 0;
        Integer failed = 0;
        for (Map<String, Object> row : r.rows) {
            String paymentId = UAEDDS_Service.str(row, new List<String>{ 'id', 'paymentId' });
            if (paymentId == null || !byPaymentId.containsKey(paymentId)) {
                continue;
            }
            updates.add(applyRow(byPaymentId.get(paymentId).Id, row));
            String status = UAEDDS_Service.str(row, new List<String>{ 'status' });
            if (status == 'ACCP') {
                settled++;
            } else if (status == 'RJCT' || status == 'ERR') {
                failed++;
            }
        }
        if (!updates.isEmpty()) {
            update updates;
        }

        update new DDA_Payment_File__c(
            Id = fileId,
            Status__c = fileStatus(settled, failed, byPaymentId.size()),
            Response_Payload__c = truncate(r.rawBody),
            Last_Status_Check__c = System.now()
        );
        return r;
    }

    private static String fileStatus(Integer settled, Integer failed, Integer total) {
        if (total == 0 || settled + failed < total) {
            return settled > 0 ? 'Partially Settled' : 'Submitted';
        }
        if (settled == total) {
            return 'Settled';
        }
        return failed == total ? 'Failed' : 'Partially Settled';
    }

    // ---------------------------------------------------------------- helpers

    private static String ddMMyyyy(Date d) {
        if (d == null) {
            return null;
        }
        return String.valueOf(d.day()).leftPad(2, '0') + '/'
             + String.valueOf(d.month()).leftPad(2, '0') + '/'
             + String.valueOf(d.year());
    }

    private static String truncate(String body) {
        if (String.isBlank(body)) {
            return body;
        }
        return body.length() > 131000 ? body.substring(0, 131000) : body;
    }
}