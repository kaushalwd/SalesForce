/**********************************************************************************************************************
* Name               : sendRequestXIboServiceRequest                                                         
* Created By         : Active Minds Middle East                                                      
* @author            : Raghu Gajjela
* @group             : 
* Created			 : 05 June 2025
* @last modified on  : 03-10-2025
* @last modified by  : Raghu Gajjela
******************************************************************************************************************/
public class sendRequestXIboServiceRequest {
    public static void callSRXIboService(Set<String> recordIds){
        Organization this_org = [Select Id, Name, IsSandbox from Organization];
        String instanceName = this_org.IsSandbox ? '%Sandbox' : 'xeboAPI_SR%'; // checking instance either prod or sandbox
        
        List<sendXiboconfig__mdt> pg_metadataList = new List<sendXiboconfig__mdt>();
        WrapperClass wrapperPrpertyTransfer = new WrapperClass();
        WrapperClass wrapperJoAddition = new WrapperClass();
       // WrapperClass wrapperADM = new WrapperClass();
        WrapperClass wrapperJoTitleDeed = new WrapperClass();
        WrapperClass wrapperPtTitleDeed = new WrapperClass();
        
        WrapperClass wrapperLPCWaiver = new WrapperClass(); // new clouser added on 03-11-25
        WrapperClass wrapperMortgageDischarge = new WrapperClass();
        WrapperClass wrapperMortgageRegistration = new WrapperClass();
        WrapperClass wrapperPaymentPlanSwap = new WrapperClass();
        WrapperClass wrapperPlotHandover = new WrapperClass();
        WrapperClass wrapperRequestPE = new WrapperClass();
        WrapperClass wrapperUnitCancellation = new WrapperClass();
        WrapperClass wrapperUnitConsolidation = new WrapperClass();
        WrapperClass wrapperUnitHandover = new WrapperClass();
        WrapperClass wrapperUnitSwap = new WrapperClass();
        WrapperClass wrapperUnitUpgrade = new WrapperClass();
        WrapperClass wrapperPreUnitCancellation = new WrapperClass();
        WrapperClass wrapperPostUnitCancellation = new WrapperClass();
        
        Map<String, sendXiboconfig__mdt> mapRecTyeMetaData = new Map<String, sendXiboconfig__mdt>();
        List<ServiceRequest__c> srPropertyTransfer = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srJoAddition = new List<ServiceRequest__c>();
       // List<ServiceRequest__c> srADM = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srJoTitleDeed = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srPtTitleDeed = new List<ServiceRequest__c>();
        
        List<ServiceRequest__c> srLPCWaiver = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srMortgageDischarge  = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srMortgageRegistration = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srPaymentPlanSwap = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srPlotHandover = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srRequestPE = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srUnitCancellation = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srUnitHandover = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srUnitConsolidation = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srUnitSwap = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srUnitUpgrade = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srPreUnitCancellation = new List<ServiceRequest__c>();
        List<ServiceRequest__c> srPostUnitCancellation = new List<ServiceRequest__c>();

        
        // Metadata Mster Label format xeboAPI_SR_RecTypeName_<Org Insance>
        pg_metadataList = [SELECT MasterLabel, DeveloperName, ObjectName__c,RecordTypeDevName__c,End_Point_URL__c, API_Key__c,CollectionId__c,
                           ProcessType__c FROM sendXiboconfig__mdt WHERE ObjectName__c = 'ServiceRequest' AND MasterLabel LIKE :instanceName];
        
        system.debug('pg_metadataList=================='+ pg_metadataList);
        for(sendXiboconfig__mdt mData : pg_metadataList){
            mapRecTyeMetaData.put(mData.RecordTypeDevName__c, mData);
        }
        String jsonBody;
        /*this_org.IsSandbox 
? sendXiboconfig__mdt.getInstance('xeboAPI_SR_Sandbox')
: sendXiboconfig__mdt.getInstance('xeboAPI_SR');*/
        
        Set<String> recDevNames = new Set<String>();
        // checking salesorder Entity 
        List<ServiceRequest__c> srList = [SELECT Id, AccountId__c, AccountId__r.IsPersonAccount, UnitId__c,Unit_Name__c,RecordType.Name, RecordType.DeveloperName,
                                          AccountId__r.PersonEmail, AccountId__r.RecordType.Name,AccountId__r.Name,RecordTypeName__c ,SalesOrder__c,SalesOrder__r.Source_Entity__c,
                                          SalesOrder__r.CustomerAccount__r.PersonEmail,SalesOrder__r.PrimaryContact__r.Email
                                          FROM ServiceRequest__c  WHERE Id IN :recordIds and SalesOrder__r.Source_Entity__c != 'Modon - Egypt' ];
        
        WrapperClass wrapper = new WrapperClass();
        Date closedDate = System.today();
        Set<Id> brokerOrgAccountIds = new Set<Id>();
        
        for (ServiceRequest__c sr : srList) {
            recDevNames.add(sr.RecordType.DeveloperName);
            if (sr.AccountId__r != null && 
                (sr.AccountId__r.RecordType.Name == 'Broker Agency' || sr.AccountId__r.RecordType.Name == 'Organization Account')) {
                    brokerOrgAccountIds.add(sr.AccountId__c);
                }
        }
        
        Map<Id, String> brokerOrgContactEmailMap = new Map<Id, String>();
        
        if (!brokerOrgAccountIds.isEmpty()) {
            for (Contact con : [SELECT AccountId, Email FROM Contact WHERE AccountId IN :brokerOrgAccountIds AND Is_Active__c = true ORDER BY Name ASC LIMIT 1]) {
                brokerOrgContactEmailMap.put(con.AccountId, con.Email);
            }
        }
        
        for (ServiceRequest__c sr : srList) {
            String email = null;
            String typeService = null;
            string salesOrder = null;
            
            if (sr.AccountId__r != null) {
                if (sr.AccountId__r.IsPersonAccount) {
                    email = sr.AccountId__r.PersonEmail; 
                } else if (brokerOrgContactEmailMap.containsKey(sr.AccountId__c)) {
                    email = brokerOrgContactEmailMap.get(sr.AccountId__c); 
                }
            }
            
            // Check if  SR Rec Type is Service Request Management - ADM record type
            if (sr.RecordType.Name == 'Property Transfer OffPlan'){typeService = 'Property Transfer OffPlan';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Joint Owner Addition And Deletion'){typeService = 'Joint Owner Addition And Deletion';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Joint Owner Title Deed'){typeService = 'Joint Owner Title Deed';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Property Transfer Title Deed'){typeService = 'Property Transfer Title Deed';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'LPC Waiver'){typeService = 'LPC Waiver';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Mortgage Discharge'){typeService = 'Mortgage Discharge';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Mortgage Registration'){typeService = 'Mortgage Registration';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Payment plan Swap'){typeService = 'Payment plan Swap';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Plot Handover'){typeService = 'Plot Handover';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Request Payment Extension'){typeService = 'Request Payment Extension';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Unit Cancellation'){typeService = 'Unit Cancellation';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Unit Consolidation'){typeService = 'Unit Consolidation';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Unit Handover'){typeService = 'Unit Handover';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Unit Swap'){typeService = 'Unit Swap';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Unit Upgrade'){typeService = 'Unit Upgrade';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Pre unit Cancellation'){typeService = 'Pre unit Cancellation';salesOrder = sr.SalesOrder__c;}
            else if(sr.RecordType.Name == 'Post unit Cancellation'){typeService = 'Pre unit Cancellation';salesOrder = sr.SalesOrder__c;}

           // else if (sr.RecordType.Name == 'ADM Registration') {typeService = 'ADM';salesOrder = sr.SalesOrder__c;}
            
            
            if(sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER){
                system.debug('srPropertyTransfer==============');
                srPropertyTransfer.add(sr);
                wrapperPrpertyTransfer.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                        sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            } else if(sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION){
                system.debug('srJoAddition==============');
                srJoAddition.add(sr);
                wrapperJoAddition.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                   sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }/*else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM){
                system.debug('ADM=======================');
                srADM.add(sr);
                wrapperADM.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                            sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }*/else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED){
                system.debug('srJoTitleDeed=======================');
                srJoTitleDeed.add(sr);
                wrapperJoTitleDeed.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                    sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED){
                system.debug('srPtTitleDeed=======================');
                srPtTitleDeed.add(sr);
                wrapperPtTitleDeed.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                    sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_LPC){
                system.debug('srLPCWaiver=======================');
                srLPCWaiver.add(sr);
                wrapperLPCWaiver.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                  sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_Mortgage_Discharge){
                system.debug('srMortgageDischarge=======================');
                srMortgageDischarge.add(sr);
                wrapperMortgageDischarge.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                          sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_Mortgage_Registration){
                system.debug('srMortgageRegistration=======================');
                srMortgageRegistration.add(sr);
                wrapperMortgageRegistration.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                             sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP){
                system.debug('srPaymentPlanSwap=======================');
                srPaymentPlanSwap.add(sr);
                wrapperPaymentPlanSwap.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                        sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_PLOT_HANDOVER ){
                system.debug('srPlotHandover=======================');
                srPlotHandover.add(sr);
                wrapperPlotHandover.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                     sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PE ){
                system.debug('srRequestPE=======================');
                srRequestPE.add(sr);
                wrapperRequestPE.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                  sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT ){
                system.debug('srUnitCancellation=======================');
                srUnitCancellation.add(sr);
                wrapperUnitCancellation.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                         sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_UC ){
                system.debug('srUnitConsolidation=======================');
                srUnitConsolidation.add(sr);
                wrapperUnitConsolidation.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                          sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_UNIT_HANDOVER ){
                system.debug('srUnitHandover=======================');
                srUnitHandover.add(sr);
                wrapperUnitHandover.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                     sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP){
                system.debug('srUnitSwap=======================');
                srUnitSwap.add(sr);
                wrapperUnitSwap.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                 sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE){
                system.debug('srUnitUpgrade=======================');
                srUnitUpgrade.add(sr);
                wrapperUnitUpgrade.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                    sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
             else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION){
                system.debug('srPreUnitCancellation=======================');
                srPreUnitCancellation.add(sr);
                wrapperPreUnitCancellation.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                    sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION){
                system.debug('srPostUnitCancellation=======================');
                srPostUnitCancellation.add(sr);
                wrapperPostUnitCancellation.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                                    sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }
            else {
                wrapper.srlst.add(new WrapperClass.ServiceRequestWrapper(sr.Id, email, sr.UnitId__c != null ? sr.Unit_Name__c : null,
                                                                         sr.AccountId__r != null ? sr.AccountId__r.Name : null,closedDate,typeService,salesOrder));
            }                                        
        }
        
