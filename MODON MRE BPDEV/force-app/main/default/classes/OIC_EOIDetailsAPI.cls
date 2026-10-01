/**********************************************************************************************************************
* Name               : OIC_EOIDetailsAPI                                                        
* Description        : This class is used to fetch the EOI details based on name.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL
***********************************************************************************************************************/
@RestResource(urlMapping='/EOIDetailsAPI/*')
global with sharing class OIC_EOIDetailsAPI {

    @HttpGet
    global static void findEOIDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            String eoiName = req.params.get('EOIName');
            if (String.isBlank(eoiName)) {
                returnErrorAPI.returnError(res, requestId, 'Missing EOI Name parameter', 200);
                return;
            } 
            System.debug('>>>>>>>>>>>>>>>>>>>>> EOI Name >>>> '+eoiName);
            List<EOIDetails> lst_EOIDetails = new List<EOIDetails>();
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Expressionofinterest__c query
            List<Expressionofinterest__c> lst_EOI = [SELECT Id, Name, Opportunity__c, Project__c, Phase__c, UnitType__c, 
                                                         NumberofBedrooms__c, UnitTypologyMRE__c, Number_of_Units__c, EOI_Range__c, 
                                                         EOI_Amount_AED__c, EOIComments__c, Account__c, Contact__c,
                                                         Phase__r.EscrowAccount__r.Current_Acc_Merchant_ID__c, Contact__r.Name, Contact__r.Email, 
                                                         Contact__r.MobilePhone, Phase__r.Project__r.Name, Phase__r.Name, Status__c, EOIId__c,
                                                         EOI_Balance__c, TotalPaidAmount__c, Phase__r.EscrowAccount__r.AccountNumber__c,
                                                         Total_Authorize_Amount__c
                                                         from Expressionofinterest__c where Source_Entity__c != 'Modon - Egypt' 
                                                         and Opportunity__r.StageName != 'Closed Lost' and Account__c != null 
                                                         and EOIId__c = :eoiName and Status__c NOT IN ('Voided', 'Rejected', 'Cancelled')
                                                         WITH USER_MODE
                                                         order by createddate desc];
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on CreditCardToken__c query
            List<CreditCardToken__c> lst_CCToken = [SELECT Id, Account__c, Amount__c, Approved__c, Authcode__c, Card_Category__c, Card_Type__c, 
                                  					CurrencyIsoCode, ExpiresOn__c, Expression_of_Interest__c, Issuer__c, Issuer_Country__c, 
                                 					Last4CardNumber__c, Opportunity__c, Processed_On__c, Reference__c, Response_Code__c, 
                                                    Response_Summary__c, SourceSystem__c, Status__c, TokenId__c,  Transaction_Id__c,
                                                    Card_Source_Id__c
                                                    from CreditCardToken__c where Status__c = 'Authorized' and Approved__c = true
                                                    and Expression_of_Interest__r.EOIId__c = :eoiName
                                                    WITH USER_MODE];
            
            for(Expressionofinterest__c obj_EOI : lst_EOI){
                EOIDetails obj_EOIDetails = new EOIDetails();
                obj_EOIDetails.EOIName = obj_EOI.EOIId__c;
                obj_EOIDetails.EOIId = obj_EOI.Id;
                obj_EOIDetails.CustomerName = obj_EOI.Contact__r.Name;
                obj_EOIDetails.CustomerEmail = obj_EOI.Contact__r.Email;
                obj_EOIDetails.CustomerMobile = obj_EOI.Contact__r.MobilePhone;
                obj_EOIDetails.OpportunityId = obj_EOI.Opportunity__c;
                obj_EOIDetails.AccountId = obj_EOI.Account__c;
                obj_EOIDetails.ContactId = obj_EOI.Contact__c;
                obj_EOIDetails.EOIStatus = obj_EOI.Status__c;
                obj_EOIDetails.MerchantID = obj_EOI.Phase__r?.EscrowAccount__r?.Current_Acc_Merchant_ID__c;
                obj_EOIDetails.EscrowAccountNumber = obj_EOI.Phase__r?.EscrowAccount__r?.AccountNumber__c;
                obj_EOIDetails.ProjectName = obj_EOI.Phase__r?.Project__r?.Name;
                obj_EOIDetails.PhaseName = obj_EOI.Phase__r?.Name;
                obj_EOIDetails.PhaseId = obj_EOI.Phase__c;
                obj_EOIDetails.EOIAmount = obj_EOI.EOI_Amount_AED__c;
                obj_EOIDetails.EOIBalance = obj_EOI.EOI_Balance__c;
                obj_EOIDetails.TotalPaidAmount = obj_EOI.TotalPaidAmount__c;
                obj_EOIDetails.TotalAuthorizedAmount = obj_EOI.Total_Authorize_Amount__c;
                obj_EOIDetails.UnitType = obj_EOI.UnitType__c;
                obj_EOIDetails.NumberofBedrooms = obj_EOI.NumberofBedrooms__c;
                obj_EOIDetails.Number_of_Units = obj_EOI.Number_of_Units__c;
                obj_EOIDetails.EOIComments = obj_EOI.EOIComments__c;
                
                obj_EOIDetails.CreditCardTokens = new List<CreditCardToken>();
                
                for(CreditCardToken__c obj_CC : lst_CCToken){
                    CreditCardToken obj_JSONCC = new CreditCardToken();
                    obj_JSONCC.CreditCardTokenId = obj_CC.Id;    
                    obj_JSONCC.Amount = obj_CC.Amount__c;
                    obj_JSONCC.Approved = obj_CC.Approved__c;
                    obj_JSONCC.Card_Type = obj_CC.Card_Type__c;
                    obj_JSONCC.CurrencyIsoCode = obj_CC.CurrencyIsoCode;
                    obj_JSONCC.ExpiresOn = obj_CC.ExpiresOn__c;
                    obj_JSONCC.Issuer = obj_CC.Issuer__c;
                    obj_JSONCC.Issuer_Country = obj_CC.Issuer_Country__c;
                    obj_JSONCC.Reference = obj_CC.Reference__c;
                    obj_JSONCC.Status = obj_CC.Status__c;
                    obj_JSONCC.CheckoutId = obj_CC.TokenId__c;
                    obj_JSONCC.Last4CardNumber = obj_CC.Last4CardNumber__c;
                    obj_JSONCC.CardSourceId = obj_CC.Card_Source_Id__c;
                    obj_EOIDetails.CreditCardTokens.add(obj_JSONCC);
                }
                lst_EOIDetails.add(obj_EOIDetails);
            }
            
            APIResponse response = new APIResponse('success', requestId, lst_EOIDetails, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
        } catch (Exception ex) { 
            LoggerService.save(LoggerService.createApexLog(ex, 'OIC_EOIDetailsAPI', 'OIC_EOIDetailsAPI', 'findEOIDetails'));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200); 
        }
    }
    
    public class EOIDetails{
        public string EOIName;
        public string EOIId;
        public string CustomerName;
        public string CustomerEmail;
        public string CustomerMobile;
        public string OpportunityId;
        public string AccountId;
        public string ContactId;
        public string EOIStatus;
        public string MerchantID;
        public string ProjectName;
        public string PhaseName;
        public string PhaseId;
        public string UnitType;
        public string NumberofBedrooms;
        public string UnitTypology;
        public string EscrowAccountNumber;
        public Decimal Number_of_Units;
        public Decimal EOIAmount;
        public Decimal EOIBalance;
        public Decimal TotalPaidAmount;
        public Decimal TotalAuthorizedAmount;
        public string EOIComments;
        public List<CreditCardToken> CreditCardTokens;
    }  
    
    public class CreditCardToken {
        public String CreditCardTokenId;
        public Decimal Amount;
        public Boolean Approved;
        public String Card_Type;
        public String CurrencyIsoCode;
        public Datetime ExpiresOn;
        public String Issuer;
        public String Issuer_Country;
        public String Reference;
        public String Status;
        public String CheckoutId;
        public Decimal Last4CardNumber;
        public String CardSourceId;
    }
}