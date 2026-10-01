/**********************************************************************************************************************
* Name               : ModonPayOppHelper                                                        
* Description        : This class is used Modon Pay SLA
* Usage              : Apex class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    12 07 2026     Initial Draft       
******************************************************************************************************************/
public without sharing class ModonPayOppHelper {

    @AuraEnabled
    public static String updateBookingSLA(Id oppId, Id currentUserId) {
        System.debug('>>>> ModonPayOppHelper.updateBookingSLA | Opportunity Id: ' + oppId);
        
        if (oppId == null) {
            throw new AuraHandledException('Missing mandatory Opportunity record ID parameter.');
        }
        
        try {
            List<Opportunity> oppList = [
                SELECT Id, Name, BookingSLA__c, BookingSLAEnd__c, BookingStatus__c, Unit__c, Unit__r.ApprovalStatus__c, 
                       Unit__r.Status__c, Unit__r.Sub_Status__c, OwnerId 
                FROM Opportunity 
                WHERE Id = :oppId 
                  AND BookingStatus__c != 'Reserved' 
                  AND Unit__r.ApprovalStatus__c = 'Released' 
                  AND Unit__r.Status__c = 'Available' 
                  AND Unit__r.Sub_Status__c != 'Assigned'
                  AND Source_Entity__c != 'Modon - Egypt'
                WITH SYSTEM_MODE 
                LIMIT 1
            ];
            
            if (oppList.isEmpty()) {
                List<Opportunity> oppTempList = [
                    SELECT Id, Name, BookingSLA__c, BookingSLAEnd__c, BookingStatus__c, Unit__c, Unit__r.ApprovalStatus__c, 
                           Unit__r.Status__c, Unit__r.Sub_Status__c, OwnerId, Unit__r.BlockedFor__r.Name, Unit__r.BlockedFor__c 
                    FROM Opportunity 
                    WHERE Id = :oppId AND Unit__c != null
                    WITH SYSTEM_MODE 
                    LIMIT 1
                ];
                
                if (!oppTempList.isEmpty()) {
                    Opportunity tempOpp = oppTempList.get(0);
                    if (tempOpp.Unit__r != null && tempOpp.Unit__r.BlockedFor__c == currentUserId) {
                        return 'MatchUser';
                    }
                    return (tempOpp.Unit__r != null && tempOpp.Unit__r.BlockedFor__c != null) 
                        ? tempOpp.Unit__r.BlockedFor__r.Name 
                        : 'Unavailable';
                }
                return 'UnitNotFound'; 
            } 
            
            Opportunity opp = oppList[0];
            
            if (opp.Unit__c == null) {
                return 'Unavailable'; 
            }

            Unit__c objUnit = [
                SELECT Id, ApprovalStatus__c, Status__c, Sub_Status__c, BlockedFor__c, BlockedBy__c, 
                       Blocked_Time__c, BlockComment__c, Name 
                FROM Unit__c
                WHERE Id = :opp.Unit__c
                WITH SYSTEM_MODE 
                LIMIT 1
                FOR UPDATE
            ];
            
            DateTime currentTimestamp = DateTime.now();
            
            objUnit.Sub_Status__c = 'Assigned';
            objUnit.BlockedFor__c = opp.OwnerId; 
            objUnit.BlockedBy__c  = UserInfo.getUserId();
            objUnit.Blocked_Time__c = currentTimestamp;
            objUnit.BlockComment__c = 'Unit reserved for booking';
            
            String bookingSLA = System.Label.BookingSLA;
            if (String.isBlank(bookingSLA)) {
                opp.BookingSLAEnd__c = currentTimestamp.addMinutes(5);  
            } else {
                Integer slaMinutes = Integer.valueOf(bookingSLA.trim()); 
                opp.BookingSLAEnd__c = currentTimestamp.addMinutes(slaMinutes); 
            }
            
            opp.BookingStatus__c = 'Reserved';
            opp.BookingSLA__c    = currentTimestamp;
            
            update as system objUnit;                
            update as system opp;
            List<Modon_Pay_SLA_Event__e> slaEvents = new List<Modon_Pay_SLA_Event__e>();
            slaEvents.add(new Modon_Pay_SLA_Event__e(
                RecordId__c = opp.Id
            ));
            if (!slaEvents.isEmpty()) {
                EventBus.publish(slaEvents);
                System.debug('>>>> Published Modon Pay SLA Expiration Events for processing.');
            }
            return 'Reserved';
            
        } catch (System.TypeException te) {
            System.debug('>>>> Custom Label Conversion Error: ' + te.getMessage());
            throw new AuraHandledException('System configuration error: Invalid value for SLA duration labels.');
        } catch (System.DmlException de) {
            System.debug('>>>> Record Update Commit Failure: ' + de.getMessage());
            throw new AuraHandledException('Failed to reserve records. The rows may be locked by another processor.');
        } catch (Exception ex) {
            System.debug('>>>> ModonPayOppHelper Generic Error: ' + ex.getMessage());
            throw new AuraHandledException('An internal server error occurred while calculating SLA parameters: ' + ex.getMessage());
        }
    }  
    
    @AuraEnabled
    public static Map<String, Object> getBookingSLAConfig(Id oppId) {
        System.debug('>>>> ModonPayOppHelper.getBookingSLAConfig | Opportunity Id: ' + oppId);
        
        Map<String, Object> result = new Map<String, Object>();
        
        if (oppId == null) {
            throw new AuraHandledException('Missing mandatory Opportunity record ID parameter.');
        }
        
        try {
            Opportunity opp = [
                SELECT Id, Name, BookingSLA__c, BookingSLAEnd__c, BookingStatus__c, Total_Received_Amount__c 
                FROM Opportunity 
                WHERE Id = :oppId AND Source_Entity__c != 'Modon - Egypt'
                WITH SYSTEM_MODE 
                LIMIT 1
            ];
            List<Booking_Fee_Line__c> lst_BFLine = [
                SELECT Id, Name, Balance_Amount__c, Comments__c, Opportunity__c, Fee_Status__c, Total_Amount__c, 
                       Total_Paid_Amount__c, Type__c, Unit__c
                FROM Booking_Fee_Line__c 
                WHERE Opportunity__r.Source_Entity__c != 'Modon - Egypt' 
                  AND Opportunity__r.Id = :oppId
                WITH SYSTEM_MODE
                Limit 50
            ];
            System.debug('>>>> BookingSLA: ' + opp.BookingSLA__c + '>>>> BookingSLAEnd: ' + opp.BookingSLAEnd__c + ' | BookingStatus: ' + opp.BookingStatus__c);
            for(Booking_Fee_Line__c objBFL : lst_BFLine){
                if(objBFL.Type__c == 'ADM & Dari'){
                    result.put('ADMDariTotalAmount', objBFL.Total_Amount__c);
                    result.put('ADMDariPaidAmount', objBFL.Total_Paid_Amount__c);
                    result.put('ADMDariBalanceAmount', objBFL.Balance_Amount__c);
                    result.put('ADMDariFeeStatus', objBFL.Fee_Status__c);
                } else if(objBFL.Type__c == 'Down Payment'){
                    result.put('DownPaymentTotalAmount', objBFL.Total_Amount__c);
                    result.put('DownPaymentPaidAmount', objBFL.Total_Paid_Amount__c);
                    result.put('DownPaymentBalanceAmount', objBFL.Balance_Amount__c);
                    result.put('DownPaymentFeeStatus', objBFL.Fee_Status__c);
                }else{}
            }
            result.put('SLA_Start', opp.BookingSLA__c);
            result.put('SLA_End', opp.BookingSLAEnd__c);
            result.put('Booking_Status', opp.BookingStatus__c);
            if(opp.Total_Received_Amount__c > 0){
               result.put('PaymentStatusCheck', true); 
            }else {
               result.put('PaymentStatusCheck', false); 
            }
            
            return result;
            
        } catch (System.QueryException qe) {
            System.debug('>>>> ModonPayOppHelper Query Error: ' + qe.getMessage());
            throw new AuraHandledException('The specified Opportunity record could not be found or access is restricted.');
        } catch (Exception ex) {
            System.debug('>>>> ModonPayOppHelper Generic Error: ' + ex.getMessage());
            throw new AuraHandledException('An internal server error occurred while calculating SLA parameters: ' + ex.getMessage());
        }
    }
}