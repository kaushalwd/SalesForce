/**********************************************************************************************************************
* Name               : SPAWhatsappJOQueueable                                                        
* Description        : This class is used for SPAWhatsapp
* Usage              : Called from SPAWhatsappTriggerHelper
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         				05-10-2025      Initial Draft
* 2.0           Dinesh                      28 Dec 2025     To Align With new SO Journey 
******************************************************************************************************************/
public class SPAWhatsappJOQueueable implements Queueable {
    Set<Id> set_SPAWhatsappId = new Set<Id>();
    public SPAWhatsappJOQueueable(Set<Id> set_SPAWhatsappId){
        this.set_SPAWhatsappId = set_SPAWhatsappId;
    }
    public void execute(QueueableContext context) {
           SPAWhatsappJOQueueable.sendSPAOICCallout(set_SPAWhatsappId);   
    }

    @future(callout=true)
    public static void sendSPAOICCallout(Set<Id> set_SPAWhatsappId){
        try{
            if(set_SPAWhatsappId.size() > 0){
                Set<String> set_SOId = new Set<String>();
                Set<String> set_EnvId = new Set<String>();
                
                List<SPAWhatsapp__c> lst_QuerySPAWhatsapp = new List<SPAWhatsapp__c>();
                Map<String, SalesOrder__c> map_SO= new Map<String, SalesOrder__c>();
                Map<String, dfsle__EnvelopeStatus__c> map_EvelopeStatus = new Map<String, dfsle__EnvelopeStatus__c>();
                List<dfsle__EnvelopeStatus__c> lst_UpdateEnvStatus = new List<dfsle__EnvelopeStatus__c>();
                List<SalesOrder__c> lst_UpdateSO = new List<SalesOrder__c>();
                
                lst_QuerySPAWhatsapp = [SELECT Id, Name, EnvelopeId__c, Sales_Order__c, Sales_Order__r.CustomerAccount__r.PersonMobilePhone, 
                                               Sales_Order__r.CustomerAccount__r.Name, DocuSignURL__c, APICallStatus__c, WhatsappURL__c,
                                               WhatsappMessageId__c, Sales_Order__r.LastModifiedBy.Name, Sales_Order__r.LastModifiedBy.Email,
                                               AccountType__c, Customer_Account__c, FileUploaded__c  
                                               from SPAWhatsapp__c where Id IN :set_SPAWhatsappId];
                
                for(SPAWhatsapp__c obj_SPAWhatsapp : lst_QuerySPAWhatsapp){
                    if(obj_SPAWhatsapp.Sales_Order__c != null){
                        set_SOId.add(obj_SPAWhatsapp.Sales_Order__c); 
                        set_EnvId.add(obj_SPAWhatsapp.EnvelopeId__c);
                    }                    
                }
                System.debug('>>>>>>>>>> set_SOId >>>>  '+System.JSON.serialize(set_SOId));
                System.debug('>>>>>>>>>> set_EnvId >>>>  '+System.JSON.serialize(set_EnvId));
                
                List<dfsle__EnvelopeStatus__c> lst_EnvStatus = [select dfsle__SourceId__c, dfsle__Status__c, dfsle__Completed__c 
                                                                from dfsle__EnvelopeStatus__c 
                                                  		     	where dfsle__Status__c = 'sent' and dfsle__DocuSignId__c IN :set_EnvId];
                List<SalesOrder__c> lst_SalesOrder = [SELECT Id, CustomerAccount__c, Owner.Name, Owner.Email, Status__c, JO1__c, JO1__r.Name, 
                                                      JO1__r.Email,  JO2__c, JO2__r.Name, JO2__r.Email, JO3__c, JO3__r.Name, JO3__r.Email, 
                                                      JO4__c, JO4__r.Name, JO4__r.Email, JO5__c, JO5__r.Name, JO5__r.Email, 
                                                      JO6__c, JO6__r.Name, JO6__r.Email from SalesOrder__c 
                                         			  WHERE Id IN :set_SOId];
                for(SalesOrder__c obj_SOLoop : lst_SalesOrder){
                    if(!map_SO.containsKey(obj_SOLoop.Id)){
                        map_SO.put(obj_SOLoop.Id, obj_SOLoop);
                    }
                }
                
                for(dfsle__EnvelopeStatus__c obj_Env : lst_EnvStatus){
                    if(!map_EvelopeStatus.containsKey(obj_Env.dfsle__SourceId__c)){
                        map_EvelopeStatus.put(obj_Env.dfsle__SourceId__c, obj_Env);
                    }
                }
                
                for(SPAWhatsapp__c obj_SPAWhatsapp : lst_QuerySPAWhatsapp){
                    if(obj_SPAWhatsapp.EnvelopeId__c != ''){
                        SalesOrder__c obj_ExistingSO = map_SO.containsKey(obj_SPAWhatsapp.Sales_Order__c)?map_SO.get(obj_SPAWhatsapp.Sales_Order__c):null;
                   		dfsle__EnvelopeStatus__c obj_EnvStatus = map_EvelopeStatus.containsKey(obj_SPAWhatsapp.Sales_Order__c)?map_EvelopeStatus.get(obj_SPAWhatsapp.Sales_Order__c):null;
                            
                        if(!String.isBlank(obj_ExistingSO.JO1__c) && String.isBlank(obj_SPAWhatsapp.AccountType__c)){
                            String status = OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(obj_ExistingSO.Id, 'JO1');
                            System.debug('>>>>>>>>> JO1  >>>> Initiated');
                        } else if(obj_ExistingSO != null && !String.isBlank(obj_SPAWhatsapp.AccountType__c)){
                               if(obj_SPAWhatsapp.AccountType__c == 'JO1' && !String.isBlank(obj_ExistingSO.JO2__c)){
                                 String status = OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(obj_ExistingSO.Id, 'JO2');
                           		 System.debug('>>>>>>>>> JO2  >>>> Initiated');
                               } else if(obj_SPAWhatsapp.AccountType__c == 'JO2' && !String.isBlank(obj_ExistingSO.JO3__c)){
                                 String status = OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(obj_ExistingSO.Id, 'JO3');
                           		 System.debug('>>>>>>>>> JO3  >>>> Initiated'); 
                               } else if(obj_SPAWhatsapp.AccountType__c == 'JO3' && !String.isBlank(obj_ExistingSO.JO4__c)){
                                  String status = OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(obj_ExistingSO.Id, 'JO4');
                           		  System.debug('>>>>>>>>> JO4  >>>> Initiated');
                               } else if(obj_SPAWhatsapp.AccountType__c == 'JO4' && !String.isBlank(obj_ExistingSO.JO5__c)){
                                  String status = OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(obj_ExistingSO.Id, 'JO5');
                           		  System.debug('>>>>>>>>> JO5  >>>> Initiated'); 
                               } else if(obj_SPAWhatsapp.AccountType__c == 'JO5' && !String.isBlank(obj_ExistingSO.JO6__c)){
                                  String status = OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(obj_ExistingSO.Id, 'JO6');
                           		  System.debug('>>>>>>>>> JO6  >>>> Initiated'); 
                               } else {
                                  // obj_ExistingSO.Status__c = 'SPA Signed (Customer)';  /** 2.0 To Align With new SO Journey **/
                                   obj_ExistingSO.SPAStatus__c = 'Pending for Validation';
                                   lst_UpdateSO.add(obj_ExistingSO);
                               }
                        } else {
                            //obj_ExistingSO.Status__c = 'SPA Signed (Customer)'; /** 2.0 To Align With new SO Journey **/
                            obj_ExistingSO.SPAStatus__c = 'Pending for Validation';
                            lst_UpdateSO.add(obj_ExistingSO);
                        }	
                        obj_EnvStatus.dfsle__Status__c = 'Completed';
           			    obj_EnvStatus.dfsle__Completed__c = System.now();
                        lst_UpdateEnvStatus.add(obj_EnvStatus);   
                     }
                }
                if(lst_UpdateSO.size() > 0){
                    update lst_UpdateSO;
                }
                if(lst_UpdateEnvStatus.size() > 0){
                    update lst_UpdateEnvStatus;
                }
           }      
        } catch(Exception exe){}  
    }  
}