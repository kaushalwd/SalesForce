/**********************************************************************************************************************
* Name               : PrintChequeController                                                        
* Description        : This class is used to handle PrintCheque
* Usage              : Called from LWC
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                      19 Feb 2025     Initial Draft 
* 2.0           Suresh                      13 Oct 2025     UI changes
* 2.1           Suresh                      14 Oct 2025     Content Type changed
* 2.2           Prateek                     03 Jun 2026      Content Type changed
******************************************************************************************************************/
public without sharing class PrintChequeController {

    @AuraEnabled
    public static String printChequeStatus(String salesOrderId) {
        try{
            System.debug('>>>>>>>>>>>>> PrintChequeController >>>>  '+salesOrderId);
            List<SalesOrderInstallments__c> lst_SOI = [SELECT Id, Name, SalesOrder__r.Name, SalesOrder__r.VirtualAccount__r.EscrowAccount__r.Name, MilestoneDate__c, SalesOrder__r.ProjectName__c,
                                                        InstallmentAmount__c, SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BankName__c, SalesOrder__r.VirtualAccount__r.EscrowAccountNameText__c 
                                                        from SalesOrderInstallments__c where SalesOrder__c  = :salesOrderId];
            List<PrintChequeRequest> lst_PrintChequeRequest = new List<PrintChequeRequest>();
            for(SalesOrderInstallments__c obj_SOI : lst_SOI){
                PrintChequeRequest obj_PrintChequeRequest = new PrintChequeRequest();
                obj_PrintChequeRequest.date_str = String.valueOf(obj_SOI.MilestoneDate__c);
                if(String.isNotBlank(obj_SOI.SalesOrder__r.ProjectName__c) && obj_SOI.SalesOrder__r.ProjectName__c == 'Hudayriyat Golf Estates'){//v2.2
                    obj_PrintChequeRequest.beneficiaryName = obj_SOI.SalesOrder__r.VirtualAccount__r.EscrowAccountNameText__c;//v2.2
                }else{
                	obj_PrintChequeRequest.beneficiaryName = obj_SOI.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.Name;    
                }
                
                obj_PrintChequeRequest.amount = obj_SOI.InstallmentAmount__c;
                obj_PrintChequeRequest.chequeNumber = '';
                obj_PrintChequeRequest.referenceNo = obj_SOI.SalesOrder__r.Name;
                obj_PrintChequeRequest.installmentId = obj_SOI.Name;
                obj_PrintChequeRequest.bank = obj_SOI.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BankName__c;
                lst_PrintChequeRequest.add(obj_PrintChequeRequest);
            }
            Modon_Generic_Metadata__mdt CONFIG = Modon_Generic_Metadata__mdt.getInstance('PrintChequeController');
			    HttpRequest req = new HttpRequest();
                req.setTimeout(120000);
                req.setHeader('Accept', 'application/json');
            	req.setHeader('Content-Type', 'application/json');
                req.setHeader('x-api-key', CONFIG?.Api_Key__c);
                req.setEndpoint(CONFIG?.Endpoint__c);
        		req.setMethod('POST');
                String requestMessage = JSON.serialize(lst_PrintChequeRequest);
                requestMessage = requestMessage.replace('date_str','date');
                req.setBody(requestMessage);
                system.debug('>>>>> obj_PrintChequeRequest >> ' + requestMessage);
                Http http = new Http();
                HTTPResponse res = http.send(req);
                System.debug(res.getBody());            
            
        } catch(Exception exe){
            return 'Failure';
        }
        return 'Success';
    } 
    
    public class PrintChequeRequest{
        public String date_str;
        public String beneficiaryName;
        public Decimal amount;
        public String chequeNumber;
        public String referenceNo;
        public String installmentId;
        public String bank;
    }
}