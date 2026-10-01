/**********************************************************************************************************************
 * Name               : Modon_Egypt_FileUploadViewController
 * Description        : This class is the Apex controller for the Modon Egypt File Upload View LWC.
 * Usage              : Called from Modon_Egypt_FileUploadView LWC
 * Created By         : Horizontal Digital
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Milin kapatel                       06-02-2025      Initial Draft
 ******************************************************************************************************************/
public with sharing class Modon_Egypt_FileUploadViewController {

    /**************************************************************************************************************************************************************************************
     * Method         : getRelatedFiles
     * Description    : Get files linked to a record
     * Parameters     : recordId - Parent record Id
     * Returns        : List<File>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<file> getRelatedFiles(String recordId){
        List<File> files = new List<File>();

        for(ContentDocumentLink conLink : [SELECT 
                                                ContentDocument.Id, 
                                                ContentDocument.Title, 
                                                ContentDocument.CreatedDate, 
                                                ContentDocument.FileType
                                                    FROM ContentDocumentLink 
                                                        WHERE LinkedEntityId =: recordId]){
            File file = new File();
            file.Title = conLink.ContentDocument.Title;
            file.Id = conLink.ContentDocument.Id;
            file.CreatedDate = conLink.ContentDocument.CreatedDate;
            file.Type = conLink.ContentDocument.FileType;
            files.add(file);
        }
        return files;
    }

    public class File{
        @AuraEnabled public String Title;
        @AuraEnabled public String Type;
        @AuraEnabled public Id Id;
        @AuraEnabled public Datetime CreatedDate;
    }
}