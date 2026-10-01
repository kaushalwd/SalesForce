@RestResource(urlMapping='/handoverMilestone/*')
global with sharing class HandoverMilestoneAPI {

    @HttpGet
    global static HandoverMilestoneResponse getMilestone() {

        RestRequest req = RestContext.request;
        RestResponse resCon = RestContext.response;
        String unitId = req.params.get('unitId');

        if (String.isBlank(unitId)) {
            throw new AuraHandledException('unitId is required');
        }

        
        HandoverMilestoneService.HandoverMilestone hm=HandoverMilestoneService.getHandoverMilestoneByUnit((Id)unitId);
        
       //  RestResponse res = RestContext.response;
           // Convert to JSON string
       String responseString = JSON.serialize(hm);
      // String responseStringFinal = '{ "responseString": "' + responseString + '" }';
        
        HandoverMilestoneResponse handoverResponse=new HandoverMilestoneResponse();
        handoverResponse.responseString=JSON.serialize(hm);
         /* String finalJson = JSON.serialize(
            new Map<String, String>{
                'responseString' => responseString
            }
        );*/

       // resCon.addHeader('Content-Type', 'application/json');
       // resCon.statusCode = 200;		
        
        
       // resCon.responseBody =  Blob.valueOf('{ "responseString": "' + JSON.serialize(hm) + '" }');
        
        return handoverResponse;

       
    }
    
      Global class HandoverMilestoneResponse {
        @AuraEnabled public String responseString;
      
    }
    
}