public class SignzyJourneyStatusWrapper {
    public Result result;
    public class Result {
        public Flow_x flow; // Renamed from 'flow'
        public ProcessingConfig processingConfig;
        public CapturedData capturedData;
        public MatchPercentage matchPercentage;
        public DocumentIntelligence documentIntelligence;
        public DocumentIntelligence documentIntelligence2;
        //public SelfieAnalysis selfieAnalysis;
        public String id; // Renamed from '_id'
        public String clientId;
        public String userId;
        public String journeyId;
        public String currentStatus;
        public String step;
        public String message;
        public Boolean callbackSent;
        public String callbackSentMessage;
        public Boolean mobileStatus;
        public UserInfo userInfo;
        //public List<ExternalApiResponse> externalApiResponses;
        public Long createdAt;
        public Long startedAt;
        public Long completedAt;
        public Boolean isDeleted; // Renamed from '_deleted'
        public String deletionTimeLimit;
        public String updatedAt;
        public Integer v; // Renamed from '__v'
        public AmlCheckResult amlCheckResult;
        public Map<String, IpAddressInfo> ipAddresses;
    }
    
    public class AmlCheckResult {
        public AmlInput Input;
        public AmlResponse Response;
    }
    
    public class AmlInput {
        public Checks checks;
        public CheckConfig checkConfig;
    }
    
    public class AmlResponse {
        public MetaDetails metaDetails;
        public String batchId;
        public String requestId;
        public String searchableString;
        public String result;
        public List<String> dbsMatched;
        public String pepResult;
        public String reportId;
        public String overallStatus;
    }
    
    public class AuthenticityCheck {
        public Map<String, List<ElementCheck>> frontAuthenticityCheckList;
        public Map<String, List<ElementCheck>> backAuthenticityCheckList;
    }
    
    public class CapturedData {
        public Images images;
        public Boolean consent;
        public Boolean livenessConsent;
        public String country;
        public String idType;
        public String idType2;
    }
    
    public class CheckConfig {
        public Integer nameMatchThreshold;
        public String resultType;
        public String startDate;
        public String endDate;
        public Boolean countryExactMatch;
        public Decimal nameMatchScoreWeight;
        public Decimal dobMatchScoreWeight;
        public Decimal countryMatchScoreWeight;
        public Decimal idNumberMatchScoreWeight;
    }
    
    public class Checks {
        public List<String> databaseList;
        public Boolean adverseMedia;
        public Boolean pep;
    }
    
    public class CompleteStatus {
        public DetailsOptical detailsOptical;
        public String optical;
        public String overallStatus;
        public String message;
        public String severity;
        public String portrait;
        public String rfid;
    }
    
    public class DetailsOptical {
        public String docType;
        public String expiry;
        public String imageQA;
        public String mrz;
        public String overallStatus;
        public Integer pagesCount;
        public String security;
        public String text;
        public String vds;
    }
    
    public class DocumentIntelligence {
        public CompleteStatus completeStatus;
       // public ImageQuality imageQuality;
       // public AuthenticityCheck authenticityCheck;
        public GraphicFields graphicFields;
        public PredictedIdType predictedIdTypeFront;
        public PredictedIdType predictedIdTypeBack;
        public String idExpired;
        public extractedFieldsCls extractedFields;
        public Integer attempts;
    }
    public class extractedFieldsCls{
        public String lastName;
        public String Surname;
        public String RemainderTerm;
        public String issuingStateName;         // Original: "Issuing State Name"
        public String ageAtIssue;               // Original: "Age at Issue"
        public String Age;
        public String firstName;
        public String givenNames;               // Original: "Given Names"
        public String mrzStrings;               // Original: "MRZ Strings"
        public String names;
        public String surnameAndGivenNames;     // Original: "Surname And Given Names"
        public String nameOnCardVisual;
        public String finalCheckdigit;          // Original: "Final Checkdigit"
        public String nationalityCode;          // Original: "Nationality Code"
        public String dateOfExpiryCheckdigit;   // Original: "Date of Expiry Checkdigit"
        public String Sex;
        public String documentClassCode;        // Original: "Document Class Code"
        public String issuingStateCode;         // Original: "Issuing State Code"
        public String documentNumber;           // Original: "Document Number"
        public String documentNumberCheckdigit; // Original: "Document Number Checkdigit"
        public String optionalData;             // Original: "Optional Data"
        public String dateOfExpiry;             // Original: "Date of Expiry"
        public String dateOfExpiry1;  
        public String dateOfBirthCheckdigit;    // Original: "Date of Birth Checkdigit"
        public String dateOfBirth;              // Original: "Date of Birth"
        public String optionalDataCheckDigit;   // Original: "Optional Data CheckDigit"
        public String identityCardNumber;       // Original: "Identity Card Number"
        public String nationalityArabicUAE;     // Original: "Nationality(Arabic (U.A.E.))"
        public String yearsSinceIssue;          // Original: "Years Since Issue"
        public String Nationality;
        public String dateOfIssue;              // Original: "Date of Issue"
        public String dateOfIssue1;
        public String sexArabicUAE;             // Original: "Sex(Arabic (U.A.E.))"
        public String surnameAndGivenNamesArabicUAE; // Original: "Surname And Given Names(Arabic (U.A.E.))"
        public String placeOfIssue;             // Original: "Place of Issue"
        public String placeOfIssue1;
        public String Profession;
        public String Sponsor;
        public String professionArabicUAE;      // Original: "Profession(Arabic (U.A.E.))"
        public String sponsorArabicUAE;         // Original: "Sponsor(Arabic (U.A.E.))"
        public String placeOfIssueArabicUAE;    // Original: "Place of Issue(Arabic (U.A.E.))"
        public String mrzType;                  // Original: "MRZ Type"
        public String placeOfBirth;
        public String placeOfBirth1;
    }
    public class ElementCheck {
        public Boolean ElementResult;
        public String ElementDiagnose;
        public String ElementType;
        public String Image;
        public String EtalonImage;
    }
    
