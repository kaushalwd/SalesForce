/**********************************************************************************************************************
* Name               : DocuSignRecipientStatusTriggerHelper                                                        
* Description        : This class is used as a handle envelope status
* Created By         : ActiveMinds                                                
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           ChangeMeIn@UserSettingsUnder.SFDoc	01-08-2025     Initial Draft 
* 2.0           Suresh                              02 Apr2026     Updated SalesOrder Status.
******************************************************************************************************************/

public class DocuSignRecipientStatusTriggerHelper { 

//Function to udpated sales order SPA Status whether the SPA is pending from Modon or the Customer    
    public static void updateDocuSginRecipientStatus( list<SObject> listSobject,  map<ID,SObject> RecipientStatusMap){
        SalesOrder__c salesOrderObj = new SalesOrder__c();
        Set<Id> spaStsstepCloseId = new Set<Id>();
        Set<Id> spaSignedCustomerStsstepCloseId = new Set<Id>();
        Set<Id> spaSignedMODONStsstepCloseId = new Set<Id>();
        try{
            Set<Id> envelopeStatusIds = new Set<Id>();
            for(dfsle__RecipientStatus__c tempRecipientStatusObj : (List<dfsle__RecipientStatus__c>)RecipientStatusMap.values() ){
                envelopeStatusIds.add(tempRecipientStatusObj.dfsle__EnvelopeStatus__c);
            }
            dfsle__EnvelopeStatus__c EnvelopeStatusobj = [SELECT Id,Name,dfsle__SourceId__c,dfsle__Status__c  FROM dfsle__EnvelopeStatus__c WHERE Id IN :envelopeStatusIds LIMIT 1];
            String objectName =Id.valueOf(EnvelopeStatusobj.dfsle__SourceId__c).getSObjectType().getDescribe().getName();
            System.debug('objectName: '+objectName);
            if( objectName.contains('Sales Order') || objectName.contains('SalesOrder__c') ){  
                List <dfsle__RecipientStatus__c> RecipientStatusList = [SELECT Id,dfsle__RoutingOrder__c FROM dfsle__RecipientStatus__c WHERE dfsle__EnvelopeStatus__c = :EnvelopeStatusobj.Id ORDER BY dfsle__RoutingOrder__c DESC LIMIT 1];
                for(dfsle__RecipientStatus__c tempRecipientStatusObj : (List<dfsle__RecipientStatus__c>)RecipientStatusMap.values() ){
                    salesOrderObj.Id=EnvelopeStatusobj.dfsle__SourceId__c;
                    if( RecipientStatusList[0].dfsle__RoutingOrder__c == tempRecipientStatusObj.dfsle__RoutingOrder__c && tempRecipientStatusObj.dfsle__RoutingOrder__c == 9 && EnvelopeStatusobj.dfsle__Status__c != 'Voided' ){
                        //completd
                        if(tempRecipientStatusObj.dfsle__Status__c == 'Completed'){
                            salesOrderObj.SPAStatus__c = 'SPA Signed (Modon)';
                            salesOrderObj.Status__c = 'Completed';
                            salesOrderObj.Sub_Status__c = 'Completed';
                            salesOrderObj.SPACounterSignedDate__c = DATE.TODAY(); //Added CounterSigned Date
                            spaSignedMODONStsstepCloseId.add(salesOrderObj.Id);
                        }else if(tempRecipientStatusObj.dfsle__Status__c == 'sent' &&  tempRecipientStatusObj.dfsle__RoutingOrder__c != 9 && EnvelopeStatusobj.dfsle__Status__c != 'Voided'){
                            //pending by Modon
                            salesOrderObj.SPAStatus__c = 'Pending with Modon';
                            //salesOrderObj.Status__c = 'SPA Validated';
                        }
                    }else if(tempRecipientStatusObj.dfsle__Status__c == 'Sent' &&  RecipientStatusList[0].dfsle__RoutingOrder__c != tempRecipientStatusObj.dfsle__RoutingOrder__c && EnvelopeStatusobj.dfsle__Status__c != 'Voided'){
                        //pending by Customer
                            if(tempRecipientStatusObj.Name == 'SPA Validation Team' || tempRecipientStatusObj.Name == 'SPA Validation Team Reem Hills'
                                || tempRecipientStatusObj.dfsle__RoutingOrder__c == 8){
                                salesOrderObj.SPAStatus__c = 'Pending for Validation';
                                //salesOrderObj.Status__c = 'SPA Signed (Customer)';
                                salesOrderObj.SPACustomerSignedDate__c = DATE.TODAY(); //Added Customer Signed Date
                                spaSignedCustomerStsstepCloseId.add(salesOrderObj.Id);
                            }else{
                                //Updated the status - 2.0
                                if(RecipientStatusList[0].dfsle__RoutingOrder__c == 9 && EnvelopeStatusobj.dfsle__Status__c != 'Voided'){
                                    salesOrderObj.SPAStatus__c = 'Pending with Modon';
                                } else {
                                    salesOrderObj.SPAStatus__c = 'Pending with Customer';
                                    salesOrderObj.SPA_Send_Date_for_Signature__c = System.today();
                                    spaStsstepCloseId.add(salesOrderObj.Id);
                                    //salesOrderObj.Status__c = 'SPA Sent to customer';   
                                }                                
                            }
                        
                    }
                }
            }
            
            if(!spaStsstepCloseId.isEmpty()){
                SalesOrderStatusAutomationHelper.closingTheStatus(spaStsstepCloseId,new List<String>{'SPA In-Progress'});
            }
            if(!spaSignedCustomerStsstepCloseId.isEmpty()){
                SalesOrderStatusAutomationHelper.closingTheStatus(spaSignedCustomerStsstepCloseId,new List<String>{'Signed SPA (Customer)', 'SPA Generated & Signed (Customer)'}); 
               // SalesOrderStatusAutomationHelper.closingTheStatus(spaSignedCustomerStsstepCloseId,'SPA Generated & Signed (Customer)');
            }
            if(!spaSignedMODONStsstepCloseId.isEmpty()){
                SalesOrderStatusAutomationHelper.closingTheStatus(spaSignedMODONStsstepCloseId,new List<String>{'Signed SPA (Modon)'}); 
            }
        }
        catch(QueryException e){
            system.debug('An error has occurred.');
        }try{
            if (salesOrderObj != null && salesOrderObj.Id != null) {
                SalesOrder__c salesOrderObject = [SELECT Id, SPAStatus__c FROM SalesOrder__c WHERE Id = :salesOrderObj.Id];
                if (salesOrderObject.SPAStatus__c != salesOrderObj.SPAStatus__c) {
                    System.debug('salesOrderObjbefore ===>> ' + salesOrderObj.Status__c);
                    update salesOrderObj;
                    System.debug('salesOrderObj ===>> ' + salesOrderObj);
                    System.debug('salesOrderObjaftersave ===>> ' + salesOrderObj.Status__c);
                }
            } else {
                System.debug('salesOrderObj is null, cannot perform update.');
            }     
        }catch(DMLException e){
            system.debug('An error has occurred.' +e.getMessage());
            
        }
    }
}