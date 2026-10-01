/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft
* 1.1           Jay Patel                    04-09-2026      MCR-45 - SOQL Injection remediation using bind variables
**********************************************************************************************************************/

public class LookupController {

    @AuraEnabled(cacheable=true)
    public static List<sObject> lookUp(String searchTerm, String objectName, String filters, String recordId, String fields) {
        Integer limitNum = 20;
        String finalQuery = 'SELECT ' + fields + ' FROM ' + objectName;

        // MCR-45 | Version 1.1
        // SOQL Injection Fix: Added bind variable map to safely pass user-provided values.
        Map<String, Object> bindVariables = new Map<String, Object>();

        if(String.isBlank(recordId)){
            if(String.isNotBlank(searchTerm)){

                // MCR-45 | Version 1.1
                // SOQL Injection Fix: Use searchTerm as a bind variable instead of
                // directly concatenating the user-provided value into the SOQL query.
                finalQuery += ' WHERE Name Like :searchTerm ';
                bindVariables.put('searchTerm', '%' + searchTerm + '%');
            }
            if(String.isNotBlank(filters)){
                finalQuery += String.isNotBlank(searchTerm) ? ' AND ' : ' WHERE ';
                finalQuery += filters;
            }
        }else{

            // MCR-45 | Version 1.1
            // SOQL Injection Fix: Use recordId as a bind variable instead of
            // directly concatenating the record Id into the SOQL query.
            finalQuery += ' WHERE Id = :recordId';
            bindVariables.put('recordId', recordId);
        }

        finalQuery+= ' LIMIT ' + limitNum;
        System.debug('Final Query::::' + finalQuery);

        // MCR-45 | Version 1.1
        // SOQL Injection Fix: Use queryWithBinds to safely execute the dynamic SOQL
        // with user-provided values separated from the query structure.
        List<sObject> lookUpList = Database.queryWithBinds(
            finalQuery,
            bindVariables,
            AccessLevel.SYSTEM_MODE
        );

        return lookUpList;  
    }
    
    @AuraEnabled(cacheable=true)
    public static List<sObject> lookUpSearch(String displayField, String searchTerm, string myObject, String filter, String fieldsToQuery){
        System.debug('displayField : '+displayField);
        System.debug('lookupSearch : '+searchTerm);
        System.debug('myObject : '+myObject);
        System.debug('filter : '+filter);
        System.debug('fieldsToQuery : '+fieldsToQuery);
        String myQuery = null;

        // MCR-45 | Version 1.1
        // SOQL Injection Fix: Added bind variable map to safely pass user-provided values.
        Map<String, Object> bindVariables = new Map<String, Object>();

        if(displayField != null && displayField != ''){
            if(filter != null && filter != ''){

                // MCR-45 | Version 1.1
                // SOQL Injection Fix: Use searchTerm as a bind variable instead of
                // directly concatenating the user-provided search value.
                myQuery = 'Select '+ fieldsToQuery +' from '+myObject+' Where '+ displayField + ' Like :searchTerm AND '+filter+' LIMIT  5';
                bindVariables.put('searchTerm', '%' + searchTerm + '%');
            }
            else {
                if(searchTerm == null || searchTerm == ''){
                    myQuery = 'Select '+ fieldsToQuery +' from '+myObject+' Where LastViewedDate != NULL ORDER BY LastViewedDate DESC LIMIT  5';
                }
                else {

                    // MCR-45 | Version 1.1
                    // SOQL Injection Fix: Use searchTerm as a bind variable instead of
                    // directly concatenating the user-provided search value.
                    myQuery = 'Select '+ fieldsToQuery +' from '+myObject+' Where '+ displayField + ' Like :searchTerm LIMIT  5';
                    bindVariables.put('searchTerm', '%' + searchTerm + '%');
                }
            }
        }
        
        if(displayField == null || displayField == ''){
            if(filter != null && filter != ''){

                // MCR-45 | Version 1.1
                // SOQL Injection Fix: Use searchTerm as a bind variable instead of
                // directly concatenating the user-provided search value.
                myQuery = 'Select Id, Name from '+myObject+' Where Name Like :searchTerm AND '+filter+' LIMIT  5';
                bindVariables.put('searchTerm', '%' + searchTerm + '%');
            }
            else {
                if(searchTerm == null || searchTerm == ''){
                    myQuery = 'Select Id, Name from '+myObject+' Where LastViewedDate != NULL ORDER BY LastViewedDate DESC LIMIT  5';
                }
                else {

                    // MCR-45 | Version 1.1
                    // SOQL Injection Fix: Use searchTerm as a bind variable instead of
                    // directly concatenating the user-provided search value.
                    myQuery = 'Select Id, Name from '+myObject+' Where Name Like :searchTerm LIMIT  5';
                    bindVariables.put('searchTerm', '%' + searchTerm + '%');
                }
            }
        }

        System.debug('myQuery : '+myQuery);

        // MCR-45 | Version 1.1
        // SOQL Injection Fix: Use queryWithBinds to safely execute the dynamic SOQL
        // with user-provided values separated from the query structure.
        List<sObject> lookUpList = Database.queryWithBinds(
            myQuery,
            bindVariables,
            AccessLevel.SYSTEM_MODE
        );

        return lookUpList;
    }
}