public class DocuSignRecipientStatusTriggerHandler extends TriggerHandler
{
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap){
        //check recipient status whether the document is pending from Modon or the Customer
        DocuSignRecipientStatusTriggerHelper.updateDocuSginRecipientStatus(newList, newMap);
    }
}