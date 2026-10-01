/**********************************************************************************************************************
* Name               : SalesOrderPathController                                                        
* Description        : This class is used to handle Sales Order Custom Status Path LWC Controller
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                             Date            Comment                                                                       
* 1.0          dinesh.selvam@modon.com             02 Nov 2025     Initial Draft 
**********************************************************************************************************************/
public without sharing class SalesOrderPathController {

    public class PathData {
        @AuraEnabled public List<String> orderedStatuses;
        @AuraEnabled public Map<String, List<String>> statusToSubstatusMap;
    }

    @AuraEnabled(cacheable=true)
    public static PathData getStatusAndSubstatusData() {
        List<Status_Substatus_Mapping__mdt> mappings = [
            SELECT Status__c, Order__c, Substatus__c
            FROM Status_Substatus_Mapping__mdt
        ];

        mappings.sort((Comparator<Object>) new OrderComparator());

        List<String> orderedStatuses = new List<String>();
        Map<String, List<String>> subMap = new Map<String, List<String>>();

        for (Status_Substatus_Mapping__mdt mapping : mappings) {
            if (!orderedStatuses.contains(mapping.Status__c)) {
                orderedStatuses.add(mapping.Status__c);
            }
            if (String.isNotBlank(mapping.Substatus__c)) {
                try {
                    List<String> subList = (List<String>) JSON.deserialize(mapping.Substatus__c, List<String>.class);
                    subMap.put(mapping.Status__c, subList);
                } catch (Exception e) {
                    System.debug('Invalid Substatus JSON for ' + mapping.Status__c + ': ' + e.getMessage());
                    subMap.put(mapping.Status__c, new List<String>());
                }
            } else {
                subMap.put(mapping.Status__c, new List<String>());
            }
        }

        PathData data = new PathData();
        data.orderedStatuses = orderedStatuses;
        data.statusToSubstatusMap = subMap;
        system.debug('subMap::'+subMap);
        return data;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSalesOrderDetails(Id recordId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            SalesOrder__c so = [
                SELECT Id,
                       Status__c,
                       Sub_Status__c,
                       Sales_Type__c,
                       Is_Reservation_Form_Required__c,
                       Unit__r.Phase__r.Is_Reservation_Form_Required__c,
                       Sales_Journey_Flow__c
                FROM SalesOrder__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            result.put('Status', so.Status__c);
            result.put('SubStatus', so.Sub_Status__c);
            result.put('SalesJourneyFlow', so.Sales_Journey_Flow__c);

            /* Boolean isReservationRequired =
                (so.Is_Reservation_Form_Required__c == 'Yes' ||
                 so.Unit__r?.Phase__r?.Is_Reservation_Form_Required__c == 'Yes');
            result.put('IsReservationRequired', isReservationRequired); */

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching SalesOrder details: ' + e.getMessage());
        }
    }

    public class OrderComparator implements Comparator<Object> {
        public Integer compare(Object o1, Object o2) {
            Status_Substatus_Mapping__mdt a = (Status_Substatus_Mapping__mdt) o1;
            Status_Substatus_Mapping__mdt b = (Status_Substatus_Mapping__mdt) o2;
            return Integer.valueOf(a.Order__c) - Integer.valueOf(b.Order__c);
        }
    }
}