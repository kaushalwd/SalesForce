/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class BusinessProcessNintexDocumentGeneration {
    
    
    @AuraEnabled(cacheable=true)
    public static List<Process_Flow_Document__c> getDocuments(Id businessProcessId) {
        if (businessProcessId == null) return new List<Process_Flow_Document__c>();
        
        Business_Process__c bp = [
            SELECT Process_Flow__c
            FROM Business_Process__c
            WHERE Id = :businessProcessId
            LIMIT 1
        ];
        
        if (bp.Process_Flow__c == null) return new List<Process_Flow_Document__c>();
        
        return [
            SELECT Id, Name, Nintex_Package_Name__c
            FROM Process_Flow_Document__c
            WHERE Process_Flow__c = :bp.Process_Flow__c
            AND Nintex_Package_Name__c != null
            ORDER BY Name
        ];
    }
    
    
    @AuraEnabled
    public static void startDocumentGeneration(Id processFlowDocumentId, Id businessProcessId) {
        if (processFlowDocumentId == null || businessProcessId == null) {
            throw new AuraHandledException('Missing required IDs for document generation.');
        }
        List<Business_Process__c> bProcessList=[Select Id, Type__c, Sales_order__c from Business_Process__c  where Id=:businessProcessId];
        if(bProcessList[0].Type__c=='Default And Termination'){
        List<AggregateResult> results = [SELECT SUM(InvoiceBalance__c) TotalBalance FROM Invoice__c
                                         WHERE SalesOrderInstallment__r.SalesOrder__c = :bProcessList[0].Sales_order__c
                                         AND SalesOrderInstallment__r.MilestoneDate__c < TODAY
                                         AND InvoiceBalance__c > 0
                                         AND SalesOrderInstallment__r.PaymentStatus__c != 'Cancelled'
                                         GROUP BY SalesOrderInstallment__r.SalesOrder__c
                                        ];
        
        Decimal totalBalance = 0;
        
        if (!results.isEmpty() ) {
            totalBalance = (Decimal) results[0].get('TotalBalance');
            
            if (totalBalance == null) {
                totalBalance = 0;
            }
        }
        
        Decimal lpcAmmount=LPCCalculationService.getLPCBySalesOrder(bProcessList[0].Sales_order__c);
        Decimal paidAmount=LPCCalculationService.getPaidLpcInvoiceAmount(bProcessList[0].Sales_order__c);
        Decimal lpcAmountFinal=lpcAmmount-paidAmount;
        update new Business_Process__c(Id=businessProcessId, LPC_Amount__c =lpcAmountFinal , Out_Standing_amount__c=totalBalance);
        }
        generateDocumentAsync(processFlowDocumentId, businessProcessId, null);
    }
    
    
    @future(callout=true)
    public static void generateDocumentAsync(Id processFlowDocumentId, Id businessProcessId, String msg) {
        
        Process_Flow_Document__c selectedDoc;
        Business_Process_Documents__c targetDoc;
        String objName=processFlowDocumentId.getSObjectType().getDescribe().getName();
        if(objName=='Business_Process_Step__c')
            processFlowDocumentId = [
                SELECT Process_Flow_Document__c,Business_Process_Step__r.Business_Process__r.Sales_Order__c
                FROM Business_Process_Documents__c
                WHERE Business_Process_Step__c = :processFlowDocumentId
                LIMIT 1].Process_Flow_Document__c;
        try {
            List<Process_Flow_Document__c> docs = [
                SELECT Name, Nintex_Package_Name__c
                FROM Process_Flow_Document__c
                WHERE Id = :processFlowDocumentId
                LIMIT 1
            ];
            List<Business_Process__c> bProcessList=[Select Id, Type__c, Sales_order__c from Business_Process__c 
                                                    where Id=:businessProcessId];
            if (docs.isEmpty()) {
                throw new CalloutException('No Process Flow Document found for Id: ' + processFlowDocumentId);
            }
            selectedDoc = docs[0];
            
            String documentPackageName = selectedDoc.Nintex_Package_Name__c;
            if (documentPackageName == null) {
                throw new CalloutException('Nintex Package Name is missing on the selected document.');
            }
            String url= DrawloopHelper.GetDrawloopURL(
                    'Business Process', 'Business_Process__c', documentPackageName, businessProcessId
                );

            if (url.contains('?')) {
                url += '&format=PDF&download=1';
            } else {
                url += '?format=PDF&download=1';
            }
            
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setTimeout(120000);
            req.setEndpoint(url);
            req.setMethod('GET');
            
            HttpResponse res = http.send(req);
            System.debug('Drawloop response status: ' + res.getStatusCode());
            
            if (res.getStatusCode() != 200) {
                throw new CalloutException('Drawloop call failed with status code: ' + res.getStatusCode() + ' Response Body: ' + res.getBody());
            }
            
            
            
            
            targetDoc = getOrCreateDocumentContainer(
                businessProcessId,
                selectedDoc.Name
            );
            
            
            Blob finalBlob = null;
            String responseBody = res.getBody();
            Boolean isPdf = false;
            
            if (responseBody != null && responseBody.startsWith('<head')) {
                finalBlob = extractPdfFromHtml(responseBody, url, http);
                if (finalBlob != null && finalBlob.size() > 0) {
                    isPdf = true;
                }
            } else {
                finalBlob = res.getBodyAsBlob();
                if (finalBlob != null && finalBlob.size() > 4 && res.getBody().substring(0, 4).equals('%PDF')) {
                    isPdf = true;
                }
            }
            
            if (finalBlob == null || !isPdf) {
                throw new CalloutException('Failed to retrieve a valid PDF document after callout attempts.');
            }
            
            String documentName = selectedDoc.Name;
            String fileName = documentName.replace(' ', '_') + '_' + DateTime.now().format('yyyyMMdd_HHmmss') + '.pdf';
            
            ContentVersion cv = new ContentVersion(
                Title = documentName + ' Generated Document',
                PathOnClient = fileName,
                VersionData = finalBlob,
                Description = 'Generated PDF via Drawloop for BP: ' + businessProcessId
            );
            insert cv;
            
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = targetDoc.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
            
            if(msg!=null && (msg=='First_Default_Notice' || msg=='Second_Default_Email_Notification')){
                Map<Id, String> bpIdToTemplateName=new Map<Id, String>();
                Set<Id> bpIdSet=new Set<Id>();
                bpIdSet.add(businessProcessId);
                bpIdToTemplateName.put(businessProcessId, msg);
                SendDefaultNoticesFromBp.sendDefaultedEmail(bpIdSet, bpIdToTemplateName);
            }
            
            
        } catch (Exception e) {
            System.debug('Exception in generateDocumentAsync: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    
    private static Blob extractPdfFromHtml(String htmlContent, String originalUrl, Http http) {
        try {
            Pattern downloadPattern = Pattern.compile('href="(/download/[^"]+)"');
            Matcher matcher = downloadPattern.matcher(htmlContent);
            
            if (matcher.find()) {
                String relativePath = matcher.group(1);
                
                String[] urlParts = originalUrl.split('/');
                String baseUrl = urlParts[0] + '//' + urlParts[2];
                String downloadUrl = baseUrl + relativePath;
                
                System.debug('Attempting to download PDF from: ' + downloadUrl);
                
                HttpRequest pdfReq = new HttpRequest();
                pdfReq.setTimeout(120000);
                pdfReq.setEndpoint(downloadUrl);
                pdfReq.setMethod('GET');
                
                HttpResponse pdfRes = http.send(pdfReq);
                
                if (pdfRes.getStatusCode() == 200) {
                    Blob pdfBlob = pdfRes.getBodyAsBlob();
                    if (pdfBlob != null && pdfBlob.size() > 0 && pdfRes.getBody().substring(0, 4).equals('%PDF')) {
                        return pdfBlob;
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error extracting PDF from HTML: ' + e.getMessage());
        }
        return null;
    }
    
    private static Business_Process_Documents__c getOrCreateDocumentContainer(Id businessProcessId, String documentName) {
        List<Business_Process_Documents__c> docs = [
            SELECT Id, Name
            FROM Business_Process_Documents__c
            WHERE Business_Process__c = :businessProcessId
            AND Name = :documentName
            LIMIT 1
        ];
        
        if (!docs.isEmpty()) {
            System.debug('Found exact match container: ' + docs[0].Id);
            return docs[0];
        }
        
        docs = [
            SELECT Id, Name
            FROM Business_Process_Documents__c
            WHERE Business_Process__c = :businessProcessId
            AND Name = 'Support Documents'
            LIMIT 1
        ];
        
        if (!docs.isEmpty()) {
            System.debug('Using existing Support Documents fallback record: ' + docs[0].Id);
            return docs[0];
        }
        
        Business_Process_Documents__c supportDoc = new Business_Process_Documents__c(
            Name = 'Support Documents',
            Business_Process__c = businessProcessId
        );
        insert supportDoc;
        System.debug('Created new Support Documents fallback record: ' + supportDoc.Id);
        return supportDoc;
    }
    
}