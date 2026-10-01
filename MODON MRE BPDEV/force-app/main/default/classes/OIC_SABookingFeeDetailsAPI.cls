/**********************************************************************************************************************
* Name               : OIC_SABookingFeeDetailsAPI                                                        
* Description        : This class is used to fetch the Booking fee details based on opportunity.
* Usage              : 
* Created By         : MODON                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                11 07 2026      Initial Draft
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL
***********************************************************************************************************************/
@RestResource(urlMapping='/BookingFeeDetailsAPI/*')
global with sharing class OIC_SABookingFeeDetailsAPI {

    @HttpGet
    global static void findBookingFeeDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            
            if (req == null || req.params == null 
                || String.isBlank(req.params.get('OpportunityId')) || String.isBlank(req.params.get('UserEmail'))) {
                returnErrorAPI.returnError(res, requestId, 'Missing Opportunity Id or User email parameter', 200);
                return;
            } 
            String oppId = req.params.get('OpportunityId');
            String userEmail = req.params.get('UserEmail');
            
            System.debug('>>>>>>>>>>>>>>>>>>>>> Opportunity Id >>>> '+oppId);
            List<BookingFeeDetails> lst_BFDetails = new List<BookingFeeDetails>();
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Booking_Fee_Line__c query
            List<Booking_Fee_Line__c> lst_BFLine = [
                SELECT Id, Name, Balance_Amount__c, Comments__c, Opportunity__c, Fee_Status__c, Total_Amount__c, 
                       Total_Paid_Amount__c, Type__c, Unit__c, Opportunity__r.Name, Unit__r.Name, 
                       Opportunity__r.PrimaryContact__r.Name, Opportunity__r.PrimaryContact__r.Email, 
                       Opportunity__r.PrimaryContact__r.MobilePhone, Unit__r.Phase__r.EscrowAccount__r.MerchantID__c, 
                       Unit__r.Phase__r.EscrowAccount__r.Current_Acc_Merchant_ID__c, Unit__r.Phase__r.Project__r.Name, 
                       Unit__r.Phase__r.Name, Unit__r.Type__c, Unit__r.Typology__c, Unit__r.Number_of_Bedrooms__c,
                      (Select Id from Payment_Links__r)
                FROM Booking_Fee_Line__c 
                WHERE Opportunity__r.Source_Entity__c != 'Modon - Egypt' 
                  AND Opportunity__r.StageName != 'Closed Lost' 
                  AND Opportunity__r.AccountId != null
                  AND Opportunity__r.PrimaryContact__c != null 
                  AND Opportunity__r.Id = :oppId
                  AND Fee_Status__c IN ('Generated', 'Partially Paid', 'Paid')
                  AND Opportunity__r.Owner.Email = :userEmail
                WITH USER_MODE
                Limit 50
            ];
            if(lst_BFLine.isEmpty()){
                //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Opportunity query
                List<Opportunity> oppCheckList = [
                    SELECT Id, Owner.Email, Total_Received_Amount__c, Total_Booking_Amount__c 
                    FROM Opportunity 
                    WHERE Id = :oppId
                    WITH USER_MODE
                    LIMIT 1
                ];
                
                if (!oppCheckList.isEmpty() && userEmail != oppCheckList.get(0).Owner.Email) {
                     returnErrorAPI.returnError(res, requestId, 'PG-001', 200);
                     return;
                } else if(!oppCheckList.isEmpty() && userEmail == oppCheckList.get(0).Owner.Email
                         && oppCheckList.get(0).Total_Booking_Amount__c > 0
                         && oppCheckList.get(0).Total_Booking_Amount__c == oppCheckList.get(0).Total_Received_Amount__c){
                    returnErrorAPI.returnError(res, requestId, 'PG-002', 200);
                    return;
                } else {
                     returnErrorAPI.returnError(res, requestId, 'PG-003', 200);
                     return;
                }
            }
            for(Booking_Fee_Line__c obj_BFLine : lst_BFLine){
               lst_BFDetails.add(new BookingFeeDetails(obj_BFLine));
            }
            
            APIResponse response = new APIResponse('success', requestId, lst_BFDetails, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
        } catch (Exception ex) { 
            LoggerService.save(LoggerService.createApexLog(ex, 'OIC_SABookingFeeDetailsAPI', 'OIC_SABookingFeeDetailsAPI', 'findBookingFeeDetails'));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200); 
        }
    }
    
    public class BookingFeeDetails{
        public string PaymentLinkId;
        public string OpportunityId;
        public string OpportunityName;
        public string BookingFeeId;
        public string Status;
        public string Type;
        public string UnitName;
        public string CustomerName;
        public string CustomerEmail;
        public string CustomerMobile;
        public string ProjectName;
        public string PhaseName;
        public string UnitType;
        public string NumberofBedrooms;
        public string UnitTypology;
        public string MerchantId;
        public string CurrentAccMerchantId;
        public Decimal BalanceAmount;
        public Decimal TotalPaidAmount;
        public Decimal TotalAmount;
        
        public BookingFeeDetails(Booking_Fee_Line__c line) {
            this.opportunityId       = line.Opportunity__c;
            this.opportunityName     = line.Opportunity__r?.Name;
            this.bookingFeeId        = line.Id;
            this.status              = line.Fee_Status__c;
            this.type                = line.Type__c;
            this.unitName            = line.Unit__r?.Name;
            this.customerName        = line.Opportunity__r?.PrimaryContact__r?.Name;
            this.customerEmail       = line.Opportunity__r?.PrimaryContact__r?.Email;
            this.customerMobile      = line.Opportunity__r?.PrimaryContact__r?.MobilePhone;
            this.projectName         = line.Unit__r?.Phase__r?.Project__r?.Name;
            this.phaseName           = line.Unit__r?.Phase__r?.Name;
            this.unitType            = line.Unit__r?.Type__c;
            this.numberofBedrooms    = line.Unit__r?.Number_of_Bedrooms__c;
            this.unitTypology        = line.Unit__r?.Typology__c;
            this.merchantId          = line.Unit__r?.Phase__r?.EscrowAccount__r?.MerchantID__c;
            this.currentAccMerchantId = line.Unit__r?.Phase__r?.EscrowAccount__r?.Current_Acc_Merchant_ID__c;
            this.balanceAmount       = line.Balance_Amount__c;
            this.totalPaidAmount     = line.Total_Paid_Amount__c;
            this.totalAmount         = line.Total_Amount__c;
            if (line.Payment_Links__r != null && !line.Payment_Links__r.isEmpty()) {
                this.PaymentLinkId = line.Payment_Links__r[0].Id;
            } else {
                this.PaymentLinkId = null;
            }
        }
    }
}