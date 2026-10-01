/**********************************************************************************************************************
* Name               : AccountAddressController
* Description        : AccountAddressControllerto get details for Opporutniy Record page LWC
* Usage              : gelocationlwc to get the record 
* Created By         : Arvind Kesharani
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                           Date            Description
* -------  -------------------------------- --------------- -------------------------------------------------------
* 1.0      Arvind Kesharani              14 July 2026         Initial Draft
* 1.1      Arvind Kesharani              11 Aug 2026          Fixed Org account billing fields (incl. Postal code)
*                                                              not saving; added mandatory TradeLicenseNumber__c and
*                                                              UAEVATRegisterNumber__c fields for Org accounts.
* 1.2      Arvind Kesharani              12 Aug 2026          Added mandatory TradeName__c field for Org accounts.
* 1.3      Arvind Kesharani              30 Sep 2026          Org accounts: Nationality / UAE Resident Status are
*                                                              now loaded from and saved to Opportunity.PrimaryContact__c
*                                                              (and still saved to the Opportunity). Picklist options
*                                                              now described from Contact fields.
****************************************************************************************************/
public with sharing class AccountAddressController {

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class PicklistOptionsWrapper {
        @AuraEnabled public List<PicklistOption> nationalityOptions;
        @AuraEnabled public List<PicklistOption> uaeResidentOptions;
    }

    // 1.3 - Describe the Contact fields. Account.Nationality__pc / UAE_Resident_Status__pc
    // ARE Contact.Nationality__c / UAE_Resident_Status__c, so one option list now serves
    // Person accounts AND the Org Primary Contact.
    @AuraEnabled(cacheable=true)
    public static PicklistOptionsWrapper getPicklistOptions() {
        PicklistOptionsWrapper wrap = new PicklistOptionsWrapper();
        wrap.nationalityOptions = describePicklist(Contact.Nationality__c.getDescribe());
        wrap.uaeResidentOptions = describePicklist(Contact.UAE_Resident_Status__c.getDescribe());
        return wrap;
    }

    private static List<PicklistOption> describePicklist(Schema.DescribeFieldResult fieldResult) {
        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.label = entry.getLabel();
                opt.value = entry.getValue();
                options.add(opt);
            }
        }
        return options;
    }

    @AuraEnabled
    public static Id resolveAccountId(Id sourceRecordId) {
        if (sourceRecordId == null) {
            throw new AuraHandledException('No record was provided to load the address form.');
        }

        String objectType = sourceRecordId.getSObjectType().getDescribe().getName();

        if (objectType == 'Account') {
            return sourceRecordId;
        }

        if (objectType == 'Opportunity') {
            List<Opportunity> opps = [
                SELECT AccountId FROM Opportunity WHERE Id = :sourceRecordId LIMIT 1
            ];
            if (opps.isEmpty()) {
                throw new AuraHandledException('Could not find this opportunity record.');
            }
            if (opps[0].AccountId == null) {
                throw new AuraHandledException('This opportunity has no related account.');
            }
            return opps[0].AccountId;
        }

        throw new AuraHandledException('Unsupported record type for address form: ' + objectType);
    }

    public class AccountAddressWrapper {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Boolean isPersonAccount;
        @AuraEnabled public String recordTypeName;

        // Person account - mailing
        @AuraEnabled public String personMailingStreet;
        @AuraEnabled public String personMailingCity;
        @AuraEnabled public String personMailingState;
        @AuraEnabled public String personMailingCountry;
        @AuraEnabled public String personMailingPostalCode;

        // Billing (both Person + Org)
        @AuraEnabled public String billingStreet;
        @AuraEnabled public String billingCity;
        @AuraEnabled public String billingState;
        @AuraEnabled public String billingCountry;
        @AuraEnabled public String billingPostalCode;

        // Nationality / residency (Person: from Account; Org: from Primary Contact)
        @AuraEnabled public String nationality;
        @AuraEnabled public String uaeResidentStatus;

        // 1.3 - Org accounts: the Opportunity's Primary Contact
        @AuraEnabled public Id primaryContactId;

        // Org account extra
        @AuraEnabled public String unifiedNumber;
        @AuraEnabled public String tradeLicenseNumber;
        @AuraEnabled public String uaeVatRegisterNumber;
        @AuraEnabled public String tradeName;

        // Geo coordinates - backend only, never shown to user
        @AuraEnabled public Decimal personMailingLatitude;
        @AuraEnabled public Decimal personMailingLongitude;
        @AuraEnabled public Decimal billingLatitude;
        @AuraEnabled public Decimal billingLongitude;
    }

    // 1.3 - added opportunityId (param name must stay "opportunityId"; the LWC passes it by name)
    @AuraEnabled
    public static AccountAddressWrapper loadAccount(Id accountId, Id opportunityId) {
        if (accountId == null) {
            throw new AuraHandledException('No account was provided to load.');
        }

        List<Account> accounts = [
            SELECT Id, IsPersonAccount, RecordType.Name,
                   PersonMailingStreet, PersonMailingCity, PersonMailingState,
                   PersonMailingCountry, PersonMailingPostalCode,
                   PersonMailingLatitude, PersonMailingLongitude,
                   BillingStreet, BillingCity, BillingState, BillingCountry, BillingPostalCode,
                   BillingLatitude, BillingLongitude,
                   Nationality__pc, UAE_Resident_Status__pc,
                   UnifiedNumber__c, TradeLicenseNumber__c, UAEVATRegisterNumber__c, TradeName__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            throw new AuraHandledException('Could not find this account record.');
        }

        Account acc = accounts[0];
        AccountAddressWrapper wrap = new AccountAddressWrapper();
        wrap.accountId = accountId;
        wrap.opportunityId = opportunityId;

        wrap.isPersonAccount = acc.IsPersonAccount;
        wrap.recordTypeName = acc.RecordType != null ? acc.RecordType.Name : '';

        wrap.personMailingStreet = acc.PersonMailingStreet;
        wrap.personMailingCity = acc.PersonMailingCity;
        wrap.personMailingState = acc.PersonMailingState;
        wrap.personMailingCountry = acc.PersonMailingCountry;
        wrap.personMailingPostalCode = acc.PersonMailingPostalCode;
        wrap.personMailingLatitude = acc.PersonMailingLatitude;
        wrap.personMailingLongitude = acc.PersonMailingLongitude;

        wrap.billingStreet = acc.BillingStreet;
        wrap.billingCity = acc.BillingCity;
        wrap.billingState = acc.BillingState;
        wrap.billingCountry = acc.BillingCountry;
        wrap.billingPostalCode = acc.BillingPostalCode;
        wrap.billingLatitude = acc.BillingLatitude;
        wrap.billingLongitude = acc.BillingLongitude;

        if (acc.IsPersonAccount) {
            wrap.nationality = acc.Nationality__pc;
            wrap.uaeResidentStatus = acc.UAE_Resident_Status__pc;
        } else {
            // 1.3 - Org accounts: business Accounts have no __pc values, so read from the
            // Opportunity's Primary Contact, falling back to what is already on the Opportunity.
            Opportunity opp = getOpportunityWithPrimaryContact(opportunityId);
            if (opp != null) {
                wrap.primaryContactId = opp.PrimaryContact__c;
                if (opp.PrimaryContact__c != null) {
                    wrap.nationality = opp.PrimaryContact__r.Nationality__c;
                    wrap.uaeResidentStatus = opp.PrimaryContact__r.UAE_Resident_Status__c;
                }
                if (String.isBlank(wrap.nationality)) wrap.nationality = opp.Nationality__c;
                if (String.isBlank(wrap.uaeResidentStatus)) wrap.uaeResidentStatus = opp.UAE_Resident_Status__c;
            }
        }

        wrap.unifiedNumber = acc.UnifiedNumber__c;
        wrap.tradeLicenseNumber = acc.TradeLicenseNumber__c;
        wrap.uaeVatRegisterNumber = acc.UAEVATRegisterNumber__c;
        wrap.tradeName = acc.TradeName__c;

        return wrap;
    }

    private static Opportunity getOpportunityWithPrimaryContact(Id opportunityId) {
        if (opportunityId == null) return null;
        List<Opportunity> opps = [
            SELECT Id, Nationality__c, UAE_Resident_Status__c,
                   PrimaryContact__c,
                   PrimaryContact__r.Nationality__c,
                   PrimaryContact__r.UAE_Resident_Status__c,
                   PrimaryContact__r.AccountId,
                   PrimaryContact__r.IsPersonAccount
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    @AuraEnabled
    public static String saveAccount(String accountData) {
        try {
            AccountAddressWrapper wrap = (AccountAddressWrapper) JSON.deserialize(
                accountData, AccountAddressWrapper.class
            );

            if (wrap.accountId == null) {
                throw new AuraHandledException('Could not save: no account was linked to this form. Please close and reopen it.');
            }

            if (String.isBlank(wrap.nationality)) {
                throw new AuraHandledException('Nationality is required.');
            }
            if (String.isBlank(wrap.uaeResidentStatus)) {
                throw new AuraHandledException('UAE Resident Status is required.');
            }

            // 1.3 - null-safe (a null Boolean in an if() throws in Apex)
            Boolean isPerson = wrap.isPersonAccount == true;

            Account acc = new Account(Id = wrap.accountId);

            if (isPerson) {
                acc.PersonMailingStreet = wrap.personMailingStreet;
                acc.PersonMailingCity = wrap.personMailingCity;
                acc.PersonMailingState = wrap.personMailingState;
                acc.PersonMailingCountry = wrap.personMailingCountry;
                acc.PersonMailingPostalCode = wrap.personMailingPostalCode;
                acc.PersonMailingLatitude = wrap.personMailingLatitude;
                acc.PersonMailingLongitude = wrap.personMailingLongitude;

                acc.Nationality__pc = wrap.nationality;
                acc.UAE_Resident_Status__pc = wrap.uaeResidentStatus;
            }

            acc.BillingStreet = wrap.billingStreet;
            acc.BillingCity = wrap.billingCity;
            acc.BillingState = wrap.billingState;
            acc.BillingCountry = wrap.billingCountry;
            acc.BillingPostalCode = wrap.billingPostalCode;
            acc.BillingLatitude = wrap.billingLatitude;
            acc.BillingLongitude = wrap.billingLongitude;

            if (!isPerson) {
                if (String.isBlank(wrap.unifiedNumber)) {
                    throw new AuraHandledException('Unified Number is required.');
                }
                if (String.isBlank(wrap.tradeLicenseNumber)) {
                    throw new AuraHandledException('Trade License Number is required.');
                }
                if (String.isBlank(wrap.uaeVatRegisterNumber)) {
                    throw new AuraHandledException('UAE VAT Register Number is required.');
                }
                if (String.isBlank(wrap.tradeName)) {
                    throw new AuraHandledException('Trade Name is required.');
                }

                acc.UnifiedNumber__c = wrap.unifiedNumber;
                acc.TradeLicenseNumber__c = wrap.tradeLicenseNumber;
                acc.UAEVATRegisterNumber__c = wrap.uaeVatRegisterNumber;
                acc.TradeName__c = wrap.tradeName;
            }

            update acc;

            // Nationality / UAE Resident Status still save to the Opportunity for both types.
            if (wrap.opportunityId != null) {
                Opportunity opp = new Opportunity(Id = wrap.opportunityId);
                opp.Nationality__c = wrap.nationality;
                opp.UAE_Resident_Status__c = wrap.uaeResidentStatus;
                update opp;
            }

            // 1.3 - Org accounts: also save to the Opportunity's Primary Contact.
            // Re-read PrimaryContact__c on the server rather than trusting the client value.
            if (!isPerson) {
                Opportunity oppWithContact = getOpportunityWithPrimaryContact(wrap.opportunityId);
                if (oppWithContact == null || oppWithContact.PrimaryContact__c == null) {
                    throw new AuraHandledException(
                        'The Opportunity has no Primary Contact, so Nationality and UAE Resident Status could not be saved to it.');
                }

                if (oppWithContact.PrimaryContact__r.IsPersonAccount) {
                    // A person-account Contact can't be updated directly - update its Account.
                    update new Account(
                        Id = oppWithContact.PrimaryContact__r.AccountId,
                        Nationality__pc = wrap.nationality,
                        UAE_Resident_Status__pc = wrap.uaeResidentStatus
                    );
                } else {
                    update new Contact(
                        Id = oppWithContact.PrimaryContact__c,
                        Nationality__c = wrap.nationality,
                        UAE_Resident_Status__c = wrap.uaeResidentStatus
                    );
                }
            }

            return 'SUCCESS';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to save account: ' + e.getMessage());
        }
    }
}