/**********************************************************************************************************************
* Name               : OffersAndCollectionsTriggerHelper                                                        
* Description        : This class is used to handle all the Credit Note Creation & Other Offers Collection related Logics
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0          dinesh.selvam@modon.com             11 Nov 2025     Handle the Entire Offers & Collections Automation Changes 
* 2.0          dinesh.selvam@modon.com             02 Mar 2026     handle the credit note & Allocation, Transaction Number for Credit Note
* 2.1          dinesh.selvam@modon.com             04 Mar 2026     handle ADM Waiver Accept & Reject Notification, Reject reason capture
* 3.0          dinesh.selvam@modon.com             13 Apr 2026     Uncommented to do auto allocation for the credit note from ADM Waiver automation 
**********************************************************************************************************************/
public class OffersAndCollectionsTriggerHelper {
    /**2.1 handle ADM Waiver Accept & Reject Notification **/
    private static final String ADM_CREATED_TEMPLATE  = 'ADM_Created';
    private static final String ADM_APPROVED_TEMPLATE = 'ADM_Approved';
    private static final String ADM_REJECTED_TEMPLATE = 'ADM_Rejected';
    private static final String ADM_SENDER_EMAIL = 'no-reply@modon.com';
    private static final String ADM_SENDER_NAME  = 'MODON Sales Team';
    
    public static List<Receipt__c> insertedReceipts = new List<Receipt__c>();
    
