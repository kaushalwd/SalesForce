/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft 
* 2.0           sivannaryana.p@modon.com     24-07-2026      Seesion ID changes 
**********************************************************************************************************************/
public class DrawloopHelper {
    
    public static String GetDrawloopURL(String objectName, String objectApiName, String documentType, String objectId) {

        // Get session information
         Boolean useOAuthSession = Boolean.valueOf(System.Label.Docgen_Session_Flag);
        String sessionId;
        if (useOAuthSession) {
            sessionId = SessionOAuthHelper.getOAuthAccessToken();
        } else {
            sessionId = UserInfo.getSessionId();
        }
        String UserId = UserInfo.getUserId();
        String OrgId = UserInfo.getOrganizationId();

        String Origin = System.Label.DrawloopOrigin;
        String location = Origin + OrgId;

        // Get DDP record and related Integration Options
        List<Loop__DDP__c> ddps = [SELECT Id, (SELECT Id FROM Loop__Custom_Integration_Options__r order by CreatedDate DESC limit 1)
                                   FROM Loop__DDP__c
                                   WHERE Name =:documentType AND Loop__Object_Name__c = :objectApiName];

         System.debug('*** ddps ***' + ddps);
     
        if (ddps.isEmpty()) {
           // throw new CustomException('No Loop__DDP__c record found for document type');
        }
        Loop__DDP__c selectedDDP = ddps[0];

        if (selectedDDP.Loop__Custom_Integration_Options__r.isEmpty()) {
           // throw new CustomException('No Loop__Custom_Integration_Options__c child records found for Loop__DDP__c Id: ' + selectedDDP.Id);
           
        }
        String ddpId = selectedDDP.Id;
        String ddpDeliveryIds = selectedDDP.Loop__Custom_Integration_Options__r[0].Id;

        // Construct the Drawloop URL
        String URLs = 'https://apps.drawloop.com/SFLogin.aspx?';
        String next = '/ddps/42?objname=' + objectName
            + '&objtype=' + objectApiName.toLowerCase()
            + '&auto=false&header=false&sessiondata=SFuser:' + UserId
            + ';SForganization:' + OrgId
            + ';OptDocs:;SF' + objectApiName.toLowerCase() + ':' + objectId
            + ';DDPId:' + ddpId
            + ';Deploy:' + ddpDeliveryIds
            + ';DeployType:Download';

        String reqBody = 'sessionid=' + SessionId
            + '&location=' + EncodingUtil.urlEncode(location, 'UTF-8')
            + '&auto=true&next=' + EncodingUtil.urlEncode(next, 'UTF-8')
            + '&attachments=&sandbox=';

        URLs += reqBody;
        System.debug('Drawloop URL ->> ' + URLs);
        return URLs;
    }
    
     // You may define CustomException if you haven't already
    public class CustomException extends Exception {}


}