    public class ExternalApiResponse {
        public String API;
        public Map<String, Object> Input;
        public Response_x Response;
    }
    
    public class FDSIDList {
        public String ICAOCode;
        public String dCountryName;
        public String dDescription;
        public Integer dFormat;
        public Boolean dMRZ;
        public Integer dType;
        public String dYear;
        public Boolean isDeprecated;
        public Integer Count;
        public List<Integer> ListCls;
    }
    
    public class FaceMatch {
        public String status;
        public Boolean verified;
        public String message;
        public String matchPercentage;
    }
    
    public class Flow_x {
        public String flowId;
        public Integer version;
    }
    
    public class GraphicField {
        public String fieldType;
        public String value;
        public String docSide;
        public String source;
        public String containerType;
    }
    
    public class GraphicFields {
        public List<List<GraphicField>> fieldList;
    }
    
    public class IdCheck {
        public Boolean ImageFocus;
        public String ImageGlares;
        public Boolean Portrait;
        public String Bounds;
        public Boolean Perspective;
        public Boolean ImageResolution;
    }
    
    public class Images {
        public String frontDoc;
        public String backDoc;
        public String selfie;
    }
    
    public class ImageQuality {
        public Boolean result;
        public IdCheck frontIdCheck;
        public IdCheck backIdCheck;
    }
    
    public class IpAddressInfo {
        public String message;
    }
    
    public class MatchPercentage {
        public String dateOfBirthMatch;
        public String addressMatch;
        public String fullNameMatch;
    }
    
    public class MetaDetails {
        public Address address;
        public String gender;
        public String name;
        public String relevantDate;
        public List<String> relevantIdNumbers;
        public String screenedOn;
        public String type;
    }
    
    public class PassiveLiveliness {
        public String status;
        public Boolean liveness;
        public Decimal score;
    }
    
    public class PredictedIdType {
        public String DocumentName;
        public FDSIDList FDSIDList;
        public Decimal P;
    }
    
    public class ProcessingConfig {
        public String callbackUrl;
        public String authKeyForCallback;
        public Integer redirectTime;
        public String successRedirectUrl;
        public String failureRedirectUrl;
        public Integer journeyLinkValidity;
        public Integer journeySessionExpiry;
    }
    
    public class Response_x { // Renamed from 'Response'
        public String message;
        public String overallStatus;
    }
    
    public class SelfieAnalysis {
        public PassiveLiveliness passiveLiveliness;
        public FaceMatch faceMatch;
        public Integer attempts;
    }
    
    public class UserInfo {
        public String phoneNumber;
        public String dateOfBirth;
        public String emailAddress;
        public String externalReferenceId;
        public Name name;
        public Address address;
        public IdInfo id;
    }
    
    public class Name {
        public String firstName;
        public String lastName;
    }
    
    public class Address {
        public String street;
        public String street2;
        public String city;
        public String region;
        public String postalCode;
        public String country;
    }
    
    public class IdInfo {
        public String idType;
        public String idType2;
        public String country;
    }
}