/**********************************************************************************************
 * Name           : CheckoutReturnControllerTest
 * Description     : Coverage for the CheckoutReturn VF page controller (confirm-on-return).
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    05 Jul 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class CheckoutReturnControllerTest {

    private class Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('/payments?reference=')) {
                res.setStatusCode(200);
                res.setBody('{"data":[{"id":"pay_ret","status":"captured","source":{"last4":"4242","scheme":"Visa"}}]}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    @TestSetup
    static void seed() {
        Account acc = new Account(Name = 'Return Test Account', Phone = '+971500000000');
        insert acc;
        Contact con = new Contact(AccountId = acc.Id, FirstName = 'Ret', LastName = 'Contact',
            Email = 'ret.contact@example.com', MobilePhone = '+971500000001');
        insert con;
        Opportunity opp = new Opportunity(Name = 'Return Test Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id);
        if (Opportunity.SObjectType.getDescribe().fields.getMap().containsKey('contactid')) {
            opp.put('ContactId', con.Id);
        }
        insert opp;

        insert new Checkout_Payment__c(
            Reference__c = 'CKO-RET', Status__c = 'Authorized', Amount__c = 500, Currency_Code__c = 'AED',
            EOI_Creation_Payload__c = JSON.serialize(new Map<String, Object>{
                'opportunityId' => opp.Id, 'eoiAmount' => 500, 'numberOfUnits' => 1, 'paymentType' => 'Online'
            })
        );
    }

    @IsTest
    static void successConfirmsAndShowsEoi() {
        Test.setMock(HttpCalloutMock.class, new Mock());
        Test.setCurrentPage(Page.CheckoutReturn);
        ApexPages.currentPage().getParameters().put('paymentResult', 'success');
        ApexPages.currentPage().getParameters().put('ref', 'CKO-RET');

        Test.startTest();
        CheckoutReturnController ctrl = new CheckoutReturnController();
        ctrl.process();
        Test.stopTest();

        System.assertEquals(true, ctrl.isSuccess, 'Payment confirmed on the spot');
        System.assertNotEquals(null, ctrl.eoiUrl, 'Link to the created EOI is built');
        System.assertNotEquals(null, ctrl.eoiName, 'EOI name resolved');
    }

    @IsTest
    static void cancelledShowsNoEoi() {
        Test.setCurrentPage(Page.CheckoutReturn);
        ApexPages.currentPage().getParameters().put('paymentResult', 'cancelled');

        CheckoutReturnController ctrl = new CheckoutReturnController();
        ctrl.process();

        System.assertEquals(false, ctrl.isSuccess, 'Cancelled is not a success');
        System.assertEquals(true, ctrl.isFailed, 'Cancelled flagged as failed/no-EOI');
    }

    @IsTest
    static void successWithoutReferenceIsPending() {
        Test.setCurrentPage(Page.CheckoutReturn);
        ApexPages.currentPage().getParameters().put('paymentResult', 'success');

        CheckoutReturnController ctrl = new CheckoutReturnController();
        ctrl.process();

        System.assertEquals(true, ctrl.isPending, 'No reference -> pending message, poller will finish');
    }
}