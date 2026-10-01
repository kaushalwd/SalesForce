/**********************************************************************************************************************
* Name               : PaymentGatewayUtility                                                       
* Description        : This is a utility class for Payment Gateway Integration.
* Usage              : Called from -
* Created By         : PwC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                15 Jan 2024     Initial Draft   
******************************************************************************************************************/    

public without sharing class PaymentGatewayUtility {

    
    public static string getRequestBodyForPaymentURL (string recordID){
    
        string requestBody = null;
        
        if(recordID <> null){
            Organization this_org = [Select Id, Name, IsSandbox from Organization];
            
            
            Payment_Gateway__mdt pg_metadata = new Payment_Gateway__mdt();
            
            if(this_org.IsSandbox){
                pg_metadata = Payment_Gateway__mdt.getInstance('Payment_Gateway_Sandbox');
            }
            else{
                pg_metadata = Payment_Gateway__mdt.getInstance('Payment_Gateway');
            }
            
            if(pg_metadata <> null){
                
                Receipt__c receipt = [select Id, Account__c, AppliedAmount__c, BankName__c, Expressionofinterest__c, 
                            GeneratePaymentGatewayURLCallCount__c, Modeofpayment__c, PaymentGatewayURL__c,
                            ReceiptDate__c, RemainingAmount__c, Status__c, TotalAmount__c, TransactionNumber__c,
                            PaymentEscrowAccount__c, EOIEscrowAccount__c, PaymentEscrowAccount__r.StoreId__c, EOIEscrowAccount__r.StoreId__c
                            from Receipt__c where Id =: recordID];
                
                if(receipt <> null){
                    
                    PaymentLinkRequestWrapper plinkReqWrapper = new PaymentLinkRequestWrapper();
                    PaymentLinkRequestWrapper.tamount transAmnt = new PaymentLinkRequestWrapper.tamount();
                    
                    if(receipt.TotalAmount__c <> null)
                    transAmnt.total = string.ValueOf(receipt.TotalAmount__c);
                    
                    transAmnt.str_currency = pg_metadata.Currency__c;
                    
                    plinkReqWrapper.transactionAmount = transAmnt;
                    plinkReqWrapper.transactionType = pg_metadata.Transaction_Type__c;

                    if(receipt.GeneratePaymentGatewayURLCallCount__c <> null && receipt.GeneratePaymentGatewayURLCallCount__c <> 0)
                    plinkReqWrapper.orderId = receipt.Id + '_' + string.valueOf(receipt.GeneratePaymentGatewayURLCallCount__c);
                    else 
                    plinkReqWrapper.orderId = receipt.Id;
                    
                    plinkReqWrapper.transactionNotificationURL = pg_metadata.Transaction_Notification_URL__c;
                    
                    if(receipt.PaymentEscrowAccount__c <> null && receipt.PaymentEscrowAccount__r.StoreId__c <> null)
                    plinkReqWrapper.storeId = receipt.PaymentEscrowAccount__r.StoreId__c;
                    else if(receipt.EOIEscrowAccount__c <> null && receipt.EOIEscrowAccount__r.StoreId__c <> null)
                    plinkReqWrapper.storeId = receipt.EOIEscrowAccount__r.StoreId__c;

                    requestBody = JSON.Serialize(plinkReqWrapper).replace('str_currency', 'currency');
                    
                }
                
            }
            
            
        
        }
        
        return requestBody;
    
    }
    
    
    public static PaymentLinkResponseWrapper postRequestBodyForPaymentURL (string requestBody, string recordID){
        
        PaymentLinkResponseWrapper plinkResponseWrap = new PaymentLinkResponseWrapper();
        
        system.debug('REQUEST BODY:::: ' + requestBody);
        system.debug('Record ID:::: ' + recordID);
        
        if(requestBody <> null){
            
            PaymentLinkRequestWrapper prwrap = (PaymentLinkRequestWrapper) System.JSON.deserialize(requestBody, PaymentLinkRequestWrapper.class);
            string clientRequestID = null;
            clientRequestID = prwrap.orderId;

            string storeId = null;
            storeId = prwrap.storeId;

            Organization this_org = [Select Id, Name, IsSandbox from Organization];
            
            Payment_Gateway__mdt pg_metadata = new Payment_Gateway__mdt();
            
            if(this_org.IsSandbox){
                pg_metadata = Payment_Gateway__mdt.getInstance('Payment_Gateway_Sandbox');
            }
            else{
                pg_metadata = Payment_Gateway__mdt.getInstance('Payment_Gateway');
            }

            system.debug('storeId::::::' + storeId);

            Store_ID_and_API_Key_Mapping__mdt storeID_KeyMapping = new Store_ID_and_API_Key_Mapping__mdt();
            if(storeId <> null){
                if(this_org.IsSandbox)
                storeID_KeyMapping = Store_ID_and_API_Key_Mapping__mdt.getInstance('sandbox_' + storeId);
                else 
                storeID_KeyMapping = Store_ID_and_API_Key_Mapping__mdt.getInstance('X' + storeId);
                
            }
            
            system.debug('storeID_KeyMapping:::::' + storeID_KeyMapping);
            
            if(pg_metadata <> null){
                
                Datetime dt = Datetime.now();
                Long longDateTimeInstance = dt.getTime();

                Http http = new Http();
                HttpRequest request = new HttpRequest();
                
                request.setEndpoint(pg_metadata.End_Point_URL__c);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setHeader('Api-Key', storeID_KeyMapping.API_Key__c);
                request.setHeader('Client-Request-Id', clientRequestID);
                
                Blob mac = Crypto.generateMac('hmacSHA256', blob.valueOf(storeID_KeyMapping.API_Key__c + clientRequestID + String.ValueOf(longDateTimeInstance) + +requestBody),blob.valueOf(storeID_KeyMapping.Secret_Key__c));
                String signature = EncodingUtil.base64Encode(mac);
                request.setHeader('Message-Signature', signature);
                request.setHeader('Timestamp', String.ValueOf(longDateTimeInstance));
                request.setBody(requestBody);

                HttpResponse response = http.send(request);
                // If the request is successful, parse the JSON response.
                system.debug('FETCH PAYMENT URL STATUS CODE:::: ' + response.getStatusCode());
                System.debug('FETCH PAYMENT URL RESPONSE BODY:::: ' + response.getBody());
                
                if(response.getBody() <> null && response.getBody() <> ''){
                    plinkResponseWrap = (PaymentLinkResponseWrapper) System.JSON.deserialize(response.getBody(), PaymentLinkResponseWrapper.class);
                }

            }
            

        }
        
        return plinkResponseWrap;
        
    }

    // To get the payment gateway URL, used in an action button on Receipt
    @AuraEnabled
    public static string getPaymentGatewayURL(string recordID){

        string str = 'Success';

        try{
            if(recordID <> null){
                
                Receipt__c receipt = [select Id, Account__c, AppliedAmount__c, BankName__c, Expressionofinterest__c, GeneratePaymentGatewayURLCallCount__c, 
                            Modeofpayment__c, PaymentGatewayURL__c, PaymentStatus__c,
                            ReceiptDate__c, RemainingAmount__c, Status__c, TotalAmount__c, TransactionNumber__c, 
                            ReSendPaymentURLRequest__c,
                            PaymentEscrowAccount__c, EOIEscrowAccount__c, PaymentEscrowAccount__r.StoreId__c, EOIEscrowAccount__r.StoreId__c
                            from Receipt__c where Id =: recordID];
                
                if(receipt <> null){

                    if(receipt.TotalAmount__c <= 0){
                        str = 'Total Amount should be Greater than 0.'; // To Do: Need to move the error message to custom metadata or label.
                    }
                    else if(receipt.PaymentGatewayURL__c <> null && (receipt.PaymentStatus__c <> null && receipt.PaymentStatus__c <> 'WAITING')){
                        str = 'Payment Gateway URL is already generated and the payment link has been accessed. If you wish to generate the payment link again, please create a new receipt and proceed with the new receipt.';
                    }
                    else if(receipt.PaymentGatewayURL__c <> null && receipt.ReSendPaymentURLRequest__c == false){
                        str = 'Payment Gateway URL is already generated for this record. If you want to re-generate the payment link, please check the checkbox "Re-Send Payment URL Request" and click on the "Fetch Payment Link" button again.'; // To Do: Need to move the error message to custom metadata or label.
                    }
                    else{
                        // Form request body, Send Request and Parse Response.
                        string reqBody = null;
                        reqBody = getRequestBodyForPaymentURL(recordID);

                        if(reqBody <> null){
                            PaymentLinkResponseWrapper paymentRespWrap = new PaymentLinkResponseWrapper();
                            PaymentLinkResponseWrapper deletepaymentRespWrap = new PaymentLinkResponseWrapper();

                            if(receipt.PaymentGatewayURL__c <> null && receipt.ReSendPaymentURLRequest__c == true)
                            deletepaymentRespWrap = deletePaymentURL(recordID);

                            paymentRespWrap = postRequestBodyForPaymentURL (reqBody, recordID);

                            if(paymentRespWrap <> null && paymentRespWrap.orderId <> null && paymentRespWrap.orderId <> ''){
                                Receipt__c receiptToUpdate = new Receipt__c();

                                if(paymentRespWrap.orderId.contains('_'))
                                receiptToUpdate.Id = paymentRespWrap.orderId.substringBefore('_');
                                else 
                                receiptToUpdate.Id = paymentRespWrap.orderId;
                                
                                receiptToUpdate.PaymentGatewayURL__c = paymentRespWrap.paymentUrl;

                                if(receipt.GeneratePaymentGatewayURLCallCount__c <> null && receipt.GeneratePaymentGatewayURLCallCount__c <> 0)
                                receiptToUpdate.GeneratePaymentGatewayURLCallCount__c = receipt.GeneratePaymentGatewayURLCallCount__c + 1;
                                else 
                                receiptToUpdate.GeneratePaymentGatewayURLCallCount__c = 1;

                                receiptToUpdate.ReSendPaymentURLRequest__c = false;

                                update receiptToUpdate;
                            }

                        }

                    }
                
                }
            }

            return str;
        }

        catch(Exception e) {        
            LoggerService.save(LoggerService.createApexLog(e,'PaymentGatewayUtility','PaymentGatewayUtility.parsePaymentGatewayURLResponse',''));
            str = e.getMessage();
            return str;
        }   

    }

    @AuraEnabled
    public static PaymentLinkResponseWrapper deletePaymentURL (string recordID){

        PaymentLinkResponseWrapper deletePaymentResp = new PaymentLinkResponseWrapper();
        if(recordID <> null && recordID <> ''){

            Organization this_org = [Select Id, Name, IsSandbox from Organization];
            
            Payment_Gateway__mdt pg_metadata = new Payment_Gateway__mdt();
            
            if(this_org.IsSandbox){
                pg_metadata = Payment_Gateway__mdt.getInstance('Payment_Gateway_Sandbox');
            }
            else{
                pg_metadata = Payment_Gateway__mdt.getInstance('Payment_Gateway');
            }
            
            if(pg_metadata <> null){
                
                Receipt__c receipt = [select Id, Account__c, AppliedAmount__c, BankName__c, Expressionofinterest__c, GeneratePaymentGatewayURLCallCount__c, 
                            Modeofpayment__c, PaymentGatewayURL__c,
                            ReceiptDate__c, RemainingAmount__c, Status__c, TotalAmount__c, TransactionNumber__c, 
                            ReSendPaymentURLRequest__c, PaymentEscrowAccount__c, EOIEscrowAccount__c, PaymentEscrowAccount__r.StoreId__c, EOIEscrowAccount__r.StoreId__c
                            from Receipt__c where Id =: recordID];
                
                string storeId = null;
                if(receipt.PaymentEscrowAccount__c <> null && receipt.PaymentEscrowAccount__r.StoreId__c <> null){
                    storeId = receipt.PaymentEscrowAccount__r.StoreId__c;
                }
                else if(receipt.EOIEscrowAccount__r <> null && receipt.EOIEscrowAccount__r.StoreId__c <> null){
                    storeId = receipt.EOIEscrowAccount__r.StoreId__c;
                }

                Store_ID_and_API_Key_Mapping__mdt storeID_KeyMapping = new Store_ID_and_API_Key_Mapping__mdt();
                if(storeId <> null){
                    if(this_org.IsSandbox)
                    storeID_KeyMapping = Store_ID_and_API_Key_Mapping__mdt.getInstance('sandbox_' + storeId);
                    else 
                    storeID_KeyMapping = Store_ID_and_API_Key_Mapping__mdt.getInstance('X' + storeId);
                    
                }

                if(receipt.PaymentGatewayURL__c <> null && receipt.PaymentGatewayURL__c <> ''){

                    string clientRequestID = null;
                    integer pgCount = null;

                    if(receipt.GeneratePaymentGatewayURLCallCount__c <> null)
                    pgCount = integer.ValueOf(receipt.GeneratePaymentGatewayURLCallCount__c) - 1; // for delete, we have to discount one count as the count will be increnented after URL is fetched..

                    if(pgCount <> null && pgCount <> 0){
                        clientRequestID = recordID + '_' + pgCount;
                    }
                    else 
                    clientRequestID = recordID;

                    Datetime dt = Datetime.now();
                    Long longDateTimeInstance = dt.getTime();
    
                    Http http = new Http();
                    HttpRequest request = new HttpRequest();
                    
                    string payURLID = receipt.PaymentGatewayURL__c.subStringAfterLast('=');

                    
                    string deletePG_EndPointURL = pg_metadata.Delete_Payment_Gateway_URL_End_Point_URL__c;
                    deletePG_EndPointURL= deletePG_EndPointURL + '?orderId=' + clientRequestID + '&paymentUrlId=' + payURLID;

                    request.setEndpoint(deletePG_EndPointURL);
                    request.setMethod('DELETE');
                    request.setHeader('Content-Type', 'application/json');
                    request.setHeader('Api-Key', storeID_KeyMapping.API_Key__c);
                    request.setHeader('Client-Request-Id', clientRequestID);
                    
                    Blob mac = Crypto.generateMac('hmacSHA256', blob.valueOf(storeID_KeyMapping.API_Key__c + clientRequestID + String.ValueOf(longDateTimeInstance) ),blob.valueOf(storeID_KeyMapping.Secret_Key__c));
                    String signature = EncodingUtil.base64Encode(mac);
                    request.setHeader('Message-Signature', signature);
                    request.setHeader('Timestamp', String.ValueOf(longDateTimeInstance));
                    
                    system.debug('DELETE URL TIMESTAMP:::: ' + String.ValueOf(longDateTimeInstance));
                    system.debug('DELETE URL SIGNATURE:::: ' + signature);

                    HttpResponse response = http.send(request);
                    // If the request is successful, parse the JSON response.
                    system.debug('DELETE URL STATUS CODE:::: ' + response.getStatusCode());
                    System.debug('DELETE URL RESPONSE BODY:::: ' + response.getBody());
                    
                    if(response.getBody() <> null && response.getBody() <> ''){
                        deletePaymentResp = (PaymentLinkResponseWrapper) System.JSON.deserialize(response.getBody(), PaymentLinkResponseWrapper.class);
                    }

                }

            }

        }

        return deletePaymentResp;
    }

    @AuraEnabled
    public static string retrievePaymentStatus (string recordID){

        string str = 'Success';

        try{
            RetrievePaymentStatusResponseWrapper retrievePaymentStatusResponseWrap = new RetrievePaymentStatusResponseWrapper();
            if(recordID <> null && recordID <> ''){

                Organization this_org = [Select Id, Name, IsSandbox from Organization];
                
                Payment_Gateway__mdt pg_metadata = new Payment_Gateway__mdt();
                
                if(this_org.IsSandbox){
                    pg_metadata = Payment_Gateway__mdt.getInstance('Payment_Gateway_Sandbox');
                }
                else{
                    pg_metadata = Payment_Gateway__mdt.getInstance('Payment_Gateway');
                }
                
                if(pg_metadata <> null){
                    
                    Receipt__c receipt = [select Id, Account__c, AppliedAmount__c, BankName__c, Expressionofinterest__c, GeneratePaymentGatewayURLCallCount__c, 
                                Modeofpayment__c, PaymentGatewayURL__c,
                                ReceiptDate__c, RemainingAmount__c, Status__c, TotalAmount__c, TransactionNumber__c, 
                                ReSendPaymentURLRequest__c, PaymentEscrowAccount__c, EOIEscrowAccount__c, PaymentEscrowAccount__r.StoreId__c, EOIEscrowAccount__r.StoreId__c
                                from Receipt__c where Id =: recordID];
                    
                    string storeId = null;
                    if(receipt.PaymentEscrowAccount__c <> null && receipt.PaymentEscrowAccount__r.StoreId__c <> null){
                        storeId = receipt.PaymentEscrowAccount__r.StoreId__c;
                    }
                    else if(receipt.EOIEscrowAccount__r <> null && receipt.EOIEscrowAccount__r.StoreId__c <> null){
                        storeId = receipt.EOIEscrowAccount__r.StoreId__c;
                    }
    
                    Store_ID_and_API_Key_Mapping__mdt storeID_KeyMapping = new Store_ID_and_API_Key_Mapping__mdt();
                    if(storeId <> null){
                        if(this_org.IsSandbox)
                        storeID_KeyMapping = Store_ID_and_API_Key_Mapping__mdt.getInstance('sandbox_' + storeId);
                        else 
                        storeID_KeyMapping = Store_ID_and_API_Key_Mapping__mdt.getInstance('X' + storeId);
                    }

                                
                    if(receipt.PaymentGatewayURL__c <> null && receipt.PaymentGatewayURL__c <> ''){

                        string clientRequestID = null;
                        integer pgCount = null;

                        if(receipt.GeneratePaymentGatewayURLCallCount__c <> null)
                        pgCount = integer.ValueOf(receipt.GeneratePaymentGatewayURLCallCount__c) - 1; // for retrieve, we have to discount one count as the count will be increnented after URL is fetched..

                        if(pgCount <> null && pgCount <> 0){
                            clientRequestID = recordID + '_' + pgCount;
                        }
                        else 
                        clientRequestID = recordID;

                        Datetime dt = Datetime.now();
                        Long longDateTimeInstance = dt.getTime();
        
                        Http http = new Http();
                        HttpRequest request = new HttpRequest();
                        
                        string payURLID = receipt.PaymentGatewayURL__c.subStringAfter('paymentUrlId=');


                        string retrievePG_EndPointURL = pg_metadata.Retrieve_Payment_Status_End_Point_URL__c;
                        retrievePG_EndPointURL= retrievePG_EndPointURL + '/' + clientRequestID;

                        request.setEndpoint(retrievePG_EndPointURL);
                        request.setMethod('GET');
                        request.setHeader('Content-Type', 'application/json');
                        request.setHeader('Api-Key', storeID_KeyMapping.API_Key__c);
                        request.setHeader('Client-Request-Id', clientRequestID);
                        
                        Blob mac = Crypto.generateMac('hmacSHA256', blob.valueOf(storeID_KeyMapping.API_Key__c + clientRequestID + String.ValueOf(longDateTimeInstance) ),blob.valueOf(storeID_KeyMapping.Secret_Key__c));
                        String signature = EncodingUtil.base64Encode(mac);
                        request.setHeader('Message-Signature', signature);
                        request.setHeader('Timestamp', String.ValueOf(longDateTimeInstance));
                            
                        HttpResponse response = http.send(request);
                        // If the request is successful, parse the JSON response.
                        system.debug('RETRIEVE PAYMENT STATUS STATUS CODE:::: ' + response.getStatusCode());
                        System.debug('RETRIEVE PAYMENT STATUS RESPONSE BODY:::: ' + response.getBody());
                        
                        if(response.getBody() <> null && response.getBody() <> ''){
                        
                            retrievePaymentStatusResponseWrap = (RetrievePaymentStatusResponseWrapper) System.JSON.deserialize(response.getBody(), RetrievePaymentStatusResponseWrapper.class);
                            if(retrievePaymentStatusResponseWrap <> null){

                                Receipt__c rcpt = new Receipt__c();
                                for(RetrievePaymentStatusResponseWrapper.cls_transaction trans: retrievePaymentStatusResponseWrap.transactions){ // only one record will be there in this array in our use case.
                                    rcpt.Id = recordID;
                                    rcpt.PaymentStatus__c = trans.transactionResult;
                                    rcpt.RetrievePaymentStatusRawResponse__c = response.getBody();
                                }

                                update rcpt;                               

                            }
                        }

                    }

                }

            }

        }
        catch(Exception e) {        
            LoggerService.save(LoggerService.createApexLog(e,'PaymentGatewayUtility','PaymentGatewayUtility.retrievePaymentStatus',''));
            str = e.getMessage() + 'Trace:: ' + e.getStackTraceString();
            system.debug('Error:: ' + str);
           
        } 

        return str;
    }

}