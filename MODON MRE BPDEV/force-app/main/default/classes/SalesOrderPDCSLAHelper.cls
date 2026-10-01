/**********************************************************************************************************************
* Name               : SalesOrderPDCSLAHelper                                                        
* Description        : This class is used PDC SLA
* Usage              : Apex class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    02 02 2026     Initial Draft       
******************************************************************************************************************/
public without sharing class SalesOrderPDCSLAHelper {
    
    public static BusinessHours getBusinessHours(String team) {
        System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][START] team=' + team);
        BusinessHours bh;

        String bhFields = 'Id, Name, IsDefault, MondayStartTime, MondayEndTime, ' +
                        'TuesdayStartTime, TuesdayEndTime, WednesdayStartTime, WednesdayEndTime, ' +
                        'ThursdayStartTime, ThursdayEndTime, FridayStartTime, FridayEndTime, ' +
                        'SaturdayStartTime, SaturdayEndTime, SundayStartTime, SundayEndTime';

        Map<String, String> teamToBH = new Map<String, String>{
            'Sales' => 'Sales Team',
            'Sales Operation' => 'Sales Operation Team',
            'Finance' => 'Finance Team',
            'Customer Management' => 'Customer Management Team'
        };
        System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][MAP] teamToBH=' + teamToBH);

        try {
            String bhName = teamToBH.get(team);
            System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][INFO] resolvedBhName=' + bhName);
            if (bhName != null) {
                List<BusinessHours> teamBH = (List<BusinessHours>) Database.queryWithBinds(
                    'SELECT ' + bhFields + ' FROM BusinessHours WHERE Name = :bhName LIMIT 1',
                    new Map<String, Object>{ 'bhName' => bhName },
                    AccessLevel.SYSTEM_MODE
                );
                System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][SOQL] teamBH.size=' + teamBH.size());
                if (!teamBH.isEmpty()) {
                    bh = teamBH[0];
                    System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][HIT] team=' + team + ', bh.Name=' + bh.Name + ', bh.Id=' + bh.Id);
                } else {
                    System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][MISS] no BH for team=' + team + ', will try default');
                }
            }

            if (bh == null) {
                List<BusinessHours> defaults = (List<BusinessHours>) Database.queryWithBinds(
                    'SELECT ' + bhFields + ' FROM BusinessHours WHERE IsDefault = true LIMIT 1',
                    new Map<String, Object>(),
                    AccessLevel.SYSTEM_MODE
                );
                System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][SOQL] defaults.size=' + defaults.size());
                if (!defaults.isEmpty()) {
                    bh = defaults[0];
                    System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][DEFAULT] using default BH: ' + bh.Name + ' (' + bh.Id + ')');
                } else {
                    System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][WARN] no default BusinessHours record found');
                }
            }

        } catch (Exception e) {
            System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][ERROR] ' + e.getMessage());
        }

        System.debug('[SalesOrderPDCSLAHelper][getBusinessHours][END] bh=' + bh);
        return bh;
    }
 
    @AuraEnabled
    public static String updatePDCSOStatus(Id salesOrderId) {
        SalesOrder__c obj_SalesOrder = new SalesOrder__c();
        try{
            // 1. Fetch the string from the Custom Label
            String labelValue = System.Label.SalesOrderStatusForPDC;
            
            // 2. Convert to a List of Strings
            List<String> statusList = new List<String>();
            
            for(String s : labelValue.split(',')) {
                // Trim whitespace and remove the single quotes (') from the values
                statusList.add(s.trim().replace('\'', ''));
            }
            obj_SalesOrder = [SELECT Id, Name, PDC_SLA__c, IsPDCSLAExtensionRequired__c, PDCSLAExtensionApproved__c, PDC_SLA_Comments__c,
                              Resale__c, Status__c, PDC_Collected__c, ExcludePDCCheck__c
                              FROM SalesOrder__c WHERE Resale__c = false AND PDC_Collected__c = 'No' AND ExcludePDCCheck__c = false
                              AND Status__c not IN :statusList
                              AND Id = :salesOrderId LIMIT 1];
            if(obj_SalesOrder != null){
                obj_SalesOrder.Status__c = 'Voided';
                update obj_SalesOrder;
            }
            return 'Updated successfull >>';
        }catch(Exception exe){
            return 'Failure >> '+exe.getMessage();
        }
        
    } 
    
    @AuraEnabled
    public static String updatePDCSLAExtensionFlag(Id salesOrderId, String comments) {
        SalesOrder__c obj_SalesOrder = new SalesOrder__c();
        try{
            obj_SalesOrder = [SELECT Id, Name, PDC_SLA__c, IsPDCSLAExtensionRequired__c, PDCSLAExtensionApproved__c, PDC_SLA_Comments__c 
                              FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1];
            obj_SalesOrder.IsPDCSLAExtensionRequired__c = true;
            obj_SalesOrder.PDC_SLA_Comments__c = comments;
            update obj_SalesOrder;
            
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(obj_SalesOrder.Id);
            req.setProcessDefinitionNameOrId('PDC_SLA_Approve');
            req.setSkipEntryCriteria(false); // set true if you want to bypass criteria
            Approval.ProcessResult result = Approval.process(req);
            if (!result.isSuccess()) {
                throw new AuraHandledException('Approval submission failed.');
            }
        }catch(Exception exe){}        
        return 'Success';
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPDCSLAConfig(Id salesOrderId) {
        System.debug('SalesOrderPDCSLAHelper >>>>>>> salesOrderId=' + salesOrderId);
        
        Map<String, Object> result = new Map<String, Object>();
        
        if (salesOrderId == null) {
            System.debug('SalesOrderPDCSLAHelper >>>>>>> recordId is NULL');
            result.put('Error', 'No recordId provided');
            return result;
        }
        
        SalesOrder__c obj_SalesOrder = new SalesOrder__c();
        try {
            obj_SalesOrder = [SELECT Id, Name, PDC_SLA__c, PDC_Extended_SLA__c, IsPDCSLAExtensionRequired__c, PDCSLAExtensionApproved__c 
                              FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1];
            System.debug('SalesOrderPDCSLAHelper >>>>>>>  '+obj_SalesOrder.PDC_SLA__c+' >>>>  '+obj_SalesOrder.IsPDCSLAExtensionRequired__c+ ' >>>> '+obj_SalesOrder.PDCSLAExtensionApproved__c);
        } catch (Exception e) {
            System.debug('SalesOrderPDCSLAHelper >>>>>>> ' + e.getMessage());
            result.put('Error', e.getMessage());
            return result;
        }
        
        result.put('SLA_Start', obj_SalesOrder.PDC_SLA__c!=null?obj_SalesOrder.PDC_SLA__c:null);
        if(obj_SalesOrder.PDCSLAExtensionApproved__c){
           result.put('SLA_End', obj_SalesOrder.PDC_Extended_SLA__c!=null?obj_SalesOrder.PDC_Extended_SLA__c:null);           
        } else {
        	result.put('SLA_End', obj_SalesOrder.PDC_SLA__c!=null?obj_SalesOrder.PDC_SLA__c:null);    
        }           
        result.put('IsPDCSLAExtensionRequired', obj_SalesOrder.IsPDCSLAExtensionRequired__c);
                System.debug('[SalesOrderSLAHelper][getSLAConfig][END] result=' + result);
        return result;
    }
}