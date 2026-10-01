@isTest
private class PaymentGatewayUtilityTest {

    @isTest
    static void myTestMethod() {
        
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account acc = new Account(RecordTypeId = recordTypeId);
        acc.PersonEmail = 'abdallahhdaib@outlook.com';
        acc.FirstName = 'First';
        acc.LastName = 'Last';
        insert acc;
        
        //Account acc = new Account();
        //acc.name = 'Test Account';
        //insert acc;
        EscrowAccount__c eacc = new EscrowAccount__c();
        eacc.AccountNumber__c = 'test12345';
        eacc.StoreId__c = '811187409';
        insert eacc;

        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        recObj.PaymentEscrowAccount__c = eacc.Id;
        insert recObj;
        
        PaymentLinkRequestWrapper.tamount tAmountInnerClass = new PaymentLinkRequestWrapper.tamount();
        tAmountInnerClass.str_currency = 'AED';
        tAmountInnerClass.total = '1000';
        
        PaymentLinkRequestWrapper reqWrapper = new PaymentLinkRequestWrapper();
        reqWrapper.transactionAmount = tAmountInnerClass;
        reqWrapper.transactionType = 'SALE';
        reqWrapper.orderId = recObj.Id;
        

        test.StartTest();
            try{
                PaymentGatewayUtility.getRequestBodyForPaymentURL(recObj.Id);
                PaymentGatewayUtility.postRequestBodyForPaymentURL(JSON.serialize(reqWrapper), recObj.Id); 
            } catch (Exception e){}
        test.stoptest();        
    }

    @isTest
    static void myTestMethod_1a() {
        
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account acc = new Account(RecordTypeId = recordTypeId);
        acc.PersonEmail = 'abdallahhdaib@outlook.com';
        acc.FirstName = 'First';
        acc.LastName = 'Last';
        insert acc;
        
        //Account acc = new Account();
        //acc.name = 'Test Account';
        //insert acc;
        EscrowAccount__c eacc = new EscrowAccount__c();
        eacc.AccountNumber__c = 'test12345';
        eacc.StoreId__c = '811187409';
        insert eacc;

        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        recObj.EOIEscrowAccount__c = eacc.Id;
        insert recObj;
        
        PaymentLinkRequestWrapper.tamount tAmountInnerClass = new PaymentLinkRequestWrapper.tamount();
        tAmountInnerClass.str_currency = 'AED';
        tAmountInnerClass.total = '1000';
        
        PaymentLinkRequestWrapper reqWrapper = new PaymentLinkRequestWrapper();
        reqWrapper.transactionAmount = tAmountInnerClass;
        reqWrapper.transactionType = 'SALE';
        reqWrapper.orderId = recObj.Id;
        

        test.StartTest();
            try{
                PaymentGatewayUtility.getRequestBodyForPaymentURL(recObj.Id);
                PaymentGatewayUtility.postRequestBodyForPaymentURL(JSON.serialize(reqWrapper), recObj.Id); 
            } catch (Exception e){}
        test.stoptest();        
    }
    
    @isTest
    static void myTestMethod2() {
Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account acc = new Account(RecordTypeId = recordTypeId);
        acc.PersonEmail = 'abdallahhdaib@outlook.com';
        acc.FirstName = 'First';
        acc.LastName = 'Last';
        insert acc;
        
        EscrowAccount__c eacc = new EscrowAccount__c();
        eacc.AccountNumber__c = 'test12345';
        eacc.StoreId__c = '811187409';
        insert eacc;

        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        recObj.PaymentGatewayURL__c = 'testtesttes';
        recObj.PaymentEscrowAccount__c = eacc.Id;
        insert recObj;
        
        PaymentLinkRequestWrapper.tamount tAmountInnerClass = new PaymentLinkRequestWrapper.tamount();
        tAmountInnerClass.str_currency = 'AED';
        tAmountInnerClass.total = '1000';
        
        PaymentLinkRequestWrapper reqWrapper = new PaymentLinkRequestWrapper();
        reqWrapper.transactionAmount = tAmountInnerClass;
        reqWrapper.transactionType = 'SALE';
        reqWrapper.orderId = recObj.Id;
        

        test.StartTest();
            try{
                PaymentGatewayUtility.getPaymentGatewayURL(recObj.Id);
                PaymentGatewayUtility.deletePaymentURL(recObj.Id);
                PaymentGatewayUtility.retrievePaymentStatus(recObj.Id);
            } catch (Exception e){}
        test.stoptest();        
    }