    public static void createCreditNoteWaiverADM(List<Offers_Collections__c> offerList,Map<Id,Offers_Collections__c> oldMap){
        List<Offers_Collections__c> eligibleOffersList = new List<Offers_Collections__c>();
        List<Offers_Collections__c> revertADMOffersList = new List<Offers_Collections__c>();
        Set<Id> soIdset = new Set<Id>();
        Set<Id> offerCollecIdset = new Set<Id>();
        Set<Id> rejectedOfferIds = new Set<Id>();
        
        // Email sets
        Set<Id> submittedOfferIds = new Set<Id>();
        Set<Id> approvedOfferIds = new Set<Id>();
        Set<Id> rejectedOfferIdsForEmail = new Set<Id>();
        List<Offers_Collections__c> updateOffrCollecList = new List<Offers_Collections__c>();
        
        for(Offers_Collections__c offers: offerList){
            if(oldMap.get(offers.Id).Approval_Status__c <> null && oldMap.get(offers.Id).Approval_Status__c <> offers.Approval_Status__c){
                Offers_Collections__c offr = new Offers_Collections__c();
                offr.Id = offers.Id;
                if(offers.Approval_Status__c == 'Submitted'){
                    submittedOfferIds.add(offers.Id);
                }else if(offers.Approval_Status__c == 'Approved' && !offers.DontAllowToCreateCreditNote__c && offers.Credit_Note__c == null){
                    eligibleOffersList.add(offers);
                    approvedOfferIds.add(offers.Id);
                    offr.Approved_Rejected_By__c = UserInfo.getUserId();
                }else if(offers.Approval_Status__c == 'Rejected'){
                    soIdset.add(offers.Sales_Order__c);
                    rejectedOfferIds.add(offers.Id);
                    rejectedOfferIdsForEmail.add(offers.Id);
                    offr.Approved_Rejected_By__c = UserInfo.getUserId();
                }else if(offers.Approval_Status__c == 'Approved' && offers.DontAllowToCreateCreditNote__c){
                    offerCollecIdset.add(offers.Id);
                    approvedOfferIds.add(offers.Id);
                    offr.Approved_Rejected_By__c = UserInfo.getUserId();
                }
                updateOffrCollecList.add(offr);
            }
        }
        if(!eligibleOffersList.isEmpty()){
            createReceiptsForOffers(eligibleOffersList);
        }
        if(!soIdset.isEmpty()){
            List<SalesOrder__c> soUpdateList = new List<SalesOrder__c>();
            for(Id soId: soIdset){
                SalesOrder__c so = new SalesOrder__c();
                so.Id = soId;
                so.Discount_on_ADM_Fees__c = 0;
                soUpdateList.add(so);
            }
            if(!soUpdateList.isEmpty()){
                update soUpdateList;
            }
        }
        if(!offerCollecIdset.isEmpty()){
            for(Id offer: offerCollecIdset){
                Offers_Collections__c ofr = new Offers_Collections__c();
                ofr.Id = offer;
                ofr.Approval_Status__c = 'Not Submitted';
                revertADMOffersList.add(ofr);
            }
            if(!revertADMOffersList.isEmpty()){
                update revertADMOffersList;
            }
        }
        if(!rejectedOfferIds.isEmpty()){
            updateRejectedReasonAsync(new List<Id>(rejectedOfferIds));
        }

         /**2.1 handle ADM Waiver Accept & Reject Notification EMail Triggering Part **/
        if(!submittedOfferIds.isEmpty()){
            System.enqueueJob(new AdmWaiverEmailQueueable(new List<Id>(submittedOfferIds), 'Submitted'));
        }
        if(!approvedOfferIds.isEmpty()){
            System.enqueueJob(new AdmWaiverEmailQueueable(new List<Id>(approvedOfferIds), 'Approved'));
        }
        if(!rejectedOfferIdsForEmail.isEmpty()){
            System.enqueueJob(new AdmWaiverEmailQueueable(new List<Id>(rejectedOfferIdsForEmail), 'Rejected'));
        }
        if(!updateOffrCollecList.isEmpty()){
            try{
            	update updateOffrCollecList;
            }catch(Exception ex){}
        }
    }
    /**2.1 handle ADM Waiver  Reject Reasons Capture Logic**/
    @future
    public static void updateRejectedReasonAsync(List<Id> rejectedOfferIds){
        if(rejectedOfferIds == null || rejectedOfferIds.isEmpty()){
            return;
        }
    
        Map<Id, String> rejectionCommentsByOfferId = new Map<Id, String>();
    
        for(ProcessInstanceStep step : [
            SELECT Comments, ProcessInstance.TargetObjectId, CreatedDate
            FROM ProcessInstanceStep
            WHERE ProcessInstance.TargetObjectId IN :rejectedOfferIds
            AND StepStatus = 'Rejected'
            ORDER BY CreatedDate DESC
        ]){
            Id offerId = step.ProcessInstance.TargetObjectId;
            if(!rejectionCommentsByOfferId.containsKey(offerId) && String.isNotBlank(step.Comments)){
                rejectionCommentsByOfferId.put(offerId, step.Comments);
            }
        }
    
        List<Offers_Collections__c> offersToUpdate = new List<Offers_Collections__c>();
        for(Id offerId : rejectionCommentsByOfferId.keySet()){
            offersToUpdate.add(new Offers_Collections__c(
                Id = offerId,
                Approved_Rejected_By__c = UserInfo.getUserId(),
                Rejection_Reason__c = rejectionCommentsByOfferId.get(offerId)
            ));
        }
    
        if(!offersToUpdate.isEmpty()){
            update offersToUpdate;
        }
    }
    
    public class AdmWaiverEmailQueueable implements Queueable {
        private List<Id> offerIds;
        private String statusValue;

        public AdmWaiverEmailQueueable(List<Id> offerIds, String statusValue){
            this.offerIds = offerIds;
            this.statusValue = statusValue;
        }

