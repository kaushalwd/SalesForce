/**********************************************************************************************************************
* Name               : sendRequestToXiboApi                                                         
* Description        : This class is helper for Creating JSON Body
* Usage              : Called from case trigger
* Created By         : Active Minds Middle East                                                      
* @author            : Raghu Gajjela
* @group             : 
* Created			 : 05 June 2025
* @last modified on  : 24-09-2025
* @last modified by  : Raghu Gajjela
* @***************************************           : ***************************************
 @Version Comment                                   : 1.1
* @Author                                            : Raghu Gajjela
* @Date                                              : 02-01-2026
* @Description                                       : added timeout value to the sendrequest object

******************************************************************************************************************/
public class sendRequestToXiboApi {
    @future(callout = true)
    public static void getSurvey_Future(Set<String> recIds, String sObjectName){
        //Based on the object call releavant service class.
        if(sObjectName == 'Case'){
           sendRequestXiboCase.callCaseXIboService(recIds);
      } else if(sObjectName == 'ServiceRequest__c'){ 
           sendRequestXIboServiceRequest.callSRXIboService(recIds);
        } else if(sObjectName == 'SalesOrder__c'){
            SendRequestToXiboSalesOrder.callSalesOrderXiboService(recIds);
        }
    }
    
    
    public static HttpResponse sendRequest(requestWrapper reqWrapper){
        sendXiboconfig__mdt xiboMeta = reqWrapper.metaData;
        
        if (reqWrapper.metaData != null) {
            String endpoint = reqWrapper.metaData.End_Point_URL__c;
            endpoint = endpoint.replace('{{CollectionId}}', reqWrapper.metaData.CollectionId__c);
            system.debug('endpoint'+ endpoint);
            Http http = new Http();
            HttpRequest request = new HttpRequest();                
            request.setEndpoint(endpoint);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('x-api-key', reqWrapper.metaData.API_Key__c);
            request.setBody(reqWrapper.jsonBody);  
            request.setTimeout(120000);
            HttpResponse res = http.send(request);
            
            return res;
            
        }
        return null;
    }
    
    public class requestWrapper {
        public sendXiboconfig__mdt metaData {get; set;}
        public String  jsonBody {get; set;}
        public String sObjectName {get; set;}
        public requestWrapper(sendXiboconfig__mdt metaData, String jsonBody, String sObjectName ) {
            this.metaData = metaData;
            this.jsonBody = jsonBody;
            this.sObjectName = sObjectName;
        }
    }
}