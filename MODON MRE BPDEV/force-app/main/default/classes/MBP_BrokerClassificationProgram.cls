/* Version       Author                              Date                 Comment
* 1.0           sanath.manohar@modon.com                         Initial Draft
* 1.1           Upendra.assam@activemindsit.com                          Broker Monthly performance logic
* 1.2           raghu.chilukuri@activemindsit.com    16 April 2026       Aspire Dashboard Method Addition
* 1.3           Upendra.assam@activemindsit.com                          Adjustment of Broker Monthly Logic
* 1.4           raghu.chilukuri@activemindsit.com    20 april 2026       Added Period field Logic
* 1.5           raghu.chilukuri@activemindsit.com    22 april 2026       Changed SendDowngraded emails Method to sendEmails Method and Added Upgrade and Downgrade date email too
* 1.6           upendra.asam@modon.com               16/06/26            I have done multiple changes in this batch apex to handle the broker classification.
* 1.7           sanath.manohar@modon.com     07 July 2026        Broker_Monthly_Performance__c is now upserted per Broker_Agency__c/Month__c/Year__c
*                                                                        instead of being skipped when a record already exists for the period.
* 1.8                                                09 July 2026        Added a configurable runDate. The rolling 12-month window, the monthly
*                                                                        sales aggregate, the downgrade-warning clock and the Month__c/Year__c
*                                                                        stamps are now all derived from runDate instead of System.today().
                                                                               bodyContent was missing. Every other paragraph is unchanged.
*                                                                            No other logic changed.
* 5.1           upendra.asam@modon.com               04 Sep 2026         Aspire classification emails now send from aspire@modon.com instead of
*                                                                        the shared noreply@modon.com default. Switched the send call from
*                                                                        BP_SendGridUtilityClass.sendEmail() (hardcoded to noreply@modon.com and
*                                                                        used by other processes -- left untouched) to
*                                                                        BP_SendGridUtilityClass.sendEmailWithAttachments(), which already accepts
*                                                                        an explicit fromEmail. No attachments are sent from this class, so an
*                                                                        empty list is passed. Nothing else in sendEmails() changed.
* 5.2           upendra.asam@modon.com               04 Sep 2026         Welcome (UPGRADE) emails for Principal, Maestro and Ambassador -- the
*                                                                        "explore more at aspire.modon.com" closing paragraph (with its tracked
*                                                                        safelinks/marketing-link wrapper) has been replaced with a plain
*                                                                        "Please feel free to contact us on aspire@modon.com" mailto line, matching
*                                                                        the wording already used in the WARNING/DOWNGRADE/TERMINATION emails.
*                                                                        Nothing else in WELCOME_TEMPLATES changed.
* 6.0           upendra.asam@modon.com               04 Sep 2026         Resale process change: transfers now use ONE SalesOrder__c (no second
*                                                                        "Property Transfer Cancelled - SR" record). Sales-order-to-broker-agency
*                                                                        attribution must now replicate the Sales Order's BrokerAgency__c FORMULA
*                                                                        FIELD logic (Old_Opportunity__r.BrokerAgency__c wins when populated, else
*                                                                        Opportunity__r.BrokerAgency__c) so a transferred sale keeps crediting the
*                                                                        ORIGINAL broker agency once the cancelled leg no longer exists to exclude
*                                                                        itself. This attribution cannot be expressed as a SOQL GROUP BY key (SOQL
*                                                                        cannot GROUP BY a conditional/fallback expression), so the three separate
*                                                                        AggregateResult/GROUP BY queries (rolling-12, lifetime, monthly) have been
*                                                                        replaced with ONE raw-row query pulling Opportunity__r.BrokerAgency__c AND
*                                                                        Old_Opportunity__r.BrokerAgency__c as Ids, with the fallback resolved and
*                                                                        summed in Apex (see resolveEffectiveAgencyId() and the single loop below).
*                                                                        Same WHERE filters as before (date window, Unit__c/Unit__r.Status__c,
*                                                                        Sales_Type__c, EXCLUDED_SO_STATUSES, EXCLUDED_SOURCE_ENTITY) are preserved
*                                                                        exactly -- only the query shape and the attribution key changed. No other
*                                                                        logic in this class (classification, emails, monthly performance) changed.
*/
global class MBP_BrokerClassificationProgram implements Database.Batchable<sObject>, Database.Stateful, Schedulable, Database.AllowsCallouts {

    public List<Broker_Classification__c> classificationTiers;

    /* ------------------------------------------------------------------
* Version 2.5 (fix requested 21 July 2026) -- SalesOrder__c Status__c
* values that must be EXCLUDED from every sales aggregate query (rolling
* 12-month, lifetime, monthly). Kept as a single shared set so all three
* attribution passes stay in sync if this list ever changes.
* ------------------------------------------------------------------ */
    private static final Set<String> EXCLUDED_SO_STATUSES = new Set<String>{
        'Cancelled',
            'System cancelled',
            'Cancelled SR',
            'Voided',
            'Pending Blocking Fees',
            'Blocking Fees Collected',
            'Unit Swap Cancelled - SR',
            'Unit Upgrade Cancelled - SR',
            'Unit Cancellation Cancelled - SR',
            'Unit Consolidation Cancelled - SR',
            'Property Transfer Cancelled - SR',
            'Property Transfer Title Deed Cancelled - SR'
    };

    /* Version 2.5 -- Source_Entity__c value to exclude from every sales
* aggregate query. */
    private static final String EXCLUDED_SOURCE_ENTITY = 'Modon - Egypt';

    /* Version 2.6 -- how close (as a fraction of the next tier's minimum
* threshold) an account's rolling-12-month sales need to be before the
* PRE_PROMOTION nudge fires. 0.80 = 80%. Change this single constant to
* tune how early the nudge kicks in. */
    private static final Decimal PRE_PROMOTION_THRESHOLD_PCT = 0.70;

    /* ------------------------------------------------------------------
* Version 1.8 -- runDate is the "pretend today" for this execution.
* Database.Stateful keeps it alive across all chunks of the batch.
* ------------------------------------------------------------------ */
    public Date runDate;

    /* Version 1.9 -- when true, no SendGrid callout is made. Everything else
* (classification, warning dates, monthly performance records) still runs,
* so you can verify the transitions without emailing real brokers. */
    public Boolean dryRun = false;


    public Boolean isInitialRun = false;

    /* Version 1.9 -- contacts pre-queried once per chunk, keyed by AccountId. */
    private Map<Id, List<Contact>> contactsByAccount = new Map<Id, List<Contact>>();


    global MBP_BrokerClassificationProgram() {
        this.runDate = System.today();
    }

    // Month only -> that month in the CURRENT year.
    global MBP_BrokerClassificationProgram(Integer month) {
        this.runDate = resolveRunDate(month, null);
    }

    // Month + year. Either may be null and falls back to today's value.
    global MBP_BrokerClassificationProgram(Integer month, Integer year) {
        this.runDate = resolveRunDate(month, year);
    }

    // Month + year + dry run.
    global MBP_BrokerClassificationProgram(Integer month, Integer year, Boolean dryRun) {
        this.runDate = resolveRunDate(month, year);
        this.dryRun  = (dryRun == null) ? false : dryRun;
    }


    global MBP_BrokerClassificationProgram(Integer month, Integer year, Boolean dryRun, Boolean isInitialRun) {
        this.runDate      = resolveRunDate(month, year);
        this.dryRun       = (dryRun == null) ? false : dryRun;
        this.isInitialRun = (isInitialRun == null) ? false : isInitialRun;
    }

    // Explicit date -> that date's month. Null falls back to today.
    global MBP_BrokerClassificationProgram(Date referenceDate) {
        this.runDate = (referenceDate == null) ? System.today() : referenceDate;
    }

    /* Central fallback logic. Anything null becomes today's value.
* Day is pinned to the 1st because only the month matters downstream. */
    public static Date resolveRunDate(Integer month, Integer year) {
        Date todayDate = System.today();

        Integer m = (month == null) ? todayDate.month() : month;
        Integer y = (year  == null) ? todayDate.year()  : year;

        if (m < 1 || m > 12) {
            throw new IllegalArgumentException('Month must be 1-12. Received: ' + m);
        }
        return Date.newInstance(y, m, 1);
    }


    global void execute(SchedulableContext ctx) {
        // No month -> current month.
        Database.executeBatch(new MBP_BrokerClassificationProgram(), 50);
    }

    global List<Account> start(Database.BatchableContext context) {

        if (runDate == null) { runDate = System.today(); }   // safety net
        if (dryRun  == null) { dryRun  = false;           }

        String currentYear = String.valueOf(runDate.year());

        classificationTiers = [
            SELECT Id, AnnualSalesTargetFrom__c, AnnualSalesTargetTo__c,
            AnnualSalesTargetFromInternational__c, AnnualSalesTargetToInternational__c, Name
            FROM Broker_Classification__c
            WHERE Year__c = :currentYear
            ORDER BY AnnualSalesTargetFrom__c
        ];

        System.debug('START: runDate=' + runDate + ', dryRun=' + dryRun
                     + ', tiers loaded=' + classificationTiers.size());

        if (classificationTiers.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                         'No Broker_Classification__c rows for Year__c = ' + currentYear
                         + '. Every account will be skipped and no emails will send.');
        }

        Id brokerRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Broker_Agency')
            .getRecordTypeId();

        return [
            SELECT Id, Name, Broker_Classification__c, ParentId, Agency_Region__c,
            Parent.Broker_Classification__c, ClassificationSalesAmount__c,
            Downgrade_Warning_Date__c, Company_Email_Address__c, Owner.Email
            FROM Account
            WHERE RecordTypeId = :brokerRecordTypeId 

        ];
    }

    global void execute(Database.BatchableContext context, List<Account> brokerAccounts) {

        if (runDate == null) { runDate = System.today(); }   // safety net
        if (dryRun  == null) { dryRun  = false; }

        final String REGION_DOMESTIC = 'Domestic';
        final String REGION_INTERNATIONAL = 'International';

        Map<Id, Account> accountMap = new Map<Id, Account>(brokerAccounts);
        Map<Id, Set<Id>> childAccountsMap = new Map<Id, Set<Id>>();
        Set<Id> allAccountIds = new Set<Id>(accountMap.keySet());

        for (Account child : [
            SELECT Id, ParentId FROM Account
            WHERE ParentId IN :accountMap.keySet()
        ]) {
            allAccountIds.add(child.Id);
            if (!childAccountsMap.containsKey(child.ParentId)) {
                childAccountsMap.put(child.ParentId, new Set<Id>());
            }
            childAccountsMap.get(child.ParentId).add(child.Id);
        }

        // ------------------------------------------------------------------
        // Version 1.9: pre-query recipients ONCE, not once per account inside
        // sendEmails(). Previously this was a SOQL call in a loop.
        // ------------------------------------------------------------------
        contactsByAccount = new Map<Id, List<Contact>>();
        for (Contact con : [
            SELECT Id, Email, AccountId
            FROM Contact
            WHERE AccountId IN :accountMap.keySet()
            AND Broker_Type__c IN ('Owner', 'Agency Admin')
            AND Email != null
            AND Agent_Status__c = 'Active'
        ]) {
            if (!contactsByAccount.containsKey(con.AccountId)) {
                contactsByAccount.put(con.AccountId, new List<Contact>());
            }
            contactsByAccount.get(con.AccountId).add(con);
        }
        System.debug('Recipient map built for ' + contactsByAccount.size() + ' account(s).');

        //Update version 1.4 for the Period Value Calculation
        //Update version 1.8 -- driven by runDate, not System.today()
        Date today = runDate;

        Date endDate   = today.toStartOfMonth().addDays(-1);
        Date startDate = endDate.addMonths(-11).toStartOfMonth();

        // Version 2.8 -- CreatedDate is a DateTime field, so the rolling
        // 12-month window's upper bound is applied as an EXCLUSIVE
        // "< endDateExclusive" comparison (the day AFTER endDate) so that
        // Sales Orders created any time on endDate itself are still counted,
        // not just the ones created before midnight.
        Date endDateExclusive = endDate.addDays(1);

        String startMonth = Datetime.newInstance(startDate, Time.newInstance(0,0,0,0)).format('MMMM yyyy');
        String endMonth   = Datetime.newInstance(endDate,   Time.newInstance(0,0,0,0)).format('MMMM yyyy');

        String periodValue = startMonth + ' - ' + endMonth;

        System.debug('Period Calculation: RunDate=' + today + ', StartDate=' + startDate
                     + ', EndDate=' + endDate + ', Period=' + periodValue);

        // Update version 1.8: month/year of the aggregate now come from runDate.
        Integer runMonth = today.month();
        Integer runYear  = today.year();

        Map<Id, SalesInfo> agencySalesMap  = new Map<Id, SalesInfo>();  // rolling 12 months
        Map<Id, Decimal>   totalSalesMap   = new Map<Id, Decimal>();    // lifetime
        Map<Id, Decimal>   monthlySalesMap = new Map<Id, Decimal>();    // current calendar month

        for (SalesOrder__c so : [
            SELECT TotalAmount__c, CreatedDate,
                   Opportunity__r.BrokerAgency__c,
                   Old_Opportunity__r.BrokerAgency__c
            FROM SalesOrder__c
            WHERE (Opportunity__r.BrokerAgency__c IN :allAccountIds
                   OR Old_Opportunity__r.BrokerAgency__c IN :allAccountIds)
            AND Unit__c != null
            AND Unit__r.Status__c = 'Sold'
            AND Sales_Type__c = 'Indirect'
            AND Status__c NOT IN :EXCLUDED_SO_STATUSES
            AND Source_Entity__c != :EXCLUDED_SOURCE_ENTITY
        ]) {

            Id effectiveAgencyId = resolveEffectiveAgencyId(so);

            if (effectiveAgencyId == null || !allAccountIds.contains(effectiveAgencyId)) {
                continue;
            }

            Decimal amt = (so.TotalAmount__c == null) ? 0 : so.TotalAmount__c;
            Date soDate = (so.CreatedDate == null) ? null : so.CreatedDate.date();

            // Lifetime -- every qualifying row, no date filter.
            totalSalesMap.put(effectiveAgencyId,
                (totalSalesMap.containsKey(effectiveAgencyId) ? totalSalesMap.get(effectiveAgencyId) : 0) + amt);

            // Rolling 12 months -- same exclusive upper-bound rule as v2.8.
            if (soDate != null && soDate >= startDate && soDate < endDateExclusive) {
                SalesInfo info = agencySalesMap.get(effectiveAgencyId);
                if (info == null) {
                    info = new SalesInfo(0, 0);
                    agencySalesMap.put(effectiveAgencyId, info);
                }
                info.totalSaleCount++;
                info.totalSalesAmount += amt;
            }

            // Current calendar month (same CALENDAR_MONTH/CALENDAR_YEAR intent as before).
            if (soDate != null && soDate.month() == runMonth && soDate.year() == runYear) {
                monthlySalesMap.put(effectiveAgencyId,
                    (monthlySalesMap.containsKey(effectiveAgencyId) ? monthlySalesMap.get(effectiveAgencyId) : 0) + amt);
            }
        }

        Map<Id, Id> oldClassificationMap = new Map<Id, Id>();

        for (Account acc : accountMap.values()) {

            Decimal netSales = agencySalesMap.containsKey(acc.Id)
                ? agencySalesMap.get(acc.Id).totalSalesAmount
                : 0;
            Decimal totalSales = totalSalesMap.containsKey(acc.Id)
                ? totalSalesMap.get(acc.Id)
                : 0;

            Id oldClassification = acc.Broker_Classification__c;
            oldClassificationMap.put(acc.Id, oldClassification);

            Id newClassification;

            for (Broker_Classification__c tier : classificationTiers) {

                if (acc.Agency_Region__c == REGION_DOMESTIC &&
                    netSales >= tier.AnnualSalesTargetFrom__c &&
                    netSales <= tier.AnnualSalesTargetTo__c) {
                        newClassification = tier.Id;
                        break;
                    }
                if (acc.Agency_Region__c == REGION_INTERNATIONAL &&
                    netSales >= tier.AnnualSalesTargetFromInternational__c &&
                    netSales <= tier.AnnualSalesTargetToInternational__c) {
                        newClassification = tier.Id;
                        break;
                    }
            }

            System.debug('ACC ' + acc.Id + ' | netSales=' + netSales
                         + ' | old=' + getTierNameById(oldClassification)
                         + ' | new=' + getTierNameById(newClassification)
                         + ' | warnDate=' + acc.Downgrade_Warning_Date__c);

            // Version 2.6: tracks whether a WARNING/DOWNGRADE/UPGRADE email
            // was already sent for this account this run. PRE_PROMOTION is
            // only ever evaluated when none of those fired, so an account
            // still gets at most one email per run.
            Boolean classificationEmailSent = false;

            if (oldClassification != null && newClassification != null && oldClassification != newClassification) {

                Integer oldIndex = getTierIndex(oldClassification);
                Integer newIndex = getTierIndex(newClassification);

                if (newIndex < oldIndex) {
                    if (acc.Downgrade_Warning_Date__c == null) {
                        // First time we see the drop -> warn, hold the old tier.
                        acc.Downgrade_Warning_Date__c = today;   // v1.8: stamped with runDate

                        sendEmails(acc, oldClassification, newClassification, 'WARNING', netSales);
                        classificationEmailSent = true;
                        acc.Broker_Classification__c = oldClassification;
                    } else if (acc.Downgrade_Warning_Date__c.addMonths(1) <= today) {
                        // Grace period expired -> actually downgrade.  v1.8: measured against runDate
                        acc.Broker_Classification__c = newClassification;
                        acc.Downgrade_Warning_Date__c = null;
                        // ------------------------------------------------------------------
                        // Version 4.0 -- route to TERMINATION instead of DOWNGRADE when the
                        // landing tier is no longer an Aspire tier at all (Standard/blank --
                        // i.e. the broker has dropped below the Principal floor and is
                        // leaving the programme entirely), as opposed to an ordinary
                        // downgrade between two real Aspire tiers (e.g. Maestro->Principal).
                        // Reuses isFirstTimeAspireEntry() since "not a real Aspire tier" is
                        // exactly the same null/Standard check either direction.
                        // ------------------------------------------------------------------
                        String newNameForRouting = getTierNameById(newClassification);
                        if (isFirstTimeAspireEntry(newNameForRouting)) {
                            sendEmails(acc, oldClassification, newClassification, 'TERMINATION', netSales);
                        } else {
                            sendEmails(acc, oldClassification, newClassification, 'DOWNGRADE', netSales);
                        }
                        classificationEmailSent = true;
                    } else {
                        // Still inside the grace month -> hold, no email.
                        System.debug('ACC ' + acc.Id + ' still in grace period until '
                                     + acc.Downgrade_Warning_Date__c.addMonths(1));
                        acc.Broker_Classification__c = oldClassification;
                    }
                } else {
                    acc.Broker_Classification__c = newClassification;
                    acc.Downgrade_Warning_Date__c = null;
                    // ------------------------------------------------------------------
                    // Version 3.9 -- route to the right email for a non-downgrade
                    // classification change. isFirstTimeAspireEntry(oldName) here is
                    // reading the tier the broker is LEAVING: if it's null/Standard,
                    // this is a genuine first-time entry into Aspire -> UPGRADE
                    // (welcome). If the old tier was already Principal or Maestro,
                    // this is a promotion WITHIN the programme -> the new
                    // TIER_PROMOTION type (05_Aspire_Tier_Promotion_Email template),
                    // which previously had no email at all for this case.
                    // ------------------------------------------------------------------
                    String oldNameForRouting = getTierNameById(oldClassification);
                    if (isFirstTimeAspireEntry(oldNameForRouting)) {
                        sendEmails(acc, oldClassification, newClassification, 'UPGRADE', netSales);
                    } else {
                        sendEmails(acc, oldClassification, newClassification, 'TIER_PROMOTION', netSales);
                    }
                    classificationEmailSent = true;
                }

            } else if (newClassification != null) {
                acc.Broker_Classification__c = newClassification;

                // Send email only when classification actually changes
                // (covers first-time classification where oldClassification is null).
                if (oldClassification != newClassification) {
                    sendEmails(acc, oldClassification, newClassification, 'UPGRADE', netSales);
                    classificationEmailSent = true;
                }
            }

            // ------------------------------------------------------------------
            // Version 2.6: PRE_PROMOTION nudge. Only considered when nothing
            // else fired above -- i.e. the account's tier is unchanged this
            // run. Uses whichever classification is now current (falls back
            // to oldClassification when newClassification didn't resolve to
            // anything, e.g. netSales didn't land in any configured band).
            // ------------------------------------------------------------------
            if (!classificationEmailSent) {
                Id currentClassificationId = (acc.Broker_Classification__c != null)
                    ? acc.Broker_Classification__c
                    : oldClassification;
                checkAndSendPrePromotion(acc, currentClassificationId, netSales);
            }

            acc.ClassificationSalesAmount__c = netSales;
            acc.Total_Sales_Amount__c = totalSales;
        }

        // ------------------------------------------------------------------
        // Version 1.9: surface save failures. allOrNone=false was hiding them,
        // which meant Downgrade_Warning_Date__c could silently never persist --
        // so the next run would re-send the WARNING and never reach DOWNGRADE.
        // ------------------------------------------------------------------
        List<Account> accountsToUpdate = accountMap.values();
        List<Database.SaveResult> saveResults = Database.update(accountsToUpdate, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            if (!saveResults[i].isSuccess()) {
                for (Database.Error err : saveResults[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                                 'Account update FAILED for ' + accountsToUpdate[i].Id
                                 + ' -> ' + err.getStatusCode() + ': ' + err.getMessage()
                                 + ' | fields: ' + err.getFields());
                }
            }
        }

        // ------------------------------------------------------------------
        // Update version 1.7 / 1.8: upsert Broker_Monthly_Performance__c per
        // Broker_Agency__c + Period__c.
        // ------------------------------------------------------------------
        List<Broker_Monthly_Performance__c> monthlyList = new List<Broker_Monthly_Performance__c>();

        String currentMonth = Datetime.newInstance(
            today,
            Time.newInstance(0,0,0,0)
        ).format('MMMM');
        String currentYear = String.valueOf(today.year());

        Map<String, Broker_Monthly_Performance__c> existingRecords = new Map<String, Broker_Monthly_Performance__c>();

        for (Broker_Monthly_Performance__c rec : [
            SELECT Id, Broker_Agency__c, Name, Month__c, Year__c,
            Current_Classification__c, Previous_Classification__c,
            Monthly_Sales__c, Rolling_12M_Sales__c, Period__c, Change_Type__c
            FROM Broker_Monthly_Performance__c
            WHERE Broker_Agency__c IN :accountMap.keySet()
            AND Period__c = :periodValue
        ]) {
            String key = buildDedupeKey(rec.Broker_Agency__c, rec.Period__c);
            existingRecords.put(key, rec);
        }

        for (Account acc : accountMap.values()) {

            String key = buildDedupeKey(acc.Id, periodValue);

            Broker_Monthly_Performance__c rec = existingRecords.containsKey(key)
                ? existingRecords.get(key)
                : new Broker_Monthly_Performance__c();

            if (rec.Id == null) {
                rec.Broker_Agency__c = acc.Id;
                rec.Month__c = currentMonth;
                rec.Year__c = currentYear;
            }

            rec.Current_Classification__c  = acc.Broker_Classification__c;
            rec.Previous_Classification__c = oldClassificationMap.get(acc.Id);
            rec.Monthly_Sales__c     = monthlySalesMap.containsKey(acc.Id) ? monthlySalesMap.get(acc.Id) : 0;
            rec.Rolling_12M_Sales__c = acc.ClassificationSalesAmount__c;
            rec.Period__c = periodValue;

            Id oldClass = oldClassificationMap.get(acc.Id);
            Id newClass = acc.Broker_Classification__c;

            if (oldClass == newClass) {
                rec.Change_Type__c = 'No Change';
            } else {
                Integer oldIndex = getTierIndex(oldClass);
                Integer newIndex = getTierIndex(newClass);
                if (newIndex > oldIndex) rec.Change_Type__c = 'Upgrade';
                else if (newIndex < oldIndex) rec.Change_Type__c = 'Downgrade';
            }

            monthlyList.add(rec);
        }
        system.debug('monthlyList:::'+monthlyList);
        upsert monthlyList;
    }

    global void finish(Database.BatchableContext context) {}

    /* ==================================================================
* Version 6.0 -- resolves which broker Account Id a Sales Order counts
* toward, replicating the Sales Order's own BrokerAgency__c FORMULA FIELD
* exactly:
*     IF(NOT(ISBLANK(Old_Opportunity__r.BrokerAgency__r.Name)),
*        Old_Opportunity__r.BrokerAgency__r.Name,
*        Opportunity__r.BrokerAgency__r.Name)
* The formula returns a Name (text); this returns the underlying Id
* instead, since Id is what the batch's maps/filters need. Same
* precedence: Old_Opportunity__r.BrokerAgency__c wins whenever it is
* populated (this is the ORIGINAL broker on a resale/transfer), otherwise
* falls back to Opportunity__r.BrokerAgency__c (the normal, non-transfer
* case).
* ================================================================== */
    private Id resolveEffectiveAgencyId(SalesOrder__c so) {
        if (so.Old_Opportunity__r != null && so.Old_Opportunity__r.BrokerAgency__c != null) {
            return so.Old_Opportunity__r.BrokerAgency__c;
        }
        if (so.Opportunity__r != null) {
            return so.Opportunity__r.BrokerAgency__c;
        }
        return null;
    }

    public Integer getTierIndex(Id tierId) {
        if (tierId == null) return -1;
        for (Integer i = 0; i < classificationTiers.size(); i++) {
            if (classificationTiers[i].Id == tierId) {
                return i;
            }
        }
        return -1;
    }

    public static String buildDedupeKey(Id agencyId, String period) {
        return String.valueOf(agencyId) + '-' + (period == null ? '' : period.trim());
    }

    public class AccountWrapper implements Comparable {
        public Account acc;

        public AccountWrapper(Account acc) {
            this.acc = acc;
        }

        public Integer compareTo(Object obj) {
            AccountWrapper other = (AccountWrapper) obj;

            Decimal thisSales  = acc.ClassificationSalesAmount__c != null ? acc.ClassificationSalesAmount__c : 0;
            Decimal otherSales = other.acc.ClassificationSalesAmount__c != null ? other.acc.ClassificationSalesAmount__c : 0;

            if (otherSales > thisSales) return 1;
            else if (otherSales < thisSales) return -1;
            else return 0;
        }
    }

    /* ==================================================================
* Version 2.2 -- master email switch driven by a Custom Label.
* Emails ONLY send when MBP_Emails_Enabled == 'true' (case-insensitive).
* Any other value ('false', blank, junk) suppresses ALL sends.
* ================================================================== */