        public void execute(QueueableContext qc){
            if(offerIds == null || offerIds.isEmpty() || String.isBlank(statusValue)){
                return;
            }

            if(statusValue == 'Submitted'){
                Map<Id, Id> approverByOfferId = new Map<Id, Id>();
                Set<Id> approverIds = new Set<Id>();

                for(ProcessInstanceWorkitem wi : [
                    SELECT ActorId, ProcessInstance.TargetObjectId, CreatedDate
                    FROM ProcessInstanceWorkitem
                    WHERE ProcessInstance.TargetObjectId IN :offerIds
                    ORDER BY CreatedDate DESC
                ]){
                    Id offerId = wi.ProcessInstance.TargetObjectId;
                    if(!approverByOfferId.containsKey(offerId) && wi.ActorId != null && wi.ActorId.getSObjectType() == User.SObjectType){
                        approverByOfferId.put(offerId, wi.ActorId);
                        approverIds.add(wi.ActorId);
                    }
                }

                if(!approverIds.isEmpty()){
                    Map<Id, User> approverMap = new Map<Id, User>([
                        SELECT Id, Email
                        FROM User
                        WHERE Id IN :approverIds
                        AND Email != null
                    ]);

                    for(Id offerId : approverByOfferId.keySet()){
                        Id approverId = approverByOfferId.get(offerId);
                        if(approverMap.containsKey(approverId)){
                            User approver = approverMap.get(approverId);
                            SendGridNotificationUtility.sendEmail(
                                null,
                                approver.Id,
                                ADM_CREATED_TEMPLATE,
                                approver.Email,
                                ADM_SENDER_EMAIL,
                                ADM_SENDER_NAME,
                                'Offers Collections',
                                'ADM Waiver',
                                'ADM Waiver Submitted',
                                'Sales',
                                'Immediate',
                                null,
                                offerId
                            );
                        }
                    }
                }

            }else if(statusValue == 'Approved'){
                for(Offers_Collections__c offer : [
                    SELECT Id, CreatedById, CreatedBy.Email
                    FROM Offers_Collections__c
                    WHERE Id IN :offerIds
                ]){
                    if(offer.CreatedById != null && String.isNotBlank(offer.CreatedBy.Email)){
                        SendGridNotificationUtility.sendEmail(
                            null,
                            offer.CreatedById,
                            ADM_APPROVED_TEMPLATE,
                            offer.CreatedBy.Email,
                            ADM_SENDER_EMAIL,
                            ADM_SENDER_NAME,
                            'Offers Collections',
                            'ADM Waiver',
                            'ADM Waiver Approved',
                            'Sales',
                            'Immediate',
                            null,
                            offer.Id
                        );
                    }
                }

            }else if(statusValue == 'Rejected'){
                Map<Id, String> rejectionCommentsByOfferId = new Map<Id, String>();

                for(ProcessInstanceStep step : [
                    SELECT Comments, ProcessInstance.TargetObjectId, CreatedDate
                    FROM ProcessInstanceStep
                    WHERE ProcessInstance.TargetObjectId IN :offerIds
                    AND StepStatus = 'Rejected'
                    ORDER BY CreatedDate DESC
                ]){
                    Id offerId = step.ProcessInstance.TargetObjectId;
                    if(!rejectionCommentsByOfferId.containsKey(offerId) && String.isNotBlank(step.Comments)){
                        rejectionCommentsByOfferId.put(offerId, step.Comments);
                    }
                }

                if(!rejectionCommentsByOfferId.isEmpty()){
                    List<Offers_Collections__c> offersToUpdate = new List<Offers_Collections__c>();
                    for(Id offerId : rejectionCommentsByOfferId.keySet()){
                        offersToUpdate.add(new Offers_Collections__c(
                            Id = offerId,
                            Rejection_Reason__c = rejectionCommentsByOfferId.get(offerId)
                        ));
                    }
                    if(!offersToUpdate.isEmpty()){
                        update offersToUpdate;
                    }
                }

                for(Offers_Collections__c offer : [
                    SELECT Id, CreatedById, CreatedBy.Email
                    FROM Offers_Collections__c
                    WHERE Id IN :offerIds
                ]){
                    if(offer.CreatedById != null && String.isNotBlank(offer.CreatedBy.Email)){
                        SendGridNotificationUtility.sendEmail(
                            null,
                            offer.CreatedById,
                            ADM_REJECTED_TEMPLATE,
                            offer.CreatedBy.Email,
                            ADM_SENDER_EMAIL,
                            ADM_SENDER_NAME,
                            'Offers Collections',
                            'ADM Waiver',
                            'ADM Waiver Rejected',
                            'Sales',
                            'Immediate',
                            null,
                            offer.Id
                        );
                    }
                }
            }
        }
    }
    
