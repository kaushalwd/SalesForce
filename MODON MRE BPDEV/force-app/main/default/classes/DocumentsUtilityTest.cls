@isTest
public class DocumentsUtilityTest {

      @isTest
    static void myTestmethod(){
        test.startTest();
            DocumentsUtility.getDocumentsForSObject('Docuemnts__c');
        test.stopTest();
    }
    
    @isTest
    static void createModonDocuments() {
        Test.startTest();

        // Step 1: Get metadata entries for Refund__c and Modon - Egypt
        List<Modon_Documents_Master_Configuration__mdt> expectedMetaDocs = [
            SELECT DocumentDisplayName__c, GenerateDocument__c, SendForESignature__c 
            FROM Modon_Documents_Master_Configuration__mdt 
            WHERE ObjectAPIName__c = 'Refund__c' 
            AND DocumentAPIName__c != null 
            AND DocumentDisplayName__c != null 
            AND Source_Entity__c = 'Modon - Egypt'
        ];

        // Step 2: Call method under test
        List<Documents__c> generatedDocs = DocumentsUtility.getEgyptDocumentsForSObject('Refund__c', 'Modon - Egypt');
        
        // Step 3: Assert count
        System.assertEquals(expectedMetaDocs.size(), generatedDocs.size(), 'Mismatch in number of documents generated vs metadata');

        Test.stopTest();
    }
}