    @isTest
    static void myTestMethod2a() {
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account acc = new Account(RecordTypeId = recordTypeId);
        acc.PersonEmail = 'abdallahhdaib@outlook.com';
        acc.FirstName = 'First';
        acc.LastName = 'Last';
        insert acc;
        
        EscrowAccount__c eacc = new EscrowAccount__c();
        eacc.AccountNumber__c = 'test12345';
        eacc.StoreId__c = '811187409';
        insert eacc;

        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        recObj.PaymentGatewayURL__c = 'testtesttes';
        recObj.EOIEscrowAccount__c = eacc.Id;
        insert recObj;
        
        PaymentLinkRequestWrapper.tamount tAmountInnerClass = new PaymentLinkRequestWrapper.tamount();
        tAmountInnerClass.str_currency = 'AED';
        tAmountInnerClass.total = '1000';
        
        PaymentLinkRequestWrapper reqWrapper = new PaymentLinkRequestWrapper();
        reqWrapper.transactionAmount = tAmountInnerClass;
        reqWrapper.transactionType = 'SALE';
        reqWrapper.orderId = recObj.Id;
        

        test.StartTest();
            try{
                PaymentGatewayUtility.getPaymentGatewayURL(recObj.Id);
                PaymentGatewayUtility.deletePaymentURL(recObj.Id);
                PaymentGatewayUtility.retrievePaymentStatus(recObj.Id);
            } catch (Exception e){}
        test.stoptest();        
    }
    
    @isTest
    static void myTestMethod3() {
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account acc = new Account(RecordTypeId = recordTypeId);
        acc.PersonEmail = 'abdallahhdaib@outlook.com';
        acc.FirstName = 'First';
        acc.LastName = 'Last';
        insert acc;
        

        EscrowAccount__c eacc = new EscrowAccount__c();
        eacc.AccountNumber__c = 'test12345';
        eacc.StoreId__c = '811187409';
        insert eacc;

        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        recObj.PaymentGatewayURL__c = 'testtesttes';
        recObj.PaymentEscrowAccount__c = eacc.Id;
        insert recObj;
        
        PaymentLinkRequestWrapper.tamount tAmountInnerClass = new PaymentLinkRequestWrapper.tamount();
        tAmountInnerClass.str_currency = 'AED';
        tAmountInnerClass.total = '1000';
        
        PaymentLinkRequestWrapper reqWrapper = new PaymentLinkRequestWrapper();
        reqWrapper.transactionAmount = tAmountInnerClass;
        reqWrapper.transactionType = 'SALE';
        reqWrapper.orderId = recObj.Id;
        

        test.StartTest();
            try{
                PaymentGatewayUtility.retrievePaymentStatus(recObj.Id);
            } catch (Exception e){}
        test.stoptest();        
    }
    
    
    @isTest
    static void myTestMethod4() {
      Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account acc = new Account(RecordTypeId = recordTypeId);
        acc.PersonEmail = 'abdallahhdaib@outlook.com';
        acc.FirstName = 'First';
        acc.LastName = 'Last';
        insert acc;
        

        EscrowAccount__c eacc = new EscrowAccount__c();
        eacc.AccountNumber__c = 'test12345';
        eacc.StoreId__c = '811187409';
        insert eacc;

        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        recObj.TotalAmount__c = 100;
        recObj.ReSendPaymentURLRequest__c = true;
        recObj.PaymentGatewayURL__c = 'testtesttes';
        recObj.PaymentEscrowAccount__c = eacc.Id;
        insert recObj;
        
        PaymentLinkRequestWrapper.tamount tAmountInnerClass = new PaymentLinkRequestWrapper.tamount();
        tAmountInnerClass.str_currency = 'AED';
        tAmountInnerClass.total = '1000';
        
        PaymentLinkRequestWrapper reqWrapper = new PaymentLinkRequestWrapper();
        reqWrapper.transactionAmount = tAmountInnerClass;
        reqWrapper.transactionType = 'SALE';
        reqWrapper.orderId = recObj.Id;
        

        test.StartTest();
            try{
                PaymentGatewayUtility.getPaymentGatewayURL(recObj.Id);
                
                recObj.TotalAmount__c = 0;
                update recObj;
                PaymentGatewayUtility.getPaymentGatewayURL(recObj.Id);
                
                recObj.PaymentStatus__c = 'APPROVED';
                update recObj;
                PaymentGatewayUtility.getPaymentGatewayURL(recObj.Id);
            } catch (Exception e){}
        test.stoptest();        
    }
        
