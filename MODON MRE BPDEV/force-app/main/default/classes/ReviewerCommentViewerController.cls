/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10      Initial Draft     
**********************************************************************************************************************/
public with sharing class ReviewerCommentViewerController {

    /*@AuraEnabled(cacheable=true)
    public static List<ReviewerCommentWrapper> getCommentsByStep(Id stepId) {
        List<Business_Process_Step__c> bStep=[Select Id, Business_Process__c  from Business_Process_Step__c where Id =:stepId LIMIT 1];
        
        List<Reviewer_Comment__c> comments = [
            SELECT Id, Notes_Comments__c, Actioned_To__c,
                (SELECT ContentDocumentId, ContentDocument.LatestPublishedVersionId
                 FROM ContentDocumentLinks
                 ORDER BY ContentDocument.CreatedDate DESC)
            FROM Reviewer_Comment__c
            //WHERE Business_Process_Step__c = :stepId
            where Business_Process__c =:bStep[0].Business_Process__c
        ];

        List<ReviewerCommentWrapper> result = new List<ReviewerCommentWrapper>();
        for (Reviewer_Comment__c rc : comments) {
            String latestFileId = rc.ContentDocumentLinks.isEmpty() ? null
                : rc.ContentDocumentLinks[0].ContentDocumentId;

            result.add(new ReviewerCommentWrapper(
                rc.Id, rc.Notes_Comments__c, rc.Actioned_To__c, latestFileId,true
            ));
        }
        return result;
    }*/

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
                    ORDER BY ContentDocument.CreatedDate DESC)
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