/**********************************************************************************************************************
* Name               : OIC_SAHandoverMilestoneAPI                                                        
* Description        : This class is used to fetch Unit handover details.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft       
***********************************************************************************************************************/
@RestResource(urlMapping='/superapp/handover/*')
global class OIC_SAHandoverMilestoneAPI {

    private static final String RECORD_TYPE_CUSTOMER_SNAG = 'Customer_Snagging';
    private static final Set<String> REQUIRED_DOCUMENT_NAMES = new Set<String>{
        'BCC Letter',
        'Handover Phasing Letter',
        'Home Orientation Letter',
        'Customer Snagging Letter',
        'Customer De Snagging Letter (RFO)',
        'Title Deed Copy',
        'Unified Handover Document',
        'Home Orientation Attendee Document',
        'Handover Attendee Document'    
    };
        
    @HttpGet
    global static void getUnitHandoverDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            String unitId = req.params.get('UnitId');
            if (String.isBlank(unitId)) {
                returnErrorAPI.returnError(res, requestId, 'Missing unitId parameter', 200);
                return;
            } 
            System.debug('>>>>>>>>>>>>>>>>>>>>> getUnitHandoverDetails >>>> '+unitId);
            HandoverMilestoneResponse obj_Handover = new HandoverMilestoneResponse();
            
            Id sanitizedUnitId;
            try {
                sanitizedUnitId = (Id) unitId;
            } catch (StringException se) {
                res.statusCode = 400;
                returnErrorAPI.returnError(res, requestId, 'Invalid Salesforce ID format for UnitId.', 200);
                return;
            }
            
            List<Handover_Details__c> hdList = [
                SELECT Id, Is_Bcc_Letter_Sent__c, Handover_Phasing_Letter_Sent__c,
                       Home_Orientation_Letter_Date_Sent__c, Customer_Attended_Snagging__c, Customer_Attended_Desnagging__c, 
                       Business_Process__c, Business_Process__r.Unit__c, Business_Process__r.Sales_Order__c,
                	   Payment_Status__c, QA_Status__c, QA_Desnagging_Status__c, Title_Deed_Status__c, Fixed_QA_Snags__c,
                       Pending_QA_Snags__c, Business_Process__r.Status__c, Business_Process__r.Current_Step_Status__c,
                	   Business_Process__r.Current_Step_Name__c, Business_Process__r.Sales_Order__r.Status__c,
                       KAR__r.Name, KAR__r.Email, KAR__r.MobilePhone, KAR__c
                FROM Handover_Details__c
                where Business_Process__c != null and Business_Process__r.Unit__c = :sanitizedUnitId 
                and Business_Process__r.Sales_Order__r.Status__c = 'Completed' 
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (hdList.isEmpty()) {
                returnErrorAPI.returnError(res, requestId, 'No completed handover milestone found for the specified Unit ID.', 200);
                return;
            }
            
            Handover_Details__c obj_HD = hdList.size()>0?hdList.get(0):new Handover_Details__c();
			obj_Handover.BusinessProcessId =  obj_HD.Business_Process__c!=null?obj_HD.Business_Process__c:'';
            obj_Handover.UnitId = obj_HD.Business_Process__r!=null?obj_HD.Business_Process__r.Unit__c:'';
            obj_Handover.SalesOrderId =  obj_HD.Business_Process__r!=null?obj_HD.Business_Process__r.Sales_Order__c:'';
            obj_Handover.HandoverDetailsId = obj_HD.Id;
            obj_Handover.Is_Bcc_Letter_Sent = obj_HD.Is_Bcc_Letter_Sent__c;
            obj_Handover.Handover_Phasing_Letter_Sent = obj_HD.Handover_Phasing_Letter_Sent__c;
            obj_Handover.Home_Orientation_Letter_Date_Sent = obj_HD.Home_Orientation_Letter_Date_Sent__c;
            obj_Handover.Customer_Attended_Snagging = obj_HD.Customer_Attended_Snagging__c;
            obj_Handover.Customer_Attended_Desnagging = obj_HD.Customer_Attended_Desnagging__c;
            obj_Handover.Status = obj_HD.Business_Process__r!=null?obj_HD.Business_Process__r.Status__c:'';
            if(String.isNotBlank(obj_HD?.Business_Process__r?.Current_Step_Name__c)){
                List<SA_Handover_Mapping__mdt> handoverMapping= [Select App_Step_Name__c, Current_Step_Name__c, Next_Step_Name__c, 
                                                                 Previous_Step_Name__c from SA_Handover_Mapping__mdt 
                                                                 where Current_Step_Name__c = :obj_HD?.Business_Process__r?.Current_Step_Name__c];
                if(!handoverMapping.isEmpty()){
                    SA_Handover_Mapping__mdt obj_HM = handoverMapping.get(0);
                    obj_Handover.CurrentStage = obj_HM.App_Step_Name__c;
                } else {
                    obj_Handover.CurrentStage = obj_HD.Business_Process__r.Current_Step_Name__c;
                }
            }
            
            obj_Handover.Documents = new List<DocumentDetails>();
            Map<String, String> documentNameToLatestContentDocumentId = getLatestDocumentMap(sanitizedUnitId);
            
            for (String docName : REQUIRED_DOCUMENT_NAMES) {
                String fileId = documentNameToLatestContentDocumentId.get(docName);
                obj_Handover.documents.add(new DocumentDetails(docName, fileId != null ? fileId : ''));
            }
            
            populateSnagDetails(obj_Handover, obj_HD);
            populateManagerDetails(obj_Handover, obj_HD);
            populateAppointmentDetails(obj_Handover, obj_HD);
            populateServiceTerritoryDetails(obj_Handover, obj_HD);
            
            APIResponse response = new APIResponse('success', requestId, obj_Handover, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
        } catch (Exception ex) { // Return generic server error response
            LoggerService.save(LoggerService.createApexLog(ex, 'OIC_SAHandoverMilestoneAPI', 'OIC_SAHandoverMilestoneAPI', 'getUnitHandoverDetails'));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200); 
        }
    }
    
    private static void populateServiceTerritoryDetails(HandoverMilestoneResponse obj_Handover, Handover_Details__c obj_HD) {
        if (obj_HD == null) {
            return;
        }
        obj_Handover.ServiceTerritory = new ServiceTerritoryDetails('0HhVG000000lcbJ0AQ','Muheira - Phase1 Handover Center',
                                                                    '24.39023','54.57667','Al maria','Abu Dhabi','Abu Dhabi',
                                                                    'Abu Dhabi','AD');       
    }
    
    private static void populateManagerDetails(HandoverMilestoneResponse obj_Handover, Handover_Details__c obj_HD) {
        if (obj_HD.KAR__c == null) {
            obj_Handover.KeyAccountManager = new ManagerDetails('Suresh Bhethi','suresh.bhethi@modon.com','+971566058266',''); 
            return;
        }
        obj_Handover.KeyAccountManager = new ManagerDetails(obj_HD.KAR__r.Name,obj_HD.KAR__r.Email,obj_HD.KAR__r.MobilePhone,obj_HD.KAR__c); 
    }
    
    private static void populateAppointmentDetails(HandoverMilestoneResponse obj_Handover, Handover_Details__c obj_HD) {
        if (obj_HD.Business_Process__c == null || obj_HD.Business_Process__r.Unit__c == null) {
            return;
        }

        List<ServiceAppointment> lst_ServiceAppointment = [
            SELECT Id, SchedStartTime, SchedEndTime, WorkTypeId, WorkType.Name, UnitId__c, 
            ServiceResourceId__c, Status from ServiceAppointment where UnitId__c = :obj_HD.Business_Process__r.Unit__c
            WITH SYSTEM_MODE
        ];
		obj_Handover.Appointments = new List<Appointment>();
        for (ServiceAppointment obj_SA : lst_ServiceAppointment) {
            obj_Handover.Appointments.add(new Appointment(obj_SA));
        }
    }
    
    private static void populateSnagDetails(HandoverMilestoneResponse obj_Handover, Handover_Details__c obj_HD) {
        if (obj_HD.Business_Process__c == null || obj_HD.Business_Process__r.Unit__c == null) {
            return;
        }

        List<Snagging__c> lst_Snag = [
            SELECT Id, External_Snag_Id__c, Snag_Name__c, Status__c, Snag_Comment__c, 
                   De_Snag_Comment__c, Snag_Rectification_Comment__c, Snag_Link__c, De_Snag_Link__c, 
                   Snag_Type__c, Priority__c
            FROM Snagging__c 
            WHERE RecordType.DeveloperName = :RECORD_TYPE_CUSTOMER_SNAG 
              AND Business_Process__c = :obj_HD.Business_Process__c 
              AND Unit__c = :obj_HD.Business_Process__r.Unit__c
            WITH SYSTEM_MODE
            LIMIT 1000
        ];
		obj_Handover.Snags = new List<Snag>();
        for (Snagging__c obj_Snagging : lst_Snag) {
            obj_Handover.Snags.add(new Snag(obj_Snagging));
        }
    }
    
    private static Map<String, String> getLatestDocumentMap(Id unitId) {
        Map<String, String> contentDocumentIdToDocName = new Map<String, String>();
        Map<String, String> documentNameToLatestContentDocumentId = new Map<String, String>();

        for (Business_Process_Documents__c doc : [
            SELECT Name, (SELECT ContentDocumentId FROM ContentDocumentLinks)
            FROM Business_Process_Documents__c
            WHERE Business_Process__r.Unit__c = :unitId
              AND Name IN :REQUIRED_DOCUMENT_NAMES
            WITH SYSTEM_MODE
        ]) {
            for (ContentDocumentLink cdl : doc.ContentDocumentLinks) {
                if (cdl.ContentDocumentId != null) {
                    contentDocumentIdToDocName.put(cdl.ContentDocumentId, doc.Name);
                }
            }
        }

        // Fetch latest version sorting descending by creation date securely
        if (!contentDocumentIdToDocName.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocumentIdToDocName.keySet()
                  AND IsLatest = true
                WITH SYSTEM_MODE
            ]) {
                String docName = contentDocumentIdToDocName.get(cv.ContentDocumentId);
                if (!documentNameToLatestContentDocumentId.containsKey(docName)) {
                    documentNameToLatestContentDocumentId.put(docName, cv.Id);
                }
            }
        }
        return documentNameToLatestContentDocumentId;
    }
    
    global class HandoverMilestoneResponse {
        public Boolean Is_Bcc_Letter_Sent;
        public Boolean Handover_Phasing_Letter_Sent;
        public Date Home_Orientation_Letter_Date_Sent;
        public Boolean Customer_Attended_Snagging;
        public Boolean Customer_Attended_Desnagging;
        public String Status;
        public String CurrentStage;
        public String BusinessProcessId;
        public String UnitId;
        public String SalesOrderId;
        public String HandoverDetailsId;
        public Decimal Total_Customer_Snags;
        public Date Customer_Snag_Date;
        public String Customer_Snag_Executive;
        public String Contractor_Name;
        public Decimal Fixed_Customer_Snags;
        public Date Customer_De_Sang_Date;
        public String Customer_Desnagging_Status;
        public String Customer_Desnagging_Report;
        public Decimal Pending_Customer_Snags;
        public List<Snag> Snags;
        public List<DocumentDetails> Documents;
        public ManagerDetails KeyAccountManager;
        public List<Appointment> Appointments;
        public ServiceTerritoryDetails ServiceTerritory;
    }
    
    global class ServiceTerritoryDetails {
        public String Id;
        public String Name;
        public String Latitude;
        public String Longitude;
        Public String Street;
        public String City;
        public String Country;
        public String State;
        public String StateCode;
        
        global ServiceTerritoryDetails(String Id, String name, String latitude, String longitude, String street, String city,
                               String country, String state, String stateCode) {
            this.Id = Id;
            this.Name = name;
            this.Latitude = latitude;
            this.Longitude = longitude;
            this.Street = street;
            this.City = city;
            this.Country = country;
            this.State = state;
            this.StateCode = stateCode;
        }
    }
    
    global class Appointment{
        public String Id;
        public Datetime SchedStartTime;
        public Datetime SchedEndTime;
        public String WorkTypeId;
        public String WorkTypeName;
        public String ServiceResourceId;
        public String Status;
        
        global Appointment(ServiceAppointment record) {
            this.Id = record.Id;
            TimeZone gstTimeZone = TimeZone.getTimeZone('Asia/Dubai');
            if (record.SchedStartTime != null) {
                Integer offsetMsStart = gstTimeZone.getOffset(record.SchedStartTime);            
                this.SchedStartTime = record.SchedStartTime.addMinutes(offsetMsStart / 60000);
            }
            if (record.SchedEndTime != null) {
                Integer offsetMsEnd = gstTimeZone.getOffset(record.SchedEndTime);
                this.SchedEndTime = record.SchedEndTime.addMinutes(offsetMsEnd / 60000);
            }
            this.WorkTypeId = record.WorkTypeId;
            if (record.WorkType != null) {
                this.WorkTypeName = record.WorkType.Name;
            }
            this.ServiceResourceId = record.ServiceResourceId__c; 
            this.Status = record.Status;            
        }

    }

    global class ManagerDetails {
        public String Name;
        public String Email;
        public String MobileNumber;
        public String ManagerSFId;
        
        global ManagerDetails(String name, String email, String mobileNumber, String managerSFId) {
            this.Name = name;
            this.Email = email;
            this.MobileNumber = mobileNumber;
            this.ManagerSFId = managerSFId;
        }
    }
    
    global class DocumentDetails {
        public String DocumentName;
        public String DocumentFileId;
        
        global DocumentDetails(String documentName, String documentFileId) {
            this.DocumentName = documentName;
            this.DocumentFileId = documentFileId;
        }
    }
    
    global class Snag{
        public String RecordId;
        public String External_Snag_Id;
        public String Snag_Name;
        public String Status;
        public String Snag_Comment;
        public String De_Snag_Comment;
        public String Snag_Rectification_Comment;
        public String Snag_Link;
        public String De_Snag_Link;
        public String Snag_Type;
        public String Priority;
        
        global Snag(Snagging__c record) {
            this.RecordId = record.Id;
            this.External_Snag_Id = record.External_Snag_Id__c;
            this.Snag_Name = record.Snag_Name__c;
            this.Status = record.Status__c;
            this.Snag_Comment = record.Snag_Comment__c;
            this.De_Snag_Comment = record.De_Snag_Comment__c;
            this.Snag_Rectification_Comment = record.Snag_Rectification_Comment__c;
            this.Snag_Link = record.Snag_Link__c;
            this.De_Snag_Link = record.De_Snag_Link__c;
            this.Snag_Type = record.Snag_Type__c;
            this.Priority = record.Priority__c;
        }
    }
}