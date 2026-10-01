/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10      Initial Draft     
**********************************************************************************************************************/

public with sharing class ReviewerCommentController {

	 @AuraEnabled(cacheable=true)
    public static List<String> getActionedToOptions() {
        List<String> options = new List<String>();
        for (PNC_Approval__mdt meta : [SELECT MasterLabel FROM PNC_Approval__mdt]) {
            options.add(meta.MasterLabel);
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getRemarkOptions(Id stepId) {
        Business_Process_Step__c  bps = [Select Id, Name, Business_Process__r.Type__c FROM Business_Process_Step__c WHERE ID = :stepId LIMIT 1];
        List<String> options = new List<String>();
        List<Business_Process_Reviewer_Cmt__mdt> lstMdt = [SELECT ID, Picklist_Options__c FROM Business_Process_Reviewer_Cmt__mdt where Business_Process_Step_Name__c = :bps.Name AND Business_Process_Type__c = :bps.Business_Process__r.Type__c LIMIT 1];
        options = !lstMdt?.isEmpty() ? lstMdt[0]?.Picklist_Options__c?.split(';') : NULL;
        return options;
    }




    @AuraEnabled(cacheable=true)
    public static List<ReviewerCommentWrapper> getCommentsByStep(Id stepId) {
        List<ReviewerCommentWrapper> result = new List<ReviewerCommentWrapper>();

        List<Business_Process_Step__c> bStep = [
            SELECT Id, Business_Process__c  
            FROM Business_Process_Step__c 
            WHERE Id = :stepId 
            LIMIT 1
        ];
    
        if (!bStep.isEmpty()) {
            List<Reviewer_Comment__c> comments = [
                SELECT Id, Notes_Comments__c, Actioned_To__c, Remarks__c, Review_Status__c,
                    (SELECT ContentDocumentId, ContentDocument.LatestPublishedVersionId
                    FROM ContentDocumentLinks
                    ORDER BY ContentDocument.CreatedDate DESC LIMIT 1)
                FROM Reviewer_Comment__c
                WHERE Business_Process__c = :bStep[0].Business_Process__c
            ];

            for (Reviewer_Comment__c rc : comments) {
                String latestFileId = rc.ContentDocumentLinks.isEmpty() ? null : rc.ContentDocumentLinks[0].ContentDocumentId;
                List<String> fileList = (latestFileId == null) ? new List<String>() : new List<String>{ latestFileId };

                result.add(new ReviewerCommentWrapper(
                    rc.Id, rc.Notes_Comments__c, rc.Actioned_To__c, fileList, true, rc.Remarks__c, rc.Review_Status__c
                ));
            }
        }
        return result;
    }

    @AuraEnabled
    public static void deleteCommentWithFiles(String commentId) {
        try {
            System.debug('commentId = '+commentId);
            
            List<Reviewer_Comment__c> comments = [ SELECT Id, Business_Process_Step__c, Business_Process__c FROM Reviewer_Comment__c WHERE Id = :commentId ];
            if (comments.isEmpty()) {
                throw new AuraHandledException('Comment not found');
            }
            
            List<ContentDocumentLink> documentLinks = [SELECT Id, ContentDocumentId FROM ContentDocumentLink  WHERE LinkedEntityId = :commentId];
        
            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentDocumentLink link : documentLinks) {
                contentDocumentIds.add(link.ContentDocumentId);
            }
        
            if (!documentLinks.isEmpty()) {
                delete documentLinks;
            }
        
            if (!contentDocumentIds.isEmpty()) {
                List<ContentDocument> contentDocuments = [SELECT Id FROM ContentDocument WHERE Id IN :contentDocumentIds];
                delete contentDocuments;
            }
        
            delete comments;
        
        } catch (Exception e) {
            throw new AuraHandledException('Delete failed: ' + e.getMessage());
        }
    }









 
 @AuraEnabled(cacheable=true)
    public static Id getDesignDocumentPlaceholder(Id stepId) {
        // Get the Step
        Business_Process_Step__c step = [
            SELECT Business_Process__c, Business_Process_Steps_Name_Custom__c 
            FROM Business_Process_Step__c 
            WHERE Id = :stepId 
            LIMIT 1
        ];
        String placeholderName;
        // Map Step_Name__c to Document Placeholder Name
        if(step.Business_Process_Steps_Name_Custom__c == 'PNCA Approval') {
            placeholderName = 'PNCA Approval Review documents';
        } else if(step.Business_Process_Steps_Name_Custom__c == 'Development Approval') {
            placeholderName = 'Development Approval review documents';
        } else {
            // fallback
            placeholderName = 'Verify Request review document';
        }
        Business_Process_Documents__c placeholder = [
            SELECT Id 
            FROM Business_Process_Documents__c 
            WHERE Business_Process__c = :step.Business_Process__c
            AND Name = :placeholderName
            LIMIT 1
        ];
        return placeholder.Id;
    }



@AuraEnabled
public static void updateReviewerComment(String commentData) {
    try {
        // Deserialize the JSON string
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(commentData);
        
        String commentId = (String) data.get('commentId');
        String notes = (String) data.get('notes');
        String actionedTo = (String) data.get('actionedTo');
        String remarks = (String) data.get('remarks');
        String reviewStatus = (String) data.get('reviewStatus');
        
        // Handle lists properly
        List<Object> newFileIdsObj = (List<Object>) data.get('newFileIds');
        List<Object> filesToRemoveObj = (List<Object>) data.get('filesToRemove');
        
        List<String> newFileIds = new List<String>();
        List<String> filesToRemove = new List<String>();
        
        // Convert Object lists to String lists
        if (newFileIdsObj != null) {
            for (Object obj : newFileIdsObj) {
                newFileIds.add(String.valueOf(obj));
            }
        }
        
        if (filesToRemoveObj != null) {
            for (Object obj : filesToRemoveObj) {
                filesToRemove.add(String.valueOf(obj));
            }
        }
        
        // Update the comment record
        Reviewer_Comment__c comment = [SELECT Id FROM Reviewer_Comment__c WHERE Id = :commentId];
        comment.Notes_Comments__c = notes;
        comment.Actioned_To__c = actionedTo;
        comment.Remarks__c = remarks;
        comment.Review_Status__c = reviewStatus;
        
        update comment;
        
        // Remove files if any
        if (!filesToRemove.isEmpty()) {
            List<ContentDocumentLink> linksToDelete = [
                SELECT Id FROM ContentDocumentLink 
                WHERE LinkedEntityId = :commentId 
                AND ContentDocumentId IN :filesToRemove
            ];
            if (!linksToDelete.isEmpty()) {
                delete linksToDelete;
            }
        }
        
        // Add new files if any
        if (!newFileIds.isEmpty()) {
            List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
            for (String contentDocId : newFileIds) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = contentDocId;
                cdl.LinkedEntityId = commentId;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';
                newLinks.add(cdl);
            }
            if (!newLinks.isEmpty()) {
                insert newLinks;
            }
        }
        
    } catch (Exception e) {
        throw new AuraHandledException('Update failed: ' + e.getMessage());
    }
}



     @AuraEnabled
    public static void createReviewerComments(List<CommentWrapper> comments) {
        if(comments.isEmpty()) return;
        
        List<Business_Process_Step__c> bstep = [
            SELECT Id, Business_Process__c 
            FROM Business_Process_Step__c 
            WHERE Id = :comments[0].stepId 
        ];
        String paId = bstep[0].Business_Process__c;
        
        List<Business_Process_Documents__c> nocDocuments = [
            SELECT Id 
            FROM Business_Process_Documents__c 
            WHERE Business_Process__c = :paId
            AND Name = 'Include In NOC'
            LIMIT 1
        ];
        
        Id nocDocumentId = nocDocuments.isEmpty() ? null : nocDocuments[0].Id;
        
        List<Reviewer_Comment__c> recordsToInsert = new List<Reviewer_Comment__c>();
        
     
        for (CommentWrapper cw : comments) {
            Reviewer_Comment__c rc = new Reviewer_Comment__c();
            rc.Notes_Comments__c = cw.notes;
            rc.Actioned_To__c = cw.actionedTo;
            rc.Business_Process_Step__c = cw.stepId;
            rc.Remarks__c = cw.remarks;
            rc.Review_Status__c = cw.reviewStatus;
            rc.Business_Process__c = paId;
            
            recordsToInsert.add(rc);
        }
        insert recordsToInsert;
        
        List<ContentDocumentLink> cdlToInsert = new List<ContentDocumentLink>();
        
        for (Integer i = 0; i < comments.size(); i++) {
            CommentWrapper cw = comments[i];
            Id parentId = recordsToInsert[i].Id;
            
            if (cw.fileIds != null && !cw.fileIds.isEmpty()) {
                for (String contentDocId : cw.fileIds) {
                    // Link to Reviewer Comment
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = contentDocId;
                    cdl.LinkedEntityId = parentId;
                    cdl.ShareType = 'V';
                    cdl.Visibility = 'AllUsers';
                    cdlToInsert.add(cdl);
                    
                    if (cw.actionedTo == 'Included in NOC' && nocDocumentId != null) {
                        ContentDocumentLink nocCdl = new ContentDocumentLink();
                        nocCdl.ContentDocumentId = contentDocId;
                        nocCdl.LinkedEntityId = nocDocumentId;
                        nocCdl.ShareType = 'V';
                        nocCdl.Visibility = 'AllUsers';
                        cdlToInsert.add(nocCdl);
                    }
                }
            }
        }
        
        if (!cdlToInsert.isEmpty()) {
            insert cdlToInsert;
        }
    }
    
    public class CommentWrapper {
        @AuraEnabled public String notes { get; set; }
        @AuraEnabled public String actionedTo { get; set; }
        @AuraEnabled public List<String> fileIds { get; set; }
        @AuraEnabled public String stepId { get; set; }
        @AuraEnabled public String bpId { get; set; }
        @AuraEnabled public String remarks { get; set; }
        @AuraEnabled public String reviewStatus { get; set; }
    }


    public class ReviewerCommentWrapper {
        @AuraEnabled public Id commentId;
        @AuraEnabled public String notes;
        @AuraEnabled public String actionedTo;
        @AuraEnabled public List<String> fileIds;
        @AuraEnabled Public boolean dataPresent;
		@AuraEnabled public String remarks;
        @AuraEnabled public String reviewStatus;
        public ReviewerCommentWrapper(Id commentId, String notes, String actionedTo, List<String> fileIds, Boolean dataPresent, String remarks, String reviewStatus) {
            this.commentId = commentId;
            this.notes = notes;
            this.actionedTo = actionedTo;
            this.fileIds = fileIds;
            this.dataPresent=dataPresent;
            this.remarks =remarks;
            this.reviewStatus = reviewStatus;
        }
    }

}