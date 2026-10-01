/* Version       Author                          Date            Comment                                                                      
* 1.0           raghu.chilukuri@activemindsit.com    19 Dec 2023      Initial Draft(Communication Record Creation,Approvalprocess,emailsending)      
  1.1           raghu.chilukuri@activemindsit.com    08/03/26         code Refinement
**********************************************************************************************
*/

public with sharing class CommunicationBatchEmailSender implements Queueable, Database.AllowsCallouts {

    private Id communicationId;

    public CommunicationBatchEmailSender(Id communicationId) {
        this.communicationId = communicationId;
    }

    public void execute(QueueableContext ctx) {
        CommunicationController.portal('sendCommunicationEmails', new Map<String, Object>{ 'communicationId' => communicationId });
    }
}