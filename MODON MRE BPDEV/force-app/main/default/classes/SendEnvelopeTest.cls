@isTest
public class SendEnvelopeTest {
    static TestMethod void runTest1(){
        Contact conObj = new Contact();
        conObj.LastName = 'Test contact';
        INSERT conObj;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.EIDNumber__c = '784-1996-3732188-7';
        oppObj.PrimaryContact__c = conObj.Id;
        oppObj.EmiratesIDExpiryDate__c = System.today();
        INSERT oppObj;
        
        Documents__c docObj = new Documents__c();
        docObj.Name = 'Emirates Id';
        docObj.Opportunity__c=oppObj.id;
        INSERT docObj;
         
        
        Documents__c docObj2 = new Documents__c();
        docObj2.Name = 'Signed Emirates Id';
        INSERT docObj2;
        
        ContentVersion content=new ContentVersion(); 
        content.Title='Header_Picture1'; 
        content.PathOnClient='/' + content.Title + '.jpg'; 
        Blob bodyBlob=Blob.valueOf('Unit Test ContentVersion Body'); 
        content.VersionData=bodyBlob; 
        //content.LinkedEntityId=sub.id;
        content.origin = 'H';
        insert content;

        ContentDocumentLink contentlink=new ContentDocumentLink();
        contentlink.LinkedEntityId=docObj.id;
        contentlink.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;
        contentlink.ShareType = 'I';
        contentlink.Visibility = 'AllUsers'; 
        INSERT contentlink;
        SendEnvelope.sendEnvelopeMethod(docObj.id);
        
        conObj.UAE_Resident_Status__c = Constants.RESIDENT;
        update conObj;
        
        SendEnvelope.sendEnvelopeMethod(docObj.id);
    }
}