    /** 2.0 - Creating the Credit Note & Allocation Automation **/
    public static void createReceiptsForOffers(List<Offers_Collections__c> offerList) {
        
        List<Id> salesOrderIds = new List<Id>();
        for (Offers_Collections__c offer : offerList) {
            if (offer.Sales_Order__c != null) {
                salesOrderIds.add(offer.Sales_Order__c);
            }
        }
        
        Map<Id, SalesOrder__c> salesOrderMap = new Map<Id, SalesOrder__c>(
            [SELECT Id, CustomerAccount__c, Discount_on_ADM_Fees__c, TotalAmount__c,Daricharges__c 
             FROM SalesOrder__c 
             WHERE Id IN :salesOrderIds]
        );
        List<Receipt__c> crReceiptsToInsert = new List<Receipt__c>();
        
        for (Offers_Collections__c offer : offerList) {
            SalesOrder__c so = salesOrderMap.get(offer.Sales_Order__c);
            
            if (so != null && so.Discount_on_ADM_Fees__c != null && so.TotalAmount__c != null) {
                
                Receipt__c crNote = new Receipt__c();
                crNote.Modeofpayment__c = 'Credit Note';
                crNote.SalesOrder__c = so.Id;
                crNote.Account__c = so.CustomerAccount__c;
                crNote.TotalAmount__c = (so.Discount_on_ADM_Fees__c * so.TotalAmount__c / 100) + (offer.Is_DARI_Fee_Waived__c == true ? so.Daricharges__c : 0); 
                crNote.Receipt_Amount__c = crNote.TotalAmount__c;
                crNote.Is_ADM_Fees_and_Dari_charges__c = true;
                crNote.Status__c = 'Cleared';
                crNote.EBS_Clearing_Date__c = System.today();
                crNote.OffersPromationIdentifier__c = offer.Id;
                crReceiptsToInsert.add(crNote);
            }
        }
        
        if (!crReceiptsToInsert.isEmpty()) {
            insert crReceiptsToInsert;
            List<Offers_Collections__c> offersLstUpd = new List<Offers_Collections__c>();
            List<Allocation__c> allocList = new List<Allocation__c>();
            Set<Id> offerIdset = new Set<Id>();
            Map<Id,Id> invoiceIdMap = new Map<Id,Id>();
            for(Receipt__c rec: crReceiptsToInsert){
                offerIdset.add(rec.OffersPromationIdentifier__c);
            }
            for(Offers_Collections__c offrs:[SELECT Id,Invoice__c FROM Offers_Collections__c WHERE Id IN: offerIdset]){
                invoiceIdMap.put(offrs.Id,offrs.Invoice__c);
            }
            for(Receipt__c rec: crReceiptsToInsert){
                if(invoiceIdMap.containsKey(rec.OffersPromationIdentifier__c)){
                    Offers_Collections__c ofr = new Offers_Collections__c();
                    ofr.Id = rec.OffersPromationIdentifier__c;
                    ofr.Credit_Note__c = rec.Id;
                    offersLstUpd.add(ofr);
                    /**3.0 Uncommented to do auto allocation for the credit note from ADM Waiver automation **/
                    Allocation__c alloc = new Allocation__c();
                    alloc.Receipt__c = rec.Id;
                    alloc.Invoice__c = invoiceIdMap.get(rec.OffersPromationIdentifier__c);
                    alloc.AllocationAmount__c = rec.Receipt_Amount__c;
                    alloc.ApprovedReceiptAmount__c = rec.Receipt_Amount__c;
                    alloc.Allocation_Type__c = 'Credit Note';
                    allocList.add(alloc);
                }
            }
            if(!offersLstUpd.isEmpty()){
                update offersLstUpd;
            }
            if(!allocList.isEmpty()){
                insert allocList;
            }
        }
    }
}