@TestVisible
private static Boolean emailsEnabledOverride = null;

public static Boolean areEmailsEnabled() {
    if (emailsEnabledOverride != null) {
        return emailsEnabledOverride;
    }
    String flag = Label.MBP_Emails_Enabled;
    return String.isNotBlank(flag) && flag.trim().equalsIgnoreCase('true');
}

    /* ==================================================================
* Version 2.6 -- PRE_PROMOTION eligibility check.
* Looks at the tier immediately above currentClassId (classificationTiers
* is ordered ascending by AnnualSalesTargetFrom__c, so that's simply
* index+1). If there IS a tier above (i.e. currentClassId isn't already
* Ambassador / the top tier) and netSales has reached
* PRE_PROMOTION_THRESHOLD_PCT of that next tier's minimum -- but hasn't
* reached it outright, since that would have been caught as an UPGRADE
* earlier in the loop -- fires the nudge email.
*
* Version 2.7 -- Standard is NOT part of the Aspire programme; it's the
* baseline before a broker has joined at all. So a broker currently
* sitting at Standard never gets a "you're close to Principal" nudge --
* the nudge only applies once someone is already an Aspire member
* (Principal or Maestro approaching the next tier up). Crossing INTO
* Principal for the first time is still handled separately by the
* ordinary UPGRADE email (that's the actual welcome-to-Aspire moment,
* not a pre-emptive nudge).
* ================================================================== */
    private void checkAndSendPrePromotion(Account acc, Id currentClassId, Decimal netSales) {
        Integer currentIdx = getTierIndex(currentClassId);
        if (currentIdx < 0 || currentIdx + 1 >= classificationTiers.size()) {
            return; // no classification yet, or already at the top tier (Ambassador)
        }

        Broker_Classification__c currentTier = classificationTiers[currentIdx];
        if (currentTier.Name != null && currentTier.Name.trim() == 'Standard') {
            return; // Standard isn't an Aspire tier -- no pre-promotion nudge from here
        }

        Broker_Classification__c nextTier = classificationTiers[currentIdx + 1];
        Decimal nextThreshold = resolveTierMin(nextTier, acc.Agency_Region__c);

        if (nextThreshold == null || nextThreshold <= 0) return;
        if (netSales >= nextThreshold) return; // would already have been an UPGRADE this run

        Decimal progressRatio = netSales / nextThreshold;
        if (progressRatio >= PRE_PROMOTION_THRESHOLD_PCT) {
            sendEmails(acc, currentClassId, nextTier.Id, 'PRE_PROMOTION', netSales);
        }
    }

    /* ==================================================================
* Version 3.4(a) -- per-tier WELCOME (UPGRADE) email content.
* Each tier's supplied template (01_Aspire_Principal_Welcome_Email,
* 02_Aspire_Maestro_Welcome_Email, 03_Aspire_Ambassador_Welcome_Email) has
* its own opening paragraph, tier description and benefits list -- they
* are NOT the same copy with the tier name swapped in. WelcomeTemplate
* holds one tier's pieces; WELCOME_TEMPLATES is keyed by tier Name so
* sendEmails() can look up the right copy for whichever tier the broker
* is being welcomed into (newName). Standard deliberately has no entry --
* UPGRADE-into-Standard is already suppressed earlier in sendEmails().
*
* Version 5.2 -- each tier's closing paragraph that used to say "explore
* more at aspire.modon.com" (linking out to the marketing site) has been
* replaced with a plain "Please feel free to contact us on
* aspire@modon.com" mailto line, matching the contact line already used
* in the WARNING/PRE_PROMOTION/DOWNGRADE/TERMINATION/TIER_PROMOTION
* emails. No other paragraph in any of the three templates changed.
* ================================================================== */
    private class WelcomeTemplate {
        String openingParagraph;
        String tierDescription;
        String benefitsIntro;
        List<String> benefits;
        // Rendered in order after the benefits list, each its own paragraph.
        List<String> closingParagraphs;

        WelcomeTemplate(String openingParagraph, String tierDescription, String benefitsIntro,
                         List<String> benefits, List<String> closingParagraphs) {
            this.openingParagraph  = openingParagraph;
            this.tierDescription   = tierDescription;
            this.benefitsIntro     = benefitsIntro;
            this.benefits          = benefits;
            this.closingParagraphs = closingParagraphs;
        }
    }

    private static final Map<String, WelcomeTemplate> WELCOME_TEMPLATES = new Map<String, WelcomeTemplate>{

        'Principal' => new WelcomeTemplate(
            'It\u2019s our pleasure to welcome you to Modon\u2019s Aspire Partner Programme. This programme was created to recognise the partners who represent our product with the credibility, professionalism, and market influence that define how our neighbourhoods are experienced by clients around the world.',
            'This tier is reserved for an exclusive, hand-selected group of partners whose performance and market presence place them at the absolute forefront of Modon\u2019s broker network. Being named a <strong>Principal</strong> partner is a reflection of the trust we place in you and the impact you\u2019ve had in bringing Modon\u2019s vision to market. It\u2019s a distinction only a select few will hold.',
            'As a <strong>Principal</strong> partner, you\u2019ll enjoy:',
            new List<String>{
                '<strong>Private access during launch dates:</strong> See our developments before they reach the wider market',
                '<strong>Open house activation opportunities:</strong> Exclusive platforms to showcase properties to your clients',
                '<strong>Personalised development workshops:</strong> Tailored sessions to deepen your expertise on our masterplans',
                '<strong>Invitations to private Modon engagements and networking events:</strong> Access to our inner circle of partners and leadership'
            },
            new List<String>{
                'This is just the beginning. In the coming weeks, we\u2019ll be formally introducing the full programme and the opportunities it will unlock for you.',
                'Please feel free to contact us on <a href="mailto:aspire@modon.com" style="color:#0563C1; text-decoration:underline;">aspire@modon.com</a>.',
                'Congratulations again on this well-earned recognition \u2014 we\u2019re proud to have you as part of the Aspire programme.'
            }
        ),

        'Maestro' => new WelcomeTemplate(
            'It\u2019s our pleasure to welcome you to the <strong>Aspire Partner Programme</strong>, a programme established to recognise partners who play a meaningful role in representing Modon\u2019s masterplans with credibility, professionalism, and influence. It reflects our commitment to working more closely with those who contribute to how Modon\u2019s neighbourhoods are understood and experienced by clients around the world.',
            'This tier recognises an exclusive, hand-selected group of partners whose performance and market presence place them at the forefront of Modon\u2019s broker network. Being named a <strong>Maestro</strong> partner is a reflection of the trust we place in you and the impact you\u2019ve had in bringing Modon\u2019s vision to market.',
            'As a <strong>Maestro</strong> partner, you\u2019ll enjoy:',
            new List<String>{
                '<strong>Pre-launch allocation ahead of market release:</strong> Receive access to our developments before they are available to the public.',
                '<strong>Private access during launch dates:</strong> See our developments before they reach the wider market.',
                '<strong>Bespoke support for local events:</strong> Tailored assistance for your marketing and client events.',
                '<strong>Open house activation opportunities:</strong> Exclusive platforms to showcase properties to your clients.',
                '<strong>Personalised development workshops:</strong> Tailored sessions to deepen your expertise on our masterplans.',
                '<strong>Invitations to private Modon engagements and networking events:</strong> Access to our inner circle of partners and leadership.'
            },
            new List<String>{
                'This is just the beginning. In the coming weeks, we will be formally introducing the full programme and the opportunities it will unlock for you.',
                'Please feel free to contact us on <a href="mailto:aspire@modon.com" style="color:#0563C1; text-decoration:underline;">aspire@modon.com</a>.',
                'Congratulations on this well-earned recognition, we are proud to have you as part of the Aspire programme.'
            }
        ),

        'Ambassador' => new WelcomeTemplate(
            'It\u2019s our pleasure to welcome you to the <strong>Aspire by Modon</strong>, a programme established to recognise partners who represent Modon\u2019s masterplans with credibility, professionalism, and influence. It reflects our commitment to working more closely with those who contribute to how Modon\u2019s neighbourhoods are understood and experienced by clients around the world.',
            'This tier recognises an exclusive group of partners whose performance and market presence place them at the forefront of Modon\u2019s broker network. Being named an <strong>Ambassador</strong> partner is a reflection of the trust we place in you and the significant impact you have had in bringing Modon\u2019s vision to market.',
            'As an <strong>Ambassador</strong> partner, you\u2019ll enjoy:',
            new List<String>{
                'Pre-launch allocation ahead of market release',
                'Private sales event access during key launches',
                'Dedicated allocation for international roadshows',
                'Kiosk takeover and open house activation opportunities',
                'Bespoke support for local and international events',
                'Personalised development workshops',
                'Invitations to private Modon engagements and networking events'
            },
            new List<String>{
                'This is just the beginning. In the coming weeks, we will be formally introducing the full programme and the opportunities it will unlock for you.',
                'Congratulations on this well-earned recognition. We are proud to have you as part of the Aspire programme.',
                'Please feel free to contact us on <a href="mailto:aspire@modon.com" style="color:#0563C1; text-decoration:underline;">aspire@modon.com</a>.'
            }
        )
    };

    /* ==================================================================
* Version 3.7 -- ONE shared wrapper for every plain-text paragraph in the
* welcome email (opening paragraph, tier description, benefits intro,
* AND every closing paragraph), not just the closing ones. Applying the
* same defensive styling everywhere means no paragraph in this email --
* present or future -- can pick up a stray highlight/underline/color
* from a mail client's auto-formatting, no matter which line it lands
* on. Uses !important on color/font-weight/text-decoration so nothing
* the client injects can override them, but keeps the background
* TRANSPARENT rather than hardcoding white -- a hardcoded white box
* behind the text would itself look like an unwanted highlight in a
* dark-mode/dark-background mail client, which is the exact symptom
* this is trying to avoid.
* ================================================================== */
    private static String wrapPlainParagraph(String html) {
        return '<p style="margin:0 0 16px 0; padding:0; '
             + 'color:#000000 !important; '
             + 'background:transparent !important; '
             + 'background-color:transparent !important; '
             + 'font-weight:normal !important; '
             + 'text-decoration:none !important;">'
             + '<span style="color:#000000 !important; '
             + 'background:transparent !important; '
             + 'background-color:transparent !important; '
             + 'font-weight:normal !important; '
             + 'text-decoration:none !important;">'
             + html
             + '</span></p>';
    }

    /* Builds the welcome bodyContent for newName from WELCOME_TEMPLATES.
* Falls back to a minimal generic message if a tier somehow has no
* template entry, so a future new tier can't silently send a blank
* email -- it sends something safe while the template gets filled in. */
    private String buildWelcomeBody(String brokerName, String newName) {

        WelcomeTemplate t = WELCOME_TEMPLATES.get(newName);

        if (t == null) {
            System.debug(LoggingLevel.WARN,
                         'buildWelcomeBody: no WELCOME_TEMPLATES entry for tier "' + newName
                         + '" -- sending generic fallback copy.');
            return
                'Dear ' + brokerName + ',<br><br>' +
                wrapPlainParagraph('It\u2019s our pleasure to welcome you to Modon\u2019s Aspire Partner Programme at <strong>' + newName + ' Tier</strong>.') +
                wrapPlainParagraph('In the meantime, you can explore more at <a href="https://aspire.modon.com/" target="_blank" style="color:#0563C1; text-decoration:underline;">aspire.modon.com</a>.') +
                wrapPlainParagraph('Congratulations again on this well-earned recognition \u2014 we\u2019re proud to have you as part of the Aspire programme.');
        }

        String benefitsHtml = '<ul style="margin:8px 0 16px 0; padding-left:20px;">';
        for (String benefit : t.benefits) {
            benefitsHtml += '<li>' + benefit + '</li>';
        }
        benefitsHtml += '</ul>';

        // Version 3.7 -- every paragraph in the email, not just the closing
        // ones, now goes through the same wrapPlainParagraph() wrapper (see
        // above), so the opening paragraph, the tier description, and the
        // benefits intro line get the identical belt-and-braces protection
        // that the closing paragraphs (Congratulations etc.) already had
        // from v3.5/3.6.
        String closingHtml = '';
        for (String para : t.closingParagraphs) {
            closingHtml += wrapPlainParagraph(para);
        }

        return
            'Dear ' + brokerName + ',<br><br>' +
            wrapPlainParagraph(t.openingParagraph) +
            wrapPlainParagraph('We\u2019re delighted to invite you into the programme at: <strong>' + newName + ' Tier</strong>.') +
            wrapPlainParagraph(t.tierDescription) +
            wrapPlainParagraph(t.benefitsIntro) +
            benefitsHtml +
            closingHtml;
    }

    /* ==================================================================
* Version 3.4(b) -- "is this the broker's first time entering Aspire?"
* Standard is the pre-membership baseline (see v2.7), so a broker only
* has "no prior Aspire tier" when their OLD classification is null or
* Standard -- i.e. they have never previously cleared the AED 60,000,000
* Principal floor. Once someone has been Principal or Maestro, every
* later move to a higher tier (Principal->Maestro, Maestro->Ambassador,
* or a Principal->Ambassador jump) is a promotion WITHIN Aspire, not a
* first-time entry, so the welcome email should not fire again for it.
* ================================================================== */
    private Boolean isFirstTimeAspireEntry(String oldName) {
        String normalizedOldName = (oldName == null) ? '' : oldName.trim();
        return normalizedOldName == '' || normalizedOldName == 'Standard';
    }

    /* ==================================================================
* Version 3.1 -- Welcome-email header images, keyed by tier name.
* Version 3.2 -- now used as a straight lookup that REPLACES the standard
* Modon banner (via MBP_ModonEmailUtilityClass.getFullEmailHtml(body, url)),
* not appended as an extra row. See the headerImageUrl line inside
* sendEmails() below. Standard deliberately has no entry, so a lookup for
* 'Standard' returns null -- a no-op, since UPGRADE-into-Standard is
* already suppressed elsewhere, and getFullEmailHtml() falls back to the
* standard banner whenever the URL passed in is blank/null.
*
* To extend tier header images to WARNING / DOWNGRADE / PRE_PROMOTION
* later, just widen the condition on headerImageUrl inside sendEmails()
* to include those types, passing whichever tier name makes sense for
* that email (e.g. oldName for WARNING/DOWNGRADE, newName for
* PRE_PROMOTION) -- this same map can be reused as-is.
* ================================================================== */
    private static final Map<String, String> TIER_HEADER_IMAGES = new Map<String, String>{
        'Principal'  => 'https://image.realestate.modon.com/lib/fe2e117373640475741678/m/1/74c3ab03-da83-47f2-8e01-22d7ddbe4386.jpg',
        'Maestro'    => 'https://image.realestate.modon.com/lib/fe2e117373640475741678/m/1/99f84dfb-a686-4d5d-8a04-534d225565de.jpg',
        'Ambassador' => 'https://image.realestate.modon.com/lib/fe2e117373640475741678/m/1/2a75ca45-5556-4162-89e6-fed593e9854b.jpg'
    };

    /* ==================================================================
* Version 4.6 -- TERMINATION-specific header image, requested to use the
* exact same PATTERN as every tier's welcome banner (the two-arg
* getFullEmailHtml(body, headerImageUrl) overload), just with this one
* fixed URL instead of a per-tier lookup, since a broker leaving the
* programme has no tier left to key a lookup off. No other logic in
* TERMINATION's send tail changes -- recipient resolution
* (Company_Email_Address__c -> contact list -> Account Owner email) and
* the synchronous sendEmail(...) call (v4.5) are exactly as before.
* ================================================================== */
    private static final String TERMINATION_HEADER_IMAGE =
        'https://image.realestate.modon.com/lib/fe2e117373640475741678/m/1/709e54b6-f02d-4f9f-acc8-c8897b059188.jpg';

   public void sendEmails(
    Account acc,
    Id oldClassId,
    Id newClassId,
    String type,
    Decimal classificationAmount
   ){

        // ------------------------------------------------------------------
        // Version 2.2 -- master switch. If the Custom Label MBP_Emails_Enabled
        // isn't 'true', nothing sends. This covers WARNING, DOWNGRADE and
        // UPGRADE in one place, and sits BEFORE the dryRun check.
        // ------------------------------------------------------------------
        if (!areEmailsEnabled()) {
            System.debug(LoggingLevel.WARN,
                         'sendEmails: suppressed by Custom Label MBP_Emails_Enabled. '
                         + 'type=' + type + ', account=' + acc.Id);
            return;
        }

        // ------------------------------------------------------------------
        // Version 4.7 -- TERMINATION now uses the SAME recipient source as
        // every other email type: the Owner/Agency-Admin contact list. The
        // earlier Company_Email_Address__c-first / Account-Owner-fallback
        // chain (v4.0-v4.2) is removed -- TERMINATION no longer has any
        // special recipient handling at all, per explicit request to match
        // the welcome/other-types pattern exactly.
        // ------------------------------------------------------------------
        List<Contact> contactList = contactsByAccount.containsKey(acc.Id)
            ? contactsByAccount.get(acc.Id)
            : new List<Contact>();

        if (contactList.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                         'sendEmails(' + type + '): NO recipients for account ' + acc.Id
                         + '. Check Broker_Type__c IN (Owner, Agency Admin), Agent_Status__c = Active, Email != null.');
            return;
        }

        String oldName = getTierNameById(oldClassId);
        String newName = getTierNameById(newClassId);


        if (type == 'UPGRADE' && newName == 'Standard') {
            System.debug('sendEmails: suppressing UPGRADE-into-Standard for ' + acc.Id);
            return;
        }

        // ------------------------------------------------------------------
        // Version 3.8 -- the one-time backfill run. Every account is being
        // classified for the first time because the AUTOMATION is new, not
        // because the broker just achieved this tier -- so the welcome
        // email would be misleading. Classification and
        // Broker_Monthly_Performance__c still update normally either way;
        // this ONLY suppresses the email.
        // ------------------------------------------------------------------
        if (type == 'UPGRADE' && isInitialRun) {
            System.debug('sendEmails: suppressing UPGRADE welcome for ' + acc.Id
                         + ' -- isInitialRun=true (one-time backfill, not a genuine new entry).');
            return;
        }

        // Version 3.9 -- same bootstrap protection extended to TIER_PROMOTION.
        // In practice this can't fire on a genuine first run anyway (it
        // requires a non-null oldClassification, which every account lacks
        // on the very first run), but this keeps the guard consistent if the
        // batch is ever re-run in initial mode against partially-populated
        // data.
        if (type == 'TIER_PROMOTION' && isInitialRun) {
            System.debug('sendEmails: suppressing TIER_PROMOTION for ' + acc.Id
                         + ' -- isInitialRun=true (one-time backfill).');
            return;
        }

        // ------------------------------------------------------------------
        // Version 3.4(b) -- the welcome email is a "you've just joined
        // Aspire" message. Only send it the FIRST time a broker enters the
        // programme (old tier was null/Standard). A broker who is already
        // an Aspire member (Principal or Maestro) climbing to a higher tier
        // still gets classified and recorded normally -- they just don't
        // get a second "welcome" email, since they're not newly entering.
        // ------------------------------------------------------------------
        if (type == 'UPGRADE' && !isFirstTimeAspireEntry(oldName)) {
            System.debug('sendEmails: suppressing UPGRADE welcome for ' + acc.Id
                         + ' -- already an Aspire member (oldTier=' + oldName
                         + '), moving to ' + newName + ' is a within-programme promotion, not a first-time entry.');
            return;
        }

        String brokerName    = String.isBlank(acc.Name) ? 'Partner' : acc.Name;
        String effectiveDate = formatDate(runDate);
        String actualSales = formatAed(classificationAmount);

        String subject;
        String bodyContent;

        if (type == 'WARNING') {

            // DEMOTION -- PRE-NOTIFICATION EMAIL
            // v4.1 -- reverted to the ACTUAL supplied "06_Aspire_Tier_Review"
            // template body (the plain "let's meet" invitation), not the
            // "Adjusted Text" merge-field variant used in v3.9 -- confirmed
            // against the rendered email screenshot, which shows this exact
            // copy with no AED figures or day-count in it. No sales/target
            // amounts or days-remaining are referenced in this copy at all.
            subject = 'Tier Status Alert';

            bodyContent =
                'Dear ' + brokerName + ',<br><br>' +
                wrapPlainParagraph('As our valued partner in Aspire by Modon, we remain committed to supporting your continued growth and success within our network.') +
                wrapPlainParagraph('As part of our ongoing engagement with Aspire programme, we\u2019d like to invite you to meet with our channel Partner Management team to review your current performance, discuss your business pipeline, and explore opportunities that can help you maintain your current Aspire tier.') +
                wrapPlainParagraph('A member of our team will be in touch shortly to arrange a meeting.') +
                wrapPlainParagraph('We value the partnership we\u2019ve built together and look forward to continuing to support your success.') +
                wrapPlainParagraph('Please feel free to contact us on <a href="mailto:aspire@modon.com" style="color:#0563C1; text-decoration:underline;">aspire@modon.com</a>.')
                ;

        } else if (type == 'PRE_PROMOTION') {

            // Version 2.6 -- PROMOTION-DIRECTION NUDGE. oldClassId/oldName is
            // the broker's CURRENT tier here; newClassId/newName is the NEXT
            // tier they're approaching (not an actual change yet).
            // v3.9 -- bodyContent replaced to match the supplied
            // "04_Aspire_Pre_Promotion_Email" template.
            Decimal requiredAmount = getTierMinById(newClassId, acc.Agency_Region__c);
            Integer daysRemaining = getDaysUntilNextEvaluation();

            subject = 'You have a Tier Status Update';

            // ------------------------------------------------------------------
            // Version 4.9 -- body brought back in line with the supplied
            // "04_Aspire_Pre_Promotion_Email" template exactly: the template's
            // milestone paragraph states the target amount and the tier move
            // (from/to) but does NOT state a remaining-gap figure, so the
            // "-- a remaining gap of AED X" clause (and the now-unused `gap`
            // calculation that produced it) has been removed. A closing
            // "Best regards, Modon" line -- present in the template but
            // previously missing from this bodyContent -- has been added.
            // No other paragraph changed.
            // ------------------------------------------------------------------
            bodyContent =
                'Dear ' + brokerName + ',<br><br>' +
                wrapPlainParagraph('We\u2019re excited to share a performance update as part of <strong>Aspire by Modon</strong>, our partnership programme designed to recognise, reward, and support the continued growth of our partners.') +
                wrapPlainParagraph('You are currently positioned at <strong>' + oldName + '</strong>, with a recorded sales value of <strong>AED ' + actualSales + '</strong>. This is a strong reflection of the momentum you\u2019ve built, and we want to recognise the effort behind it.') +
                wrapPlainParagraph('Keep up the continued momentum! Your next milestone is well within reach. Once your total transaction value has reached <strong>AED ' + formatAed(requiredAmount) + '</strong>, you will advance from the <strong>' + oldName + '</strong> to the <strong>' + newName + '</strong>.') +
                wrapPlainParagraph('With <strong>' + daysRemaining + ' days</strong> remaining in the current evaluation period, you are well-positioned to close this gap and secure your place at the next tier.') +
                wrapPlainParagraph('Your recent performance reflects strong momentum, and we encourage you to continue building on this progress in the days ahead.') +
                wrapPlainParagraph('Our Channel Partner Management Team is here to help \u2014 simply reach out to us at <a href="mailto:aspire@modon.com" style="color:#0563C1; text-decoration:underline;">aspire@modon.com</a>.') +
                wrapPlainParagraph('Review your full performance and track your progress through the Broker Portal.') +
                wrapPlainParagraph('We\u2019re proud of the progress you\u2019ve made, and we look forward to celebrating your continued success.')
                ;

        } else if (type == 'DOWNGRADE') {

            // v3.9 -- bodyContent replaced to match the supplied
            // "08_Aspire_TierDowngrade" template ("your Aspire tier has been
            // updated from X to Y"). v4.0 -- the isTierRemoval split that
            // used to live here is gone: a landing tier of Standard/blank is
            // now routed to the separate TERMINATION type instead (see
            // execute()), so DOWNGRADE only ever fires between two real
            // Aspire tiers (e.g. Maestro->Principal) and always uses the
            // template's plain "updated from X to Y" wording.
            Decimal requiredAmount = getTierMinById(oldClassId, acc.Agency_Region__c);

            subject = 'Tier Status Change';

            bodyContent =
                'Dear ' + brokerName + ',<br><br>' +
                wrapPlainParagraph('Following the completion of the latest Aspire Programme performance review, we would like to share an update regarding your tier status.') +
                wrapPlainParagraph('Following this evaluation, your Aspire tier has been updated from <strong>' + oldName + '</strong> to <strong>' + newName + '</strong>, effective <strong>' + effectiveDate + '</strong>.') +
                wrapPlainParagraph('This update reflects your current performance against the Aspire Programme criteria while recognising your continued place within the programme.') +
                wrapPlainParagraph('As an Aspire partner, you\u2019ll continue to enjoy the benefits and opportunities available within your new tier, and we\u2019ll continue working closely with you to support your growth and future progression.') +
                wrapPlainParagraph('Should you have any questions or wish to discuss your performance or future opportunities, please feel free to contact us on <a href="mailto:aspire@modon.com" style="color:#0563C1; text-decoration:underline;">aspire@modon.com</a>.')
                ;

        } else if (type == 'TERMINATION') {

            // ------------------------------------------------------------------
            // Version 4.0 -- NEW email type for a broker dropping out of the
            // Aspire Programme entirely (landing tier is Standard/blank --
            // below even the Principal floor). Uses the supplied
            // "07_Aspire_Programme_Termination" template. Routed here from
            // execute() instead of DOWNGRADE when the landing tier is not a
            // real Aspire tier -- see the routing comment there.
            //
            // Required = the Principal floor, i.e. the minimum needed to
            // remain in the Aspire structure at all (same threshold already
            // used for this scenario before v4.0 split it out).
            //
            // NOTE: this type is handled with its own tail below (standard
            // banner only, sent to Company_Email_Address__c) rather than
            // falling through to the shared header/recipient logic further
            // down -- see the dedicated block right after this if/else
            // chain.
            // ------------------------------------------------------------------
            Decimal minThreshold = getTierMinByName('Principal', acc.Agency_Region__c);

            subject = 'Aspire Status Update';

            bodyContent =
                'Dear ' + brokerName + ',<br><br>' +
                wrapPlainParagraph('Following the completion of the latest Aspire Programme Performance review, we would like to share an update regarding your tier status.') +
                wrapPlainParagraph('Based on your recorded sales performance of <strong>AED ' + actualSales + '</strong> during the evaluation period, which is below the minimum requirement of <strong>AED ' + formatAed(minThreshold) + '</strong>, your agency no longer qualifies to remain in the Aspire Programme.') +
                wrapPlainParagraph('We sincerely value the partnership we\u2019ve built together. We remain confident that, with continued performance, your agency will have the opportunity to qualify for the Aspire Programme again in future evaluation periods.') +
                wrapPlainParagraph('Should you have any questions or wish to discuss your performance, please feel free to contact us on <a href="mailto:aspire@modon.com" style="color:#0563C1; text-decoration:underline;">aspire@modon.com</a>.')
                ;

        } else if (type == 'TIER_PROMOTION') {

            // ------------------------------------------------------------------
            // Version 3.9 -- NEW email type for a promotion WITHIN the
            // programme (existing Aspire member, e.g. Principal->Maestro or
            // Maestro->Ambassador). Previously this case sent NO email at all
            // (only the first-time UPGRADE welcome was wired up). Uses the
            // supplied "05_Aspire_Tier_Promotion_Email" template. Routed here
            // from execute() when oldName is already an Aspire tier (not
            // null/Standard) -- see the routing comment there.
            // ------------------------------------------------------------------
            subject = 'Your Tier Status has been Upgraded';

            bodyContent =
                'Dear ' + brokerName + ',<br><br>' +
                wrapPlainParagraph('We are pleased to confirm your promotion within <strong>Aspire by Modon</strong>.') +
                wrapPlainParagraph('Your tier status has been upgraded from <strong>' + oldName + '</strong> to <strong>' + newName + '</strong>, effective <strong>' + effectiveDate + '</strong>.') +
                wrapPlainParagraph('This progression reflects your achieved sales performance of <strong>AED ' + actualSales + '</strong>, meeting the required threshold for your new tier, and recognises your continued contribution and performance as an Aspire by Modon partner.') +
                wrapPlainParagraph('As a <strong>' + newName + '</strong> partner, you will now have access to enhanced Aspire benefits aligned with your tier level. We encourage you to continue building on this strong performance and momentum.') +
                wrapPlainParagraph('Please review your performance and track your progress through the Broker Portal, and feel free to contact us on <a href="mailto:aspire@modon.com" style="color:#0563C1; text-decoration:underline;">aspire@modon.com</a>.') +
                wrapPlainParagraph('We value your partnership and look forward to your continued success.')
                ;

        } else if (type == 'UPGRADE') {

            // PROMOTION -- FORMAL WELCOME EMAIL
            // v3.4(a) -- bodyContent now built from the tier-specific
            // WELCOME_TEMPLATES entry for newName (see buildWelcomeBody()),
            // instead of reusing the Principal copy for every tier. Only
            // reached once isFirstTimeAspireEntry() has confirmed this is
            // genuinely the broker's first time entering the programme.
            // Version 4.9 -- subject is now tier-specific ("Welcome to the
            // Principal/Maestro/Ambassador Tier") instead of one fixed line
            // reused for every tier. newName is always Principal, Maestro,
            // or Ambassador here (the UPGRADE-into-Standard guard above
            // already returns before this point is reached).
            subject = 'Welcome to the ' + newName + ' Tier';

            bodyContent = buildWelcomeBody(brokerName, newName);

        } else {
            System.debug(LoggingLevel.ERROR, 'sendEmails: unknown type "' + type + '"');
            return;
        }

        String body =
            '<tr>' +
            '  <td style="padding:20px 30px 10px 30px; font-family:Arial, sans-serif; font-size:16px; line-height:20px; color:#000000;">' +
            bodyContent +
            '  </td>' +
            '</tr>';

        // ------------------------------------------------------------------
        // Version 4.7 -- TERMINATION no longer has a separate tail at all.
        // Recipient resolution (contactList, above) and the send call below
        // are now identical to every other email type; the only thing that
        // still differs for TERMINATION is which header image gets looked
        // up, handled in the headerImageUrl block immediately below.
        // ------------------------------------------------------------------


        String headerImageUrl;
        if (type == 'WARNING' || type == 'PRE_PROMOTION') {
            headerImageUrl = TIER_HEADER_IMAGES.get(oldName == null ? '' : oldName.trim());
        } else if (type == 'TERMINATION') {
            headerImageUrl = TERMINATION_HEADER_IMAGE;
        } else if (type == 'UPGRADE' || type == 'TIER_PROMOTION' || type == 'DOWNGRADE') {
            headerImageUrl = TIER_HEADER_IMAGES.get(newName == null ? '' : newName.trim());
        } else {
            headerImageUrl = null;
        }

        String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(body, headerImageUrl);

        List<String> emailJsonList = new List<String>();
        for (Contact con : contactList) {
            emailJsonList.add('{"email": "' + con.Email + '"}');
        }

                String toEmails = String.join(emailJsonList, ',');

        // Version 5.0 -- CC these two addresses on every classification email.
        List<String> ccEmailJsonList = new List<String>{
            '{"email": "bodour.alaaraj@modon.com"}',
            '{"email": "katarzyna.pawluk@modon.com"}'
        };
        String ccEmails = String.join(ccEmailJsonList, ',');

        String personalizationsEntry = '[{"to": [' + toEmails + '], "cc": [' + ccEmails + ']}]';

        if (dryRun) {
            System.debug('DRY RUN -- would send "' + subject + '" to ' + toEmails + ' from aspire@modon.com');
            System.debug('DRY RUN -- body: ' + bodyContent);
            return;
        }

        try {
            // ------------------------------------------------------------------
            // Version 5.1 -- Aspire classification emails now send FROM
            // aspire@modon.com, not the shared noreply@modon.com default.
            // BP_SendGridUtilityClass.sendEmail() (used elsewhere / by other
            // processes) hardcodes noreply@modon.com and is intentionally left
            // untouched. sendEmailWithAttachments() already accepts an explicit
            // fromEmail, so we use that instead, passing an empty attachments
            // list since this class doesn't send any files. 'Al Naseem' is kept
            // as the SendGrid_Configuration__mdt lookup key (fromName), matching
            // the previous call -- only the sender address changes.
            // ------------------------------------------------------------------
            BP_SendGridUtilityClass.sendEmailWithAttachments(
                personalizationsEntry,
                'Al Naseem',
                'aspire@modon.com',
                subject,
                emailHtml,
                true,
                new List<ContentDocumentLink>()
            );
            System.debug('Sent "' + subject + '" to ' + toEmails + ' from aspire@modon.com');
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                         'SendGrid callout failed for ' + acc.Id + ' (' + type + '): ' + e.getMessage());
        }
    }

    /* ==================================================================
* v2.1 -- Aspire email helpers
* ================================================================== */

    // Minimum sales threshold for a tier, region-aware.
    public Decimal getTierMinById(Id tierId, String region) {
        if (tierId == null) return 0;
        for (Broker_Classification__c tier : classificationTiers) {
            if (tier.Id == tierId) {
                return resolveTierMin(tier, region);
            }
        }
        return 0;
    }

    public Decimal getTierMinByName(String tierName, String region) {
        if (String.isBlank(tierName)) return 0;
        for (Broker_Classification__c tier : classificationTiers) {
            if (tier.Name != null && tier.Name.trim() == tierName) {
                return resolveTierMin(tier, region);
            }
        }
        return 0;
    }

    public Decimal resolveTierMin(Broker_Classification__c tier, String region) {
        Decimal val = (region == 'International')
            ? tier.AnnualSalesTargetFromInternational__c
            : tier.AnnualSalesTargetFrom__c;
        return (val == null) ? 0 : val;
    }

    // Grace period expires one month after the warning was stamped.
    public Integer getDaysUntilEvaluation(Date warningDate) {
        Date effectiveWarning = (warningDate == null) ? runDate : warningDate;
        Integer days = runDate.daysBetween(effectiveWarning.addMonths(1));
        return (days < 0) ? 0 : days;
    }

    // Version 2.6 -- days remaining until the next monthly evaluation
    // (i.e. until the batch would next reassess this account), used by the
    // PRE_PROMOTION email. There's no explicit "upgrade evaluation window"
    // field like there is for downgrades, so this approximates it as the
    // days left until the start of next month, matching the batch's
    // monthly cadence.
    public Integer getDaysUntilNextEvaluation() {
        Date nextEvalDate = runDate.toStartOfMonth().addMonths(1);
        Integer days = runDate.daysBetween(nextEvalDate);
        return (days < 0) ? 0 : days;
    }

    public static String formatAed(Decimal amount) {
        system.debug('amount::'+amount);
        if (amount == null) return '0';
        system.debug(' formatted amount::'+String.valueOf(amount.setScale(0, RoundingMode.HALF_UP)).replaceAll('(?<=\\d)(?=(\\d{3})+$)', ','));
        return String.valueOf(amount.setScale(0, RoundingMode.HALF_UP))
            .replaceAll('(?<=\\d)(?=(\\d{3})+$)', ',');
    }

    public static String formatDate(Date d) {
        if (d == null) d = System.today();
        return Datetime.newInstance(d, Time.newInstance(0,0,0,0)).format('d MMMM yyyy');
    }

    // Returns the programme benefits list (as <ul>) for a Channel Partner tier,
    // or null if newName isn't one of the three recognised programme tiers.
 //update version 1.5 ends here

    public String getTierNameById(Id tierId) {
        if (tierId == null) return '';
        for (Broker_Classification__c tier : classificationTiers) {
            if (tier.Id == tierId) {
                return tier.Name;
            }
        }
        return '';
    }

    public class SalesInfo {
        public Integer totalSaleCount;
        public Decimal totalSalesAmount;

        public SalesInfo(Integer count, Decimal amount) {
            this.totalSaleCount   = count  != null ? count  : 0;
            this.totalSalesAmount = amount != null ? amount : 0;
        }
    }

    /*Update version 1.2
@description : This method is used for Broker Aspire Dashboard to show details dynamically.
NOTE: this is a live UI call, so it intentionally still uses System.today().
*/
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBrokerDashboardData() {
        Map<String, Object> result = new Map<String, Object>();

        try {
            User currentUser = [
                SELECT Id, Name, ContactId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (currentUser.ContactId == null) {
                result.put('error', 'No contact linked to user');
                result.put('currentSales', 0);
                result.put('currentTier', 'Standard');
                result.put('nextMilestone', null);
                result.put('nextTier', null);
                return result;
            }

            Contact contact = [
                SELECT AccountId,
                Account.Name,
                Account.Agency_Region__c,
                Account.Broker_Classification__c,
                Account.Broker_Classification__r.Name,
                Account.ClassificationSalesAmount__c
                FROM Contact
                WHERE Id = :currentUser.ContactId
                LIMIT 1
            ];

            if (contact.AccountId == null) {
                result.put('error', 'No account linked to contact');
                result.put('currentSales', 0);
                result.put('currentTier', 'Standard');
                result.put('nextMilestone', null);
                result.put('nextTier', null);
                return result;
            }

            String agencyRegion = String.isBlank(contact.Account.Agency_Region__c) ? 'Domestic' : contact.Account.Agency_Region__c.trim();
            Decimal currentSales = contact.Account.ClassificationSalesAmount__c == null ? 0 : contact.Account.ClassificationSalesAmount__c;
            String currentTier = contact.Account.Broker_Classification__r == null ? 'Standard' : contact.Account.Broker_Classification__r.Name.trim();

            String currentYear = String.valueOf(System.today().year());

            List<Broker_Classification__c> allTiers = [
                SELECT Id,
                Name,
                AnnualSalesTargetFrom__c,
                AnnualSalesTargetTo__c,
                AnnualSalesTargetFromInternational__c,
                AnnualSalesTargetToInternational__c
                FROM Broker_Classification__c
                WHERE Year__c = :currentYear
                ORDER BY AnnualSalesTargetFrom__c ASC
            ];

            Map<String, Broker_Classification__c> tierMap = new Map<String, Broker_Classification__c>();
            List<Broker_Classification__c> displayTiers = new List<Broker_Classification__c>();

            for (Broker_Classification__c tier : allTiers) {
                String tierName = tier.Name == null ? '' : tier.Name.trim();
                tierMap.put(tierName, tier);
                if (tierName == 'Principal' || tierName == 'Maestro' || tierName == 'Ambassador') {
                    displayTiers.add(tier);
                }
            }

            Broker_Classification__c principal  = tierMap.get('Principal');
            Broker_Classification__c maestro    = tierMap.get('Maestro');
            Broker_Classification__c ambassador = tierMap.get('Ambassador');

            Decimal principalMin = principal == null ? null : (agencyRegion == 'Domestic' ? principal.AnnualSalesTargetFrom__c : principal.AnnualSalesTargetFromInternational__c);
                Decimal principalMax = principal == null ? null : (agencyRegion == 'Domestic' ? principal.AnnualSalesTargetTo__c   : principal.AnnualSalesTargetToInternational__c);

                    Decimal maestroMin = maestro == null ? null : (agencyRegion == 'Domestic' ? maestro.AnnualSalesTargetFrom__c : maestro.AnnualSalesTargetFromInternational__c);
                        Decimal maestroMax = maestro == null ? null : (agencyRegion == 'Domestic' ? maestro.AnnualSalesTargetTo__c   : maestro.AnnualSalesTargetToInternational__c);

                            Decimal ambassadorMin = ambassador == null ? null : (agencyRegion == 'Domestic' ? ambassador.AnnualSalesTargetFromInternational__c : ambassador.AnnualSalesTargetFromInternational__c);
                                Decimal ambassadorMax = ambassador == null ? null : (agencyRegion == 'Domestic' ? ambassador.AnnualSalesTargetTo__c   : ambassador.AnnualSalesTargetToInternational__c);

                                    Decimal nextMilestone = null;
            String nextTier = null;

            if (currentTier == 'Standard') {
                nextMilestone = principalMin;
                nextTier = 'Principal';
            } else if (currentTier == 'Principal') {
                nextMilestone = maestroMin;
                nextTier = 'Maestro';
            } else if (currentTier == 'Maestro') {
                nextMilestone = ambassadorMin;
                nextTier = 'Ambassador';
            } else if (currentTier == 'Ambassador') {
                nextMilestone = null;
                nextTier = 'Maximum';
            } else {
                if (currentSales < (principalMin == null ? 0 : principalMin)) {
                    nextMilestone = principalMin;
                    nextTier = 'Principal';
                } else if (currentSales < (maestroMin == null ? 0 : maestroMin)) {
                    nextMilestone = maestroMin;
                    nextTier = 'Maestro';
                } else if (currentSales < (ambassadorMin == null ? 0 : ambassadorMin)) {
                    nextMilestone = ambassadorMin;
                    nextTier = 'Ambassador';
                } else {
                    nextMilestone = null;
                    nextTier = 'Maximum';
                }
            }

            result.put('userName', currentUser.Name);
            result.put('agencyName', contact.Account.Name);
            result.put('currentSales', currentSales);
            result.put('currentTier', currentTier);
            result.put('nextMilestone', nextMilestone);
            result.put('nextTier', nextTier);

            result.put('principalMin', principalMin);
            result.put('principalMax', principalMax);
            result.put('maestroMin', maestroMin);
            result.put('maestroMax', maestroMax);
            result.put('ambassadorMin', ambassadorMin);
            result.put('ambassadorMax', ambassadorMax);

            return result;
        } catch (Exception e) {
            result.put('error', e.getMessage());
            result.put('currentSales', 0);
            result.put('currentTier', 'Standard');
            result.put('nextMilestone', null);
            result.put('nextTier', null);
            result.put('principalMin', null);
            result.put('principalMax', null);
            result.put('maestroMin', null);
            result.put('maestroMax', null);
            result.put('ambassadorMin', null);
            result.put('ambassadorMax', null);
            return result;
        }
    }
    //Update version 1.2 Ends Here
}