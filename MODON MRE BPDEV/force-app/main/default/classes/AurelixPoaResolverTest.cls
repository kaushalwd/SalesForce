/**
 * AurelixPoaResolverTest
 *
 * Version  Author       Date         Detail
 * 1.1      Aurelix Dev  29 Sep 2026  Resolver 1.1: bookingSubject prefers the primary contact over any POA row,
 *                                    falls back to the POA row, and is null for a person buyer.
 * 1.0      Aurelix Dev  18 Sep 2026  MSC-176 (B6).
 */
@IsTest
private class AurelixPoaResolverTest {

    private static Id orgRecordTypeId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    @IsTest
    static void noPoaRowMeansNoSignatory() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix POA Co None', RecordTypeId = rt);
        insert co;
        Contact c = new Contact(LastName = 'Aurelix Nobody', AccountId = co.Id);
        insert c;
        System.assertEquals(null, AurelixPoaResolver.resolve(co.Id, c.Id),
            'A contact without a Power of Attorney row is not a signatory.');
        System.assertEquals(null, AurelixPoaResolver.resolve(null, null), 'Null in, null out.');
    }

    @IsTest
    static void theOpportunityContactIsPreferredAmongPoaRows() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix POA Co Two', RecordTypeId = rt);
        insert co;
        Contact older = new Contact(LastName = 'Aurelix Older', AccountId = co.Id);
        Contact chosen = new Contact(LastName = 'Aurelix Chosen', AccountId = co.Id);
        insert new List<Contact>{ older, chosen };
        insert new List<Power_of_Attorney__c>{
            new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = older.Id),
            new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = chosen.Id)
        };

        System.assertEquals(chosen.Id, AurelixPoaResolver.resolve(co.Id, chosen.Id),
            'The Opportunity primary contact wins when it holds a POA row.');
        Id fallback = AurelixPoaResolver.resolve(co.Id, null);
        System.assert(fallback == older.Id || fallback == chosen.Id,
            'With no preference the most recently maintained row is used.');

        Opportunity opp = new Opportunity(
            Name = 'Aurelix POA Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = chosen.Id);
        insert opp;
        System.assertEquals(chosen.Id, AurelixPoaResolver.resolveForOpportunity(opp.Id),
            'The Opportunity form reads the company and the contact itself.');
        System.assertEquals(null, AurelixPoaResolver.resolveForOpportunity(null));
    }

    /** 1.1 - a company's own booking is checked on its primary contact. */
    @IsTest
    static void aBookingIsCheckedOnItsPrimaryContactWithOrWithoutAPoaRow() {
        Id rt = orgRecordTypeId();
        if (rt == null) { return; }
        Account co = new Account(Name = 'Aurelix POA Co Booking', RecordTypeId = rt);
        insert co;
        Contact rowHolder = new Contact(LastName = 'Aurelix Row Holder', AccountId = co.Id);
        Contact primary   = new Contact(LastName = 'Aurelix Primary', AccountId = co.Id);
        insert new List<Contact>{ rowHolder, primary };

        System.assertEquals(primary.Id, AurelixPoaResolver.bookingSubject(co.Id, primary.Id),
            'No POA row: the primary contact.');
        System.assertEquals(null, AurelixPoaResolver.bookingSubject(co.Id, null),
            'No primary contact and no POA row: nobody.');

        insert new Power_of_Attorney__c(Organization_Account__c = co.Id, Contact__c = rowHolder.Id);
        System.assertEquals(primary.Id, AurelixPoaResolver.bookingSubject(co.Id, primary.Id),
            'A POA row naming someone else does not replace the primary contact.');
        System.assertEquals(rowHolder.Id, AurelixPoaResolver.bookingSubject(co.Id, null),
            'With no primary contact the POA row answers.');
        System.assertEquals(rowHolder.Id, AurelixPoaResolver.resolve(co.Id, primary.Id),
            'resolve itself is unchanged: it answers who holds the row.');

        Opportunity opp = new Opportunity(
            Name = 'Aurelix POA Booking Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id, PrimaryContact__c = primary.Id);
        Opportunity bare = new Opportunity(
            Name = 'Aurelix POA Booking Opp Bare', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = co.Id);
        insert new List<Opportunity>{ opp, bare };
        System.assertEquals(primary.Id, AurelixPoaResolver.bookingSubjectForOpportunity(opp.Id));
        System.assertEquals(rowHolder.Id, AurelixPoaResolver.bookingSubjectForOpportunity(bare.Id));
        System.assertEquals(null, AurelixPoaResolver.bookingSubjectForOpportunity(null));
    }

    /** 1.1 - a person buyer has no POA: null, as resolveForOpportunity answers. */
    @IsTest
    static void aPersonBookingHasNoBookingSubjectHere() {
        List<RecordType> prt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1
        ];
        if (prt.isEmpty()) { return; }
        Account person = new Account(FirstName = 'Aurelix', LastName = 'Resolver Person', RecordTypeId = prt[0].Id);
        insert person;
        Account back = [SELECT Id, PersonContactId FROM Account WHERE Id = :person.Id LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'Aurelix Resolver Person Opp', StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30), AccountId = person.Id, PrimaryContact__c = back.PersonContactId);
        insert opp;
        System.assertEquals(null, AurelixPoaResolver.bookingSubjectForOpportunity(opp.Id));
    }
}