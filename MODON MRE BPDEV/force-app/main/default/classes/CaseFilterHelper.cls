/*********************************************************************************************************************************
* <Case_FilterHelper> : This class handles logic for the Case trigger handler for separation of Case records.
*
* @Author: Ravikumar Pasumarthi (AMGS)
* @Date: 12th May, 2025
*********************************************************************************************************************************/
public class CaseFilterHelper 
{
    public static void emptyMethod(){system.debug('debug: in emptyMethod()');}
    //*** Filters for beforeInsertMethod ***//
    /*
    public static Map<String, Object> filterCasesByRecordType(List<SObject> newList, Map<ID, SObject> newMap, List<SObject> oldList, Map<ID, SObject> oldMap) 
    {system.debug('debug: in Case_FilterHelper.filterCasesByRecordType method');
        List<SObject> serviceCases = new List<SObject>();
        List<SObject> brokerCases = new List<SObject>();
     	List<SObject> webCases = new List<SObject>();
        List<SObject> serviceCasesOld = new List<SObject>();
        List<SObject> brokerCasesOld = new List<SObject>();
     	List<SObject> webCasesOld = new List<SObject>();

        Map<ID, SObject> serviceCasesMap = new Map<ID, SObject>();
        Map<ID, SObject> brokerCasesMap = new Map<ID, SObject>();
     	Map<ID, SObject> webCasesMap = new Map<ID, SObject>();
        Map<ID, SObject> serviceCasesMapOld = new Map<ID, SObject>();
        Map<ID, SObject> brokerCasesMapOld = new Map<ID, SObject>();
     	Map<ID, SObject> webCasesMapOld = new Map<ID, SObject>();
        
        if(newList != null && newList.size() > 0)
        {
            system.debug('debug: newList.size() ' + newList.size());
            for (SObject obj : newList) 
            {
                Case cs = (Case) obj; 
                Id brokerCaseRecordTypeId = Utility.getRecordTypeIdByDevName(Case.SObjectType, 'Broker_Cases');
                 system.debug('debug: cs.RecordType.DeveloperName ' + cs.RecordType.DeveloperName);
                if (cs.RecordTypeId  == brokerCaseRecordTypeId) 
                {
                    brokerCases.add(cs);
                    brokerCasesMap.put(cs.Id, cs);
                }
                else if (cs.Origin  == 'Web') 
                {
                    cs.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Web_Cases').getRecordTypeId();
                    webCases.add(cs);
                    webCasesMap.put(cs.Id, cs);
                }
                else
                {
                    cs.RecordTypeId = (cs.RecordTypeId == null) ? Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Service_Cases').getRecordTypeId() : cs.RecordTypeId;
                    serviceCases.add(cs);
                    serviceCasesMap.put(cs.Id, cs);
                } 
            }
        }
        
        if(oldList !=null && oldList.size() > 0)
        {
            system.debug('debug: oldList.size() ' + oldList.size());
            for (SObject obj : oldList) 
            {
                Case cs = (Case) obj; 
                Id brokerCaseRecordTypeId = Utility.getRecordTypeIdByDevName(Case.SObjectType, 'Broker_Cases');
                Id webCaseRecordTypeId = Utility.getRecordTypeIdByDevName(Case.SObjectType, 'Web_Cases');
                system.debug('debug: cs.RecordType.DeveloperName ' + cs.RecordType.DeveloperName);
                if (cs.RecordTypeId  == brokerCaseRecordTypeId) 
                {
                    brokerCasesOld.add(cs);
                    brokerCasesMapOld.put(cs.Id, cs);
                }
                else if (cs.RecordTypeId  == webCaseRecordTypeId) 
                {
                    webCasesOld.add(cs);
                    webCasesMapOld.put(cs.Id, cs);
                }
                else
                {
                    cs.RecordTypeId = (cs.RecordTypeId == null) ? Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Service_Cases').getRecordTypeId() : cs.RecordTypeId;
                    serviceCasesOld.add(cs);
                    serviceCasesMapOld.put(cs.Id, cs);
                } 
            }
        }
        
        return new Map<String, Object>
        {
            'serviceCases' => serviceCases,
            'brokerCases' => brokerCases,
            'webCases' => webCases,
            'serviceCasesMap' => serviceCasesMap,
            'brokerCasesMap' => brokerCasesMap,
            'webCasesMap' => webCasesMap,
            'serviceCasesOld' => serviceCasesOld,
            'brokerCasesOld' => brokerCasesOld,
            'webCasesOld' => webCasesOld,
            'serviceCasesMapOld' => serviceCasesMapOld,
            'brokerCasesMapOld' => brokerCasesMapOld,
            'webCasesMapOld' => webCasesMapOld
         };
    }
*/
}