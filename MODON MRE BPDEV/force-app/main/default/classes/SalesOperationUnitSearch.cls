/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : SalesOperationUnitSearch
 * Author          : Kumaravel Mathivanan
 * Created Date    : Apr 1, 2026
 * Last Modified By: Kumaravel Mathivanan
 * Last Modified On: Apr 1, 2026
 * Description     : This class implements for sales operation unit search
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Apr 1, 2026  │ Kumaravel Mathivanan   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class SalesOperationUnitSearch {
    @AuraEnabled(cacheable=false)
    public static List<Unit__c> searchUnits(String searchKey) {
        Id loggedInUserId = UserInfo.getUserId();
        
        return [
            SELECT Id, Name, Source_Entity__c, ApprovalStatus__c, 
                   Sub_Status__c, Status__c, BlockedFor__c
            FROM Unit__c
            WHERE Name LIKE :('%' + searchKey + '%')
            AND Source_Entity__c != 'Modon - Egypt'
            AND ApprovalStatus__c = 'Released'
            AND Status__c = 'Available'
            AND (
                 ((Sub_Status__c = 'Un-Assigned' AND BlockedFor__c = null )  or (Sub_Status__c = 'Assigned' AND BlockedFor__c = :loggedInUserId) )
            )
            AND (Payment_In_Progress__c = false OR Payment_Hold_Expiry__c < :System.now() OR Payment_Hold_By__c = :loggedInUserId)
            LIMIT 50
        ];
    }
}