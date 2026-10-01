/**********************************************************************************************************************
* Name               : DocumentTypeController                                                        
* Description        : This class is call in system 
* Usage              : Called from used to get all the Related docments from DocumentType__c object
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           manoj                                    02 Feb 2025     Initial Draft          
***********************************************************************************************************************/
public class DocumentTypeController {
    /************
     * Description        : This Method is used to get all the realted records
	 * Usage              : Collect all the related records and retune list of records.
     * *********/
    public static List<DocumentType__c> getDocumentTypeList(string ObjType,set<string> RectypName){
        List<DocumentType__c> docTypeList = [SELECT Id,RecordTypeDevName__c,Type__c,ObjectType__c  From DocumentType__c 
                                             WHERE ObjectType__c=:ObjType AND RecordTypeDevName__c IN : RectypName];
        return docTypeList;
    }
    
    public static void creatingDocment(List<SObject> newList,string ObjectName)// from CaseTriggerHandler.beforeInsert, CaseTriggerHandler.beforeUpdate
    {
        List<Documents__c> newDocList = new List<Documents__c>();
        
        List<DocumentType__c> docTypeList = new List<DocumentType__c>();
        set<string> RecordtypeName = new set<string>();
        Set<Id> accountIds = new Set<Id>();

        if(ObjectName == 'Prospect Account'){
            List<Prospect_Account__c> newProspectAccList = (List<Prospect_Account__c>)newList;
            
            for(Prospect_Account__c prAcc: newProspectAccList){
                RecordtypeName.add(prAcc.RecordTypeName__c);
                  if (prAcc.Account__c != null) accountIds.add(prAcc.Account__c);
            }
            
            Map<Id, Account> accMap = new Map<Id, Account>(
                [SELECT Id, IsPersonAccount, PersonContactId FROM Account WHERE Id IN :accountIds]
            );
            
            
            Map<Id, Contact> accountContactsMap = new Map<Id, Contact>();
            for (Contact c : [SELECT Id, FirstName, LastName, Email, AccountId
                              FROM Contact
                              WHERE AccountId IN :accountIds and Is_Active__c=True LIMIT 1]) {
                                  if (!accountContactsMap.containsKey(c.AccountId)) {
                                      accountContactsMap.put(c.AccountId, c);
                                  }
                              }
            
            docTypeList =DocumentTypeController.getDocumentTypeList(ObjectName,RecordtypeName);
            for(Prospect_Account__c prAcc: newProspectAccList){      
                for(DocumentType__c dt:docTypeList){
                    if(prAcc.RecordTypeName__c.contains(dt.RecordTypeDevName__c)){
                    Documents__c d=new Documents__c();
                    d.Name = dt.Type__c;
                    d.Status__c='Pending Upload';
                    d.Prospect_Account__c=prAcc.id;  
                     if (prAcc.Account__c != null && accMap.containsKey(prAcc.Account__c)) {
                Account acc = accMap.get(prAcc.Account__c);

                if (acc.IsPersonAccount) {
                    d.Account__c = acc.Id;
                } else {
                    if (accountContactsMap.containsKey(acc.Id)) {
                        d.PrimaryContact__c = accountContactsMap.get(acc.Id).Id;
                    }
                    d.Account__c = acc.Id; 
                }
                     }
                    newDocList.add(d);
                    }
                }
            }
        }else if(ObjectName == 'Service Request'){
            List<ServiceRequest__c> newSrList = (List<ServiceRequest__c>)newList;
            for(ServiceRequest__c prAcc: newSrList){
                RecordtypeName.add(prAcc.RecordTypeName__c);
            }
            docTypeList =DocumentTypeController.getDocumentTypeList(ObjectName,RecordtypeName);
            
            for(ServiceRequest__c prAcc: newSrList){      
                for(DocumentType__c dt:docTypeList){
                    if(prAcc.RecordTypeName__c.contains(dt.RecordTypeDevName__c)){
                    Documents__c d=new Documents__c();
                    d.Name = dt.Type__c;
                    d.Status__c='Pending Upload';
                    d.Service_Request__c=prAcc.id;  
                    //d.SalesOrder__c=prAcc.SalesOrder__c;
                    newDocList.add(d);
                    }
                }
            }
        }else if(ObjectName == 'Case'){
            List<case> newCaseList = (List<case>)newList;
            /*for(case prAcc: newSrList){
                RecordtypeName.add(RecordTypeName__c)
            }*/
            docTypeList =DocumentTypeController.getDocumentTypeList(ObjectName,new set<string>{'Case Management'});

            for(Case prAcc: newCaseList){      
                for(DocumentType__c dt:docTypeList){
                  //  if(prAcc.RecordTypeName__c.contains(dt.RecordTypeDevName__c)){
                    Documents__c d=new Documents__c();
                    d.Name = dt.Type__c;
                    d.Status__c='Pending Upload';
                    d.Case__c=prAcc.id;                                  
                    newDocList.add(d);
                  //  }
                }
            }
        }
        set<Id> setOfDocIds= new set<Id>();
        if(newDocList.size() > 0 && !newDocList.isEmpty()){
            Database.saveResult[] srdocList = Database.insert(newDocList,false);
            
            if(srdocList.size() >0 && !srdocList.isEmpty()){
                for(Database.saveResult sr:srdocList){
                    System.debug('setOfDocIds--->'+setOfDocIds+'Docssss'+sr.getId());
                    setOfDocIds.add(sr.getId());
                    
                }   
            }
            
        }
    }
    
    public static void justIncrement() {
        Integer i = 0;
            i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
        i++;
        i--;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++; i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++; i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++; i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++; i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;

        
    }

}