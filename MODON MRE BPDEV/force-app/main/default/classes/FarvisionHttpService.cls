public class FarvisionHttpService {
    
    public static CreateUnitResponse createUnit(CreateUnitRequest req) {
        
        HttpResponse response = sendRequest('/fms/odata/unit/upsert', 'POST', JSON.serialize(req));
        CreateUnitResponse result = (CreateUnitResponse) JSON.deserialize(response.getBody(), CreateUnitResponse.class);
        result.statusCode = response.getStatusCode();
        return result;
        
    }
    
    public static BulkCreateUnitResponse createBulkUnits(List<CreateUnitRequest> reqs) {
        
        BulkCreateUnitRequest req = new BulkCreateUnitRequest();
        req.units = reqs;
        
        HttpResponse response = sendRequest('/fms/odata/unit/upsert/bulk', 'POST', JSON.serialize(req));
        BulkCreateUnitResponse result = (BulkCreateUnitResponse) JSON.deserialize(response.getBody(), BulkCreateUnitResponse.class);
        result.statusCode = response.getStatusCode();
        return result;
        
    }
    
    public static CreateCustomerResponse createCustomer(CreateCustomerRequest req) {
        
        HttpResponse response = sendRequest('/fms/odata/customer/upsert', 'POST', JSON.serialize(req));
        CreateCustomerResponse result = (CreateCustomerResponse) JSON.deserialize(response.getBody(), CreateCustomerResponse.class);
        result.statusCode = response.getStatusCode();
        return result;
        
    }
    
    public static CreateBulkCustomerResponse createBulkCustomer(List<CreateCustomerRequest> reqs) {
        
        CreateBulkCustomerRequest req = new CreateBulkCustomerRequest();
        req.customers = reqs;
        
        HttpResponse response = sendRequest('/fms/odata/customer/upsert/bulk', 'POST', JSON.serialize(req));
        CreateBulkCustomerResponse result = (CreateBulkCustomerResponse) JSON.deserialize(response.getBody(), CreateBulkCustomerResponse.class);
        result.statusCode = response.getStatusCode();
        return result;
        
    }
    
    //Response Data Need To Validate
    public static UnitAllocationResponse unitAllocation(UnitAllocationRequest req) {
        //https://modonuat.farvisioncloud.com//fms/odata/unit/allocate/upsert
        HttpResponse response = sendRequest('//fms/odata/allocate/upsert', 'POST', JSON.serialize(req));
        System.debug('*** Resp ***'+response.getBody());
        UnitAllocationResponse result = (UnitAllocationResponse) JSON.deserialize(response.getBody(), UnitAllocationResponse.class);
        result.statusCode = response.getStatusCode();
        return result;
        
    }
    
    //Response Data Need To Validate
    public static BulkUnitAllocationResponse bulkUnitAllocation(List<UnitAllocationRequest> reqs) {
        
        BulkUnitAllocationRequest req = new BulkUnitAllocationRequest();
        req.units = reqs;
        
        HttpResponse response = sendRequest('/fms/odata/unit/allocate/upsert/bulk', 'POST', JSON.serialize(req));
        BulkUnitAllocationResponse result = (BulkUnitAllocationResponse) JSON.deserialize(response.getBody(), BulkUnitAllocationResponse.class);
        result.statusCode = response.getStatusCode();
        return result;
        
    }
    
    //Response Data Need To Validate
    public static TransferBuyerResponse createTransferBuyer(TransferBuyerRequest req) {
        
        HttpResponse response = sendRequest('/fms/odata/transfer/buyer', 'POST', JSON.serialize(req));
        TransferBuyerResponse result = (TransferBuyerResponse) JSON.deserialize(response.getBody(), TransferBuyerResponse.class);
        result.statusCode = response.getStatusCode();
        return result;
        
    }
    
    //Joint Owner API Call Response Need To Update
    public static JointOwnerResponse createJointOwner(List<JointOwnerRequest> req) {
        
        HttpResponse response = sendRequest('/fms/odata/fvJointOwner', 'POST', JSON.serialize(req));
        JointOwnerResponse result = new JointOwnerResponse();
        result.statusCode = response.getStatusCode();
        result.responseBody = response.getBody();
        return result;
    }
    
    public static FlagMasterResponse createFlagMaster(List<FlagMasterRequest> req) {
        
        HttpResponse response = sendRequest('/fms/odata/fvFlagMas', 'POST', JSON.serialize(req));
        FlagMasterResponse result = (FlagMasterResponse) JSON.deserialize(response.getBody(), FlagMasterResponse.class);
        result.statusCode = response.getStatusCode();
        return result;
        
    }
    
    public static CustomerUnitFlagTaggingResponse createCustomerUnitFlagTagging(List<CustomerUnitFlagTaggingRequest> req) {
        
        HttpResponse response = sendRequest('/fms/odata/fvFlagCustUnit', 'POST', JSON.serialize(req));
        CustomerUnitFlagTaggingResponse result = (CustomerUnitFlagTaggingResponse) JSON.deserialize(response.getBody(), CustomerUnitFlagTaggingResponse.class);
        result.statusCode = response.getStatusCode();
        return result;
        
    }
    
    public static HttpResponse sendRequest(String endpoint, String method, String body) {
        
        String token = getAccessToken();
        
        if(String.isBlank(token)) {
            HttpResponse errorRes = new HttpResponse();
            errorRes.setStatusCode(500);
            errorRes.setBody('{"status":false, "message":"Failed to generate access token"}');
            return errorRes;
        }
        
        Farvision_API_Configuration__c config = Farvision_API_Configuration__c.getOrgDefaults();
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(config.Base_URL__c + endpoint);
        req.setMethod(method);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-Target', '40');
        req.setTimeout(120000);
        if(body != null) req.setBody(body);
        
        return new Http().send(req);
    }
    
    public static String getAccessToken() {
        
        String token = String.valueOf(Cache.Org.get('FarvisionToken'));
        if(String.isNotBlank(token)) return token;
        
        Farvision_API_Configuration__c config = Farvision_API_Configuration__c.getOrgDefaults();
        if(config == null) return null;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(config.Base_URL__c + config.Token_Endpoint__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(
            'grant_type=password' +
            '&username=' + EncodingUtil.urlEncode(config.Username__c,'UTF-8') +
            '&password=' + EncodingUtil.urlEncode(config.Password__c,'UTF-8') +
            '&timespan=' + config.Token_Timespan_Minutes__c
        );
        
        HttpResponse response = new Http().send(req);
        TokenResponse tokenResponse = (TokenResponse) JSON.deserialize(response.getBody(), TokenResponse.class);
        if(response.getStatusCode() != 200) {
            //Log the Error - Logic need to add
            return null;
        }
        
        Cache.Org.put('FarvisionToken', tokenResponse.accessToken, (Integer.valueOf(config.Token_Timespan_Minutes__c) * 60));
        return tokenResponse.accessToken;
        
    }
    
    public class TokenResponse {
        public Integer statusCode;
        public String accessToken;
        public Integer expiration;
        public String type;
        public String error;
        public String error_description;
    }
    
    /********** Create Unit Requset and Response Wrapper Block Start **********/
    
    public class CreateUnitRequest {
        public String unitCode;
        public String unitId;
        public String buildingName;
        public String businessUnitName;
        public String propertyGroupName;
        public String effectiveDate;
        public String landDLDNumber;
        public String unitType;
        public String subUnitType;
        public String unitHandoverStatus;
        public String usages;
        public String unitStatus;
        
        public AreaDetails areaDetails;
        
        public String budgetZone;
        public String budgetDefinition;
        public String mollakPropertyGroupId;
        public String mollakUnitId;
        public String gisUnitId;
    }
    
    public class AreaDetails {
        public Decimal approvedBUA;
        public Decimal actualBUA;
        public Decimal plotArea;
        public Decimal balconyArea;
        public Decimal gfa;
        public Decimal actualGFA;
        public Decimal sellableArea;
    }
    
    public class CreateUnitResponse {
        public Integer statusCode;
        public String correlationId;
        public Boolean status;
        public String message;
        public CreateUnitResponseData data;
    }
    
    public class CreateUnitResponseData {
        public String unitCode;
        public Integer unitId;
        public List<FarvisionError> errors;
    }
    
    
    /********** Create Bulk Unit Requset and Response Wrapper Block Start **********/
    
    public class BulkCreateUnitRequest {
        public List<CreateUnitRequest> units;
    }
    
    public class BulkCreateUnitResponse {
        public Integer statusCode;
        public String correlationId;
        public Boolean status;
        public String message;
        public List<CreateUnitResponseData> data;
    }
    
    /********** Create Customer Requset and Response Wrapper Block Start **********/
    
    public class CreateCustomerRequest {
        public String customerCode;
        public String customerId;
        public String firstName;
        public String lastName;
        public String fullName;
        public String custType;
        public String custTRNNo;
        public String custVATType;
        
        public AddressDetails addressDetails;
        public ContactDetails contactDetails;
        public IdentityDetails identityDetails;
    }
    
    public class AddressDetails {
        public Correspondance correspondance;
    }
    
    public class Correspondance {
        public String line1;
        public String line2;
        public String line3;
        public String city;
        public String state;
        public String country;
        public String postalCode;
    }
    public class ContactDetails {
        public Mobile primaryMobile;
        public Mobile secondaryMobile;
        public Mobile phoneNo;
        public Email email;
    }
    
    public class Mobile {
        public String countryCode;
        public String no;
    }
    
    public class Email {
        public String primary;
        public String secondary;
    }
    
    public class IdentityDetails {
        public String mollakCustomerId;
        public String emiratesId;
        public String eidExpiry;
        public String passportNo;
        public String passportExpiry;
        public String nationality;
        public String tradeLicense;
        public String tradeLicenseExpiry;
    }
    
    public class CreateCustomerResponse {
        public Integer statusCode;
        public String correlationId;
        public Boolean status;
        public String message;
        public CreateCustomerResponseData data;
    }
    
    public class CreateCustomerResponseData {
        public String customerCode;
        public Integer customerId;
        public List<FarvisionError> errors;
    }
    
    /********** Create Bulk Customer Requset and Response Wrapper Block Start **********/
    
    public class CreateBulkCustomerRequest {
        public List<CreateCustomerRequest> customers;
    }
    
    public class CreateBulkCustomerResponse {
        public Integer statusCode;
        public String correlationId;
        public Boolean status;
        public String message;
        public List<CreateCustomerResponseData> data;
    }
    
    /********** Unit Allocation Requset and Response Wrapper Block Start **********/
    
    public class UnitAllocationRequest {
        public String allocationId;
        public String businessUnit;
        public String unitCode;
      
        public String customerCode;
        
       // public String customerId;
       // public String unitId;
       
        public String effectiveDate;   // Booking Date or SPA Date
        //public String effectiveTill;
        public String remarks;
    }
    
    public class UnitAllocationResponse {
        public Integer statusCode;
        public String correlationId;
        public Boolean status;
        public String message;
        public UnitAllocationResponseData data;
    }
    
    public class UnitAllocationResponseData {
        public String allocationId;
        public String unitCode;
        public String customerCode;
        public Integer allocationRecordId;
        public List<FarvisionError> errors;
    }
    
    /********** Unit Bulk Allocation Requset and Response Wrapper Block Start **********/
    
    public class BulkUnitAllocationRequest {
        public List<UnitAllocationRequest> units;
    }
    
    public class BulkUnitAllocationResponse {
        public Integer statusCode;
        public String correlationId;
        public Boolean status;
        public String message;
        public List<UnitAllocationResponseData> data;
    }
    
    /********** Buyer Transfer Requset and Response Wrapper Block Start **********/
    
    public class TransferBuyerRequest {
        public String transferId;
        public String transferDate;
        public String communityCode;
        public String precinctCode;
        public Unit unit;
        public Customer seller;
        public Customer buyer;
        public Boolean allowBalanceTransfer;
    }
    
    public class Unit {
        public String unitCode;
        public String unitId;
    }
    
    public class Customer {
        public String customerCode;
        public String customerId;
        public String firstName;
        public String lastName;
        public String fullName;
        public String custType;
        public String custTRNNo;
        public String custVATType;
        public AddressDetailsBT addressDetails;
        public ContactDetailsBT contactDetails;
        public String mollakCustomerId;
    }
    
    public class AddressDetailsBT {
        public CorrespondanceBT correspondance;
    }
    
    public class CorrespondanceBT {
        public String line1;
        public String line2;
        public String line3;
        public String city;
        public String state;
        public String country;
        public String postalCode;
    }
    
    public class ContactDetailsBT {
        public Phone primaryMobile;
        public Phone secondaryMobile;
        public Phone phoneNo;
        public EmailAddress email;
    }
    
    public class Phone {
        public String countryCode;
        public String no;
    }
    
    public class EmailAddress {
        public String primary;
        public String secondary;
    }
    
    public class TransferBuyerResponse {
        public Integer statusCode;
        public String correlationId;
        public String message;
        public Boolean status;
        public TransferBuyerData data;
    }
    
    public class TransferBuyerData {
        public List<FarvisionError> errors;
    }
    
    
    /********** Joint Owner Requset and Response Wrapper Block Start **********/
    
    public class JointOwnerRequest {
        public String customerCode;
        public String jointCustomerCode;
        public String unitNo;
        public String effectiveDate;
        public String endDate;
    }
    
    public class JointOwnerResponse {
        public Integer statusCode;
        public String responseBody;
    }
    
    /********** Flag Master Requset and Response Wrapper Block Start **********/
    
    public class FlagMasterRequest {
        public String code;
        public String description;
        public String flagType;
        public String category;
    }
    
    public class FlagMasterResponse {
        public Integer statusCode;
        public Boolean status;
        public String message;
    }
    
    /********** Customer Unit Flag Requset and Response Wrapper Block Start **********/
    
    public class CustomerUnitFlagTaggingRequest {
        public String flagCode;
        public String customerCode;
        public String unitCode;
        public Integer isActive;
        public String startDate;
        public String endDate;
    }
    
    public class CustomerUnitFlagTaggingResponse {
        public Integer statusCode;
        public Boolean status;
        public String message;
    }
    
    
    public class FarvisionError {
        public String message;
    }
    
}