    @isTest
    static void myTestMethod5() {
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account acc = new Account(RecordTypeId = recordTypeId);
        acc.PersonEmail = 'abdallahhdaib@outlook.com';
        acc.FirstName = 'First';
        acc.LastName = 'Last';
        insert acc;
        

        EscrowAccount__c eacc = new EscrowAccount__c();
        eacc.AccountNumber__c = 'test12345';
        eacc.StoreId__c = '811187409';
        insert eacc;

        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        recObj.TotalAmount__c = -1;
        recObj.ReSendPaymentURLRequest__c = true;
        recObj.PaymentGatewayURL__c = 'testtesttes';
        recObj.PaymentEscrowAccount__c = eacc.Id;
        insert recObj;
        
        PaymentLinkRequestWrapper.tamount tAmountInnerClass = new PaymentLinkRequestWrapper.tamount();
        tAmountInnerClass.str_currency = 'AED';
        tAmountInnerClass.total = '1000';
        
        PaymentLinkRequestWrapper reqWrapper = new PaymentLinkRequestWrapper();
        reqWrapper.transactionAmount = tAmountInnerClass;
        reqWrapper.transactionType = 'SALE';
        reqWrapper.orderId = recObj.Id;
        

        test.StartTest();
            try{
                PaymentGatewayUtility.getPaymentGatewayURL(recObj.Id);
            } catch (Exception e){}
        test.stoptest();        
    }
    
           
    @isTest
    static void myTestMethod6() {
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account acc = new Account(RecordTypeId = recordTypeId);
        acc.PersonEmail = 'abdallahhdaib@outlook.com';
        acc.FirstName = 'First';
        acc.LastName = 'Last';
        insert acc;
        

        EscrowAccount__c eacc = new EscrowAccount__c();
        eacc.AccountNumber__c = 'test12345';
        eacc.StoreId__c = '811187409';
        insert eacc;

        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = acc.Id;
        recObj.TotalAmount__c = 100;
        recObj.ReSendPaymentURLRequest__c = true;
        recObj.PaymentGatewayURL__c = 'testtesttes';
        recObj.PaymentStatus__c = 'REJECTED';
        recObj.PaymentEscrowAccount__c = eacc.Id;
        insert recObj;
        
        PaymentLinkRequestWrapper.tamount tAmountInnerClass = new PaymentLinkRequestWrapper.tamount();
        tAmountInnerClass.str_currency = 'AED';
        tAmountInnerClass.total = '1000';
        
        PaymentLinkRequestWrapper reqWrapper = new PaymentLinkRequestWrapper();
        reqWrapper.transactionAmount = tAmountInnerClass;
        reqWrapper.transactionType = 'SALE';
        reqWrapper.orderId = recObj.Id;
        

        test.StartTest();
            try{
                PaymentGatewayUtility.getPaymentGatewayURL(recObj.Id);
            } catch (Exception e){}
        test.stoptest();        
    }
}