/**********************************************************************************************************************
* Name               : Utilities_Service                                                        
* Description        : This class is used as service class for reusable apex Methods
* Usage              : All Class                                                          
* Created By         : ACTIVE MINDS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.1           manoj.kumar@modon.com        24 Dec 2024      Initial Draft    
******************************************************************************************************************/
public with sharing class Utilities_Service {
    
    
    public static list<map<String,string>> getPicklistOptions(string PicklistAPIName,string ObjectName){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        List<Schema.PickListEntry> pickListValues = getPickListEntries(ObjectName,PicklistAPIName);

        for(Schema.PickListEntry ple : pickListValues){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put('label',ple.getLabel());
            tempMap.put('value',ple.getValue());
            filtersToReturn.add(tempMap);
        }
        return filtersToReturn;
    } 

    public static List<Schema.PickListEntry> getPickListEntries(String objectName, String fieldName){
        //String objectName = 'Contact';
        //String fieldName ='LeadSource';
        
        Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(objectName) ;
        Schema.DescribeSObjectResult objDescribeSobject = objSobjectType.getDescribe() ;
        Map<String,Schema.SObjectField> fields = objDescribeSobject.fields.getMap() ;
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        return ple;
    }
}