        if (wrapperPrpertyTransfer.srlst.size() > 0) {
            // Construct payload with desired structure
            Map<String, Object> payload = new Map<String, Object>{
                'contacts' => wrapperPrpertyTransfer.srlst,
                    'medium'   => wrapperPrpertyTransfer.medium
                    };
                        
                        jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srPropertyTransfer);
        }
        
        if (wrapperJoAddition.srlst.size() > 0) {
            // Build custom payload with only "contacts" and "medium"
            Map<String, Object> payload = new Map<String, Object>{
                'contacts' => wrapperJoAddition.srlst,
                    'medium'   => wrapperJoAddition.medium
                    };
                        
                        jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srJoAddition);
        }
      /*  if (wrapperADM.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperADM.srlst,'medium'   => wrapperADM.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srADM);
        }*/
        if (wrapperJoTitleDeed.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperJoTitleDeed.srlst,'medium'   => wrapperJoTitleDeed.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srJoTitleDeed);
        }
        if (wrapperPtTitleDeed.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperPtTitleDeed.srlst,'medium'   => wrapperPtTitleDeed.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srPtTitleDeed);
        }
        if (wrapperLPCWaiver.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperLPCWaiver.srlst,'medium'   => wrapperLPCWaiver.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_LPC);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srLPCWaiver);
        }
        if (wrapperMortgageDischarge.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperMortgageDischarge.srlst,'medium'   => wrapperMortgageDischarge.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_Mortgage_Discharge);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srMortgageDischarge);
        }
        if (wrapperMortgageRegistration.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperMortgageRegistration.srlst,'medium'   => wrapperMortgageRegistration.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_Mortgage_Registration);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srMortgageRegistration);
        }
        if (wrapperPaymentPlanSwap.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperPaymentPlanSwap.srlst,'medium'   => wrapperPaymentPlanSwap.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srPaymentPlanSwap);
        }
        if (wrapperPlotHandover.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperPlotHandover.srlst,'medium'   => wrapperPlotHandover.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_PLOT_HANDOVER);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srPlotHandover);
        }
        if (wrapperRequestPE.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperRequestPE.srlst,'medium'   => wrapperRequestPE.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_DEV_NAME_PE);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srRequestPE);
        }
        if (wrapperUnitCancellation.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperUnitCancellation.srlst,'medium'   => wrapperUnitCancellation.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srUnitCancellation);
        }
        if (wrapperUnitConsolidation.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperUnitConsolidation.srlst,'medium'   => wrapperUnitConsolidation.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_UC);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srUnitConsolidation);
        }
        if (wrapperUnitHandover.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperUnitHandover.srlst,'medium'   => wrapperUnitHandover.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_UNIT_HANDOVER);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srUnitHandover);
        }
        if (wrapperUnitSwap.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperUnitSwap.srlst,'medium'   => wrapperUnitSwap.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srUnitSwap);
        }
        if (wrapperUnitUpgrade.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperUnitUpgrade.srlst,'medium'   => wrapperUnitUpgrade.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srUnitUpgrade);
        }
        if (wrapperPreUnitCancellation.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperPreUnitCancellation.srlst,'medium'   => wrapperPreUnitCancellation.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srPreUnitCancellation);
        }
        if (wrapperPostUnitCancellation.srlst.size() > 0) {
            Map<String, Object> payload = new Map<String, Object>{'contacts' => wrapperPostUnitCancellation.srlst,'medium'   => wrapperPostUnitCancellation.medium };
                
                jsonBody = JSON.serialize(payload);
            
            sendXiboconfig__mdt pg_metadata = mapRecTyeMetaData.get(Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION);
            sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'ServiceRequest__c');
            
            HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
            processResponse(resp, srPostUnitCancellation);
        }
    }
    
    private static void processResponse(HttpResponse resp, List<ServiceRequest__c> srList){
        Set<String> recordIds = new Set<String>();
        for(ServiceRequest__c sr : srList){
            recordIds.add(sr.Id);
        }
        if (resp.getStatusCode() == 200) {
            System.debug('Request successfully sent to Xibo.');
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            system.debug('parsedJson================'+ parsedJson);
            List<Object> dataList = (List<Object>) parsedJson.get('data');
            system.debug('dataList================'+ dataList);
            Map<String, Object> firstItem = (Map<String, Object>) dataList[0];
            String message = (String) firstItem.get('message');
            
            Pattern urlPattern = Pattern.compile('https?://\\S+');
            Matcher matcher = urlPattern.matcher(message);
            String extractedUrl = matcher.find() ? matcher.group() : '';
            System.debug('Extracted URL: ' + extractedUrl);
            List<Id> idList = new List<id>();
            
            System.debug('debug: in ServiceRequest__c scenario 2 ');
            List<ServiceRequest__c> updateSRList = new List<ServiceRequest__c>();
            for (ServiceRequest__c sr : srList) {
                sr.SurveyLink__c = extractedUrl;
                system.debug('debug: extractedUrl 2 ' + extractedUrl);
                updateSRList.add(sr);
                idList.add(sr.Id);
            }
            System.debug('debug: just before calling updateSRList');
            if(updateSRList.size()>0){
                updateRecords(updateSRList);
                System.debug('debug: after calling updateSRList');
            }
            for (ServiceRequest__c sr : updateSRList) {
                if (Label.Email_To_Customer_In_SR_Enabled == 'True') {// Enable custome label to send emails.
                    String recipientEmail = sr.SalesOrder__r.CustomerAccount__r.PersonEmail != null ? sr.SalesOrder__r.CustomerAccount__r.PersonEmail 
                        : sr.SalesOrder__r.PrimaryContact__r.Email;
                    if (String.isNotBlank(recipientEmail)) {
                        if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER )
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
                            //SendGridServiceRequestCustomerEmail.executeEmailSending(idList,ServiceConstants.CEMAIL_SR_COMPLETED,extractedUrl);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_COMPLETED,recipientEmail,'noreply@modon.com',
                                                                                       'MODON Sales Team',null,null,'PT Closed','Customer Management',null,null,sr.Id ));
                        }
                        else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION )
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION);
                            //SendGridServiceRequestCustomerEmail.executeEmailSending(idList,ServiceConstants.CEMAIL_SR_JO_COMPLETED,extractedUrl);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_JO_COMPLETED,recipientEmail,'noreply@modon.com',
                                                                                       'MODON Sales Team',null,null,'JOAddition Closed','Customer Management',null,null,sr.Id ));
                        }
                        /*else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM);
                            // SendGridServiceRequestADMCustomerEmail.executeEmailSending(idList,ServiceConstants.CEMAIL_SR_ADM_REG_COMPLETED,extractedUrl);
                            // Get the ADM document for this SR
                            List<Documents__c> admDocs = [SELECT Id FROM Documents__c WHERE Name = 'ADM Registration Document' AND Service_Request__c = :sr.Id LIMIT 1 ];
                            List<Id> attachmentIds = new List<Id>();
                            if (!admDocs.isEmpty()) {
                                // get latest ContentVersion for the document
                                List<ContentDocumentLink> cdl = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :admDocs[0].Id LIMIT 1 ];
                                system.debug('cdl========'+ cdl);
                                if (!cdl.isEmpty()) {
                                    ContentVersion cv = [ SELECT Id FROM ContentVersion WHERE ContentDocumentId = :cdl[0].ContentDocumentId ORDER BY VersionNumber DESC LIMIT 1 ];
                                    system.debug('cv========'+ cv);
                                    attachmentIds.add(cv.Id);
                                }
                            }
                            
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_ADM_REG_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'Customer Care',null,null,'ADM Closed','Customer Management',null,attachmentIds,sr.Id ));
                        }*/
                        else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED);
                            // SendGridServiceRequestCustomerEmail.executeEmailSending(idList,ServiceConstants.SREMAIL_JO_TITLEDEED_COMPLETED,extractedUrl);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.SREMAIL_JO_TITLEDEED_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'Customer Care',null,null,'JO title Closed','Customer Management',null,null,sr.Id ));
                        }
                        else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED);
                            // SendGridServiceRequestCustomerEmail.executeEmailSending(idList,ServiceConstants.SREMAIL_PT_TITLEDEED_COMPLETED,extractedUrl);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.SREMAIL_PT_TITLEDEED_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'Customer Care',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_LPC)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_LPC);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_LPC_WAIVER_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'Customer Care',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_Mortgage_Discharge)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_Mortgage_Discharge);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_MORTGAGE_DIS_WAIVER_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'Customer Care',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_Mortgage_Registration)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_Mortgage_Registration);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_MORTGAGE_RESG_WAIVER_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'Customer Care',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_PLAN_SWAP_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'MODON Sales Team',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                        else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_PLOT_HANDOVER)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_PLOT_HANDOVER);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_PLOT_HANDOVER_WAIVER_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'MODON Sales Team',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PE)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_RT_DEV_NAME_PE);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_RE_PAYMENT_EXTENSION_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'MODON Sales Team',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_UNIT_CANCELLATION_COMPLETED,recipientEmail,'customercare@modon.com',
                                                                                       'MODON Sales Team',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_UC)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_UC);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_UNIT_CONSOLIDATION_COMPLETED,recipientEmail,'noreply@modon.com',
                                                                                       'MODON Sales Team',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_UNIT_HANDOVER)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_UNIT_HANDOVER);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_UNIT_HANDOVER_COMPLETED,recipientEmail,'noreply@modon.com',
                                                                                       'MODON Sales Team',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP)
                        {
                            System.debug('debug: in  ' + Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_UNIT_SWAP_COMPLETED,recipientEmail,'noreply@modon.com',
                                                                                       'MODON Sales Team',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                         else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE)
                        {
                            System.debug('debug: inunitupgrade  ' + Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.CEMAIL_SR_UNIT_UPGRADE_COMPLETED,recipientEmail,'noreply@modon.com',
                                                                                       'MODON Sales Team',null,null,'PT TITLEDEED Closed','Customer Management',null,null,sr.Id ));
                        }
                        else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION)
                        {
                            System.debug('debug: preunitin  ' + Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.SREMAIL_PRE_UNIT_CANCELLATION,recipientEmail,'noreply@modon.com',
                                                                                       'MODON Sales Team',null,null,'Pre Unit Cancellation Closed','Customer Management',null,null,sr.Id ));
                        }
                        else if(srList[0].RecordTypeName__c == Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION)
                        {
                            System.debug('debug: preunitin  ' + Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION);
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,ServiceConstants.SREMAIL_POST_UNIT_CANCELLATION,recipientEmail,'noreply@modon.com',
                                                                                       'MODON Sales Team',null,null,'Post Unit Cancellation Closed','Customer Management',null,null,sr.Id ));
                        }
                        
                    } 
                }
            }
        } else {
            logError(resp, 'ServiceRequest__c', recordIds);
        }
    }
    
    private static void updateRecords(List<SObject> records) {
        System.debug('debug: in sendRequestToXiboApi.updateRecords method ');
        if (!records.isEmpty()) {
            try {
                System.debug('debug: before db call');
                Database.update(records, false);
                System.debug('debug: after db call');
            } catch (Exception e) {
                System.debug('Error updating records: ' + e.getMessage());
            }
        }
    }
    private static void logError(HttpResponse res, String sObjectName, Set<String> recordIds) {
        String error = res.getStatusCode() + ' - ' + res.getBody();
        LoggerService.save(LoggerService.createAPILog(
            'Survey API', 'sendRequestToXiboApi', 'SendRequest',
            JSON.serialize(recordIds), '', error, 'Update Log'
        ));
    }
}