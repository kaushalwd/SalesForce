/**********************************************************************************************************************
* Name               : UnitSearchLwcController
* Description        : Controller for unitSearchLwc LWC  -  unit search, booking, EOI linking.
* Usage              : unitSearchLwc LWC
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                           Date            Description
* -------  -------------------------------- --------------- -------------------------------------------------------
* 1.0      prateek.b.bansal@pwc.com        18 Dec 2023     Initial Draft
* 1.1      Manoj.vallapuneni@modon.com     24 Dec 2024     Update as per new status logic
* 1.2      mdixit@horizontal.com           21 May 2025     Added document validation before block request
* 1.3      hpareek@horizontal.com          30 May 2025     Added Block Request With Fee button method
* 1.4      mdixit@horizontal.com           11 Oct 2025     Maintenance fee and multicurrency logic
* 1.5      Prateek.bansal@modon.com        08 Dec 2025     Check status instead of sub-status on reserve
* 2.0      Dinesh Selvam                   28 Dec 2025     1st Installment Due Date = SO Created Date
* 3.0      Arvind                          18/04/2026      Allow booking for Closed Opportunity (ReOpenOppsforBulk__c)
* 4.0      Arvind                          27/04/2026      Broker Agency Name + Agent Name on Sales Order
* 5.0      Arvind                          22/05/2026      EOI v2.0 - getCompletedEOIs, SO-EOI linking,
*                                                          Receipt/Allocation/Charge via @future
* 6.0      Arvind                          01/06/2026      EOI v2.1 - Phase.EOI_Required__c gate,
*                                                          Opp.Allow_EOI_Any_Status__c VIP bypass,
*                                                          without-sharing EOISystemContext inner class
*                                                          (fixes Finance object access for Sales users)
*          Arvind                          01/06/2026      Bug fix - @future per-step try-catch so
*                                                          ReceiptTrigger failure does not prevent
*                                                          Allocation + Charge creation
* 7.0      Arvind                          02/06/2026      Receipt.Allow_Any_Status_for_Booking__c:
*                                                          when checked, receipt valid regardless of Status__c
* 8.0      Arvind                          04/06/2026      Phase.EOI_Strict_Required__c: when true, EOI
*                                                          always mandatory even if no EOIs on opp.
* 9.0      Arvind                           08/06/2026     Receipt re-link fix (SalesOrder__c = null guard),
*                                                          AllocationAmount__c = Math.min(receipt, invoice)
* 10.0     Arvind                           08/06/2026     Label feature flags: EOI_Enforce_Status_Check,
*                                                          EOI_Enforce_Typology_Check (toggle in Setup, no deploy)
* 11.0     Arvind                           24/06/2026     getAllProjects: auto-select project from
*                                                          Opp.ProjectInterest__c. Meta entry prepended;
*                                                          LWC matches label -> default; fallback to first.
* 11.1     Arvind                           30/06/2026     Fix for Duplicate booking
* 12.0     Arvind                           14 Jul 2026    Booking eligibility check: block Unit Selection
* 12.01    Arvind                           02 Aug 2026    Added the Is_Employee_Payment_Plan__c not to show in LWC Serach
* 12.02    Arvind                           21 Aug 2026    Added Bucket__r.Name and BlockedFor__r.Name                                                         columns to Unit Search results (getUnitDetails)
* 14.0     Arvind                           28 Aug 2026    KYC gate for "Book Unit/s" ONLY - checkKYCEligibility.
*                                                          Warning toast on failure. Generate Offer and Block
*                                                          Request flows are NOT affected.
* 14.2     Arvind                           29 Aug 2026    KYC gate document matrix: required Documents__c vary by
*                                                          Account RecordType + UAE Resident Status. Non-Person
*                                                          Accounts also need a Trade Licence / Cert of Inc.
* 15.0     Arvind                           02 Sep 2026    v13.0 Unit Search screen block retired (LWC side only -
*                                                          checkBookingEligibility left intact but no longer called).
*                                                          All enforcement moved to the "Book Unit/s" KYC gate.
*                                                          Added Primary Contact Nationality check to
*                                                          checkKYCEligibility - protects isResidentCustomer pricing.
* 16.0     Arvind                           21 Sep 2026    EOI receipt + bedrooms rule (EOI_Enforce_Status_Check = false):
*                                                          - EOI any status allowed.
*                                                          - Receipt must be Cleared/Remitted (EOI_Receipt_Valid_Statuses)
*                                                            or Allow_Any_Status_for_Booking__c; In Progress / no receipt
*                                                            now BLOCKS booking.
*                                                          - Opp.Allow_EOI_Any_Status__c = true (VIP) skips receipt check.
*                                                          - Typology check = Number of Bedrooms only (EOI.Bedrooms__c vs
*                                                            Unit.Number_of_Bedrooms__c, number-only compare).
*                                                          - Opp.Bypass_EOI_Typology_Check__c = true skips bedrooms check.
*                                                          - Server-side safety net added in saveSalesOrder.
* 16.1     Arvind                           21 Sep 2026    saveSalesOrder: Sales Order Nationality__c and
*                                                          UAE_Resident_Status__c now mapped from Opportunity
*                                                          PrimaryContact__c (Opportunity fields are no longer
*                                                          mandatory and were arriving blank):
*                                                            Person Account     -> Account.Nationality__pc /
*                                                                                  Account.UAE_Resident_Status__pc
*                                                            Non-Person Account -> Contact.Nationality__c /
*                                                                                  Contact.UAE_Resident_Status__c
*                                                          Fallback to Opportunity values if Primary Contact is blank.
* 16.2     Arvind                           21 Sep 2026    ONE EOI = ONE ACTIVE BOOKING (mandatory, no flag skips it):
*                                                          - getCompletedEOIs hides EOIs already linked to an active SO
*                                                            and ignores receipts held by an active SO.
*                                                          - saveSalesOrder blocks: same EOI on two units in one request;
*                                                            EOI already on an active SO; EOI with no FREE cleared
*                                                            receipt (VIP exempt from the receipt part only).
*                                                          - Receipt query no longer uses "SalesOrder__c = null";
*                                                            isReceiptFree() releases receipts whose SO is Cancelled
*                                                            or Voided, so re-booking works.
* 16.3     Arvind                           21 Sep 2026    Fix compile error "Field is not writeable:
*                                                          SalesOrder__c.Nationality__c" - that field is calculated
*                                                          from the Opportunity and cannot be set directly.
*                                                          - Sales Order: only UAE_Resident_Status__c is written.
*                                                          - Opportunity: Nationality__c and UAE_Resident_Status__c
*                                                            are back-filled from the Primary Contact when BLANK
*                                                            (existing values are never overwritten). Runs inside the
*                                                            savepoint, before the Sales Order insert, so the
*                                                            calculated field on the SO resolves correctly.
* 17.0     Arvind                           23 Sep 2026    Facade Style on Sales Order (Phase.Facade_Style__c = true):
*                                                          - Options from Facade_Style_c__mdt (Active__c = true,
*                                                            Phase__c + Project_Name__c EXACT, case-sensitive match
*                                                            to the unit's Phase Name / Project Name).
*                                                          - generateSalesOffer returns facadeStyleRequired +
*                                                            facadeStyleOptions (single option auto-selected in LWC).
*                                                          - saveSalesOrder safety net: style mandatory, must be an
*                                                            allowed option; no active mdt rows -> booking blocked.
*                                                          - sendSalesOfferPDFWithFacade: passes selectedDesign to PDF.
*                                                            sendSalesOfferPDF kept (same signature) for test classes.
* 18.0     Arvind                           23 Sep 2026    Pre-Approval payment plans (Book Unit/s with EOI only):
*                                                          - getCompletedEOIs returns EOI.Pre_Approval_Number__c.
*                                                          - generateSalesOffer returns PaymentPlan.Pre_Approval__c
*                                                            (query scope unchanged: unit OR phase OR project).
*                                                          - LWC: EOI with Pre-Approval Number -> only Pre_Approval__c
*                                                            plans; otherwise Pre_Approval__c plans hidden.
*                                                          - saveSalesOrder safety net enforces the same rule.
*                                                          - Generate Offer and Modon Egypt NOT affected.
* 18.1     Arvind                           24 Sep 2026    KYC gate - Organisation (non-Person) Account:
*                                                          KYC_Status__c + Manual_KYC_Approval__c are now read
*                                                          from the PRIMARY CONTACT (Contact record), not from
*                                                          the Account. Person Accounts unchanged (Account).
* 19.0     Arvind                           24 Sep 2026    Pre-Approval Number on Sales Order (replaces v18.0 rule):
*                                                          - Booking shows ALL payment plans (no filtering).
*                                                          - EOI with Pre_Approval_Number__c -> number stored on
*                                                            SalesOrder__c.Pre_Approval_Number__c (any plan).
*                                                          - Pre-approval plan without EOI number -> number typed
*                                                            on the booking screen is REQUIRED and stored.
*                                                          - Normal plan without EOI number -> nothing stored.
*                                                          - Generate Offer and Modon Egypt NOT affected.
* 20.0     Arvind                           30 Sep 2026    Custom Label EOI_Move_Receipt_To_SO (true / false):
*                                                          - 'true'  -> Receipt moved from EOI to the Sales Order
*                                                            (SalesOrder__c, Account__c, ADM flag, Transaction Type)
*                                                            - same as current behaviour.
*                                                          - 'false' -> Receipt NOT moved; stays on the EOI, and
*                                                            Allocation + Charge are NOT created / updated either.
*                                                          - Toggle in Setup, no deployment needed.
* 21.0     Arvind                           30 Sep 2026    Custom Label KYC_Enforce_Check (true / false):
*                                                          - 'true'  -> KYC gate on "Book Unit/s" enforced
*                                                            (same as current behaviour).
*                                                          - 'false' -> KYC gate skipped; checkKYCEligibility
*                                                            returns blocked = false. No other logic changed.
*                                                          - Toggle in Setup, no deployment needed.
* 21.1     Arvind                           30 Sep 2026    KYC_Enforce_Check = 'false' still enforces Nationality:
*                                                          - Primary Contact must exist (Check 1) and Nationality
*                                                            must be populated (Check 2A) in BOTH label modes.
*                                                          - Nationality source by record type:
*                                                              Person Account     -> Account.Nationality__pc
*                                                              Non-Person Account -> Contact.Nationality__c
*                                                          - Label check moved below Check 2A; KYC Status (Check 2)
*                                                            and Documents (Check 3) are the only checks skipped.
* 21.2     Arvind                           30 Sep 2026    Check 2A extended to full booking data check (runs in
*                                                          BOTH KYC_Enforce_Check modes, lists all missing fields):
*                                                            Person Account -> PersonMailing Street/City/State/
*                                                              PostalCode/Country, UAE_Resident_Status__pc,
*                                                              Nationality__pc
*                                                            Org Account    -> Billing Street/City/State/
*                                                              PostalCode/Country
*                                                            Primary Contact -> Nationality__c (both types),
*                                                              UAE_Resident_Status__c (Org only)
* 21.3     Arvind                           30 Sep 2026    Booking data check - Org Account also requires:
*                                                            UnifiedNumber__c, TradeLicenseNumber__c,
*                                                            UAEVATRegisterNumber__c
* 21.4     Arvind                           30 Sep 2026    Booking data check - Person Account no longer checks
*                                                          Primary Contact Nationality__c (Account.Nationality__pc
*                                                          only). Org Account still checks Contact Nationality__c.
* 21.5     Arvind                           30 Sep 2026    Booking data check - clearer error message naming the
*                                                          record (Customer / Organisation Account, Primary
*                                                          Contact) and the missing fields. Account Name queried.
* 22.0     Arvind                           30 Sep 2026    Org Account - Nationality / UAE Resident Status not saved:
*                                                          - saveSalesOrder: Opportunity Nationality__c and
*                                                            UAE_Resident_Status__c are now ALWAYS synced from the
*                                                            Primary Contact (Contact) for Org Accounts (was
*                                                            blank-only, so old Opportunity values were kept and
*                                                            flowed to the Sales Order). Person Account unchanged.
*                                                          - After SO insert, UAE_Resident_Status__c is re-checked
*                                                            and re-applied if an automation overwrote it.
******************************************************************************************************************/
public with sharing class UnitSearchLwcController {
    
    private static final String username = 'OIC.USER';
    private static final String password = '0r@IC18OCT_PROD_2025$$';
    
    @AuraEnabled
    public static Boolean checkExistingSalesOrder(String oppId){
      
        //3.0 Added by Arvind to Re-open and adding flag the Opportuntiy to Allow SM to book the SO in bulk using 
            
    // Get Opportunity flag
    Opportunity opp = [
        SELECT ReOpenOppsforBulk__c 
        FROM Opportunity 
        WHERE Id = :oppId 
        LIMIT 1
    ];
    
    if (opp.ReOpenOppsforBulk__c) {
        return false; // allow booking even if SO exists
    }
    
    // Existing logic
    List<SalesOrder__c> soLst = [
        SELECT Id 
        FROM SalesOrder__c 
        WHERE Status__c NOT IN ('Cancelled', 'System cancelled', 'Voided') 
        AND Opportunity__c = :oppId
    ];
    
  return !soLst.isEmpty();
       
        /* List<SalesOrder__c> soLst = [SELECT Id FROM SalesOrder__c WHERE Status__c NOT IN ('Cancelled', 'System cancelled', 'Voided') AND Opportunity__c = :oppId];
        if(!soLst.isEmpty()){
            return true;
        }
        return false;*/
    }

    // ------------------------------------------------------------------
    // Arvind v12.0 (14/07/2026) - Booking eligibility check for Unit Selection.
    // Blocks Unit Selection (same pattern as checkExistingSalesOrder above) when
    // required Nationality/UAE Resident Status/Address fields are missing, or
    // when Opportunity and Person Account values have fallen out of sync.
    //
    // Wrapper.blocked          = true if Unit Selection should be blocked
    // Wrapper.message          = the message to show (simple, fixed per scenario)
    // ------------------------------------------------------------------
    public class BookingEligibilityResult {
        @AuraEnabled public Boolean blocked;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static BookingEligibilityResult checkBookingEligibility(String oppId) {
        BookingEligibilityResult result = new BookingEligibilityResult();
        result.blocked = false;
        result.message = '';

        List<Opportunity> oppLst = [
            SELECT Id, Nationality__c, UAE_Resident_Status__c,
                   AccountId, Account.IsPersonAccount,
                   Account.PersonMailingStreet, Account.PersonMailingCity,
                   Account.PersonMailingState, Account.PersonMailingPostalCode,
                   Account.PersonMailingCountry,
                   Account.Nationality__pc, Account.UAE_Resident_Status__pc,
                   Account.UnifiedNumber__c,
                   Account.BillingStreet, Account.BillingCity,
                   Account.BillingState, Account.BillingPostalCode,
                   Account.BillingCountry
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        if (oppLst.isEmpty() || oppLst[0].AccountId == null) {
            // No account linked at all - nothing to validate against, allow through
            // (existing behaviour elsewhere in this class already handles missing Account).
            return result;
        }

        Opportunity opp = oppLst[0];
        Boolean isPersonAccount = opp.Account.IsPersonAccount;

        if (isPersonAccount) {

            // Check 1 (merged, highest priority) - Account address (mailing address),
            // Nationality, and UAE Resident Status all missing on the Account are
            // reported together as one combined requirement.
            Boolean addressMissing =
                String.isBlank(opp.Account.PersonMailingStreet) ||
                String.isBlank(opp.Account.PersonMailingCity) ||
                String.isBlank(opp.Account.PersonMailingState) ||
                String.isBlank(opp.Account.PersonMailingPostalCode) ||
                String.isBlank(opp.Account.PersonMailingCountry);

            Boolean accountNationalityMissing =
                String.isBlank(opp.Account.Nationality__pc) ||
                String.isBlank(opp.Account.UAE_Resident_Status__pc);

            if (addressMissing || accountNationalityMissing) {
                result.blocked = true;
                result.message = 'Mailing address, Nationality and Resident Status are required on the account before proceeding to Unit Selection.';
                return result;
            }

            // Check 2 (lowest priority) - Opportunity Nationality / UAE Resident Status
            // missing, or populated but mismatched against the Account (safety net -
            // these should always be kept in sync between Opportunity and Account).
            Boolean oppFieldsMissing =
                String.isBlank(opp.Nationality__c) || String.isBlank(opp.UAE_Resident_Status__c);

            if (oppFieldsMissing) {
                result.blocked = true;
                result.message = 'Please choose Nationality and Resident Status on the opportunity before proceeding to Unit Selection.';
                return result;
            }

            Boolean nationalityMismatch = opp.Nationality__c != opp.Account.Nationality__pc;
            Boolean residentStatusMismatch = opp.UAE_Resident_Status__c != opp.Account.UAE_Resident_Status__pc;

            if (nationalityMismatch || residentStatusMismatch) {
                result.blocked = true;
                result.message = 'Nationality and Resident Status on the opportunity and the account should always match. Please update them before proceeding.';
                return result;
            }

        } else {

            // Org Account - address + Unified Number, then Opportunity fields.
            Boolean addressMissing =
                String.isBlank(opp.Account.BillingStreet) ||
                String.isBlank(opp.Account.BillingCity) ||
                String.isBlank(opp.Account.BillingState) ||
                String.isBlank(opp.Account.BillingPostalCode) ||
                String.isBlank(opp.Account.BillingCountry);

            Boolean unifiedNumberMissing = String.isBlank(opp.Account.UnifiedNumber__c);

            if (addressMissing || unifiedNumberMissing) {
                result.blocked = true;
                result.message = 'Address and Unified Number are required for an organization account before proceeding to Unit Selection.';
                return result;
            }

            Boolean oppFieldsMissing =
                String.isBlank(opp.Nationality__c) || String.isBlank(opp.UAE_Resident_Status__c);

            if (oppFieldsMissing) {
                result.blocked = true;
                result.message = 'Please choose Nationality and Resident Status on the opportunity before proceeding to Unit Selection.';
                return result;
            }
        }

        return result;
    }
    // Arvind v13.0 - END

    // ==================================================================
    // Arvind v14.0 (28/08/2026) - KYC GATE - "Book Unit/s" FLOW ONLY
    // ------------------------------------------------------------------
    // Called from unitSearchLwc.js handleMenuAction -> BOOKING branch only.
    // NOT called from OFFER / BLOCKREQUEST / BLOCKREQUESTEGYPT /
    // BLOCKREQUESTWITHFEES / FORWARD / BACK. Generate Offer flow untouched.
    //
    // Pass criteria (ALL must be true):
    //   1. Opportunity.PrimaryContact__c is populated.
    //   2. KYC Status is an accepted value (see acceptedKycStatuses below)
    //      OR Manual KYC Approval = 'Approved'.
    //      Arvind v18.1 (24 Sep 2026) - source depends on the record type:
    //        Person Account       -> PrimaryContact__r.Account.KYC_Status__c /
    //                                PrimaryContact__r.Account.Manual_KYC_Approval__c
    //        Organisation Account -> PrimaryContact__r.KYC_Status__c /
    //                                PrimaryContact__r.Manual_KYC_Approval__c (Contact)
    //   3. v14.2 - The required Documents__c records all exist AND each one
    //      has an ACTUAL FILE attached (ContentDocumentLink, or a classic
    //      Attachment as fallback). A record with no file FAILS.
    //      Which documents are required depends on the Primary Contact's
    //      Account record type and UAE Resident Status:
    //
    //      ON THE PRIMARY CONTACT (Documents__c.PrimaryContact__c):
    //        Resident      -> Emirates/National ID Front
    //                         Emirates/National ID Back
    //                         KYC Form - Signed
    //                         Passport
    //        Non-Resident  -> KYC Form - Signed
    //                         Passport
    //
    //      ON THE ACCOUNT (Documents__c.Account__c) - NON-PERSON ACCOUNTS ONLY:
    //        At least ONE of these, either is accepted regardless of status:
    //                         Commercial trade License (Resident)
    //                         Certificate of Incorporation (Non Resident)
    //
    //      Resident status is read from a different field per record type,
    //      because __pc fields only populate on Person Accounts:
    //        Person Account     -> Account.UAE_Resident_Status__pc
    //        Non-Person Account -> Contact.UAE_Resident_Status__c
    //
    // On failure the LWC shows a WARNING toast and stops the booking.
    //
    // Arvind v21.0 (30 Sep 2026) - Gate can be switched off with Custom
    // Label KYC_Enforce_Check = 'false'.
    // Arvind v21.1 (30 Sep 2026) - With the label 'false', Check 1 (Primary
    // Contact) and Check 2A (Nationality) STILL run; only Check 2 (KYC Status)
    // and Check 3 (Documents) are skipped. Nationality is read from
    // Account.Nationality__pc (Person) or Contact.Nationality__c (Organisation).
    // ==================================================================
    public class KYCEligibilityResult {
        @AuraEnabled public Boolean blocked;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static KYCEligibilityResult checkKYCEligibility(String oppId) {
        KYCEligibilityResult result = new KYCEligibilityResult();
        result.blocked = false;
        result.message = '';

        // Arvind v21.1 (30 Sep 2026) - v21.0 label check moved from here to just
        // below Check 2A, so Primary Contact + Nationality are always validated.

        // Arvind v15.0 (02/09/2026) - PrimaryContact__r.Nationality__c added to the
        // SELECT list below for Check 2A. Comment kept outside the SOQL brackets;
        // inline // comments inside an Apex SOQL statement do not compile.
        // Arvind v21.1 (30 Sep 2026) - PrimaryContact__r.Account.Nationality__pc added
        // to the SELECT list below (Person Account Nationality source for Check 2A).
        // Arvind v21.2 (30 Sep 2026) - PersonMailing* and Billing* address fields of
        // PrimaryContact__r.Account added to the SELECT list below for Check 2A.
        List<Opportunity> oppLst = [
            SELECT Id, PrimaryContact__c,
                   PrimaryContact__r.Name,
                   PrimaryContact__r.Account.KYC_Status__c,
                   PrimaryContact__r.Account.Manual_KYC_Approval__c,
                   PrimaryContact__r.KYC_Status__c,
                   PrimaryContact__r.Manual_KYC_Approval__c,
                   PrimaryContact__r.AccountId,
                   PrimaryContact__r.Account.RecordType.Name,
                   PrimaryContact__r.Account.UAE_Resident_Status__pc,
                   PrimaryContact__r.UAE_Resident_Status__c,
                   PrimaryContact__r.Nationality__c,
                   PrimaryContact__r.Account.Nationality__pc,
                   PrimaryContact__r.Account.PersonMailingStreet,
                   PrimaryContact__r.Account.PersonMailingCity,
                   PrimaryContact__r.Account.PersonMailingState,
                   PrimaryContact__r.Account.PersonMailingPostalCode,
                   PrimaryContact__r.Account.PersonMailingCountry,
                   PrimaryContact__r.Account.BillingStreet,
                   PrimaryContact__r.Account.BillingCity,
                   PrimaryContact__r.Account.BillingState,
                   PrimaryContact__r.Account.BillingPostalCode,
                   PrimaryContact__r.Account.BillingCountry,
                   PrimaryContact__r.Account.UnifiedNumber__c,
                   PrimaryContact__r.Account.TradeLicenseNumber__c,
                   PrimaryContact__r.Account.UAEVATRegisterNumber__c,
                   PrimaryContact__r.Account.Name
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        if (oppLst.isEmpty()) {
            // Nothing to validate against - allow through, same defensive
            // posture as checkBookingEligibility above.
            return result;
        }

        Opportunity opp = oppLst[0];

        // -- Check 1: Primary Contact must exist --------------------------------
        if (opp.PrimaryContact__c == null) {
            result.blocked = true;
            result.message = 'Primary Contact is not set on this Opportunity. '
                           + 'Please add a Primary Contact and complete KYC before booking.';
            return result;
        }

        // Arvind v18.1 (24 Sep 2026) - record type resolved BEFORE Check 2 (was in Check 3)
        // so the KYC source can differ for Person vs Organisation accounts.
        // A Contact with no Account is treated as Organisation (reads the Contact).
        String recordTypeName = (opp.PrimaryContact__r.Account != null)
            ? opp.PrimaryContact__r.Account.RecordType.Name : null;
        Boolean isPersonAccount = String.isNotBlank(recordTypeName)
                                  && recordTypeName.trim().equalsIgnoreCase('Person Account');

        // -- Check 2A (Arvind v15.0, 02/09/2026): Primary Contact Nationality -----
        // Added when the v13.0 Unit Search screen block was retired. Nationality was
        // previously enforced there; the Book gate now owns it. This is not only a data
        // quality check: getUnitDetails derives isResidentCustomer from this exact field
        // (PrimaryContact__r.Nationality__c == 'United Arab Emirates'). A blank value
        // silently evaluates to false, which would price Wadeem units at TotalPrice__c
        // instead of UAE_Citizen_Price__c. Blocking here prevents a mispriced booking.
        // Arvind v21.1 (30 Sep 2026) - moved ABOVE Check 2 so it also runs when
        // KYC_Enforce_Check = 'false'.
        //
        // Arvind v21.2 (30 Sep 2026) - extended to the full booking data check.
        // Runs in BOTH label modes. ALL missing fields are listed in one message.
        //   Person Account (PrimaryContact__r.Account):
        //     PersonMailingStreet, PersonMailingCity, PersonMailingState,
        //     PersonMailingPostalCode, PersonMailingCountry,
        //     UAE_Resident_Status__pc, Nationality__pc
        //   Organisation Account (PrimaryContact__r.Account):
        //     BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
        //     + v21.3: UnifiedNumber__c, TradeLicenseNumber__c, UAEVATRegisterNumber__c
        //   Primary Contact (Contact) - Organisation only:
        //     Nationality__c  (v21.4 - Person Account uses Nationality__pc only)
        //     UAE_Resident_Status__c
        //     (Person Account resident status is checked on UAE_Resident_Status__pc)
        // Previous v21.1 logic (Nationality only):
        //   String pcNationality = isPersonAccount
        //       ? opp.PrimaryContact__r.Account.Nationality__pc
        //       : opp.PrimaryContact__r.Nationality__c;
        //   if (String.isBlank(pcNationality)) { ...blocked... }
        Account pcAcc = opp.PrimaryContact__r.Account;
        List<String> missingAccountFields = new List<String>();
        List<String> missingContactFields = new List<String>();

        if (isPersonAccount) {
            if (String.isBlank(pcAcc.PersonMailingStreet))     missingAccountFields.add('Mailing Street');
            if (String.isBlank(pcAcc.PersonMailingCity))       missingAccountFields.add('Mailing City');
            if (String.isBlank(pcAcc.PersonMailingState))      missingAccountFields.add('Mailing State');
            if (String.isBlank(pcAcc.PersonMailingPostalCode)) missingAccountFields.add('Mailing Postal Code');
            if (String.isBlank(pcAcc.PersonMailingCountry))    missingAccountFields.add('Mailing Country');
            if (String.isBlank(pcAcc.UAE_Resident_Status__pc)) missingAccountFields.add('UAE Resident Status');
            if (String.isBlank(pcAcc.Nationality__pc))         missingAccountFields.add('Nationality');
        } else {
            if (pcAcc == null) {
                missingAccountFields.add('Account link (the Primary Contact is not linked to an Account)');
            } else {
                if (String.isBlank(pcAcc.BillingStreet))     missingAccountFields.add('Billing Street');
                if (String.isBlank(pcAcc.BillingCity))       missingAccountFields.add('Billing City');
                if (String.isBlank(pcAcc.BillingState))      missingAccountFields.add('Billing State');
                if (String.isBlank(pcAcc.BillingPostalCode)) missingAccountFields.add('Billing Postal Code');
                if (String.isBlank(pcAcc.BillingCountry))    missingAccountFields.add('Billing Country');
                // Arvind v21.3 (30 Sep 2026) - Org identity numbers
                if (isBlankValue(pcAcc.UnifiedNumber__c))        missingAccountFields.add('Unified Number');
                if (isBlankValue(pcAcc.TradeLicenseNumber__c))   missingAccountFields.add('Trade License Number');
                if (isBlankValue(pcAcc.UAEVATRegisterNumber__c)) missingAccountFields.add('UAE VAT Register Number');
                // Arvind v21.3 - END
            }
            if (String.isBlank(opp.PrimaryContact__r.UAE_Resident_Status__c)) {
                missingContactFields.add('UAE Resident Status');
            }
        }
        // Contact Nationality__c - Organisation only.
        // Arvind v21.4 (30 Sep 2026) - Person Account no longer checks Contact
        // Nationality__c (Account.Nationality__pc above is enough).
        // Previous (both record types):
        //   if (String.isBlank(opp.PrimaryContact__r.Nationality__c)) {
        if (!isPersonAccount && String.isBlank(opp.PrimaryContact__r.Nationality__c)) {
            missingContactFields.add('Nationality');
        }

        if (!missingAccountFields.isEmpty() || !missingContactFields.isEmpty()) {
            // Arvind v21.5 (30 Sep 2026) - clearer error message: names the record
            // (Customer Account / Organisation Account / Primary Contact) and the
            // exact fields to fill, so the agent knows where to go.
            // Previous:
            //   'Please complete the following before booking. '
            //   + 'Account: ... | Primary Contact (Name): ...'
            String accName = (pcAcc != null && String.isNotBlank(pcAcc.Name)) ? pcAcc.Name : '';
            String accLabel = isPersonAccount ? 'Customer Account' : 'Organisation Account';
            List<String> parts = new List<String>();
            if (!missingAccountFields.isEmpty()) {
                parts.add(accLabel
                        + (String.isNotBlank(accName) ? ' "' + accName + '"' : '')
                        + ' - ' + String.join(missingAccountFields, ', '));
            }
            if (!missingContactFields.isEmpty()) {
                parts.add('Primary Contact "' + opp.PrimaryContact__r.Name + '" - '
                        + String.join(missingContactFields, ', '));
            }
            result.blocked = true;
            result.message = 'Unable to book the unit. The following mandatory fields are missing. '
                           + String.join(parts, '. ')
                           + '. Please update them from Update Address button on Opportunity.';
            return result;
            // Arvind v21.5 - END
        }
        // Arvind v21.4 - debug value follows the record type
        String pcNationality = isPersonAccount
            ? pcAcc.Nationality__pc
            : opp.PrimaryContact__r.Nationality__c;
        // Arvind v15.0 / v21.1 / v21.2 - END

        // Arvind v21.0 (30 Sep 2026) - START
        // Custom Label KYC_Enforce_Check (true / false):
        //   'true'  -> KYC gate enforced (same as current behaviour).
        //   'false' -> KYC Status (Check 2) and Documents (Check 3) skipped.
        // Arvind v21.1 (30 Sep 2026) - moved here from the top of the method, so
        // Check 1 (Primary Contact) and Check 2A (Nationality) always run first.
        // Only the exact value 'false' disables the gate. Any other value keeps
        // KYC enforced (fail-safe). Toggle in Setup, no deployment needed.
        if (String.isNotBlank(System.Label.KYC_Enforce_Check)
            && System.Label.KYC_Enforce_Check.trim().equalsIgnoreCase('false')) {
            System.debug('Arvind v21.1 - KYC Status + Documents skipped: KYC_Enforce_Check = '
                + System.Label.KYC_Enforce_Check + ' | Nationality check passed: ' + pcNationality);
            return result;
        }
        // Arvind v21.0 - END

        // -- Check 2: KYC Status Active OR Manual KYC Approval = Approved -------
        // Accepted KYC Status outputs are listed below - add/remove values here if
        // the formula wording changes. Do NOT use contains('Active') - 'Inactive'
        // would wrongly pass.
        // Arvind v18.1 (24 Sep 2026):
        //   Person Account       -> Account fields (unchanged)
        //   Organisation Account -> Primary Contact (Contact) fields
        // Previous (all record types):
        //   String kycStatus     = opp.PrimaryContact__r.Account.KYC_Status__c;
        //   String manualKycAppr = opp.PrimaryContact__r.Account.Manual_KYC_Approval__c;
        String kycStatus;
        String manualKycAppr;
        if (isPersonAccount) {
            kycStatus     = opp.PrimaryContact__r.Account.KYC_Status__c;
            manualKycAppr = opp.PrimaryContact__r.Account.Manual_KYC_Approval__c;
        } else {
            kycStatus     = opp.PrimaryContact__r.KYC_Status__c;
            manualKycAppr = opp.PrimaryContact__r.Manual_KYC_Approval__c;
        }

        Set<String> acceptedKycStatuses = new Set<String>{ 'active', 'kyc active' };

        Boolean kycActive = String.isNotBlank(kycStatus)
                            && acceptedKycStatuses.contains(kycStatus.trim().toLowerCase());

        Boolean kycApproved = String.isNotBlank(manualKycAppr)
                              && manualKycAppr.trim().equalsIgnoreCase('Approved');

        if (!kycActive && !kycApproved) {
            result.blocked = true;
            result.message = 'KYC is not completed for the Primary Contact. '
                           + 'KYC Status must be Active, or Manual KYC Approval must be Approved, before booking.';
            return result;
        }

        // Arvind v21.1 (30 Sep 2026) - Check 2A moved above Check 2 (see above).

        // -- Check 3 (v14.2): required documents per record type + resident status --
        // Arvind v18.1 (24 Sep 2026) - recordTypeName / isPersonAccount now resolved
        // above Check 2 and reused here.

        // __pc fields only populate on Person Accounts, so the org path reads
        // the equivalent field from the Contact instead.
        String residentStatus = isPersonAccount
            ? opp.PrimaryContact__r.Account.UAE_Resident_Status__pc
            : opp.PrimaryContact__r.UAE_Resident_Status__c;

        if (String.isBlank(residentStatus)) {
            result.blocked = true;
            result.message = 'UAE Resident Status is not set on the customer account. '
                           + 'Please populate it before booking.';
            return result;
        }

        Boolean isResident = residentStatus.trim().equalsIgnoreCase('Resident');

        // Documents required on the Primary Contact. Resident adds the two
        // Emirates/National ID sides on top of the base set.
        List<String> requiredContactDocs = new List<String>{
            'KYC Form - Signed',
            'Passport'
        };
        if (isResident) {
            requiredContactDocs.add('Emirates/National ID Front');
            requiredContactDocs.add('Emirates/National ID Back');
        }

        // Documents accepted on the Account (non-Person Accounts only).
        // EITHER one satisfies the requirement, regardless of resident status.
        List<String> acceptedAccountDocs = new List<String>{
            'Commercial trade License (Resident)',
            'Certificate of Incorporation (Non Resident)'
        };

        // -- Gather candidate Documents__c records --------------------------
        Map<String, Set<Id>> contactDocsByName = new Map<String, Set<Id>>();
        Set<Id> allDocIds = new Set<Id>();

        for (Documents__c doc : [
            SELECT Id, Name
            FROM Documents__c
            WHERE PrimaryContact__c = :opp.PrimaryContact__c
            AND Name IN :requiredContactDocs
        ]) {
            if (!contactDocsByName.containsKey(doc.Name)) {
                contactDocsByName.put(doc.Name, new Set<Id>());
            }
            contactDocsByName.get(doc.Name).add(doc.Id);
            allDocIds.add(doc.Id);
        }

        // Account-level documents - queried only for non-Person Accounts.
        // IMPORTANT: confirm Account__c is the correct Account lookup API name
        // on Documents__c before deploying.
        Set<Id> accountDocIds = new Set<Id>();
        if (!isPersonAccount && opp.PrimaryContact__r.AccountId != null) {
            for (Documents__c doc : [
                SELECT Id, Name
                FROM Documents__c
                WHERE Account__c = :opp.PrimaryContact__r.AccountId
                AND Name IN :acceptedAccountDocs
            ]) {
                accountDocIds.add(doc.Id);
                allDocIds.add(doc.Id);
            }
        }

        // A single system-context pass tells us which records actually hold a file.
        Set<Id> docsWithFile = new KYCFileContext().parentsWithFiles(allDocIds);

        // -- Evaluate, collecting EVERY problem so the agent fixes them in one pass --
        List<String> missingDocs = new List<String>();
        for (String docName : requiredContactDocs) {
            Boolean satisfied = false;
            if (contactDocsByName.containsKey(docName)) {
                for (Id docId : contactDocsByName.get(docName)) {
                    if (docsWithFile.contains(docId)) {
                        satisfied = true;
                        break;
                    }
                }
            }
            if (!satisfied) {
                missingDocs.add(docName);
            }
        }

        Boolean accountDocSatisfied = true;
        if (!isPersonAccount) {
            accountDocSatisfied = false;
            for (Id docId : accountDocIds) {
                if (docsWithFile.contains(docId)) {
                    accountDocSatisfied = true;
                    break;
                }
            }
        }

        if (!missingDocs.isEmpty() || !accountDocSatisfied) {
            result.blocked = true;
            String msg = 'KYC documents are incomplete. The following must exist '
                       + 'with a file uploaded before booking: ';
            if (!missingDocs.isEmpty()) {
                msg += String.join(missingDocs, ', ');
            }
            if (!accountDocSatisfied) {
                if (!missingDocs.isEmpty()) {
                    msg += '; ';
                }
                msg += 'and one of ' + String.join(acceptedAccountDocs, ' or ')
                     + ' on the account';
            }
            result.message = msg + '.';
            return result;
        }

        return result;
    }

    /**
     * Arvind v21.3 (30 Sep 2026)
     * Null/blank check that works for Text AND Number fields, so the booking
     * check compiles whatever the data type of UnifiedNumber__c,
     * TradeLicenseNumber__c and UAEVATRegisterNumber__c is.
     */
    private static Boolean isBlankValue(Object val) {
        return val == null || String.isBlank(String.valueOf(val));
    }

    /**
     * Arvind v14.0 / v14.2
     * Runs the file-presence lookup WITHOUT SHARING so ContentDocumentLink /
     * Attachment visibility does not depend on which user uploaded the file.
     * Read-only - no DML performed here.
     *
     * v14.2 - returns the SUBSET of parent Ids that hold at least one file,
     * so every required document is evaluated in a single pass rather than
     * one query per document.
     */
    private without sharing class KYCFileContext {

        public Set<Id> parentsWithFiles(Set<Id> parentIds) {
            Set<Id> withFile = new Set<Id>();
            if (parentIds == null || parentIds.isEmpty()) {
                return withFile;
            }
            // Salesforce Files (ContentDocument via ContentDocumentLink)
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :parentIds
            ]) {
                withFile.add(cdl.LinkedEntityId);
            }
            // Fallback: classic Attachments, only for parents still unmatched
            Set<Id> remaining = new Set<Id>(parentIds);
            remaining.removeAll(withFile);
            if (!remaining.isEmpty()) {
                for (Attachment att : [
                    SELECT ParentId
                    FROM Attachment
                    WHERE ParentId IN :remaining
                ]) {
                    withFile.add(att.ParentId);
                }
            }
            return withFile;
        }
    }
    // Arvind v14.0 - END
    
    //method to get projects
    @AuraEnabled
    public static List<Map<String, String>> getAllProjects(String oppId) {
        List<Map<String, String>> filtersToReturn = new List<Map<String, String>>();
        
        try {
            // Arvind v11.0 (24/06/2026) - Added ProjectInterest__c to auto-select default project in LWC
            Opportunity opp = [SELECT Id, Name, Source_Entity__c, ProjectInterest__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
            
            // Arvind v11.0 (24/06/2026) - Meta entry at index 0; LWC reads projectInterest to auto-select
            Map<String, String> projectMeta = new Map<String, String>();
            projectMeta.put('type',            'meta');
            projectMeta.put('projectInterest', String.isNotBlank(opp.ProjectInterest__c) ? opp.ProjectInterest__c : '');
            filtersToReturn.add(projectMeta);
            
            List<Project__c> projectsList = new List<Project__c>();
            if (opp.Source_Entity__c == 'Modon - Egypt') {
                projectsList = [SELECT Id, Name, Source_Entity__c 
                                FROM Project__c 
                                WHERE Source_Entity__c = 'Modon - Egypt' 
                                WITH SECURITY_ENFORCED 
                                ORDER BY Name];
            } else {
                projectsList = [SELECT Id, Name, Source_Entity__c 
                                FROM Project__c 
                                WHERE Source_Entity__c != 'Modon - Egypt' 
                                WITH SECURITY_ENFORCED 
                                ORDER BY Name];
            }
            
            for (Project__c tempProject : projectsList) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put('label', tempProject.Name);
                tempMap.put('value', tempProject.Id);
                filtersToReturn.add(tempMap);
            }
        } catch (Exception e) {
            // Optionally log the error or handle it as needed
            System.debug('Error in getAllProjects: ' + e.getMessage());
            // You can also return an empty list or a list with an error message if needed
        }
        
        return filtersToReturn;
    }
    
    
    
    //method to send sales offer to customer
    // Arvind v17.0 (23 Sep 2026) - kept with the original signature (test classes / other callers).
    // Delegates to sendSalesOfferPDFWithFacade with no Facade Style.
    @AuraEnabled
    public static void sendSalesOfferPDF(String unitId, String unitName, String opportunityId, String customerName, String selectedPymnt, String unitOption){
        sendSalesOfferPDFWithFacade(unitId, unitName, opportunityId, customerName, selectedPymnt, unitOption, null);
    }

    // Arvind v17.0 (23 Sep 2026) - same as sendSalesOfferPDF + Facade Style passed to the PDF as selectedDesign
    @AuraEnabled
    public static void sendSalesOfferPDFWithFacade(String unitId, String unitName, String opportunityId, String customerName, String selectedPymnt, String unitOption, String facadeStyle){
        system.debug('unitId==>' + unitId);
        system.debug('unitName==>' + unitName);
        system.debug('customerName==>' + customerName);
        system.debug('selectedPymnt==>' + selectedPymnt);
        system.debug('facadeStyle==>' + facadeStyle);
        
        PageReference pdf = Page.OfferDetailsPDF;
        pdf.getParameters().put('id',opportunityId);
        pdf.getParameters().put('currentUnit',unitId);
        pdf.getParameters().put('selectedPayment',selectedPymnt);
        pdf.getParameters().put('unitOption',unitOption);
        // Arvind v17.0 (23 Sep 2026) - Facade Style on the offer PDF
        if (String.isNotBlank(facadeStyle)) {
            pdf.getParameters().put('selectedDesign', facadeStyle);
        }
        pdf.getParameters().put('customerName',(customerName!=null?customerName:''));
        
        pdf.setRedirect(true);
        
        List<Messaging.EmailFileAttachment> fileAttachments = new List<Messaging.EmailFileAttachment>();
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('Offer-'+unitName+'-'+customerName+'-'+System.today().format()+'.pdf');
        efa.setBody(Test.isRunningTest()? blob.valueOf('Methods defined as TestMethod do not support getContent call') :pdf.getContent());
        fileAttachments.add(efa);
        string emailTemplateId = '';
        string emailTemplateLeadId = '';
        String accountEmail = '';
        string OrgWideEmailAddressID = '';
        string whatId = '';
        string targetObjectId = '';
        
        List<string> toRecipients = new List<String>();
        for(OrgWideEmailAddress tempRec: [select id,Address from OrgWideEmailAddress limit 1]){
            OrgWideEmailAddressID=tempRec.Id;
        }
        
        for(Emailtemplate tempRec:  [select id, DeveloperName from emailtemplate where DeveloperName = 'SalesOffer' limit 1]){
            emailTemplateId=tempRec.Id;
        }
        
        if(opportunityId!=null ){
            
            List<opportunity> opportunityRecords=[select id,AccountId,Account.PersonContactId, PrimaryContact__c, StageName from opportunity where id =:opportunityId limit 1];
            if(!opportunityRecords.isEmpty()){
                //accountEmail = opportunityRecords[0].Account.PersonEmail;
                //toRecipients.add(accountEmail);
                targetObjectId = (String.isNotBlank(opportunityRecords[0].Account.PersonContactId) ? opportunityRecords[0].Account.PersonContactId : ((String.isNotBlank(opportunityRecords[0].PrimaryContact__c) ? opportunityRecords[0].PrimaryContact__c : null)));
                whatId = opportunityRecords[0].Id;
            }
        }
        // toRecipients.add('prateekbansal32@gmail.com');
        // toRecipients.add('prateek.b.bansal@pwc.com');
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();             
        mail.setSaveAsActivity(true);
        mail.setBccSender(false);
        mail.setUseSignature(false);
        if(targetObjectId != null && targetObjectId != ''){
            mail.setTargetObjectId(targetObjectId);
        }
        if(whatId!=null && whatId!=''){
            mail.setWhatId(whatId);
        }
        if(emailTemplateId!=null && emailTemplateId!=''){
            mail.setTemplateID(emailTemplateId);
        }
        if(toRecipients!=null && !toRecipients.isEmpty() ){
            mail.setToAddresses(toRecipients);
        }
        if(OrgWideEmailAddressID != null && OrgWideEmailAddressID!=''){
            mail.setOrgWideEmailAddressId(OrgWideEmailAddressID);
        }
        // Specify FileAttachments
        if(fileAttachments != null && !fileAttachments.isEmpty()) {
            mail.setFileAttachments(fileAttachments);
        }
        system.debug('mail==>'+ mail);
        Messaging.sendEmail(new list<Messaging.SingleEmailMessage>{mail});
    }
    
    //method to generate sales offer
    @AuraEnabled
    public static UnitDetailsWrapper generateSalesOffer(String selectedUnitId, Boolean isModonEgyptProfile){
        
        UnitDetailsWrapper udObj = new UnitDetailsWrapper();
        List<PaymentDetails> paymentLst = new List<PaymentDetails>();
        List<UnitOptionDetails> uoLst = new List<UnitOptionDetails>();
        if(selectedUnitId != null && String.isNotBlank(selectedUnitId)){
            String phaseId = '';
            String projectId = '';
            String phaseOptions = '';
            // Arvind v17.0 (23 Sep 2026) - Added Phase__r.Name, Phase__r.Project__r.Name, Phase__r.Facade_Style__c
            for(Unit__c unitObj : [SELECT Id, Phase__c, Phase__r.Name, Phase__r.Project__c, Phase__r.Project__r.Name,
                                          Phase__r.PhaseOptions__c, Phase__r.Facade_Style__c
                                   FROM Unit__c WHERE Id = : selectedUnitId]){
                // Arvind v17.0 (23 Sep 2026) - Facade Style options for this unit (flag on Phase)
                udObj.facadeStyleRequired = unitObj.Phase__r != null && unitObj.Phase__r.Facade_Style__c == true;
                udObj.facadeStyleOptions  = new List<Map<String, String>>();
                if (udObj.facadeStyleRequired) {
                    String fProject = unitObj.Phase__r.Project__r != null ? unitObj.Phase__r.Project__r.Name : null;
                    for (String opt : getFacadeStyleOptions(getFacadeStyleMatrix(), unitObj.Phase__r.Name, fProject)) {
                        udObj.facadeStyleOptions.add(new Map<String, String>{ 'label' => opt, 'value' => opt });
                    }
                }
                // Arvind v17.0 - END
                if(String.isNotBlank(unitObj.Phase__c)){
                    phaseId = unitObj.Phase__c;
                    if(String.isNotBlank(unitObj.Phase__r.Project__c)){
                        projectId = unitObj.Phase__r.Project__c;
                    }
                    if(String.isNotBlank(unitObj.Phase__r.PhaseOptions__c)){
                        List<UnitPicklistOptions> picklistOptionWrapperLst = (List<UnitPicklistOptions>) JSON.deserialize(unitObj.Phase__r.PhaseOptions__c, List<UnitPicklistOptions>.class);
                        List<UnitOptionWrapper> unitOptionWrapperList = new List<UnitOptionWrapper>();
                        system.debug('picklistOptionWrapperLst==>' + picklistOptionWrapperLst);
                        for(UnitPicklistOptions picklistOptionObj : picklistOptionWrapperLst){
                            UnitOptionWrapper wrapperObj = new UnitOptionWrapper();
                            List<Map<String,String>> unitPicklistOptions = new List<Map<String,String>>();
                            unitPicklistOptions.add(new map<string,string>{'label' => '--None--' , 'value' => ''});
                            wrapperObj.fieldLabel = picklistOptionObj.picklistLable;
                            wrapperObj.fieldApiName = picklistOptionObj.picklistApiName;
                            wrapperObj.selectedValue = '';
                            for(String optionValue : picklistOptionObj.picklistOptions){
                                unitPicklistOptions.add(new map<string,string>{'label' => optionValue , 'value' => optionValue});
                            }
                            wrapperObj.unitOptions = unitPicklistOptions;
                            unitOptionWrapperList.add(wrapperObj);
                        }
                        udObj.unitOptionsList = unitOptionWrapperList;
                        system.debug('unitOptionWrapperList==>' + unitOptionWrapperList);
                    }
                }
                
            }
            //Arvind 12.01 
            // Arvind v18.0 (23 Sep 2026) - Added Pre_Approval__c (LWC filters booking plans by EOI Pre-Approval Number)
            String paymentQuery = 'SELECT Id, Name, isActive__c, Is_Employee_Payment_Plan__c, Pre_Approval__c, Discount_Percent__c,Maintenance_Fee__c, Number_of_Maintenance_Fee__c, CurrencyIsoCode, (SELECT Id, Name, BrokerPayout__c, IsHandoverPayment__c, Milestone__c, Milestone_Egypt_Percent__c, MilestoneDate__c, MilestoneDescription__c, MilestoneNumber__c, SalesAgentPayout__c, Is_Maintenance_Installment__c, MilestoneInstallment__c,MilestoneInstallment__r.Milestone_Due_Date__c,Milestone_Due__c FROM Payment_Installments__r ORDER BY MilestoneNumber__c) FROM PaymentPlan__c WHERE Unit__c = \'' + selectedUnitId + '\'';
            if(String.isNotBlank(phaseId)){
                paymentQuery += ' OR Phase__c = \'' + phaseId + '\'';
            }
            if(String.isNotBlank(projectId)){
                paymentQuery += ' OR Project__c = \'' + projectId + '\'';
            }
            
            String unitOptionQuery = 'SELECT Id, Name, Phase__c, Unit__c, TotalPrice__c FROM Unit_Option__c WHERE Unit__c = \'' + selectedUnitId + '\'';
            if(String.isNotBlank(phaseId)){
                unitOptionQuery += ' OR Phase__c = \'' + phaseId + '\'';
            }
            List<PaymentPlan__c> tempPaymentPlanLst = Database.query(paymentQuery);
            List<PaymentPlan__c> paymentPlanLst = new List<PaymentPlan__c>();
            for(PaymentPlan__c paymentPlanObj : tempPaymentPlanLst){
                if(paymentPlanObj.isActive__c && !paymentPlanObj.Is_Employee_Payment_Plan__c){  // Arvind 12.01
                    paymentPlanLst.add(paymentPlanObj);
                }
            }
            
            
            system.debug('paymentPlanLst====>>'+paymentPlanLst);
            List<Unit_Option__c> unitOptionLst = Database.query(unitOptionQuery);
            
            //unit options
            List<Map<String,String>> availableUnitOptions = new List<Map<String,String>>();
            Map<String, Unit_Option__c> unitOptionMap = new Map<String, Unit_Option__c>();
            for(Unit_Option__c uoObj : unitOptionLst){
                if(String.isNotBlank(uoObj.Phase__c)){
                    unitOptionMap.put(uoObj.Name, uoObj);
                }
            }
            for(Unit_Option__c uoObj : unitOptionLst){
                if(String.isNotBlank(uoObj.Unit__c)){
                    unitOptionMap.put(uoObj.Name, uoObj);
                }
            }
            availableUnitOptions.add(new map<string,string>{'label' => '--None--' , 'value' => ''});
            for(Unit_Option__c uoObj : unitOptionLst){
                UnitOptionDetails uoDetail = new UnitOptionDetails();
                uoDetail.unitOptionObj = unitOptionMap.get(uoObj.Name);
                uoLst.add(uoDetail);
                availableUnitOptions.add(new map<string,string>{'label' => unitOptionMap.get(uoObj.Name).Name , 'value' => unitOptionMap.get(uoObj.Name).Id});
            }
            UnitsUnitOptionDetails unitOptionDetailWrapper = new UnitsUnitOptionDetails();
            if(!uoLst.isEmpty()){
                unitOptionDetailWrapper.unitOptionLst = uoLst;
                unitOptionDetailWrapper.availableUnitOptions = availableUnitOptions;
                unitOptionDetailWrapper.selectedUnitOption = '';
            }
            system.debug('availableUnitOptions==>' + availableUnitOptions);
            system.debug('uoLst==>' + uoLst);
            system.debug('unitOptionDetailWrapper==>' + unitOptionDetailWrapper);
            udObj.unitOptiontDetailObj = unitOptionDetailWrapper;
            
            //payment plan
            List<Map<String,String>> availablePaymentPlan = new List<Map<String,String>>();
            for(PaymentPlan__c paymentPlanObj : paymentPlanLst){
                PaymentDetails paymentObj = new PaymentDetails();
                paymentObj.paymentObj = paymentPlanObj;
                paymentObj.paymentInstallment = paymentPlanObj.Payment_Installments__r;
                paymentLst.add(paymentObj);
                availablePaymentPlan.add(new map<string,string>{'label' => paymentPlanObj.Name , 'value' => paymentPlanObj.Id});
            }
            UnitPaymentDetails paymentDetailsWrapper = new UnitPaymentDetails();
            if(!paymentLst.isEmpty()){
                paymentLst[0].isSelected = true;
                paymentDetailsWrapper.paymentLst = paymentLst;
                paymentDetailsWrapper.availablePaymentPlans = availablePaymentPlan;
                paymentDetailsWrapper.selectedPayment = availablePaymentPlan[0].get('value');
                system.debug('paymentLst==>'+ paymentLst);
                system.debug('paymentDetailsWrapper==>'+ paymentDetailsWrapper);
            }
            udObj.unitPaymentDetailObj = paymentDetailsWrapper;
            if(isModonEgyptProfile == true) {
                List<UnitPaymentPlanMapping__c> unitPaymentPlanMappingLst = [
                    SELECT Id, Unit__c, Payment_Plan__c, Base_Price__c, CurrencyIsoCode
                    FROM UnitPaymentPlanMapping__c
                    WHERE Unit__c = :selectedUnitId 
                ];
                
                system.debug('unitPaymentPlanMappingLst==>'+ unitPaymentPlanMappingLst);
                udObj.unitPaymentPlanOptions = unitPaymentPlanMappingLst;
            }
        }
        return udObj;
    }
    
    //method to get building details
    @AuraEnabled
    public static list<map<String,string>> getAllBuildings(string projectId){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        
        for(Phase__c  tempBuilding: [Select Id,Name from Phase__c where Project__c   =: projectId WITH SECURITY_ENFORCED order by Name] ){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put('label',tempBuilding.Name);
            tempMap.put('value',tempBuilding.id);
            filtersToReturn.add(tempMap);
        }
        system.debug('filtersToReturn::'+filtersToReturn);
        return filtersToReturn;
    }
    
    @AuraEnabled
    public static string saveBlockedUnits(List<String> selectedUnits, String opportunityId, String commentValue, String blockingHours){
        List<Block_Request__c> blockRequestLst = new List<Block_Request__c>();
        
        List<Block_Request__c> exstingblockRequestLst = [SELECT Id, Name FROM Block_Request__c WHERE Unit__c IN : selectedUnits AND Status__c = 'In Progress'];
        
        if(!exstingblockRequestLst.isEmpty()){
            return 'Block request : ' + exstingblockRequestLst[0].Name + ' is already in progress.';
        }
        
        
        List<Unit__c> unitLst = [SELECT Id, Name FROM Unit__c WHERE Id IN : selectedUnits AND Status__c = 'Reserved'];
        if(!unitLst.isEmpty()){
            return 'Unit : ' + unitLst[0].Name + ' is already blocked.';
        }
        
        for(String unitId : selectedUnits){
            Block_Request__c brObj = new Block_Request__c();
            brObj.Unit__c = unitId;
            brObj.Comment__c = commentValue;
            brObj.Opportunity__c = opportunityId;
            brObj.Hourstoblock__c = blockingHours;
            blockRequestLst.add(brObj);
        }
        try{
            INSERT blockRequestLst;
        }catch(Exception ex){
            system.debug(ex.getMessage());
            return ex.getMessage();
        }
        return 'Success';
    }
    
    @AuraEnabled
    public static list<map<String,string>> getBlockingHours(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        List<Schema.PickListEntry> pickListValues = getPickListEntries('Block_Request__c','Hourstoblock__c');
        
        for(Schema.PickListEntry ple : pickListValues){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put('label',ple.getLabel());
            tempMap.put('value',ple.getValue());
            filtersToReturn.add(tempMap);
        }
        System.debug('filtersToReturn---> '+filtersToReturn);
        return filtersToReturn;
    } 
    
    //New Method Added By HZTL team
    @AuraEnabled
    public static list<map<String,string>> getUnitTypes(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        List<Schema.PickListEntry> pickListValues = getPickListEntries('Unit__c','UnitClassification__c');
        
        for(Schema.PickListEntry ple : pickListValues){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put('label',ple.getLabel());
            tempMap.put('value',ple.getValue());
            filtersToReturn.add(tempMap);
        }
        System.debug('filtersToReturn---> '+filtersToReturn);
        return filtersToReturn;
    } 
    
    //New Method Added By HZTL team
    @AuraEnabled
    public static list<map<String,string>> getNumberofBedrooms(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        List<Schema.PickListEntry> pickListValues = getPickListEntries('Unit__c','Number_of_Bedrooms__c');
        
        for(Schema.PickListEntry ple : pickListValues){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put('label',ple.getLabel());
            tempMap.put('value',ple.getValue());
            filtersToReturn.add(tempMap);
        }
        System.debug('filtersToReturn---> '+filtersToReturn);
        return filtersToReturn;
    } 
    
    //New Method Added By HZTL team
    @AuraEnabled
    public static list<map<String,string>> getQualityType(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        Unit_Search_Filter__mdt qualityTypeFilter = [
            SELECT Id 
            FROM Unit_Search_Filter__mdt 
            WHERE DeveloperName = 'Quality_Type' 
            LIMIT 1
        ];
        
        if (qualityTypeFilter != null) {
            // Get the values mapped to the Floor filter
            List<Unit_Search_Filter_Value__mdt> values = [
                SELECT Label, DeveloperName 
                FROM Unit_Search_Filter_Value__mdt 
                WHERE Unit_Search_Filter__c = :qualityTypeFilter.Id
            ];
            
            for (Unit_Search_Filter_Value__mdt val : values) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put('label', val.Label);
                tempMap.put('value', val.DeveloperName);
                filtersToReturn.add(tempMap);
            }
        }
        System.debug('filtersToReturn---> '+filtersToReturn);
        return filtersToReturn;
    } 
    
    //New Method Added By HZTL team
    @AuraEnabled
    public static list<map<String,string>> getGFARange(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        // Get the 'Floor' filter metadata record
        Unit_Search_Filter__mdt gfaFilter = [
            SELECT Id 
            FROM Unit_Search_Filter__mdt 
            WHERE DeveloperName = 'Gross_Floor_Area_GFA' 
            LIMIT 1
        ];
        
        if (gfaFilter != null) {
            // Get the values mapped to the Floor filter
            List<Unit_Search_Filter_Value__mdt> values = [
                SELECT Label, DeveloperName 
                FROM Unit_Search_Filter_Value__mdt 
                WHERE Unit_Search_Filter__c = :gfaFilter.Id
            ];
            
            for (Unit_Search_Filter_Value__mdt val : values) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put('label', val.Label);
                tempMap.put('value', val.DeveloperName);
                filtersToReturn.add(tempMap);
            }
        }
        System.debug('filtersToReturn---> '+filtersToReturn);
        return filtersToReturn;
    } 
    
    //New Method Added By HZTL team
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFloorValues() {
        List<Map<String, String>> filtersToReturn = new List<Map<String, String>>();
        
        // Get the 'Floor' filter metadata record
        Unit_Search_Filter__mdt floorFilter = [
            SELECT Id 
            FROM Unit_Search_Filter__mdt 
            WHERE DeveloperName = 'Floor' 
            LIMIT 1
        ];
        
        if (floorFilter != null) {
            // Get the values mapped to the Floor filter
            List<Unit_Search_Filter_Value__mdt> values = [
                SELECT Label, DeveloperName 
                FROM Unit_Search_Filter_Value__mdt 
                WHERE Unit_Search_Filter__c = :floorFilter.Id
            ];
            
            for (Unit_Search_Filter_Value__mdt val : values) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put('label', val.Label);
                tempMap.put('value', val.DeveloperName);
                filtersToReturn.add(tempMap);
            }
        }
        
        System.debug('filtersToReturn ---> ' + filtersToReturn);
        return filtersToReturn;
    }
    
    static List<Schema.PickListEntry> getPickListEntries(String objectName, String fieldName){
        //String objectName = 'Contact';
        //String fieldName ='LeadSource';
        
        Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(objectName) ;
        Schema.DescribeSObjectResult objDescribeSobject = objSobjectType.getDescribe() ;
        Map<String,Schema.SObjectField> fields = objDescribeSobject.fields.getMap() ;
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        return ple;
    }
    
    @AuraEnabled
    public static Integer getEOIDetails(String oppId){
        List<ExpressionofInterest__c> eoiLst = new List<ExpressionofInterest__c>();
        eoiLst = [SELECT Id FROM ExpressionofInterest__c WHERE Opportunity__c = :oppId];
        
        return eoiLst.size();
    }
    
    /**
     * Arvind - EOI v2.0 / v2.1
     * Returns valid EOIs for the LWC dropdown + meta flags for the given Opportunity.
     *
     * STANDARD mode (Allow_EOI_Any_Status__c = false):
     *   - Only Completed EOIs with at least one Cleared Receipt are returned.
     *   - Completed EOI but no Cleared Receipt -> AuraHandledException (blocks booking).
     *
     * VIP/MANAGEMENT mode (Allow_EOI_Any_Status__c = true):
     *   - EOIs of ANY status are returned.
     *   - No Receipt      -> EOI included (SO linked only, no Allocation/Charge).
     *   - Cleared Receipt -> EOI included (full @future flow fires).
     *   - Non-Cleared only -> EOI excluded; all non-cleared -> AuraHandledException.
     *
     * Arvind v16.0 (21 Sep 2026) - When label EOI_Enforce_Status_Check = 'false':
     *   - EOI of ANY status is eligible.
     *   - Normal Opp : at least one Cleared/Remitted receipt required
     *                  (EOI_Receipt_Valid_Statuses or Allow_Any_Status_for_Booking__c).
     *                  No receipt / In Progress only -> EOI excluded -> AuraHandledException.
     *   - VIP Opp (Allow_EOI_Any_Status__c = true) : receipt check skipped completely.
     *   - Bedrooms matching (EOI_Enforce_Typology_Check) is done in LWC + saveSalesOrder.
     *
     * Return list index 0 is always a META entry:
     *   { type:'meta', bypass:'true/false', allowAnyStatus:'true/false' }
     *   LWC reads these flags then discards the meta entry.
     *
     * Phase.EOI_Required__c gate enforced in LWC + saveSalesOrder safety net.
     * Modon Egypt never affected (isModonEgyptProfile guard in LWC).
     *
     * @param oppId  Opportunity Id
     * @return       List of EOI maps + meta entry at index 0
     */
    // Arvind EOI v2.1 - START
    // getCompletedEOIs -- returns valid EOIs for LWC dropdown + meta flags.
    //
    // TWO MODES depending on Opportunity.Allow_EOI_Any_Status__c:
    //
    //   STANDARD (Allow_EOI_Any_Status__c = false):
    //     * Only Completed EOIs returned
    //     * EOI must have at least one Cleared Receipt (Custom Label: EOI_Receipt_Valid_Statuses)
    //     * No Completed EOI or no Cleared Receipt -> AuraHandledException
    //
    //   VIP/MANAGEMENT (Allow_EOI_Any_Status__c = true):
    //     * EOIs of ANY status returned
    //     * No Receipt -> EOI included (booking allowed; no Allocation/Charge will be created)
    //     * Cleared Receipt -> EOI included (full Allocation + Charge flow via @future)
    //     * Non-Cleared Receipt ONLY -> EOI excluded
    //     * ALL EOIs have non-cleared receipts -> AuraHandledException
    //
    // Meta entry (index 0 in returned list):
    //   { type:'meta', bypass:'true/false', allowAnyStatus:'true/false', hasAnyEOI:'true/false' }
    //   LWC extracts flags, then removes the meta entry.
    //
    // Phase.EOI_Required__c gate is enforced in LWC (BOOKING handler)
    // and Apex (saveSalesOrder safety net) -- not here.
    // Modon Egypt never affected (isModonEgyptProfile guard in LWC).
    @AuraEnabled
    public static List<Map<String, String>> getCompletedEOIs(String oppId) {
        List<Map<String, String>> eoiList = new List<Map<String, String>>();
        try {
            // -- Step 1: Opportunity flags --------------------------------------------
            // Bypass_EOI_Typology_Check__c -> LWC skips typology+bedroom matching
            // Allow_EOI_Any_Status__c       -> VIP mode: any EOI status allowed
            // IMPORTANT: Create both checkbox fields on Opportunity before deploying.
            Opportunity opp = [
                SELECT Bypass_EOI_Typology_Check__c, Allow_EOI_Any_Status__c
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            Boolean allowAnyStatus = opp.Allow_EOI_Any_Status__c;

            // Arvind v10.0 - Label-based feature flags (toggle in Setup, no deployment needed)
            // EOI_Enforce_Status_Check:   'false' = ALL EOI statuses shown (current req)
            //                             'true'  = Completed only (original behaviour)
            // EOI_Enforce_Typology_Check: 'false' = skip typology+bedroom check (current req)
            //                             'true'  = enforce typology+bedroom (original behaviour)
            // Arvind v16.0 (21 Sep 2026) - EOI_Enforce_Typology_Check 'true' now means
            //                             Number of Bedrooms check ONLY (typology ignored).
            Boolean enforceStatusCheck   = System.Label.EOI_Enforce_Status_Check   == 'true';
            Boolean enforceTypologyCheck = System.Label.EOI_Enforce_Typology_Check == 'true';

            // -- Step 2: Fetch EOIs ---------------------------------------------------
            // Arvind v10.0 - Query block driven by EOI_Enforce_Status_Check label
            // Arvind v18.0 (23 Sep 2026) - Pre_Approval_Number__c added to all three EOI queries below
            List<ExpressionofInterest__c> eois;
            if (!enforceStatusCheck) {
                // Label 'false' (default): ALL EOIs regardless of status
                eois = [
                    SELECT Id, Name, UnitTypologyMRE__c, Bedrooms__c, Pre_Approval_Number__c, Status__c
                    FROM ExpressionofInterest__c
                    WHERE Opportunity__c = :oppId
                ];
            } else if (allowAnyStatus) {
                // Label 'true' + VIP flag: ALL EOIs regardless of status
                eois = [
                    SELECT Id, Name, UnitTypologyMRE__c, Bedrooms__c, Pre_Approval_Number__c, Status__c
                    FROM ExpressionofInterest__c
                    WHERE Opportunity__c = :oppId
                ];
            } else {
                // Label 'true' + Standard: Completed EOIs only (original behaviour)
                eois = [
                    SELECT Id, Name, UnitTypologyMRE__c, Bedrooms__c, Pre_Approval_Number__c
                    FROM ExpressionofInterest__c
                    WHERE Opportunity__c = :oppId
                    AND Status__c = 'Completed'
                ];
            }

            // Arvind v8.0 - Count ALL EOIs on opp regardless of status.
            // hasAnyEOI=false -> no EOIs at all -> allow booking if EOI_Strict_Required__c is false.
            // hasAnyEOI=true  -> EOIs exist but none valid -> LWC must still block.
            Integer totalEOICount = [SELECT count() FROM ExpressionofInterest__c WHERE Opportunity__c = :oppId];

            // No valid EOIs -> return meta-only so LWC reads hasAnyEOI flag.
            if (eois.isEmpty()) {
                Map<String, String> emptyMeta = new Map<String, String>();
                emptyMeta.put('type',           'meta');
                emptyMeta.put('bypass',         String.valueOf(opp.Bypass_EOI_Typology_Check__c));
                emptyMeta.put('allowAnyStatus', String.valueOf(allowAnyStatus));
                emptyMeta.put('hasAnyEOI',      String.valueOf(totalEOICount > 0)); // Arvind v8.0
                // Arvind v16.0 (21 Sep 2026) - also send typology flag on empty meta so LWC never reads undefined
                emptyMeta.put('enforceTypologyCheck', String.valueOf(enforceTypologyCheck));
                eoiList.add(emptyMeta);
                System.debug('Arvind v8.0 - No ' + (allowAnyStatus ? '' : 'Completed ')
                    + 'EOIs for opp: ' + oppId + ' | hasAnyEOI: ' + (totalEOICount > 0));
                return eoiList;
            }

            // -- Step 3: Query ALL receipts for these EOIs ---------------------------
            // (Need all receipts to detect non-cleared-only EOIs for VIP blocking)
            Set<Id> eoiIds = new Set<Id>();
            for (ExpressionofInterest__c eoi : eois) {
                eoiIds.add(eoi.Id);
            }
            Set<String> validStatuses = new Set<String>();
            for (String s : System.Label.EOI_Receipt_Valid_Statuses.split(',')) {
                validStatuses.add(s.trim());
            }
            // Arvind v16.2 (21 Sep 2026) - SalesOrder__c + SalesOrder__r.Status__c added.
            // A receipt already consumed by an ACTIVE Sales Order must NOT make an EOI
            // look bookable. A receipt whose Sales Order was Cancelled or Voided is
            // released and can be used again (re-booking support).
            List<Receipt__c> allReceipts = [
                SELECT Id, ExpressionOfInterest__c, Status__c, Allow_Any_Status_for_Booking__c,
                       SalesOrder__c, SalesOrder__r.Status__c
                FROM Receipt__c
                WHERE ExpressionOfInterest__c IN :eoiIds
            ];

            // Arvind v16.2 - EOIs already attached to an ACTIVE Sales Order are consumed
            // and must never appear in the dropdown again (one EOI = one active booking).
            Set<Id> consumedEOIIds = new Set<Id>();
            for (SalesOrder__c usedSO : [
                SELECT Id, ExpressionofInterest__c
                FROM SalesOrder__c
                WHERE ExpressionofInterest__c IN :eoiIds
                AND Status__c NOT IN :DEAD_SO_STATUSES
            ]) {
                consumedEOIIds.add(usedSO.ExpressionofInterest__c);
            }

            // -- Step 4: Build receipt status maps per EOI ----------------------------
            Map<Id, Boolean> eoiHasClearedReceipt      = new Map<Id, Boolean>();
            Map<Id, Boolean> eoiHasNonClearedOnly      = new Map<Id, Boolean>();
            Map<Id, List<Receipt__c>> eoiReceiptMap    = new Map<Id, List<Receipt__c>>();
            for (Receipt__c r : allReceipts) {
                if (!eoiReceiptMap.containsKey(r.ExpressionOfInterest__c)) {
                    eoiReceiptMap.put(r.ExpressionOfInterest__c, new List<Receipt__c>());
                }
                eoiReceiptMap.get(r.ExpressionOfInterest__c).add(r);
            }
            for (Id eoiId : eoiReceiptMap.keySet()) {
                Boolean hasCleared    = false;
                Boolean hasNonCleared = false;
                for (Receipt__c r : eoiReceiptMap.get(eoiId)) {
                    // Arvind v16.2 - skip receipts already consumed by an ACTIVE Sales Order
                    if (!isReceiptFree(r)) {
                        continue;
                    }
                    if (validStatuses.contains(r.Status__c) || (r.Allow_Any_Status_for_Booking__c)) {
                        hasCleared    = true;
                    } else {
                        hasNonCleared = true;
                    }
                }
                eoiHasClearedReceipt.put(eoiId, hasCleared);
                eoiHasNonClearedOnly.put(eoiId, hasNonCleared && !hasCleared);
            }

            // -- Step 5: Build return list ---------------------------------------------
            for (ExpressionofInterest__c eoi : eois) {
                Boolean hasClearedReceipt = eoiHasClearedReceipt.containsKey(eoi.Id)
                                             ? eoiHasClearedReceipt.get(eoi.Id) : false;
                Boolean hasNonClearedOnly = eoiHasNonClearedOnly.containsKey(eoi.Id)
                                             ? eoiHasNonClearedOnly.get(eoi.Id) : false;
                Boolean noReceipt         = !eoiReceiptMap.containsKey(eoi.Id);

                // Arvind v16.2 (21 Sep 2026) - HARD RULE, applies in every mode including VIP:
                // an EOI already attached to an active Sales Order can never be re-used.
                if (consumedEOIIds.contains(eoi.Id)) {
                    System.debug('Arvind v16.2 - EOI ' + eoi.Name
                        + ' skipped: already used on an active Sales Order.');
                    continue;
                }

                // Arvind v10.0 - include logic driven by EOI_Enforce_Status_Check label
                Boolean include = false;
                if (!enforceStatusCheck) {
                    // Arvind v16.0 (21 Sep 2026) - Label 'false': ANY EOI status allowed,
                    // but receipt must be Cleared/Remitted (or Allow_Any_Status_for_Booking__c).
                    // VIP (Allow_EOI_Any_Status__c = true) skips the receipt check completely
                    // -> no receipt or In Progress receipt still allowed for VIP.
                    // Previous logic (v10.0): include = true;  (receipt was never checked)
                    include = allowAnyStatus || hasClearedReceipt;
                } else if (allowAnyStatus) {
                    // Label 'true' + VIP: include if no receipt OR cleared receipt
                    include = noReceipt || hasClearedReceipt;
                } else {
                    // Label 'true' + Standard: cleared receipt required
                    include = hasClearedReceipt;
                }

                if (include) {
                    Map<String, String> eoiMap = new Map<String, String>();
                    eoiMap.put('label',       eoi.Name);
                    eoiMap.put('value',       eoi.Id);
                    eoiMap.put('unitTypology', eoi.UnitTypologyMRE__c != null ? eoi.UnitTypologyMRE__c : '');
                    eoiMap.put('bedrooms',     eoi.Bedrooms__c        != null ? eoi.Bedrooms__c        : '');
                    // hasReceipt: true = @future will run (Allocation+Charge); false = SO linked only
                    eoiMap.put('hasReceipt',  String.valueOf(hasClearedReceipt));
                    // Arvind v18.0 (23 Sep 2026) - Pre-Approval Number drives the payment plan list in LWC
                    eoiMap.put('preApprovalNumber', String.isNotBlank(eoi.Pre_Approval_Number__c) ? eoi.Pre_Approval_Number__c : '');
                    eoiList.add(eoiMap);
                }
            }

            // -- Step 6: Error if nothing valid ---------------------------------------
            // Arvind v16.0 (21 Sep 2026) - label-first message. When status check is off,
            // the only reason an EOI is excluded is a missing / non-cleared receipt.
            if (eoiList.isEmpty()) {
                // Arvind v16.2 - every EOI on this opportunity is already used on an
                // active Sales Order. Say so, instead of blaming the receipt status.
                if (consumedEOIIds.size() >= eois.size()) {
                    throw new AuraHandledException(
                        'All EOIs on this opportunity are already used on an active Sales Order. '
                        + 'An EOI can be used for one booking only.'
                    );
                } else if (!enforceStatusCheck) {
                    throw new AuraHandledException(
                        'EOI receipt is not Cleared/Remitted yet. Booking is allowed only after the receipt is cleared.'
                    );
                } else if (!allowAnyStatus) {
                    throw new AuraHandledException(
                        'EOI must be Completed with a Cleared Receipt to book.'
                    );
                } else {
                    throw new AuraHandledException(
                        'Receipt exists but status is not valid. Only Cleared receipts are accepted.'
                    );
                }
            }

            // -- Step 7: Prepend meta entry --------------------------------------------
            // LWC reads these flags, then removes the meta entry from the list.
            Map<String, String> metaEntry = new Map<String, String>();
            metaEntry.put('type',           'meta');
            metaEntry.put('bypass',         String.valueOf(opp.Bypass_EOI_Typology_Check__c));
            metaEntry.put('allowAnyStatus', String.valueOf(allowAnyStatus));
            metaEntry.put('hasAnyEOI',      String.valueOf(totalEOICount > 0)); // Arvind v8.0
            metaEntry.put('enforceTypologyCheck', String.valueOf(enforceTypologyCheck)); // Arvind v10.0
            eoiList.add(0, metaEntry);

            System.debug('Arvind EOI v2.1 - getCompletedEOIs count (excl meta): '
                + (eoiList.size() - 1)
                + ' | bypass: '        + opp.Bypass_EOI_Typology_Check__c
                + ' | allowAnyStatus: ' + allowAnyStatus);

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug('Arvind EOI v2.1 - Error in getCompletedEOIs: ' + e.getMessage());
            throw new AuraHandledException('Error fetching EOI details: ' + e.getMessage());
        }
        return eoiList;
    }
    // Arvind EOI v2.1 - END

    /**
     * Arvind v16.2 (21 Sep 2026)
     * Sales Order statuses that count as DEAD - an EOI or Receipt attached to an SO
     * in one of these statuses is considered free and can be used for a new booking.
     * Confirmed with business 21 Sep 2026: only 'Cancelled' and 'Voided' exist on the
     * SalesOrder__c.Status__c picklist. ('System cancelled' / 'System Cancelled' are
     * referenced by older queries in this class but are NOT valid picklist values.)
     */
    private static final Set<String> DEAD_SO_STATUSES = new Set<String>{
        'Cancelled', 'Voided'
    };

    /**
     * Arvind v16.2 (21 Sep 2026)
     * A receipt is FREE (usable for a new booking) when it is not linked to a Sales Order,
     * or when the Sales Order it is linked to is Cancelled or Voided.
     * A receipt linked to an ACTIVE Sales Order is already consumed and must never be
     * counted towards another EOI booking.
     * Caller must have queried SalesOrder__c and SalesOrder__r.Status__c on the receipt.
     */
    private static Boolean isReceiptFree(Receipt__c r) {
        if (r == null) {
            return false;
        }
        if (r.SalesOrder__c == null) {
            return true;
        }
        return r.SalesOrder__r != null && DEAD_SO_STATUSES.contains(r.SalesOrder__r.Status__c);
    }

    /**
     * Arvind v16.0 (21 Sep 2026)
     * Compares EOI bedrooms with Unit bedrooms using the NUMBER only, so
     * "5 Bedrooms", "5 BR", "5 Bed" and "5" all match each other.
     * When neither value contains a digit (e.g. "Studio"), falls back to a
     * trimmed, case-insensitive text compare.
     */
    private static Boolean bedroomsMatch(String eoiBeds, String unitBeds) {
        String a = String.isBlank(eoiBeds)  ? '' : eoiBeds.replaceAll('[^0-9]', '');
        String b = String.isBlank(unitBeds) ? '' : unitBeds.replaceAll('[^0-9]', '');
        if (String.isBlank(a) && String.isBlank(b)) {
            String eoiTxt  = String.isBlank(eoiBeds)  ? '' : eoiBeds.trim();
            String unitTxt = String.isBlank(unitBeds) ? '' : unitBeds.trim();
            return eoiTxt.equalsIgnoreCase(unitTxt);
        }
        return a == b;
    }
    // Arvind v16.0 - END

    // Arvind v17.0 (23 Sep 2026) - Facade Style helpers - START
    /**
     * Builds "phaseName||projectName" -> allowed Style_option__c values from
     * Facade_Style_c__mdt. getAll() consumes NO SOQL.
     * Matching is EXACT and CASE-SENSITIVE: Apex Map<String,..> keys are
     * case-sensitive and values are NOT trimmed, so "Phase A" does not match
     * "phase a" or "Phase A ". (SOQL "=" would be case-insensitive, which is
     * why the filtering is done in Apex.)
     */
    private static Map<String, List<String>> getFacadeStyleMatrix() {
        Map<String, List<String>> matrix = new Map<String, List<String>>();
        for (Facade_Style_c__mdt rec : Facade_Style_c__mdt.getAll().values()) {
            if (rec.Active__c != true
                || String.isBlank(rec.Phase__c)
                || String.isBlank(rec.Project_Name__c)
                || String.isBlank(rec.Style_option__c)) {
                continue;
            }
            String key = facadeStyleKey(rec.Phase__c, rec.Project_Name__c);
            if (!matrix.containsKey(key)) {
                matrix.put(key, new List<String>());
            }
            // Two records with the same option -> shown once
            if (!matrix.get(key).contains(rec.Style_option__c)) {
                matrix.get(key).add(rec.Style_option__c);
            }
        }
        for (List<String> opts : matrix.values()) {
            opts.sort();
        }
        return matrix;
    }

    private static String facadeStyleKey(String phaseName, String projectName) {
        return (phaseName == null ? '' : phaseName) + '||' + (projectName == null ? '' : projectName);
    }

    private static List<String> getFacadeStyleOptions(Map<String, List<String>> matrix,
                                                      String phaseName, String projectName) {
        List<String> opts = matrix.get(facadeStyleKey(phaseName, projectName));
        return opts == null ? new List<String>() : opts;
    }
    // Arvind v17.0 - Facade Style helpers - END
    
    /**
     * Arvind - EOI v2.0 / v2.1 (updated)
     * Creates Sales Orders for selected units.
     *
     * EOI v2.0 changes:
     *   - 4th param eoiMappingStr: JSON {unitId -> eoiId} for non-Modon Egypt EOI linking.
     *   - When null/blank: all EOI logic is skipped, existing behaviour 100% preserved.
     *   - Links EOI to SO (ExpressionofInterest__c field).
     *   - Queues executeEOIPostBookingAsync @future for Receipt/Allocation/Charge updates.
     *
     * EOI v2.1 changes:
     *   - Safety net: if Phase.EOI_Required__c = true and no eoiMappingStr -> return error.
     *   - Modon Egypt: completely unaffected (Source_Entity__c guard throughout).
     *
     * Arvind v16.0 (21 Sep 2026) changes:
     *   - Server-side EOI validation (when EOI_Enforce_Status_Check != 'true'):
     *       * Selected EOI must belong to this Opportunity.
     *       * Cleared/Remitted receipt required unless Opp.Allow_EOI_Any_Status__c = true.
     *       * Bedrooms must match unit when EOI_Enforce_Typology_Check = 'true',
     *         unless Opp.Bypass_EOI_Typology_Check__c = true.
     *
     * Arvind v17.0 (23 Sep 2026) changes:
     *   - Facade Style safety net for units whose Phase has Facade_Style__c = true.
     *
     * @param salesOrderList    SOs to insert (built in LWC)
     * @param oppId             Opportunity Id
     * @param offerLinesListStr JSON offer lines string
     * @param eoiMappingStr     JSON {unitId: eoiId}  -  null for normal bookings
     * @return                  'Success' or error message
     */
    //method to create sales order
    // Arvind changes for EOI v2.0 - Added 4th param eoiMappingStr (JSON {unitId -> eoiId}) for non-Modon Egypt EOI linking.
    // When null or blank, Apex skips EOI linking entirely -- existing behaviour 100% preserved.
    @AuraEnabled
    public static String saveSalesOrder(List<SalesOrder__c> salesOrderList, String oppId, String offerLinesListStr, String eoiMappingStr){
        String successMessage = 'Success';
        //todo==>
        //sales order should not be available
        //check if blocked with same opportunity and blocked for same user
        //unit is available change the status to block or if block
        //create sales order
        
        /*List<SalesOrder__c> soLst = [SELECT Id FROM SalesOrder__c WHERE Opportunity__c = :oppId AND Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')];
        if(!soLst.isEmpty()){
            return 'Sales order already in progress for this opportunity.';
        }*/
        // 3.0 Added changes to re-open the opportunity for re-book the units under the same opportunity
        Opportunity opp = [SELECT Id, ReOpenOppsforBulk__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
        if (opp.ReOpenOppsforBulk__c == false) {
        List<SalesOrder__c> soLst = [
            SELECT Id, Status__c 
            FROM SalesOrder__c 
            WHERE Opportunity__c = :oppId 
            AND Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
        ];
              if (!soLst.isEmpty()) {
            return 'Sales order already in progress for this opportunity.';
        }
    }
    
        
        set<String> unitIds = new set<String>();
        for(SalesOrder__c soObj : salesOrderList){
            unitIds.add(soObj.Unit__c);
        }
        system.debug('unitIds==>' + salesOrderList);
        system.debug('unitIds==>' + unitIds);
        Map<String, String> escrowPhaseMap = new Map<String, String>();
        // Arvind v8.0 - Added Phase__r.EOI_Strict_Required__c to SELECT
       // List<Unit__c> unitList = [SELECT Id, Name, Source_Entity__c, BlockedBy__c, BlockedFor__c,Blocked_Time__c, Status_Change_Time__c, Opportunity__c, Status__c, Sub_Status__c,ApprovalStatus__c,Phase__c, Phase__r.Name, Phase__r.EscrowAccount__c, Phase__r.EOI_Required__c, Phase__r.EOI_Strict_Required__c /*, Phase__r.EscrowAccount__r.AvailableVirtualAccounts__c*/ FROM Unit__c WHERE Id IN : unitIds];
      // Arvind 11.1 Fix for Duplicate Booking
      // Arvind v16.0 (21 Sep 2026) - Added Number_of_Bedrooms__c to SELECT for EOI bedrooms safety net
      // Arvind v17.0 (23 Sep 2026) - Added Phase__r.Project__r.Name, Phase__r.Facade_Style__c for Facade Style safety net
        List<Unit__c> unitList = [SELECT Id, Name, Source_Entity__c, BlockedBy__c, BlockedFor__c,Blocked_Time__c, Status_Change_Time__c, Opportunity__c, Status__c, Sub_Status__c,ApprovalStatus__c,Phase__c, Phase__r.Name, Phase__r.EscrowAccount__c, Phase__r.EOI_Required__c, Phase__r.EOI_Strict_Required__c, Number_of_Bedrooms__c, Phase__r.Project__r.Name, Phase__r.Facade_Style__c /*, Phase__r.EscrowAccount__r.AvailableVirtualAccounts__c*/ FROM Unit__c WHERE Id IN : unitIds FOR UPDATE];
        system.debug('unitList==>' + unitList);
        
        Map<String, String> unitEscrowMap = new Map<String, String>();
        Map<String, String> escrowVirtualMap = new Map<String, String>();
        Map<String, String> unitVirtualAccountMap = new Map<String, String>();
        Map<String, set<String>> escrowVirtualAccountMap = new Map<String, set<String>>();
        Map<String, Unit__c> unitMap = new Map<String, Unit__c>();
        set<Id> virtualIdsWithoutUnit = new set<Id>();
        
        for(Unit__c unitObj : unitList){
            if (unitObj.Source_Entity__c != 'Modon - Egypt') {
                if(String.isBlank(unitObj.Phase__r.EscrowAccount__c)){
                    return 'No escrow account is available for phase: ' + unitObj.Phase__r.Name;
                }
            }
            unitMap.put(unitObj.Id, unitObj);
            escrowPhaseMap.put(unitObj.Phase__r.EscrowAccount__c, unitObj.Phase__c);
        }
        system.debug('unitIds==>' + unitIds);
        //system.debug('==>' + [SELECT Id, Unit__c, Unit__r.Phase__c, Unit__r.Phase__r.EscrowAccount__c FROM VirtualAccount__c WHERE Status__c = 'Available' AND EscrowAccount__c IN : escrowPhaseMap.keySet() AND (Unit__c IN :unitIds OR Unit__c = null) ORDER BY Unit__c NULLS LAST]);
        for(VirtualAccount__c vaObj : [SELECT Id, EscrowAccount__c, Unit__c, Unit__r.Phase__c, Unit__r.Phase__r.EscrowAccount__c FROM VirtualAccount__c WHERE Status__c = 'Available' AND EscrowAccount__c IN : escrowPhaseMap.keySet() AND (Unit__c IN :unitIds OR Unit__c = null) FOR UPDATE]){
            
            system.debug('cal==>' + escrowPhaseMap.containsKey(vaObj.EscrowAccount__c) + '=>' + vaObj.EscrowAccount__c);
            if(String.isNotBlank(vaObj.Unit__c)){
                unitVirtualAccountMap.put(vaObj.Unit__c, vaObj.Id);
            }else if(escrowPhaseMap.containsKey(vaObj.EscrowAccount__c)){
                set<String> tempSet = escrowVirtualAccountMap.get(vaObj.EscrowAccount__c);
                if(tempSet == null){
                    tempSet = new set<String>();
                }
                tempSet.add(vaObj.Id);
                escrowVirtualAccountMap.put(vaObj.EscrowAccount__c, tempSet);
            }
        }
        List<Unit__c> updateUnitLst = new List<Unit__c>();
        system.debug('unitVirtualAccountMap==>' + unitVirtualAccountMap);
        system.debug('unitList==>' + unitList);
        system.debug('escrowVirtualAccountMap==>' + escrowVirtualAccountMap);
        if(!unitList.isEmpty()){
            for(Unit__c unitObj : unitList){
                system.debug('unitObj.Sub_Status__c => ' + unitObj.Sub_Status__c);
                system.debug('unitObj.BlockedFor__c => ' + unitObj.BlockedFor__c);
                system.debug('UserInfo.getUserId() => ' + UserInfo.getUserId());
                system.debug('unitObj.Opportunity__c => ' + unitObj.Opportunity__c);
                system.debug('oppId => ' + oppId);
                if(unitObj.Status__c == 'Reserved' && unitObj.BlockedFor__c != null && //v1.5
                    (unitObj.BlockedFor__c != UserInfo.getUserId() || (unitObj.Opportunity__c != oppId && unitObj.Opportunity__c != null))){
                    return 'Unit is not available for booking.';
                }
                //todo: virtual account must be available for all units. //!String.valueOf(unitObj.Source_Entity__c).equals('Modon - Egypt')
                if(!unitVirtualAccountMap.containsKey(unitObj.Id) && 
                   !escrowVirtualAccountMap.containsKey(unitObj.Phase__r.EscrowAccount__c) && 
                   unitObj.Source_Entity__c != 'Modon - Egypt'
                  ){
                      return 'Virtual account is not available for unit : ' + unitObj.Name;
                  } // Add Update the Change as par of new status 
                system.debug('unitObj.BlockedFor__c==>' + unitObj.BlockedFor__c+' '+unitObj.Sub_Status__c);
                if((unitObj.Status__c == 'Available' && (unitObj.Sub_Status__c == 'Un-Assigned' || unitObj.Sub_Status__c == 'Assigned')) || (unitObj.Sub_Status__c == 'Assigned'  && unitObj.BlockedFor__c == UserInfo.getUserId())){
                    unitObj.Status__c = 'Reserved';
                    unitObj.Sub_Status__c = '';
                    unitObj.ApprovalStatus__c='Released';
                    unitObj.BlockedFor__c = UserInfo.getUserId();
                    unitObj.Opportunity__c = oppId;
                    //Added by HZTL Team for Egypt
                    if(unitObj.Source_Entity__c == 'Modon - Egypt'){
                        unitObj.BlockUntil__c = System.now().addMinutes(15);
                    }else{
                        unitObj.BlockUntil__c = null;
                    }
                    unitObj.Status_Change_Time__c = DATETIME.NOW();
                    unitObj.Blocked_Time__c = DATETIME.NOW();//null;
                    //Added by HZTL Team for Egypt
                    if(String.isBlank(unitObj.BlockedBy__c) && unitObj.Source_Entity__c !='Modon - Egypt'){
                        unitObj.BlockedBy__c = UserInfo.getUserId();
                    }
                    System.debug('unitObj===>'+unitObj);
                    updateUnitLst.add(unitObj);
                }
            }   
        }else{
            return 'Unit is not available for booking.';
        }
        
        String roleName = [SELECT Id, Name, Profile.Name, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].UserRole.Name;
        
        //v4.0 Arvind Added the Query for BrokerAgency__c and BrokerAgent__c
        // Arvind v16.1 (21 Sep 2026) - Added Nationality__c and Primary Contact
        // Nationality / UAE Resident Status fields (Person Account + Contact) to SELECT.
        List<Opportunity> oppLst = [SELECT Id, Name, PrimaryContact__c, BrokerAgency__c,BrokerAgent__c, CustomerType__c, UAE_Resident_Status__c, Nationality__c, AccountId, Account.PersonContactId,
                                           PrimaryContact__r.Nationality__c, PrimaryContact__r.UAE_Resident_Status__c,
                                           PrimaryContact__r.Account.IsPersonAccount,
                                           PrimaryContact__r.Account.Nationality__pc, PrimaryContact__r.Account.UAE_Resident_Status__pc
                                    FROM Opportunity WHERE Id = :oppId];
        List<VirtualAccount__c> vaLst = new List<VirtualAccount__c>();

        // Arvind v16.1 (21 Sep 2026) - START
        // Resolve customer Nationality + UAE Resident Status for the Sales Order.
        // Source = Opportunity.PrimaryContact__c:
        //   Person Account     -> Account.Nationality__pc / Account.UAE_Resident_Status__pc
        //   Non-Person Account -> Contact.Nationality__c  / Contact.UAE_Resident_Status__c
        // If the Primary Contact value is blank (or no Primary Contact), fall back to the
        // Opportunity value so existing data keeps working.
        String soNationality     = null;
        String soResidentStatus  = null;
        if (!oppLst.isEmpty()) {
            Opportunity oppCust = oppLst[0];
            if (oppCust.PrimaryContact__c != null) {
                Boolean pcIsPersonAccount = oppCust.PrimaryContact__r.Account != null
                                            && oppCust.PrimaryContact__r.Account.IsPersonAccount == true;
                if (pcIsPersonAccount) {
                    soNationality    = oppCust.PrimaryContact__r.Account.Nationality__pc;
                    soResidentStatus = oppCust.PrimaryContact__r.Account.UAE_Resident_Status__pc;
                } else {
                    soNationality    = oppCust.PrimaryContact__r.Nationality__c;
                    soResidentStatus = oppCust.PrimaryContact__r.UAE_Resident_Status__c;
                }
            }
            if (String.isBlank(soNationality)) {
                soNationality = oppCust.Nationality__c;
            }
            if (String.isBlank(soResidentStatus)) {
                soResidentStatus = oppCust.UAE_Resident_Status__c;
            }
            System.debug('Arvind v16.1 - SO Nationality: ' + soNationality
                + ' | SO UAE Resident Status: ' + soResidentStatus);
        }
        // Arvind v16.1 - END

        // Arvind v16.3 (21 Sep 2026) - START
        // SalesOrder__c.Nationality__c is a calculated field sourced from the Opportunity,
        // so it cannot be written directly. Instead, back-fill the OPPORTUNITY from the
        // Primary Contact when its own fields are blank (they are no longer mandatory).
        // Only blank fields are touched - a value already entered on the Opportunity is
        // never overwritten. The Opportunity is updated BEFORE the Sales Orders are
        // inserted so the calculated field resolves correctly on the new SO.
        //
        // Arvind v22.0 (30 Sep 2026) - ORGANISATION ACCOUNT: the Opportunity is now
        // ALWAYS synced from the Primary Contact (Contact.Nationality__c /
        // Contact.UAE_Resident_Status__c), not only when blank. An old value already on
        // the Opportunity was blocking the back-fill, so the Sales Order kept the stale
        // value. Person Account keeps the v16.3 rule (blank-only).
        // Previous condition (all record types):
        //   if (String.isBlank(oppCurrent.Nationality__c) && String.isNotBlank(soNationality))
        //   if (String.isBlank(oppCurrent.UAE_Resident_Status__c) && String.isNotBlank(soResidentStatus))
        Opportunity oppToBackfill = null;
        if (!oppLst.isEmpty()) {
            Opportunity oppCurrent = oppLst[0];
            Boolean v22IsOrgAccount = oppCurrent.PrimaryContact__c != null
                && !(oppCurrent.PrimaryContact__r.Account != null
                     && oppCurrent.PrimaryContact__r.Account.IsPersonAccount == true);
            Boolean syncNationality = String.isNotBlank(soNationality)
                && (v22IsOrgAccount
                        ? oppCurrent.Nationality__c != soNationality
                        : String.isBlank(oppCurrent.Nationality__c));
            Boolean syncResident = String.isNotBlank(soResidentStatus)
                && (v22IsOrgAccount
                        ? oppCurrent.UAE_Resident_Status__c != soResidentStatus
                        : String.isBlank(oppCurrent.UAE_Resident_Status__c));
            if (syncNationality) {
                if (oppToBackfill == null) { oppToBackfill = new Opportunity(Id = oppCurrent.Id); }
                oppToBackfill.Nationality__c = soNationality;
            }
            if (syncResident) {
                if (oppToBackfill == null) { oppToBackfill = new Opportunity(Id = oppCurrent.Id); }
                oppToBackfill.UAE_Resident_Status__c = soResidentStatus;
            }
            System.debug('Arvind v22.0 - Org Account: ' + v22IsOrgAccount
                + ' | Opp Nationality: ' + oppCurrent.Nationality__c + ' -> ' + soNationality
                + ' | Opp UAE Resident Status: ' + oppCurrent.UAE_Resident_Status__c + ' -> ' + soResidentStatus
                + ' | Opportunity update required: ' + (oppToBackfill != null));
        }
        // Arvind v16.3 / v22.0 - END
        
        // Arvind changes for EOI v2.0 - START
        // Deserialise eoiMappingStr once before the loop.
        // Format: JSON object { "unitId": "eoiId", ... }
        // If blank/null (no completed EOIs or Modon Egypt), map stays empty and the block below is skipped entirely.
        // NOTE: Verify 'ExpressionofInterest__c' is the correct lookup field API name on SalesOrder__c before deploying.
        Map<String, Object> eoiMappingObj = new Map<String, Object>();
        if (String.isNotBlank(eoiMappingStr)) {
            try {
                eoiMappingObj = (Map<String, Object>) JSON.deserializeUntyped(eoiMappingStr);
                System.debug('Arvind changes for EOI v2.0 - eoiMappingObj: ' + eoiMappingObj);
            } catch (Exception e) {
                System.debug('Arvind changes for EOI v2.0 - Error parsing eoiMappingStr: ' + e.getMessage());
            }
        }
        // Arvind changes for EOI v2.0 - END

        // Arvind EOI v2.1 - START
        // Safety net: if any unit's Phase requires EOI (Phase__r.EOI_Required__c = true)
        // and no eoiMappingStr was passed from LWC -> block booking server-side.
        // Prevents accidental bypass if LWC validation is ever skipped.
        // Does NOT apply to Modon Egypt (Source_Entity__c check) or phases with EOI_Required__c = false.
        //
        // Arvind v8.0 - Updated logic:
        // EOI_Strict_Required__c = true  -> ALWAYS block even if no EOIs on opp.
        // EOI_Strict_Required__c = false -> block only if EOIs exist; allow if opp has none.
        Integer eoiCountForSafetyNet = [SELECT count() FROM ExpressionofInterest__c WHERE Opportunity__c = :oppId];
        for (Unit__c unitObj : unitList) {
            if (unitObj.Phase__r.EOI_Required__c == true
                && unitObj.Source_Entity__c != 'Modon - Egypt'
                && eoiMappingObj.isEmpty()) {
                if (unitObj.Phase__r.EOI_Strict_Required__c || eoiCountForSafetyNet > 0) {
                    return 'EOI is mandatory to book this unit. Please select a valid EOI before proceeding.';
                }
            }
        }
        // Arvind EOI v2.1 - END

        // Arvind changes for EOI v2.0 - START
        // Pre-query cleared Receipts for all EOIs in the mapping so we can link them to the
        // ADM Invoice after SO + Invoice creation (Block 2 below).
        // Uses the same Custom Label (EOI_Receipt_Valid_Statuses) so status criteria stay in sync.
        // Only runs when eoiMappingObj is non-empty (non-Modon Egypt + completed EOIs selected).
        // Map holds ALL cleared Receipts per EOI -- an EOI can have more than one cleared Receipt
        // and every one of them must be tagged to the SO + updated with the correct Account.
        Map<String, List<Id>> eoiToClearedReceiptMap = new Map<String, List<Id>>();
        // Stores Receipt_Amount__c per Receipt Id -- used for Allocation AllocationAmount__c + ApprovedReceiptAmount__c
        Map<Id, Decimal> receiptAmountMap = new Map<Id, Decimal>();
        // Stores receiptId -> soId -- declared here so Allocation block (after ADMFeesCharge) can access it
        Map<Id, Id> receiptToSOMap = new Map<Id, Id>();
        if (!eoiMappingObj.isEmpty()) {
            Set<String> mappedEOIIds = new Set<String>();
            for (Object eoiIdObj : eoiMappingObj.values()) {
                if (eoiIdObj != null) mappedEOIIds.add((String) eoiIdObj);
            }
            Set<String> validReceiptStatuses = new Set<String>();
            for (String s : System.Label.EOI_Receipt_Valid_Statuses.split(',')) {
                validReceiptStatuses.add(s.trim());
            }
            // Arvind v16.2 (21 Sep 2026) - the hard "AND SalesOrder__c = null" filter was
            // replaced by isReceiptFree(), so a receipt released by a CANCELLED Sales Order
            // can be used again (re-booking), while a receipt held by an ACTIVE Sales Order
            // stays blocked. Previous: AND SalesOrder__c = null
            for (Receipt__c receipt : [
                SELECT Id, ExpressionOfInterest__c, Receipt_Amount__c,
                       SalesOrder__c, SalesOrder__r.Status__c
                FROM Receipt__c
                WHERE ExpressionOfInterest__c IN :mappedEOIIds
                AND (Status__c IN :validReceiptStatuses OR Allow_Any_Status_for_Booking__c = true)
            ]) {
                if (!isReceiptFree(receipt)) {
                    System.debug('Arvind v16.2 - Receipt ' + receipt.Id
                        + ' skipped: already linked to active Sales Order ' + receipt.SalesOrder__c);
                    continue;
                }
                String eoiKey = (String) receipt.ExpressionOfInterest__c;
                if (!eoiToClearedReceiptMap.containsKey(eoiKey)) {
                    eoiToClearedReceiptMap.put(eoiKey, new List<Id>());
                }
                // Collect every cleared Receipt -- could be 2 or more per EOI
                eoiToClearedReceiptMap.get(eoiKey).add(receipt.Id);
                // Store Receipt_Amount__c for Allocation creation -- used in AllocationAmount__c + ApprovedReceiptAmount__c
                receiptAmountMap.put(receipt.Id, receipt.Receipt_Amount__c != null ? receipt.Receipt_Amount__c : 0);
            }
            System.debug('Arvind changes for EOI v2.0 - eoiToClearedReceiptMap: ' + eoiToClearedReceiptMap);
        }
        // Arvind changes for EOI v2.0 - END

        // Arvind v16.2 (21 Sep 2026) - START
        // ONE EOI = ONE ACTIVE BOOKING. This block runs in EVERY mode - both label values,
        // VIP opportunities and bypass opportunities included. There is no flag to skip it.
        //   a) The same EOI cannot be selected for two units in the same request.
        //   b) An EOI already linked to an ACTIVE Sales Order cannot be used again.
        //      (Cancelled or Voided Sales Orders release the EOI.)
        //   c) The EOI must still have at least one FREE cleared receipt - a receipt held
        //      by an active Sales Order does not count. VIP is exempt from (c) only,
        //      because VIP is allowed to book with no receipt at all.
        if (!eoiMappingObj.isEmpty()) {
            Map<String, String> v162EoiToUnit   = new Map<String, String>();
            Set<String>         v162MappedEOIs  = new Set<String>();

            // (a) duplicate EOI inside this booking request
            for (String unitKey : eoiMappingObj.keySet()) {
                String eoiId = (String) eoiMappingObj.get(unitKey);
                if (String.isBlank(eoiId)) {
                    continue;
                }
                if (v162EoiToUnit.containsKey(eoiId)) {
                    Unit__c u1 = unitMap.get(v162EoiToUnit.get(eoiId));
                    Unit__c u2 = unitMap.get(unitKey);
                    return 'The same EOI cannot be used for more than one unit. It is selected on unit '
                         + (u1 != null ? u1.Name : v162EoiToUnit.get(eoiId)) + ' and unit '
                         + (u2 != null ? u2.Name : unitKey) + '.';
                }
                v162EoiToUnit.put(eoiId, unitKey);
                v162MappedEOIs.add(eoiId);
            }

            if (!v162MappedEOIs.isEmpty()) {
                // (b) EOI already consumed by another active Sales Order
                for (SalesOrder__c usedSO : [
                    SELECT Id, Name, Status__c, ExpressionofInterest__c, ExpressionofInterest__r.Name
                    FROM SalesOrder__c
                    WHERE ExpressionofInterest__c IN :v162MappedEOIs
                    AND Status__c NOT IN :DEAD_SO_STATUSES
                ]) {
                    return 'EOI ' + usedSO.ExpressionofInterest__r.Name
                         + ' is already used on Sales Order ' + usedSO.Name
                         + ' (' + usedSO.Status__c + '). An EOI can be used for one booking only.';
                }

                // (c) EOI must still hold a FREE cleared receipt (VIP exempt)
                Opportunity v162Opp = [
                    SELECT Allow_EOI_Any_Status__c FROM Opportunity WHERE Id = :oppId LIMIT 1
                ];
                if (!v162Opp.Allow_EOI_Any_Status__c) {
                    for (String eoiId : v162MappedEOIs) {
                        if (!eoiToClearedReceiptMap.containsKey(eoiId)
                            || eoiToClearedReceiptMap.get(eoiId).isEmpty()) {
                            return 'The receipt for the selected EOI is not available. It is either not '
                                 + 'Cleared/Remitted, or already used on another Sales Order.';
                        }
                    }
                }
            }
            System.debug('Arvind v16.2 - One EOI / one booking check passed for '
                + v162MappedEOIs.size() + ' EOI(s).');
        }
        // Arvind v16.2 - END

        // Arvind v16.0 (21 Sep 2026) - START
        // Server-side EOI validation (safety net - LWC cannot bypass it).
        // Runs only when an EOI mapping is passed AND label EOI_Enforce_Status_Check != 'true'.
        //   1. Selected EOI must belong to this Opportunity.
        //   2. Receipt: at least one Cleared/Remitted receipt (eoiToClearedReceiptMap above).
        //      Skipped for VIP -> Opp.Allow_EOI_Any_Status__c = true.
        //   3. Bedrooms: EOI.Bedrooms__c must match Unit.Number_of_Bedrooms__c (number only).
        //      Runs only when label EOI_Enforce_Typology_Check = 'true'.
        //      Skipped when Opp.Bypass_EOI_Typology_Check__c = true.
        // NOTE (updated v16.2): eoiToClearedReceiptMap now excludes only receipts held by an
        //       ACTIVE Sales Order. A receipt released by a Cancelled or Voided Sales Order
        //       is usable again, so re-booking after a cancellation works.
        if (!eoiMappingObj.isEmpty() && System.Label.EOI_Enforce_Status_Check != 'true') {
            Opportunity oppEOIFlags = [
                SELECT Bypass_EOI_Typology_Check__c, Allow_EOI_Any_Status__c
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            Boolean enforceBedroomsCheck = System.Label.EOI_Enforce_Typology_Check == 'true'
                                           && !oppEOIFlags.Bypass_EOI_Typology_Check__c;

            Set<String> v16MappedEOIIds = new Set<String>();
            for (Object eoiIdObj : eoiMappingObj.values()) {
                if (eoiIdObj != null) v16MappedEOIIds.add((String) eoiIdObj);
            }

            Map<String, ExpressionofInterest__c> v16EoiMap = new Map<String, ExpressionofInterest__c>();
            for (ExpressionofInterest__c eoiRec : [
                SELECT Id, Name, Bedrooms__c
                FROM ExpressionofInterest__c
                WHERE Id IN :v16MappedEOIIds
                AND Opportunity__c = :oppId
            ]) {
                v16EoiMap.put(String.valueOf(eoiRec.Id), eoiRec);
            }

            for (String unitKey : eoiMappingObj.keySet()) {
                String eoiId = (String) eoiMappingObj.get(unitKey);
                if (String.isBlank(eoiId)) {
                    continue;
                }
                ExpressionofInterest__c eoiRec = v16EoiMap.get(eoiId);

                // 1. EOI must belong to this Opportunity
                if (eoiRec == null) {
                    return 'Selected EOI does not belong to this opportunity.';
                }

                // 2. Receipt must be Cleared/Remitted (skipped for VIP)
                if (!oppEOIFlags.Allow_EOI_Any_Status__c && !eoiToClearedReceiptMap.containsKey(eoiId)) {
                    return 'EOI ' + eoiRec.Name + ' has no Cleared/Remitted receipt. Booking not allowed.';
                }

                // 3. Bedrooms must match unit (skipped when bypass flag ticked)
                if (enforceBedroomsCheck) {
                    Unit__c eoiUnit = unitMap.get(unitKey);
                    if (eoiUnit != null && !bedroomsMatch(eoiRec.Bedrooms__c, eoiUnit.Number_of_Bedrooms__c)) {
                        return 'Number of bedrooms on EOI ' + eoiRec.Name + ' (' + eoiRec.Bedrooms__c
                             + ') does not match unit ' + eoiUnit.Name + ' (' + eoiUnit.Number_of_Bedrooms__c + ').';
                    }
                }
            }
            System.debug('Arvind v16.0 - EOI safety net passed | VIP: ' + oppEOIFlags.Allow_EOI_Any_Status__c
                + ' | bedroomsCheck: ' + enforceBedroomsCheck);
        }
        // Arvind v16.0 - END

        // Arvind v17.0 (23 Sep 2026) - START
        // Facade Style safety net (LWC cannot bypass it). For every unit whose Phase has
        // Facade_Style__c = true:
        //   - active Facade_Style_c__mdt rows must exist for the EXACT phase + project name,
        //     otherwise booking is blocked;
        //   - SalesOrder__c.FacadeStyle__c must be filled and be one of those options.
        // Units whose phase flag is false are not touched (existing behaviour kept).
        Map<String, List<String>> facadeMatrix = null;
        for (SalesOrder__c soFacade : salesOrderList) {
            Unit__c fUnit = unitMap.get(soFacade.Unit__c);
            if (fUnit == null || fUnit.Phase__r == null || fUnit.Phase__r.Facade_Style__c != true) {
                continue;
            }
            if (facadeMatrix == null) {
                facadeMatrix = getFacadeStyleMatrix();
            }
            String fProject = fUnit.Phase__r.Project__r != null ? fUnit.Phase__r.Project__r.Name : null;
            List<String> allowed = getFacadeStyleOptions(facadeMatrix, fUnit.Phase__r.Name, fProject);
            if (allowed.isEmpty()) {
                return 'No Facade Style is configured for phase ' + fUnit.Phase__r.Name
                     + ' / project ' + fProject + '. Please contact your administrator.';
            }
            if (String.isBlank(soFacade.FacadeStyle__c)) {
                return 'Please select a Facade Style for unit ' + fUnit.Name + '.';
            }
            if (!allowed.contains(soFacade.FacadeStyle__c)) {
                return 'Facade Style "' + soFacade.FacadeStyle__c + '" is not allowed for unit '
                     + fUnit.Name + '. Allowed: ' + String.join(allowed, ', ') + '.';
            }
        }
        System.debug('Arvind v17.0 - Facade Style check passed.');
        // Arvind v17.0 - END

        // Arvind v19.0 (24 Sep 2026) - START  (replaces the v18.0 Pre-Approval block)
        // Pre-Approval Number on the Sales Order. Non-Modon Egypt only.
        //   - EOI with Pre_Approval_Number__c -> that number is stored on the SO
        //     (any plan; the LWC pre-selects a pre-approval plan by default).
        //   - Pre-approval plan (Pre_Approval__c = true) without an EOI number ->
        //     the number typed on the booking screen is REQUIRED and stored.
        //   - Normal plan without an EOI number -> no number stored.
        // Previous v18.0 rule (removed): EOI number + normal plan was blocked and a
        // pre-approval plan without an EOI number was blocked.
        Set<Id>     v19PlanIds = new Set<Id>();
        Set<String> v19EoiIds  = new Set<String>();
        for (SalesOrder__c soPA : salesOrderList) {
            Unit__c paUnit = unitMap.get(soPA.Unit__c);
            if (paUnit == null || paUnit.Source_Entity__c == 'Modon - Egypt') {
                continue;
            }
            if (soPA.PaymentPlan__c != null) {
                v19PlanIds.add(soPA.PaymentPlan__c);
            }
            Object paEoi = eoiMappingObj.get(soPA.Unit__c);
            if (paEoi != null && String.isNotBlank((String) paEoi)) {
                v19EoiIds.add((String) paEoi);
            }
        }
        Map<Id, PaymentPlan__c> v19Plans = new Map<Id, PaymentPlan__c>();
        if (!v19PlanIds.isEmpty()) {
            v19Plans = new Map<Id, PaymentPlan__c>([
                SELECT Id, Name, Pre_Approval__c FROM PaymentPlan__c WHERE Id IN :v19PlanIds
            ]);
        }
        Map<String, ExpressionofInterest__c> v19Eois = new Map<String, ExpressionofInterest__c>();
        if (!v19EoiIds.isEmpty()) {
            for (ExpressionofInterest__c paEoiRec : [
                SELECT Id, Name, Pre_Approval_Number__c FROM ExpressionofInterest__c WHERE Id IN :v19EoiIds
            ]) {
                v19Eois.put(String.valueOf(paEoiRec.Id), paEoiRec);
            }
        }
        for (SalesOrder__c soPA : salesOrderList) {
            Unit__c paUnit = unitMap.get(soPA.Unit__c);
            if (paUnit == null || paUnit.Source_Entity__c == 'Modon - Egypt') {
                continue;
            }
            Object paEoiObj = eoiMappingObj.get(soPA.Unit__c);
            ExpressionofInterest__c paEoiRec = (paEoiObj == null) ? null : v19Eois.get((String) paEoiObj);
            String eoiPreApprovalNo = (paEoiRec == null) ? null : paEoiRec.Pre_Approval_Number__c;
            PaymentPlan__c paPlan = (soPA.PaymentPlan__c == null) ? null : v19Plans.get(soPA.PaymentPlan__c);
            Boolean isPreApprovalPlan = (paPlan != null && paPlan.Pre_Approval__c == true);

            if (String.isNotBlank(eoiPreApprovalNo)) {
                // EOI number always wins (server value, not the one sent by the LWC)
                soPA.Pre_Approval_Number__c = eoiPreApprovalNo.trim();
            } else if (isPreApprovalPlan) {
                if (String.isBlank(soPA.Pre_Approval_Number__c)) {
                    return 'Pre-Approval Number is required for pre-approval payment plan '
                         + paPlan.Name + ' (unit ' + paUnit.Name + ').';
                }
                soPA.Pre_Approval_Number__c = soPA.Pre_Approval_Number__c.trim();
            } else {
                soPA.Pre_Approval_Number__c = null;
            }
        }
        System.debug('Arvind v19.0 - Pre-Approval Number check passed.');
        // Arvind v19.0 - END
        // Arvind v18.0 - END

        if(!salesOrderList.isEmpty()){
            for(SalesOrder__c salesOrderObj : salesOrderList){
                // Retrieve the unit for the current sales order
                Unit__c currentUnit = unitMap.get(salesOrderObj.Unit__c);
                
                if(String.isNotBlank(oppLst[0].PrimaryContact__c)){
                    salesOrderObj.PrimaryContact__c = oppLst[0].PrimaryContact__c;
                }
                
               //v4.0 Added Logic to Update the Broker Agency Name and Agnet name on sales order
                if(!oppLst.isEmpty()){
                    
                    Opportunity oppbp = oppLst[0];
                    
                    if(String.isNotBlank(oppbp.BrokerAgency__c)){
                        salesOrderObj.Broker_Agency_Name__c = oppbp.BrokerAgency__c;
                    }
                  
                    if(String.isNotBlank(oppbp.BrokerAgent__c)){
                        salesOrderObj.Broker_Agent_Name__c = oppbp.BrokerAgent__c;
                    }
                }
                
                
                
                if (currentUnit.Source_Entity__c != 'Modon - Egypt') {
                    if(unitVirtualAccountMap.containsKey(salesOrderObj.Unit__c) 
                       || (escrowVirtualAccountMap.containsKey(unitMap.get(salesOrderObj.Unit__c).Phase__r.EscrowAccount__c) 
                           && !(escrowVirtualAccountMap.get(unitMap.get(salesOrderObj.Unit__c).Phase__r.EscrowAccount__c)).isEmpty())){
                               
                               if(unitVirtualAccountMap.containsKey(salesOrderObj.Unit__c)){
                                   salesOrderObj.VirtualAccount__c = unitVirtualAccountMap.get(salesOrderObj.Unit__c);
                               }else{
                                   List<String> vaIds = new List<String>(escrowVirtualAccountMap.get(unitMap.get(salesOrderObj.Unit__c).Phase__r.EscrowAccount__c));
                                   salesOrderObj.VirtualAccount__c = vaIds[0];
                                   set<String> vaSet = new Set<String>(vaIds);
                                   vaSet.remove(salesOrderObj.VirtualAccount__c);
                                   escrowVirtualAccountMap.put(unitMap.get(salesOrderObj.Unit__c).Phase__r.EscrowAccount__c, vaSet);
                               }
                               vaLst.add(new VirtualAccount__c(Id = salesOrderObj.VirtualAccount__c, Status__c = 'Consumed', Unit__c = salesOrderObj.Unit__c));
                           }else{
                               return 'Virtual account is not available for unit : ' + unitMap.get(salesOrderObj.Unit__c).Name;
                           }
                }
                salesOrderObj.CustomerAccount__c = oppLst[0].AccountId;
                salesOrderObj.Opportunity__c = oppId;
                salesOrderObj.CustomerType__c = oppLst[0].CustomerType__c;
                // Arvind v16.1 (21 Sep 2026) - mapped from Primary Contact (fallback Opportunity)
                // Previous: salesOrderObj.UAE_Resident_Status__c =oppLst[0].UAE_Resident_Status__c;
                salesOrderObj.UAE_Resident_Status__c = soResidentStatus;
                // Arvind v16.3 (21 Sep 2026) - SalesOrder__c.Nationality__c is NOT writeable
                // (calculated from the Opportunity). Removed to fix compile error
                // "Field is not writeable: SalesOrder__c.Nationality__c".
                // The value now reaches the SO through the Opportunity, which is
                // back-filled earlier in this method when it is blank.
                // Previous: salesOrderObj.Nationality__c = soNationality;
                //Added by HZTL Team for Egypt
                if (currentUnit.Source_Entity__c == 'Modon - Egypt') {
                    salesOrderObj.Source_Entity__c = 'Modon - Egypt';
                    salesOrderObj.AutoEndDate__c = System.now().addMinutes(15);
                }
                System.debug('roleName=>'+roleName);
                System.debug('salesOrderObj=>'+ salesOrderObj);
                if(roleName != null && roleName.contains('Sales Associate')){
                    salesOrderObj.SalesAssociate__c = UserInfo.getUserId(); 
                    salesOrderObj.CurrencyIsoCode = salesOrderObj.CurrencyIsoCode;
                }
                
                // Arvind changes for EOI v2.0 - START
                // Link the selected Completed EOI to the Sales Order for non-Modon Egypt only.
                // If eoiMappingObj is empty (no completed EOIs passed from LWC), this block is skipped.
                // Modon Egypt SOs are never affected because Source_Entity__c == 'Modon - Egypt' is excluded.
                if (currentUnit.Source_Entity__c != 'Modon - Egypt' && !eoiMappingObj.isEmpty()) {
                    String eoiId = (String) eoiMappingObj.get(salesOrderObj.Unit__c);
                    if (String.isNotBlank(eoiId)) {
                        // IMPORTANT: Confirm 'ExpressionofInterest__c' is the correct lookup field API name on SalesOrder__c
                        salesOrderObj.ExpressionofInterest__c = eoiId;
                        System.debug('Arvind changes for EOI v2.0 - Linked EOI ' + eoiId + ' to SO for unit ' + salesOrderObj.Unit__c);
                    }
                }
                // Arvind changes for EOI v2.0 - END
                
            }
            Savepoint sp = Database.setSavepoint();
            try{
                // Arvind v16.3 (21 Sep 2026) - back-fill blank Opportunity Nationality /
                // UAE Resident Status from the Primary Contact BEFORE inserting the Sales
                // Orders, so SalesOrder__c.Nationality__c (calculated from the Opportunity)
                // resolves to the correct value. Inside the savepoint: a later failure
                // rolls this back with everything else.
                if (oppToBackfill != null) {
                    UPDATE oppToBackfill;
                    System.debug('Arvind v16.3 - Opportunity back-filled: '
                        + oppToBackfill.Nationality__c + ' / ' + oppToBackfill.UAE_Resident_Status__c);
                }

                if(!updateUnitLst.isEmpty()){
                    UPDATE updateUnitLst;
                }
                //insert new sales order
               // INSERT salesOrderList;
               Set<id> modonSoids =new set<id>();
                Database.SaveResult[] results = Database.insert(salesOrderList, false);
                // Arvind changes for EOI v2.0 - START
                // Guard: collect any SO insert failures and surface them IMMEDIATELY.
                List<String> soInsertErrors = new List<String>();
                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        System.debug('Arvind changes for EOI v2.0 - Successfully inserted SO with ID: ' + sr.getId());
                        modonSoids.add(sr.getId());
                    } else {
                        for (Database.Error err : sr.getErrors()) {
                            System.debug('Arvind changes for EOI v2.0 - SO insert error: ' + err.getMessage());
                            System.debug('Arvind changes for EOI v2.0 - Fields affected: ' + err.getFields());
                            soInsertErrors.add(err.getMessage());
                        }
                    }
                }
                if (!soInsertErrors.isEmpty()) {
                    Database.rollback(sp);
                    return String.join(soInsertErrors, '; ');
                }
                // Arvind changes for EOI v2.0 - END

                // Arvind v22.0 (30 Sep 2026) - START
                // Safety net: re-read the new Sales Orders and re-apply UAE Resident Status
                // if an automation (trigger / flow on SalesOrder__c) replaced or cleared the
                // value set above (for example by copying the Opportunity value).
                if (String.isNotBlank(soResidentStatus)) {
                    List<SalesOrder__c> soFixLst = new List<SalesOrder__c>();
                    for (SalesOrder__c soChk : [
                        SELECT Id, UAE_Resident_Status__c
                        FROM SalesOrder__c
                        WHERE Id IN :modonSoids
                    ]) {
                        if (soChk.UAE_Resident_Status__c != soResidentStatus) {
                            System.debug('Arvind v22.0 - SO ' + soChk.Id + ' UAE Resident Status was "'
                                + soChk.UAE_Resident_Status__c + '" after insert; re-applying "'
                                + soResidentStatus + '".');
                            soFixLst.add(new SalesOrder__c(Id = soChk.Id,
                                                           UAE_Resident_Status__c = soResidentStatus));
                        }
                    }
                    if (!soFixLst.isEmpty()) {
                        UPDATE soFixLst;
                    }
                }
                // Arvind v22.0 - END

                if (!vaLst.isEmpty()) {
                    UPDATE vaLst;
                }

                // Arvind changes for EOI v2.0 - START
                if (!eoiToClearedReceiptMap.isEmpty()) {
                    for (SalesOrder__c so : salesOrderList) {
                        if (so.Id != null && so.Unit__c != null && eoiMappingObj.containsKey(so.Unit__c)) {
                            String eoiId = (String) eoiMappingObj.get(so.Unit__c);
                            if (eoiToClearedReceiptMap.containsKey(eoiId)) {
                                for (Id receiptId : eoiToClearedReceiptMap.get(eoiId)) {
                                    receiptToSOMap.put(receiptId, so.Id);
                                }
                            }
                        }
                    }
                    List<Receipt__c> receiptsToUpdate = new List<Receipt__c>();
                    for (List<Id> receiptIds : eoiToClearedReceiptMap.values()) {
                        for (Id receiptId : receiptIds) {
                            Receipt__c r = new Receipt__c(Id = receiptId);
                            if (receiptToSOMap.containsKey(receiptId)) {
                                r.SalesOrder__c = receiptToSOMap.get(receiptId);
                                System.debug('Arvind changes for EOI v2.0 - Setting Receipt.SalesOrder__c = '
                                    + receiptToSOMap.get(receiptId) + ' on Receipt ' + receiptId);
                            }
                            // IMPORTANT: Confirm 'Account__c' is the correct Account lookup field API name on Receipt__c
                            r.Account__c = oppLst[0].AccountId;
                            // Arvind changes for EOI v2.0 - Mark Receipt as ADM Fees and Dari charges
                            r.Is_ADM_Fees_and_Dari_charges__c = true;
                            receiptsToUpdate.add(r);
                        }
                    }
                    // Arvind EOI v2.1 - Receipt UPDATE deferred to Queueable (not @future).
                    // Queueable allows ReceiptTrigger to call sendUnIdentifiedReceipt_Future safely.
                    // (receiptsToUpdate list preserved for logic flow; DML done in EOIPostBookingQueueable)
                }
                // Arvind changes for EOI v2.0 - END

                createPaymentInstallments(salesOrderList);
                createOfferLineCollection(salesOrderList,oppId,offerLinesListStr);
                if(modonSoids.size() > 0){
                    set<string> soMREIds=new set<string>();
                    for(SalesOrder__c soRec : [select id,name from SalesOrder__c where Source_Entity__c != 'Modon - Egypt' and id =: modonSoids]){
                        soMREIds.add(soRec.id);
                    }
                     ADMFeesChargeInvoiceService.processOnUpsert(null, salesOrderList, true);

                     if (!receiptToSOMap.isEmpty()) {
                         Map<String, String>  receiptSOStr  = new Map<String, String>();
                         Map<String, Decimal> receiptAmtStr = new Map<String, Decimal>();
                         for (Id rId : receiptToSOMap.keySet()) {
                             receiptSOStr.put(rId, receiptToSOMap.get(rId));
                         }
                         for (Id rId : receiptAmountMap.keySet()) {
                             receiptAmtStr.put(rId, receiptAmountMap.get(rId));
                         }
                         System.enqueueJob(new EOIPostBookingQueueable(
                             JSON.serialize(receiptSOStr),
                             JSON.serialize(receiptAmtStr),
                             oppLst[0].AccountId
                         ));
                         System.debug('Arvind EOI v2.1 - EOIPostBookingQueueable enqueued for '
                             + receiptToSOMap.size() + ' receipt(s).');
                     }

                     /*
                     if (!eoiMappingObj.isEmpty() && !eoiToClearedReceiptMap.isEmpty()) {
                         Map<Id, String> soToUnitMap = new Map<Id, String>();
                         for (SalesOrder__c so : salesOrderList) {
                             if (so.Id != null) soToUnitMap.put(so.Id, so.Unit__c);
                         }
                         List<Invoice__c> admInvoices = [
                             SELECT Id, SalesOrder__c
                             FROM Invoice__c
                             WHERE SalesOrder__c IN :soToUnitMap.keySet()
                             AND Is_ADM_Fees_and_Dari_charges__c = true
                         ];
                         List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
                         for (Invoice__c inv : admInvoices) {
                             String unitId = soToUnitMap.get(inv.SalesOrder__c);
                             if (unitId != null && eoiMappingObj.containsKey(unitId)) {
                                 String eoiId = (String) eoiMappingObj.get(unitId);
                                 if (eoiToClearedReceiptMap.containsKey(eoiId)) {
                                     inv.Receipt__c = eoiToClearedReceiptMap.get(eoiId);
                                     invoicesToUpdate.add(inv);
                                 }
                             }
                         }
                         if (!invoicesToUpdate.isEmpty()) { update invoicesToUpdate; }
                     }
                     */

                     if(soMREIds.size() >0 && !Test.isRunningTest()){
                    System.enqueueJob(new CustomerSalesOrderCallout_Queable(soMREIds));
                }
                }
                
                
                // oppLst[0].StageName = 'Closed Won';
                // UPDATE oppLst[0];
                
            }catch (DmlException dmlEx) {
                System.debug('Validation/DML Exception: ' + dmlEx.getMessage());
                Database.rollback(sp);
                
                // Collect only the actual validation messages
                List<String> errorMessages = new List<String>();
                for (Integer i = 0; i < dmlEx.getNumDml(); i++) {
                    errorMessages.add(dmlEx.getDmlMessage(i));
                }
                
                return String.join(errorMessages, '; ');
                
            }catch(Exception ex){
                system.debug(ex.getMessage());
                Database.rollback(sp);
                 // Arvind 11.1 - Friendlier message if the FOR UPDATE lock-wait times out
    // because another agent's transaction is holding the lock on the same unit.
                if (ex.getMessage().contains('unable to obtain exclusive access')) {
        return 'This unit is currently being booked by another agent.';
    }
                return ex.getMessage();
            }
        }
        return successMessage;
    }
    
    //method to create sales order and Block Request - HZTL Team
    @AuraEnabled
    public static String saveSalesOrderWithBlockRequest(List<SalesOrder__c> salesOrderList, String oppId){
        String blockRequestResponse;
        //todo==>
        //sales order should not be available
        //check if blocked with same opportunity and blocked for same user
        //unit is available change the status to block or if block
        //create sales order
        
        List<SalesOrder__c> soLst = [SELECT Id FROM SalesOrder__c WHERE Opportunity__c = :oppId AND Status__c NOT IN ('Cancelled', 'System Cancelled')];
        if(!soLst.isEmpty()){
            return 'Sales order already in progress for this opportunity.';
        }
        
        List<Opportunity> oppLst = [SELECT Id, Name, PrimaryContact__c, CustomerType__c, UAE_Resident_Status__c,AccountId, Account.PersonContactId  , Account.Nationality__pc FROM Opportunity WHERE Id = :oppId];
        
        
        set<String> unitIds = new set<String>();
        for(SalesOrder__c soObj : salesOrderList){
            unitIds.add(soObj.Unit__c);
        }
        system.debug('unitIds==>' + salesOrderList);
        system.debug('unitIds==>' + unitIds);
        
        // Removed escrow account and virtual account related maps
        List<Unit__c> unitList = [SELECT Id, Name, BlockedBy__c, BlockedFor__c,Blocked_Time__c, Status_Change_Time__c, Opportunity__c, Status__c, Sub_Status__c,ApprovalStatus__c,Phase__c, Phase__r.Name, Phase__r.EscrowAccount__c/*, Phase__r.EscrowAccount__r.AvailableVirtualAccounts__c*/ FROM Unit__c WHERE Id IN : unitIds];
        
        
        List<Unit__c> updateUnitLst = new List<Unit__c>();
        
        if(!unitList.isEmpty()){
            for(Unit__c unitObj : unitList){
                if(unitObj.Sub_Status__c == 'Assigned' && unitObj.BlockedFor__c != null && (unitObj.BlockedFor__c != UserInfo.getUserId() || (unitObj.Opportunity__c != oppId && unitObj.Opportunity__c != null))){
                    return 'Unit is not available for booking.';
                }
                
                //todo: virtual account must be available for all units. (This logic has been removed)
                if((unitObj.Status__c == 'Available' && (unitObj.Sub_Status__c == 'Un-Assigned' || unitObj.Sub_Status__c == 'Assigned')) || (unitObj.Sub_Status__c == 'Assigned'  && unitObj.BlockedFor__c == UserInfo.getUserId())){
                    unitObj.Status__c = 'Available';
                    unitObj.Sub_Status__c = 'Assigned';
                    unitObj.BlockedFor__c = UserInfo.getUserId();
                    unitObj.Opportunity__c = oppId;
                    unitObj.BlockUntil__c = System.now().addMinutes(15);
                    unitObj.Status_Change_Time__c = DATETIME.NOW();
                    unitObj.Blocked_Time__c = DATETIME.NOW();
                    updateUnitLst.add(unitObj);
                }
            }
        } else {
            return 'Unit is not available for booking.';
        }
        
        //String roleName = [SELECT Id, Name, Profile.Name, UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].UserRole.Name;
        //v4.0 Arvind added below logic since it is failing for test class
        User usr = [ SELECT Id, UserRole.Name  FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String roleName = (usr.UserRole != null) ? usr.UserRole.Name : null;
        if(!salesOrderList.isEmpty()){
            for(SalesOrder__c salesOrderObj : salesOrderList){
                if(String.isNotBlank(oppLst[0].PrimaryContact__c)){
                    //Added by HZTL Team for Egypt
                    //salesOrderObj.PrimaryContact__c = oppLst[0].PrimaryContact__c;
                }
                salesOrderObj.Status__c = 'Pending Blocking Fees';
                salesOrderObj.CustomerAccount__c = oppLst[0].AccountId;
                salesOrderObj.Opportunity__c = oppId;
                salesOrderObj.CustomerType__c = oppLst[0].CustomerType__c;
                salesOrderObj.UAE_Resident_Status__c = oppLst[0].UAE_Resident_Status__c;
                salesOrderObj.AutoEndDate__c = System.now().addMinutes(15);
                //Added by HZTL Team for Egypt
                salesOrderObj.Source_Entity__c = 'Modon - Egypt';
                
                system.debug('roleName=>'+roleName);
                system.debug('salesOrderObj=>'+ salesOrderObj);
                //v4.0
               // if(roleName.contains('Sales Associate')){
                  //  salesOrderObj.SalesAssociate__c = UserInfo.getUserId();
                  //  salesOrderObj.CurrencyIsoCode = salesOrderObj.CurrencyIsoCode;
                //}
                if(roleName != null && roleName.contains('Sales Associate')){
   					salesOrderObj.SalesAssociate__c = UserInfo.getUserId();
                    salesOrderObj.CurrencyIsoCode = salesOrderObj.CurrencyIsoCode;}
            }
            
            // Determine block duration based on nationality
            String blockHours = (oppLst[0].Account.Nationality__pc == 'Egypt') ? '120' : '24';
            
            // Attempt to create block requests BEFORE DML to prevent partial processing
            blockRequestResponse = createBlockRequest(new List<String>(unitIds), oppId, 'Block Request With Fee', blockHours , 'Approved');
            
            // If block request failed, exit early
            if (blockRequestResponse != 'Success') {
                return blockRequestResponse;
            }
            
            Savepoint sp = Database.setSavepoint();
            try {
                // Update units if any
                if (!updateUnitLst.isEmpty()) {
                    update updateUnitLst;
                }
                
                // Insert sales orders
                insert salesOrderList;
                
                // Generate payment installments
                createPaymentInstallments(salesOrderList);
                
            } catch (DmlException dmlEx) {
                System.debug('Validation/DML Exception: ' + dmlEx.getMessage());
                Database.rollback(sp);
                
                // Collect only the actual validation messages
                List<String> errorMessages = new List<String>();
                for (Integer i = 0; i < dmlEx.getNumDml(); i++) {
                    errorMessages.add(dmlEx.getDmlMessage(i));
                }
                
                return String.join(errorMessages, '; ');
                
            }catch (Exception ex) {
                System.debug('Exception occurred: ' + ex.getMessage());
                Database.rollback(sp);
                return ex.getMessage();
            }
        }
        
        return 'Success';
    }
    
    
    
    public static string createBlockRequest(List<String> selectedUnits, String opportunityId, String commentValue, String blockingHours , String Status){
        List<Block_Request__c> blockRequestLst = new List<Block_Request__c>();
        
        List<Block_Request__c> exstingblockRequestLst = [SELECT Id, Name FROM Block_Request__c WHERE Unit__c IN : selectedUnits AND Status__c = 'In Progress'];
        
        if(!exstingblockRequestLst.isEmpty()){
            return 'Block request : ' + exstingblockRequestLst[0].Name + ' is already in progress.';
        }
        
        
        List<Unit__c> unitLst = [SELECT Id, Name FROM Unit__c WHERE Id IN : selectedUnits AND Status__c = 'Reserved'];
        if(!unitLst.isEmpty()){
            return 'Unit : ' + unitLst[0].Name + ' is already blocked.';
        }
        
        for(String unitId : selectedUnits){
            Block_Request__c brObj = new Block_Request__c();
            brObj.Unit__c = unitId;
            brObj.Comment__c = commentValue;
            brObj.Opportunity__c = opportunityId;
            brObj.Hourstoblock__c = blockingHours;
            brObj.Status__c = Status;
            blockRequestLst.add(brObj);
        }
        try{
            INSERT blockRequestLst;
        }catch(Exception ex){
            system.debug(ex.getMessage());
            return ex.getMessage();
        }
        return 'Success';
    }
    
    //method to create sales order installments
    static void createPaymentInstallments(List<SalesOrder__c> salesOrderList){
        
        //Added by MIRE Team - Get current user's profile name 
        String currentUserProfileName = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()].Name;        
        Boolean isEgyptProfile = currentUserProfileName != null && currentUserProfileName.toLowerCase().contains('egypt');
        //till here

        List<SalesOrderInstallments__c> salesOrderInstallmentLst = new List<SalesOrderInstallments__c>(); 
        
        Map<String, List<PaymentInstallements__c>> paymentPlanInstallmentMap = new Map<String, List<PaymentInstallements__c>>();
        Map<String, String> salesOrderPaymentPlanMap = new Map<String, String>();
        set<Id> paymentSet = new set<Id>();
        for(SalesOrder__c soObj : salesOrderList){
            salesOrderPaymentPlanMap.put(soObj.Id, soObj.PaymentPlan__c);
            paymentSet.add(soObj.PaymentPlan__c);
        }
        
        for(PaymentInstallements__c piObj : [SELECT Id, Name, PaymentInstallment__c, BrokerPayout__c, IsHandoverPayment__c, Milestone__c,Milestone_Egypt_Percent__c, PaymentInstallment__r.Maintenance_Fee__c, 
                                             MilestoneDate__c, MilestoneDescription__c, MilestoneNumber__c, SalesAgentPayout__c,Milestone_Due__c,MilestoneInstallment__c ,Is_Maintenance_Installment__c, PaymentInstallment__r.Number_of_Maintenance_Fee__c
                                             FROM PaymentInstallements__c 
                                             WHERE PaymentInstallment__c IN : paymentSet]){
                                                 List<PaymentInstallements__c> tempInstallment = paymentPlanInstallmentMap.get(piObj.PaymentInstallment__c);
                                                 if(tempInstallment == null){
                                                     tempInstallment = new List<PaymentInstallements__c>();
                                                 }
                                                 tempInstallment.add(piObj);
                                                 paymentPlanInstallmentMap.put(piObj.PaymentInstallment__c, tempInstallment);
                                             }
        
        for(SalesOrder__c soObj : salesOrderList){
            for(PaymentInstallements__c piObj : paymentPlanInstallmentMap.get(salesOrderPaymentPlanMap.get(soObj.Id))){
                SalesOrderInstallments__c soiObj = new SalesOrderInstallments__c();
                //Added by MIRE Team - Get current user's profile name 
                Decimal milestonePercent = isEgyptProfile ? piObj.Milestone_Egypt_Percent__c : piObj.Milestone__c;
                soiObj.SalesOrder__c = soObj.Id;
                soiObj.PaymentInstallments__c = piObj.Id;
                soiObj.BrokerPayout__c = piObj.BrokerPayout__c;
                soiObj.IsHandoverPayment__c = piObj.IsHandoverPayment__c ;
                if(isEgyptProfile){
                    soiObj.Milestone_Egypt_Percent__c = milestonePercent;
                }else{
                    soiObj.Milestone__c = milestonePercent;
                }   
                //soiObj.MilestoneDate__c = piObj.MilestoneDate__c;
                // soiObj.MilestoneDate__c = piObj.Milestone_Due__c; /** COMMENTED AND Added Below Logic**/
                if(piObj.MilestoneNumber__c == 1 ||  (piObj.MilestoneDescription__c <> null && piObj.MilestoneDescription__c.contains('Down Payment'))){  /** 2.0 Added Below Logic to Set SO Created Date as Milestone Date for 1st Installment**/
                    soiObj.MilestoneDate__c = System.today();
                }else{
                  soiObj.MilestoneDate__c = piObj.Milestone_Due__c;
                }
                if(piObj.MilestoneInstallment__c != null)soiObj.Milestone_Installment__c = piObj.MilestoneInstallment__c;
                soiObj.MilestoneDescription__c = piObj.MilestoneDescription__c;
                soiObj.MilestoneNumber__c = piObj.MilestoneNumber__c;
                soiObj.SalesAgentPayout__c = piObj.SalesAgentPayout__c;
                soiObj.InstallmentAmount__c = (soObj.TotalAmount__c) * (milestonePercent/100);
                
                //Addded Logic for MIRE team
                if(piObj.Is_Maintenance_Installment__c){
                    soiObj.Maintenance_Fee__c = ((soObj.TotalAmount__c) * (piObj.PaymentInstallment__r.Maintenance_Fee__c/100)) / piObj.PaymentInstallment__r.Number_of_Maintenance_Fee__c;
                }else{
                    soiObj.Maintenance_Fee__c = 0;
                }
                soiObj.CurrencyIsoCode = soObj.CurrencyIsoCode;
                // till here
                salesOrderInstallmentLst.add(soiObj);
            }
        }
        INSERT salesOrderInstallmentLst;
    }
    
    @AuraEnabled
    public static String updateUnitsAsBlocked(List<String> selectedUnits, String oppId){
        system.debug('selectedUnits==>' + selectedUnits);
        
        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>([SELECT Id, Name, Status__c,Blocked_Time__c, BlockedFor__c, BlockedBy__c, Opportunity__c,Sub_Status__c FROM Unit__c WHERE Id IN : selectedUnits]);
        
        List<Unit__c> unitLst = new List<Unit__c>();
        for(String unitId : selectedUnits){ //Add Update the Change as par of new status
            if((unitMap.get(unitId).Status__c == 'Available' && unitMap.get(unitId).Sub_Status__c == 'Assigned') || 
               (unitMap.get(unitId).Sub_Status__c == 'Assigned' && unitMap.get(unitId).BlockedFor__c == UserInfo.getUserId())){
                   
                   if(unitMap.get(UnitId).Status__c == 'Available' && unitMap.get(UnitId).Sub_Status__c == 'Un-Assigned'){
                       Unit__c unitObj = new Unit__c(id = unitId, 
                                                     Opportunity__c = oppId, 
                                                     BlockedFor__c = UserInfo.getUserId(), 
                                                     BlockedBy__c = UserInfo.getUserId(),
                                                     Status__c = 'Available',Sub_Status__c = 'Assigned',ApprovalStatus__c='Released',
                                                     BlockUntil__c = null, Blocked_Time__c = DATETIME.NOW());
                       unitLst.add(unitObj);
                   }
               }else if(unitMap.get(unitId).Status__c == 'Available' && unitMap.get(unitId).Sub_Status__c == 'Assigned' && unitMap.get(unitId).BlockedFor__c != UserInfo.getUserId()){
                   return 'Unit ' + unitMap.get(unitId).Name + ' is already Reserved by other user.';
               }
            
            //unitLst.add(unitMap.get(unitId));
        }
        system.debug('unitLst==>' + unitLst);
        UPDATE unitLst;
        return 'Success';
    }
    
    @AuraEnabled
    public static String checkUnitStatus(List<String> selectedUnits){
        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>([SELECT Id, Name, Status__c, BlockedFor__c, BlockedBy__c, 
                                                         Opportunity__c ,Sub_Status__c
                                                         FROM Unit__c 
                                                         WHERE Id IN : selectedUnits]);
        
        List<Unit__c> unitLst = new List<Unit__c>();
        for(String unitId : selectedUnits){ //Add Update the Change as par of new status
            if(unitMap.get(unitId).Status__c == 'Available' && unitMap.get(unitId).Sub_Status__c == 'Assigned' && unitMap.get(unitId).BlockedFor__c != UserInfo.getUserId()){
                return 'Unit ' + unitMap.get(unitId).Name + ' is already Reserved by other user.';
            }
        }
        return 'Success';
    }
    
    
    
    @AuraEnabled
    public static void unblockSelectedUnits(List<String> selectedUnits){
        List<Unit__c> unitLst = [SELECT Id, Status__c, BlockedFor__c, BlockedBy__c FROM Unit__c WHERE Id IN : selectedUnits];
        List<Unit__c> updateUnitLst = new List<Unit__c>();
        for(Unit__c unitObj : unitLst){
            if(unitObj.BlockedBy__c == UserInfo.getUserId() && unitObj.BlockedFor__c == UserInfo.getUserId()){ //Add Update the Change as par of new status
                unitObj.Status__c = 'Available';
                unitObj.Sub_Status__c='Un-Assigned';
                unitObj.ApprovalStatus__c='Released';
                unitObj.BlockedFor__c = null;
                unitObj.BlockedBy__c = null;
                unitObj.Opportunity__c = null;
                unitObj.BlockUntil__c = null;
                unitObj.Blocked_Time__c = null;
                updateUnitLst.add(unitObj);
            }
        }
        if(!updateUnitLst.isEmpty()){
            UPDATE updateUnitLst;    
        }
    }
    
    
    /*
* Method fully updated by HZTL Team for Egypt
* New Param added
* New Checks and Variable added
*/
    @AuraEnabled
    public static UnitDataWrapper getUnitDetails(Id buildingsId, String oppId, String unitType, String qualityType, String numberOfBedrooms, String gfaRange, String floor, String unitNumber, Boolean isModonProfile){
        Opportunity[] opps = [SELECT Id, PrimaryContact__c, PrimaryContact__r.Nationality__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
        List<Unit__c> unitLst = new List<Unit__c>();
        if (isModonProfile != true) {
            // Default query (non-Modon Egypt profile)
            unitLst = [
                select id,Name,Phase__c,PlotAreasqm__c,Phase__r.Name, Number_of_Bedrooms__c, TotalArea__c, 
                TotalGrossSellableAreaGSA__c, GrossFloorAreaGFA__c,Phase__r.Project__c, Phase__r.Project__r.Name, 
                TotalPrice__c, UAE_Citizen_Price__c, BlockComment__c, Project_Name__c, Interior__c, FacadeStyle__c,
                Typology__c,Bucket__r.Name, BlockedFor__r.Name,
                Phase__r.EOI_Required__c,
                Phase__r.EOI_Strict_Required__c,
                (SELECT Id FROM Sales_Orders__r WHERE Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided'))
                FROM Unit__c 
                WHERE Phase__c = :buildingsId 
                AND (
                    (Status__c = 'Available' AND Sub_Status__c = 'Un-Assigned') OR
                    (Sub_Status__c = 'Assigned' AND BlockedFor__c = :UserInfo.getUserId())
                )
                AND (Opportunity__c = null OR Opportunity__c = :oppId)
                ORDER BY Name
            ];
            // Added query (Modon Egypt profile) New
        } else {
            Integer minGFA;
            Integer maxGFA;
            String searchPattern;
            
            if (String.isNotBlank(gfaRange)) {
                String cleanedRange = gfaRange.replace('X', '').replace('_', '-'); // -> '100-200'
                if (cleanedRange.contains('-')) {
                    // Case: "100-200"
                    String[] rangeParts = cleanedRange.split('-', 2);
                    if (rangeParts.size() == 2) {
                        minGFA = Integer.valueOf(rangeParts[0].trim());
                        maxGFA = Integer.valueOf(rangeParts[1].trim());
                    }
                } else {
                    // Case: "1000"
                    minGFA = Integer.valueOf(cleanedRange);
                    maxGFA = null; // or maxGFA = minGFA if needed
                }
            }
            
            String query;
            Map<String, Object> queryParams = new Map<String, Object>();
            
            String queryPrefix = 'SELECT Id, Name, Phase__c, PlotAreasqm__c, Phase__r.Name, Number_of_Bedrooms__c, ' +
                'Phase__r.Project__c, Phase__r.Project__r.Name, TotalPrice__c, UnitClassification__c, ' +
                'Unit_Quality__c, GrossFloorAreaGFA__c, FloorNumber__c,  Bucket__r.Name, BlockedFor__r.Name, ' +
                '(SELECT Id FROM Sales_Orders__r WHERE Status__c NOT IN (\'Cancelled\', \'System Cancelled\')) ' +
                'FROM Unit__c WHERE ';
            
            // Compose filter conditions
            List<String> coreFilters = new List<String>();
            coreFilters.add('Phase__c = :buildingsId');
            coreFilters.add('((Status__c = \'Available\' AND Sub_Status__c = \'Un-Assigned\') OR (Sub_Status__c = \'Assigned\' AND BlockedFor__c = :userId))');
            coreFilters.add('(Opportunity__c = null OR Opportunity__c = :oppId)');
            
            List<String> optionalFilters = new List<String>();
            
            if (String.isNotBlank(unitType)) {
                optionalFilters.add('UnitClassification__c = :unitType');
            }
            if (String.isNotBlank(qualityType)) {
                optionalFilters.add('Unit_Quality__c = :qualityType');
            }
            if (String.isNotBlank(numberOfBedrooms)) {
                optionalFilters.add('Number_of_Bedrooms__c = :numberOfBedrooms');
            }
            if (String.isNotBlank(floor)) {
                optionalFilters.add('FloorNumber__c = :floor');
            }
            if (minGFA != null) {
                optionalFilters.add('GrossFloorAreaGFA__c >= :minGFA');
            }
            if (maxGFA != null) {
                optionalFilters.add('GrossFloorAreaGFA__c <= :maxGFA');
            }
            
            System.debug('-----optionalFilters------'+optionalFilters);
            String finalWhereClause;
            
            if (String.isNotBlank(unitNumber)) {
                // If unitNumber is provided, ignore optional filters completely
                searchPattern = '%' + unitNumber + '%';
                finalWhereClause = '(' + String.join(coreFilters, ' AND ') +
                    ' AND (Name LIKE :searchPattern))';
            } else {
                // Normal flow with optional filters
                finalWhereClause = String.join(coreFilters, ' AND ');
                if (!optionalFilters.isEmpty()) {
                    finalWhereClause += ' AND ' + String.join(optionalFilters, ' AND ');
                }
            }
            System.debug('-----finalWhereClause------'+finalWhereClause);
            
            query = queryPrefix + finalWhereClause + ' ORDER BY Name';
            
            
            // Now assign variables for binding
            String userId = UserInfo.getUserId();

            unitLst = Database.query(query);
            unitLst = Database.query(query);
        }
        // HZTL Code Ends
        
        // Filter out units with existing sales orders
        List<Unit__c> validUnitLst = new List<Unit__c>();
        if(!unitLst.isEmpty() && unitLst.size() > 0){
            for(Unit__c unitObj : unitLst){
                if(unitObj.Sales_Orders__r.isEmpty()){
                    validUnitLst.add(unitObj);
                }
            }
        }
        
        UnitDataWrapper wrapper = new UnitDataWrapper();
        wrapper.units = validUnitLst;
        wrapper.isResidentCustomer = opps.isEmpty() || opps[0].PrimaryContact__c == null || String.isEmpty(opps[0].PrimaryContact__r.Nationality__c) ? false : opps[0].PrimaryContact__r.Nationality__c.equals('United Arab Emirates');
        return wrapper;
    }
    
    @AuraEnabled(cacheable=true)
    public static String getUserProfileName() {
        System.debug('Profile current logged in'+[SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name);
        return [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;
    }
    
    
    /**
* @description Checks if the Opportunity has valid documents uploaded
*              based on the Account type (Person/Corporate) and country.
* 
* @param opportunityId The Id of the Opportunity record.
* @return allDocumentsUploaded indicating whether valid documents are uploaded.
*/ 
    @AuraEnabled(cacheable=true)
    public static DocumentValidationResult isDocumentValidEgypt(Id opportunityId) {
        final String STATUS_UPLOADED = 'Uploaded';
        final String RECORD_TYPE_ORG = 'Organization Account';
        final String RECORD_TYPE_PERSON = 'Person Account';
        final String COUNTRY_EGYPT = 'Egypt';
        
        List<String> orgRequiredDocs = new List<String>{'tax id', 'commercial registration id'};
            List<List<String>> egyptPersonRequiredDocs = new List<List<String>>{
                new List<String>{'national id', 'passport copy'}
            };
                List<List<String>> otherPersonRequiredDocs = new List<List<String>>{
                    new List<String>{'proof of residence id', 'passport copy'}
                };
                    
                    try {
                        Opportunity opp = [
                            SELECT Id, AccountId, Account.Nationality__pc, Account.RecordType.Name
                            FROM Opportunity
                            WHERE Id = :opportunityId
                            LIMIT 1
                        ];
                        
                        String country = opp.Account.Nationality__pc;
                        String recordTypeName = opp.Account.RecordType.Name;
                        
                        if (recordTypeName == RECORD_TYPE_PERSON && String.isBlank(country)) {
                            return new DocumentValidationResult(false, '', new List<String>{'Nationality is required for Account. Please Populate the Nationality Before proceeding'});
                        }
                        
                        List<Documents__c> docs = [
                            SELECT Name, Status__c
                            FROM Documents__c
                            WHERE Opportunity__c = :opportunityId
                        ];
                        
                        Map<String, String> documentStatusMap = new Map<String, String>();
                        Map<String, String> originalNameMap = new Map<String, String>();
                        for (Documents__c doc : docs) {
                            System.debug('Document fetched: ' + doc + ' ' + doc.Name + ' with status: ' + doc.Status__c);
                            String lowerName = doc.Name.toLowerCase();
                            documentStatusMap.put(lowerName, doc.Status__c);
                            originalNameMap.put(lowerName, doc.Name);
                        }
                        
                        List<String> missingDocuments = new List<String>();
                        
                        if (recordTypeName == RECORD_TYPE_ORG) {
                            Boolean isAnyDocumentUploaded = false;
                            for (String requiredDoc : orgRequiredDocs) {
                                String lowerRequiredDoc = requiredDoc.toLowerCase();
                                if (documentStatusMap.containsKey(lowerRequiredDoc) && documentStatusMap.get(lowerRequiredDoc) == STATUS_UPLOADED) {
                                    isAnyDocumentUploaded = true;
                                    break;
                                }
                            }
                            if (!isAnyDocumentUploaded) {
                                return new DocumentValidationResult(false, country, new List<String>{'At least one of the following documents is required: ' + String.join(orgRequiredDocs,' or ')});
                            }
                        } else if (recordTypeName == RECORD_TYPE_PERSON) {
                            List<List<String>> requiredDocGroups = (country == COUNTRY_EGYPT) ? egyptPersonRequiredDocs : otherPersonRequiredDocs;
                            
                            for (List<String> docGroup : requiredDocGroups) {
                                Boolean groupSatisfied = false;
                                for (String doc : docGroup) {
                                    String lowerDoc = doc.toLowerCase();
                                    if (documentStatusMap.containsKey(lowerDoc) && documentStatusMap.get(lowerDoc) == STATUS_UPLOADED) {
                                        groupSatisfied = true;
                                        break;
                                    }
                                }
                                if (!groupSatisfied) {
                                    // Add all options in the group as a single message
                                    missingDocuments.add('At least one of the following documents is required: ' + String.join(docGroup, ' or '));
                                }
                            }
                        } else {
                            return new DocumentValidationResult(false, country, new List<String>{'Unsupported record type: ' + recordTypeName});
                        }
                        
                        Boolean allDocumentsUploaded = missingDocuments.isEmpty();
                        return new DocumentValidationResult(allDocumentsUploaded, country, missingDocuments);
                    } catch (Exception e) {
                        System.debug('Error in isDocumentValidEgypt: ' + e.getMessage());
                        return new DocumentValidationResult(false, '', new List<String>{'Error occurred: ' + e.getMessage()});
                    }
    }
    
    @AuraEnabled
    public static void createOfferLineCollection(List<SalesOrder__c> SalesOrderList,Id oppId,String offersLineStr){
        system.debug('OffLineString:'+offersLineStr);
        if(offersLineStr <> null && offersLineStr !=''){
            List<unitOffersWrapper> offerLinesList = (List<unitOffersWrapper>) JSON.deserialize(offersLineStr, List<unitOffersWrapper>.class);
            System.debug('offerLinesList::'+offerLinesList);
            if(offerLinesList.size() > 0){
                List<Offers_Collections__c> offerCollectionsList = new List<Offers_Collections__c>();
                List<SalesOrder__c> salesOrderUpdateList = new List<SalesOrder__c>();
                Map<Id,OfferLines__c> offerLinesMap = new Map<Id,OfferLines__c>();
                Map<Id,List<OfferLines__c>> unitOfferWrapper = new Map<Id,List<OfferLines__c>>();
                Set<Id> offerLinesId = new Set<Id>();
                for(unitOffersWrapper uWrap: offerLinesList){
                    if(uWrap.offerLinesLst <> null && uWrap.offerLinesLst.size()>0){
                        unitOfferWrapper.put(uWrap.unitId,uWrap.offerLinesLst);
                    }
                }
                for(String keySet: unitOfferWrapper.keySet()){
                    for(OfferLines__c offerLines: unitOfferWrapper.get(keySet)){
                        offerLinesId.add(offerLines.Id);
                    }
                }
                for(OfferLines__c offerLines: [SELECT Id,OfferValue__c,OfferOn__c FROM OfferLines__c WHERE Id IN: offerLinesId ]){
                    offerLinesMap.put(offerLines.Id,offerLines);
                }
                for(SalesOrder__c so: SalesOrderList){
                    if(unitOfferWrapper.containsKey(so.unit__c)){
                        for(OfferLines__c offersLine: unitOfferWrapper.get(so.unit__c)){
                            Offers_Collections__c offersCollections = new Offers_Collections__c();
                            offersCollections.Opportunity__c = oppId;
                            offersCollections.Sales_Order__c = so.Id;
                            offersCollections.Offer_Lines__c = offersLine.Id;
                            offersCollections.Unit__c = so.Unit__c;
                            offerCollectionsList.add(offersCollections);
                            if(offerLinesMap.containsKey(offersLine.Id) && offerLinesMap.get(offersLine.Id).OfferOn__c == 'ADM Fees' &&  offerLinesMap.get(offersLine.Id).OfferValue__c <> null){
                                SalesOrder__c soObj = new SalesOrder__c();
                                soObj.Id = so.Id;
                                soObj.Discount_on_ADM_Fees__c = offerLinesMap.get(offersLine.Id).OfferValue__c;
                                salesOrderUpdateList.add(soObj);
                            }
                        }
                    } 
                }
                if(!offerCollectionsList.isEmpty()){
                    insert offerCollectionsList; 
                }
                if(!salesOrderUpdateList.isEmpty()){
                    update salesOrderUpdateList;
                }
            }
        }
    }
    
    @AuraEnabled
    public static String checkComplianceSubmitted(Id oppId, String projectName) {
        //ComplianceBypass__c complianceSetting = ComplianceBypass__c.getOrgDefaults();
        
        Date todayDate = Date.today();
        /*if (projectName.equals(complianceSetting.Project_Name__c) && todayDate == complianceSetting.Launch_Date__c) {
return null;
}*/
        
        Opportunity[] opps = [SELECT Id, Name, Account.Name, Account.profileId__c, Account.profileId__pc from Opportunity WHERE Id =: oppId];
        if (opps.isEmpty()) {
            return 'Opportunity record is not found!';
        }
        
        if (opps[0].Account.profileId__c == null && opps[0].Account.profileId__pc == null) {
            return 'Customer: ' + opps[0].Account.Name + ' is not submitted for compliance!';
        }
        
        JointOwner__c[] owners = [SELECT Id, Name, JointOwnerAccount__r.Name, JointOwnerAccount__r.profileId__c, JointOwnerAccount__r.profileId__pc from JointOwner__c WHERE Opportunity__c =: oppId];
        
        for (JointOwner__c owner: owners) {
            if (owner.JointOwnerAccount__r.profileId__c == null && owner.JointOwnerAccount__r.profileId__pc == null) {
                return 'Joint Owner: ' + owner.JointOwnerAccount__r.Name + ' is not submitted for compliance!';
            }
        }
        
        return null;
    }
    
    public class UnitDataWrapper {
        @AuraEnabled public Boolean isResidentCustomer;
        @AuraEnabled public List<Unit__c> units;
    }
    
    public class UnitDetailsWrapper{
        @AuraEnabled public UnitsUnitOptionDetails unitOptiontDetailObj;
        @AuraEnabled public UnitPaymentDetails unitPaymentDetailObj;
        @AuraEnabled public List<UnitOptionWrapper> unitOptionsList;
        @AuraEnabled public List<UnitPaymentPlanMapping__c> unitPaymentPlanOptions;
        // Arvind v17.0 (23 Sep 2026) - Facade Style (Phase.Facade_Style__c + Facade_Style_c__mdt)
        @AuraEnabled public Boolean facadeStyleRequired = false;
        @AuraEnabled public List<Map<String, String>> facadeStyleOptions = new List<Map<String, String>>();
    }
    
    public class UnitOptionWrapper{
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String selectedValue;
        @AuraEnabled public List<Map<String, String>> unitOptions;
    }
    
    public class UnitsUnitOptionDetails{
        @AuraEnabled public String selectedUnitOption;
        @AuraEnabled public List<Map<String, String>> availableUnitOptions;
        @AuraEnabled public List<UnitOptionDetails> unitOptionLst;
    }
    
    public class UnitOptionDetails{
        @AuraEnabled public Unit_Option__c unitOptionObj;
        @AuraEnabled public Boolean isSelected;
        
        public UnitOptionDetails(){
            isSelected = false;
        }
    }
    
    
    public class UnitPaymentDetails{
        @AuraEnabled public String selectedPayment;
        @AuraEnabled public List<Map<String, String>> availablePaymentPlans;
        @AuraEnabled public List<PaymentDetails> paymentLst;
    }
    
    public class PaymentDetails{
        @AuraEnabled public PaymentPlan__c paymentObj;
        @AuraEnabled public List<PaymentInstallements__c> paymentInstallment;
        @AuraEnabled public Boolean isSelected;
        
        public PaymentDetails(){
            isSelected = false;
        }
    }
    
    public class UnitPicklistOptions{
        @AuraEnabled public string picklistLable;
        @AuraEnabled public string picklistApiName;
        @AuraEnabled public List<String> picklistOptions;
    }
    public class unitOffersWrapper{
        @AuraEnabled public string unitId;
        @AuraEnabled public List<OfferLines__c> offerLinesLst = new List<OfferLines__c>();
    }
    
    public class DocumentValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public String nationality;
        @AuraEnabled public List<String> requiredDoc;
        
        public DocumentValidationResult(Boolean isValid, String nationality, List<String> requiredDoc) {
            this.isValid = isValid;
            this.nationality = nationality;
            this.requiredDoc = requiredDoc;
        }
    }
    
    //DPG API Call 
    @AuraEnabled
    public static Map<String, String> makeDPGApiCall(List<String> unitNames) {
        Map<String, String> resultMap = new Map<String, String>();
        Http http = new Http();
        System.debug('unitNames: '+ unitNames);
        for (String unitName : unitNames) {
            try {
                String endpointUrl = Label.MasterLinkURL;
                String fullUrl = endpointUrl + '?unitname=' + EncodingUtil.urlEncode(unitName, 'UTF-8');
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint(fullUrl);
                req.setMethod('GET');
                req.setTimeout(120000);
                System.debug('fullUrl:'+fullUrl);
                String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
                req.setHeader('Authorization', authHeader);
                
                HttpResponse res = http.send(req);
                System.debug(res.getStatusCode());
                if (res.getStatusCode() == 200) {
                    // Parse JSON and extract url
                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if (parsed.containsKey('url')) {
                        resultMap.put(unitName, (String) parsed.get('url'));
                    } else {
                        resultMap.put(unitName, null);
                    }
                } else {
                    resultMap.put(unitName, null);
                }
            } catch (Exception ex) {
                resultMap.put(unitName, null);
            }
        }
        
        System.debug('resultMap: '+ resultMap);
        return resultMap;
    }
    
    // Commerical
    // @AuraEnabled
    // public static void generateEoiAndPaymentPlan(Id oppId, Unit__c unitRec, Expressionofinterest__c eoiRec, PaymentPlan__c paymentPlanRec, PaymentInstallements__c[] paymentInstallments) {
    //     try {
    //         insert eoiRec;
            
    //         insert paymentPlanRec;
            
            
    //         for (PaymentInstallements__c inst: paymentInstallments) {
    //             inst.PaymentInstallment__c = paymentPlanRec.Id;
    //         }
            
    //         insert paymentInstallments;
            
            
    //         update unitRec;
    //         update new Opportunity(
    //             Id = oppId,
    //             Unit__c = unitRec.Id
    //         );
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }
    /**
     * Arvind - EOI v2.0 / v2.1
     * Thin @future wrapper. Must stay in this class (Salesforce requires @future in the
     * same class as its caller). Delegates ALL DML to EOISystemContext (without sharing).
     *
     * WHY @future:
     *   Running Receipt/Allocation/Charge inline in saveSalesOrder consumed ~38 extra
     *   SOQLs via ReceiptTrigger (+22), InvoiceTrigger (+5), SalesOrderTrigger (+9),
     *   pushing the transaction to 101 SOQLs and causing a LimitException.
     *   @future runs in a fresh transaction with its own 100-SOQL budget.
     *
     * WHY EOISystemContext (without sharing):
     *   Sales booking users have no access to Finance objects (Invoice, Allocation,
     *   Charge). Running @future in the with-sharing context of this class caused
     *   silent failures  -  Invoice query returned 0 rows, Allocation INSERT was blocked.
     *   EOISystemContext runs without sharing so all Finance objects are accessible.
     *
     * @param receiptSOMapJson     JSON Map<receiptId, soId>
     * @param receiptAmountMapJson JSON Map<receiptId, Decimal amount>
     * @param accountId            Opportunity.AccountId
     */
    // Arvind EOI v2.1 - START
    // @future wrapper -- stays in with sharing class (Salesforce requires @future to be
    // in the same class as the caller). Delegates ALL DML to EOISystemContext (without
    // sharing) so Finance objects (Invoice, Allocation, Charge) are accessible regardless
    // of the booking user's object/field permissions.
    // Root cause of missing Allocations: @future ran as Sales user who had no access to
    // Invoice/Allocation/Charge -> silent failure in single outer try-catch.
    // Arvind EOI v2.1 - @future kept for backward compatibility only.
    // No longer called from saveSalesOrder. Replaced by EOIPostBookingQueueable.
    @future
    public static void executeEOIPostBookingAsync(
        String receiptSOMapJson,
        String receiptAmountMapJson,
        Id     accountId
    ) {
        // Kept for backward compatibility. Logic moved to EOIPostBookingQueueable.
        System.debug('Arvind EOI v2.1 - executeEOIPostBookingAsync called (legacy - use Queueable).');
    }

    /**
     * Arvind - EOI v2.1
     * Inner Queueable class - replaces @future for EOI post-booking DML.
     * KEY: Queueable CAN trigger @future (ReceiptTrigger.sendUnIdentifiedReceipt_Future).
     *      @future CANNOT trigger @future - that was the crash root cause.
     * Runs in a fresh transaction with its own 100-SOQL budget.
     * Delegates DML to EOISystemContext (without sharing) for Finance object access.
     */
    private class EOIPostBookingQueueable implements Queueable {
        private final String receiptSOMapJson;
        private final String receiptAmountMapJson;
        private final Id     accountId;

        public EOIPostBookingQueueable(String receiptSOMapJson, String receiptAmountMapJson, Id accountId) {
            this.receiptSOMapJson    = receiptSOMapJson;
            this.receiptAmountMapJson = receiptAmountMapJson;
            this.accountId           = accountId;
        }

        public void execute(QueueableContext ctx) {
            System.debug('Arvind EOI v2.1 - EOIPostBookingQueueable.execute() started.');
            new EOISystemContext().run(receiptSOMapJson, receiptAmountMapJson, accountId);
        }
    }

    /**
     * Arvind - EOI v2.1
     * Private inner class that executes EOI post-booking DML in system context
     * (without sharing). This allows Finance objects to be updated regardless of
     * the booking user's object/field-level permissions.
     *
     * Execution order:
     *   Step 1 - UPDATE Receipt__c    : SalesOrder__c, Account__c, ADM flag
     *            [own try-catch  -  ReceiptTrigger failure does NOT stop Steps 2-5]
     *            Arvind v20.0 (30 Sep 2026) - runs ONLY when Custom Label
     *            EOI_Move_Receipt_To_SO = 'true'. When 'false', the Receipt is not
     *            moved and stays on the EOI, and Steps 2-5 (Allocation + Charge)
     *            are skipped as well.
     *   Step 2 - SELECT Invoice__c    : SO->Invoice + Charge mapping
     *   Step 3 - INSERT Allocation__c : one per cleared Receipt, Status = Applied
     *   Step 4 - SELECT Invoice__c    : re-query AFTER Allocation (trigger updates status)
     *   Step 5 - UPDATE Charge        : PaymentStatus, Paid_Amount, Remaining_Amount
     *            [Steps 2-5 share one try-catch]
     */
    // Arvind EOI v2.1 - without sharing inner class.
    // Runs in system context so Finance objects are always accessible.
    // Each step has its own try-catch so ReceiptTrigger failure does NOT
    // prevent Allocation + Charge creation.
    private without sharing class EOISystemContext {

        void run(String receiptSOMapJson, String receiptAmountMapJson, Id accountId) {

            // Deserialise parameters
            Map<String, Object> receiptSOMap  =
                (Map<String, Object>) JSON.deserializeUntyped(receiptSOMapJson);
            Map<String, Object> receiptAmtRaw =
                (Map<String, Object>) JSON.deserializeUntyped(receiptAmountMapJson);

            Map<Id, Id>      receiptToSOMap  = new Map<Id, Id>();
            Map<Id, Decimal> receiptAmountMap = new Map<Id, Decimal>();
            for (String rId : receiptSOMap.keySet()) {
                receiptToSOMap.put((Id) rId, (Id)(String) receiptSOMap.get(rId));
            }
            for (String rId : receiptAmtRaw.keySet()) {
                Object val = receiptAmtRaw.get(rId);
                receiptAmountMap.put((Id) rId,
                    val != null ? Decimal.valueOf(String.valueOf(val)) : 0);
            }

            // -- Step 1: Update Receipts -----------------------------------------------
            // Arvind EOI v2.1 - Receipt UPDATE restored here (running inside Queueable now).
            // From Queueable, ReceiptTrigger CAN call sendUnIdentifiedReceipt_Future safely.
            // This was the root cause: @future cannot call @future, but Queueable can.
            try {
                List<Receipt__c> receiptsToUpdate = new List<Receipt__c>();
                for (Id receiptId : receiptToSOMap.keySet()) {
                    Receipt__c r = new Receipt__c(Id = receiptId);
                    r.SalesOrder__c                   = receiptToSOMap.get(receiptId);
                    r.Account__c                      = accountId;
                    r.Is_ADM_Fees_and_Dari_charges__c = true;
                    r.Transaction_Type__c = 'ADM_CHARGES';
                    receiptsToUpdate.add(r);
                }
                // Arvind v20.0 (30 Sep 2026) - Custom Label EOI_Move_Receipt_To_SO added to the condition below.
                //   'true'  -> Receipt moved from EOI to the Sales Order (same as before).
                //   'false' -> Receipt NOT moved; stays on the EOI (no Receipt update).
                // Previous: if (!receiptsToUpdate.isEmpty()) {
                if (!receiptsToUpdate.isEmpty() && System.Label.EOI_Move_Receipt_To_SO == 'true') {
                    Database.update(receiptsToUpdate, AccessLevel.SYSTEM_MODE);
                    System.debug('Arvind EOI v2.1 - Step 1: Updated ' + receiptsToUpdate.size() + ' Receipt(s).');
                } else {
                    // Arvind v20.0 (30 Sep 2026) - debug only, no logic change
                    System.debug('Arvind v20.0 - Step 1 skipped: EOI_Move_Receipt_To_SO = '
                        + System.Label.EOI_Move_Receipt_To_SO + ' (Receipt stays on EOI).');
                }
                // Arvind v20.0 - END
            } catch (Exception receiptEx) {
                System.debug('Arvind EOI v2.1 - Step 1 failed (continuing to Allocation/Charge): '
                    + receiptEx.getMessage() + ' | Line: ' + receiptEx.getLineNumber());
            }

            // Arvind v20.0 (30 Sep 2026) - START
            // Custom Label EOI_Move_Receipt_To_SO = 'false' -> Receipt stays on the EOI,
            // so Allocation + Charge (Steps 2-5) are NOT created / updated either.
            if (System.Label.EOI_Move_Receipt_To_SO != 'true') {
                System.debug('Arvind v20.0 - Steps 2-5 skipped: EOI_Move_Receipt_To_SO = '
                    + System.Label.EOI_Move_Receipt_To_SO + ' (no Allocation / Charge).');
                return;
            }
            // Arvind v20.0 - END

                        // -- Steps 2-5: Invoice query, Allocation INSERT, Charge UPDATE ---------
            try {
                // Step 2: Query Invoice for SO mapping + Charge linkage
                // Arvind fix - also fetch InvoiceAmount__c so AllocationAmount__c
                // is capped to the invoice value (not the full receipt amount).
                // Example: Receipt = 9000, Invoice = 514 -> Allocation = 514.
                Map<Id, Id>      soToInvoiceMap     = new Map<Id, Id>();
                Map<Id, Id>      invoiceToChargeMap  = new Map<Id, Id>();
                Map<Id, Decimal> invoiceToAmountMap  = new Map<Id, Decimal>(); // Arvind fix
                for (Invoice__c inv : [
                    SELECT Id, Sales_Order__c, Charge__c, InvoiceAmount__c
                    FROM Invoice__c
                    WHERE Sales_Order__c IN :receiptToSOMap.values()
                    AND Is_ADM_Fees_and_Dari_charges__c = true
                ]) {
                    soToInvoiceMap.put(inv.Sales_Order__c, inv.Id);
                    if (inv.Charge__c != null) {
                        invoiceToChargeMap.put(inv.Id, inv.Charge__c);
                    }
                    // Store invoice amount for Allocation capping
                    invoiceToAmountMap.put(inv.Id,
                        inv.InvoiceAmount__c != null ? inv.InvoiceAmount__c : 0);
                }
                System.debug('Arvind EOI v2.1 - Invoices found: ' + soToInvoiceMap.size());

                // Step 3: Build + INSERT Allocations
                Map<Id, Decimal> chargeToReceiptAmt = new Map<Id, Decimal>();
                List<Allocation__c> allocations     = new List<Allocation__c>();

                for (Id receiptId : receiptToSOMap.keySet()) {
                    Id      soId          = receiptToSOMap.get(receiptId);
                    Id      invoiceId     = soToInvoiceMap.get(soId);
                    // Arvind fix: separate receipt amount and invoice amount
                    // AllocationAmount__c  = invoice amount (e.g. 514)
                    // ApprovedReceiptAmount__c = actual receipt amount (e.g. 9000)
                    Decimal receiptAmount = receiptAmountMap.containsKey(receiptId)
                                           ? receiptAmountMap.get(receiptId) : 0;
                    Decimal invoiceAmount = (invoiceId != null && invoiceToAmountMap.containsKey(invoiceId))
                                           ? invoiceToAmountMap.get(invoiceId) : 0;
                    if (invoiceId != null) {
                        Allocation__c alloc            = new Allocation__c();
                        alloc.Invoice__c               = invoiceId;
                        alloc.Receipt__c               = receiptId;
                        alloc.Status__c                = 'Applied';
                        alloc.AllocationDate__c        = Date.today();
                        alloc.AllocationAmount__c      = Math.min(receiptAmount, invoiceAmount);  // Arvind fix: invoice amount (514) V.9
                        alloc.ApprovedReceiptAmount__c = receiptAmount;  // receipt amount (9000) V.9
                        allocations.add(alloc);

                        Id chargeId = invoiceToChargeMap.get(invoiceId);
                        if (chargeId != null) {
                            Decimal existing = chargeToReceiptAmt.containsKey(chargeId)
                                               ? chargeToReceiptAmt.get(chargeId) : 0;
                            chargeToReceiptAmt.put(chargeId, existing + receiptAmount);
                        }
                    }
                }
                if (!allocations.isEmpty()) {
                    // Arvind EOI v2.1 - SYSTEM_MODE bypasses FLS on Allocation INSERT
                    Database.insert(allocations, AccessLevel.SYSTEM_MODE);
                    System.debug('Arvind EOI v2.1 - Created ' + allocations.size()
                        + ' Allocation(s).');
                }

                // Step 4: Re-query Invoice AFTER Allocation INSERT (trigger updates status)
                if (!chargeToReceiptAmt.isEmpty()) {
                    Set<Id> invoiceIds = new Set<Id>(invoiceToChargeMap.keySet());
                    Map<Id, String>  invStatus  = new Map<Id, String>();
                    Map<Id, Decimal> invBalance = new Map<Id, Decimal>();
                    for (Invoice__c inv : [
                        SELECT Id, InvoiceStatus__c, InvoiceBalance__c
                        FROM Invoice__c WHERE Id IN :invoiceIds
                    ]) {
                        invStatus.put(inv.Id,
                            inv.InvoiceStatus__c  != null ? inv.InvoiceStatus__c  : '');
                        invBalance.put(inv.Id,
                            inv.InvoiceBalance__c != null ? inv.InvoiceBalance__c : 0);
                    }

                    Map<Id, String>  chargeToStatus    = new Map<Id, String>();
                    Map<Id, Decimal> chargeToRemaining = new Map<Id, Decimal>();
                    for (Id invoiceId : invoiceToChargeMap.keySet()) {
                        Id chargeId = invoiceToChargeMap.get(invoiceId);
                        if (chargeId != null && invStatus.containsKey(invoiceId)) {
                            chargeToStatus.put(chargeId,    invStatus.get(invoiceId));
                            chargeToRemaining.put(chargeId, invBalance.get(invoiceId));
                        }
                    }

                    // Step 5: Update Charge
                    List<SObject> chargesToUpdate = new List<SObject>();
                    for (Id chargeId : chargeToReceiptAmt.keySet()) {
                        SObject c = chargeId.getSObjectType().newSObject(chargeId);
                        c.put('PaymentStatus__c',    chargeToStatus.get(chargeId));
                        c.put('Paid_Amount__c',      chargeToReceiptAmt.get(chargeId));
                        c.put('Remaining_Amount__c', chargeToRemaining.get(chargeId));
                        chargesToUpdate.add(c);
                    }
                    if (!chargesToUpdate.isEmpty()) {
                        // Arvind EOI v2.1 - SYSTEM_MODE bypasses FLS on Charge UPDATE
                        Database.update(chargesToUpdate, AccessLevel.SYSTEM_MODE);
                        System.debug('Arvind EOI v2.1 - Updated '
                            + chargesToUpdate.size() + ' Charge(s).');
                    }
                }
            } catch (Exception e) {
                System.debug('Arvind EOI v2.1 - Steps 2-5 error: ' + e.getMessage()
                    + ' | Line: ' + e.getLineNumber());
            }
        }
    }
    // Arvind EOI v2.1 - END


}