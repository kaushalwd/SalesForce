/**********************************************************************************************************************
* Name               : ModonEgyptConstants                                                        
* Description        : Holds all constant values used for Modon Egypt
* Usage              : Called from ReceiptTriggerHelper
* Created By         : Mirza Baig                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                Date               Comment                                                                       
* 1.0           Mirza Baig            24 Feb 2026        Initial Draft
* 1.1           Shahil Sinha          24 Feb 2026        Added Source Entity Constant
* 1.2           Mirza Baig            01 Mar 2026        Added User Constants
* 1.3           Milin Kapatel         03 Mar 2026        Added Constants for Manage Inventory and Manage Bucket LWCs 
* 1.4           Milin Kapatel         05 Mar 2026        Added Manage Bucket Constants
* 1.5           Milin Kapatel         09 Mar 2026        Added Mode of Payment Constant
* 1.6           Shahil Sinha          09 Mar 2026        Added Currency Constants
* 1.7           Gautam Mishra         09 Apr 2026        Added Oracle Constants
* 1.7           Milin Kapatel         14 Apr 2026        Added Flexible Payment Plan Constants
* 1.8           Milin Kapatel         22 Apr 2026        Added Arabic Translation Constants for Milestone Description, Area, and Currency unit and subunit
* 1.9           Milin Kapatel         22 Apr 2026        Added Flexible Plan Constants
* 1.10          Milin Kapatel         24 Apr 2026        Added Arabic Translation Constants for Maintenance Prefix
* 1.11          Milin Kapatel         28 Apr 2026        Added Installment Map Constant
* 1.12          Milin Kapatel         05 May 2026        Updated Installment Map Constant
* 1.13           Mirza Baig           19 May 2026        Added Object Constants
* 1.14          Shahil Sinha          03 June 2026       Aadded Invoice__c record types, Sales Order status, Allocation's status and SalesOrderInstallment's Payment Status
* 1.15          Shahil Sinha          17 June 2026       Aadded ServiceRequest__c record type
* 1.16          Shahil Sinha          17 June 2026       Aadded Egypt Sales Operations Queue developer name
* 1.17          Shahil Sinha          01 July 2026       Added Sales Agent profile, role, and classification constants
* 1.18          Mirza Baig            17 July 2026       Added duplicate receipt status list
******************************************************************************************************************/
 public without sharing class ModonEgyptConstants {
    // Xebo Integration Constants
    public static final String FIELD_XEBO_REQUEST = 'Xebo_Request__c';
    public static final String FIELD_XEBO_RESPONSE = 'Xebo_Response__c';
    public static final String FIELD_XEBO_STATUS = 'Xebo_Status__c';
    public static final String FIELD_XEBO_ID = 'Xebo_Id__c';
    public static final String XEBO_CONFIG_DEFAULT = 'Default';
    public static final String STATUS_SUCCESS = 'SUCCESS';
    public static final String STATUS_FAILED_PREFIX = 'FAILED_';
    
    // HTTP Settings
    public static final Integer HTTP_TIMEOUT = 120000;
    public static final String HEADER_CONTENT_TYPE = 'Content-Type';
    public static final String HEADER_CONTENT_JSON = 'application/json';
    public static final String HEADER_API_KEY = 'x-api-key';
    public static final String HTTP_POST = 'POST';
    
    
    //Object API Name
    public static final String SALES_ORDER_API_NAME = 'SalesOrder__c';
    public static final String OPPORTUNITY_API_NAME = 'Opportunity__c';//v1.13
    public static final String EOI_API_NAME = 'Expressionofinterest__c';//v1.13
    public static final String REGISTRATION_API_NAME = 'Registration__c';//v1.16
    public static final String REGISTRATION_AGENT_API_NAME = 'Registration_Agent__c';//v1.16


    //Generic Constants
    public static final String MODON_EGYPT_SOURCE_ENTITY = 'Modon - Egypt';
    public static final String EGYPTIAN_COMPANY_SPA = 'Egyptian Company SPA';
    public static final String FOREIGN_COMPANY_SPA = 'Foreign Company SPA';
    public static final String FOREIGN_INDIVIDUAL_SPA = 'Foreign Individual SPA';
    public static final String EGYPTIAN_NATURAL_PERSON_ABROAD_SPA = 'Egyptian Natural Person Abroad SPA';
    public static final String EGYPTIAN_NATURAL_PERSON_IN_EGYPT_SPA = 'Egyptian Natural Person in Egypt SPA';
    public static final String BULK_CHEQUE_RECEIPT = 'Bulk Cheque Receipt';
    public static final Set<String> EGYPT_DOC_TO_BYPASS = new Set<String>{BULK_CHEQUE_RECEIPT, EGYPTIAN_COMPANY_SPA, FOREIGN_COMPANY_SPA, FOREIGN_INDIVIDUAL_SPA, EGYPTIAN_NATURAL_PERSON_ABROAD_SPA, EGYPTIAN_NATURAL_PERSON_IN_EGYPT_SPA };
    public static final Set<String> EGYPT_SPA_DOC_NAMES = new Set<String>{EGYPTIAN_COMPANY_SPA, FOREIGN_COMPANY_SPA, FOREIGN_INDIVIDUAL_SPA, EGYPTIAN_NATURAL_PERSON_ABROAD_SPA, EGYPTIAN_NATURAL_PERSON_IN_EGYPT_SPA };
    

    // Common Keys (reuse existing inventory keys where sensible)
    public static final String EMPTY_STRING = '';

    public static final String KEY_LABEL = 'label';
    public static final String KEY_VALUE = 'value';
    public static final String KEY_CURRENCY_ISO = 'CurrencyIsoCode';

    // Record Types / Countries
    public static final String RECORD_TYPE_ORG = 'Organization Account';
    public static final String RECORD_TYPE_PERSON = 'Person Account';
    public static final String COUNTRY_EGYPT = 'Egypt';
    public static final String EGYPT_SERVICE_REQUEST_Broker_Registration = 'Egypt_Broker_Registration'; //v1.15

    // LWC Unit Search: DeveloperName Filters
    public static final String FILTER_QUALITY_TYPE = 'Quality_Type';
    public static final String FILTER_GFA = 'Gross_Floor_Area_GFA';
    public static final String FILTER_FLOOR = 'Floor';

    // Query/Text Fragments
    public static final String LIKE_8_YEAR = '%8 Year%';
    public static final String LIKE_8_YEARS = '%8 Years%';
    public static final String LIKE_CASH = '%Cash%';

    // Frequencies / Plan Types / Modes
    public static final String FREQ_QUARTERLY = 'Quarterly';
    public static final String FREQ_SEMI_ANNUAL = 'Semi-Annual';
    public static final String FREQ_ANNUAL = 'Annual';

    public static final String PLAN_STANDARD = 'Standard';
    public static final String PLAN_FLEXIBLE = 'Flexible';
    public static final String MODE_BY_AMOUNT = 'By Amount';
    public static final String MODE_BY_YEARS = 'By Years';
    public static final String MODE_BY_INSTALLMENTS = 'By Installments';
    public static final String DOWN_PAYMENT_MODE_PERCENT = 'Percent';
    public static final String DOWN_PAYMENT_MODE_AMOUNT = 'Amount';

    // Custom Payment Plan — Calculation Constants (moved from ModonEgypt_CustomPaymentPlanController)
    public static final Decimal PP_ANNUAL_RATE = 0.105;
    public static final Decimal PP_QUARTERLY_RATE = PP_ANNUAL_RATE / 4;
    public static final Integer PP_STANDARD_YEARS = 8;
    public static final Decimal PP_PV_TOLERANCE = 0.5;
    public static final Decimal PP_AMOUNT_TOLERANCE = 0.01;
    public static final Decimal PP_NUMBER_100 = 100;
    public static final Decimal PP_NUMBER_10 = 10;

    // Custom Payment Plan — Labels and Status strings
    public static final String PP_DOWNPAYMENT_LABEL = 'Downpayment';
    public static final String PP_INSTALLMENT_PREFIX = 'Installment ';
    public static final String PP_MAINTENANCE_PREFIX = 'Maintenance ';

    //v1.8
    public static final String PP_DOWNPAYMENT_LABEL_AR = 'دفعة مبدئية';
    public static final String PP_INSTALLMENT_PREFIX_AR = 'تقسيط';
    public static final String PP_MAINTENANCE_PREFIX_AR = 'صيانة';

    public static final Map<String, String> PP_INSTALLMENT_MAP = new Map<String, String>{
        'downpayment' => 'دفعة الحجز والتعاقد',
        'installment1' => 'القسط الاول',
        'installment2' => 'القسط الثاني',
        'installment3' => 'القسط الثالث',
        'installment4' => 'القسط الرابع',
        'installment5' => 'القسط الخامس',
        'installment6' => 'القسط السادس',
        'installment7' => 'القسط السابع',
        'installment8' => 'القسط الثامن',
        'installment9' => 'القسط التاسع',
        'installment10' => 'القسط العاشر',
        'installment11' => 'القسط الحادي عشر',
        'installment12' => 'القسط الثاني عشر',
        'installment13' => 'القسط الثالث عشر',
        'installment14' => 'القسط الرابع عشر',
        'installment15' => 'القسط الخامس عشر',
        'installment16' => 'القسط السادس عشر',
        'installment17' => 'القسط السابع عشر',
        'installment18' => 'القسط الثامن عشر',
        'installment19' => 'القسط التاسع عشر',
        'installment20' => 'القسط العشرون',
        'installment21' => 'القسط الحادي والعشرون',
        'installment22' => 'القسط الثاني والعشرون',
        'installment23' => 'القسط الثالث والعشرون',
        'installment24' => 'القسط الرابع والعشرون',
        'installment25' => 'القسط الخامس والعشرون',
        'installment26' => 'القسط السادس والعشرون',
        'installment27' => 'القسط السابع والعشرون',
        'installment28' => 'القسط الثامن والعشرون',
        'installment29' => 'القسط التاسع والعشرون',
        'installment30' => 'القسط الثلاثون',
        'installment31' => 'القسط الحادي والثلاثون',
        'installment32' => 'القسط الثاني والثلاثون'
    };

    public static final String PP_STATUS_UNCHANGED = 'Unchanged';
    public static final String PP_STATUS_ADJUSTED = 'Adjusted';
    public static final String PP_STATUS_ADJUSTED_PARTIAL = 'Adjusted (partial)';
    public static final String PP_STATUS_PV_ADJUSTED_SUFFIX = ' + PV Adjusted';

    public static final Map<String, Integer> FREQUENCY_MAP = new Map<String, Integer>{
        FREQ_QUARTERLY   => 4,
        FREQ_SEMI_ANNUAL => 2,
        FREQ_ANNUAL      => 1
    };

    // Reusable Messages/Templates — Unit Search + Block Request
    public static final String MSG_ERR_GET_ALL_PROJECTS = 'Error in getAllProjects: ';
    public static final String MSG_BLOCK_REQ_IN_PROGRESS_PREFIX = 'Block request : ';
    public static final String MSG_BLOCK_REQ_IN_PROGRESS_SUFFIX = ' is already in progress.';
    public static final String MSG_UNIT_ALREADY_BLOCKED_PREFIX = 'Unit : ';
    public static final String MSG_UNIT_ALREADY_BLOCKED_SUFFIX = ' is already blocked.';
    public static final String MSG_SUCCESS = 'Success';
    public static final String MSG_UNIT_NOT_AVAILABLE_FOR_BOOKING = 'Unit is not available for booking.';
    public static final String MSG_UNIT_RESERVED_BY_OTHER_PREFIX = 'Unit ';
    public static final String MSG_UNIT_RESERVED_BY_OTHER_SUFFIX = ' is already Reserved by other user.';

    // Document Validation Messages
    public static final String DOC_STATUS_UPLOADED = 'Uploaded';
    public static final String DOC_ERR_NATIONALITY_REQUIRED = 'Nationality is required for Account. Please Populate the Nationality Before proceeding';
    public static final String DOC_ERR_ORG_AT_LEAST_ONE_PREFIX = 'At least one of the following documents is required: ';
    public static final String DOC_ERR_PERSON_AT_LEAST_ONE_PREFIX = 'At least one of the following documents is required: ';
    public static final String DOC_ERR_UNSUPPORTED_RECORD_TYPE_PREFIX = 'Unsupported record type: ';
    public static final String DOC_ERR_GENERIC_PREFIX = 'Error occurred: ';

    // Payment Plan Controller Messages — templates use {0}, {1}; build with .replace('{0}', ...).replace('{1}', ...)
    public static final String PP_ERR_INVALID_FREQUENCY = 'Invalid frequency: {0}. Valid values: Quarterly, Semi-Annual, Annual';
    public static final String PP_ERR_NO_8YEAR_MAPPING = 'No 8-year payment plan mapping found for this Unit with currency: {0}';
    public static final String PP_ERR_MODE_REQUIRED = 'Please select the Mode from dropdown. Valid values: By Amount, By Years, By Installments';
    public static final String PP_ERR_INSTALLMENT_AMOUNT_GT_ZERO = 'Please enter the Each Installment Amount greater than zero.';
    public static final String PP_ERR_PV_TOTAL_TOO_LOW = 'The computed plan present value is too low. Anchor present value: {0}.';
    public static final String PP_ERR_PV_TOTAL_TOO_HIGH = 'The computed plan present value is too high. Anchor present value: {0}.';
    public static final String PP_ERR_INSTALLMENT_LOWER_LIMIT = 'Please enter the Each Installment Amount greater than or equal to {0}';
    public static final String PP_ERR_INSTALLMENT_UPPER_LIMIT = 'Please enter the Each Installment Amount less than {0}';
    public static final String PP_ERR_YEARS_CAP = 'Please enter the Total Number of Years greater than {0}.';
    public static final String PP_ERR_COUNT_ZERO = 'Please enter the Total Installment Count greater than zero.';
    public static final String PP_ERR_INSTALLMENT_COUNT_CAP = 'Please enter the Total Installment Count less than {0}.';
    public static final String PP_ERR_INSTALLMENT_MIN = 'Please enter the Total Installment Count greater than or equal to 1.';
    public static final Map<String, String> PP_ERR_INSTALLMENT_COUNT_CAP_SUFFIX_BY_FREQUENCY = new Map<String, String>{
        FREQ_QUARTERLY   => ' for Quarterly Payment Plan',
        FREQ_SEMI_ANNUAL => ' for Semi-Annual Payment Plan',
        FREQ_ANNUAL      => ' for Annual Payment Plan'
    };
    public static final String PP_ERR_INVALID_MAINT_START = 'Please enter a whole number from 1 to {0} for the Maintenance Starting Installment Number.';
    public static final String PP_ERR_INVALID_MAINT_COUNT = 'Please enter a whole number from 1 to {0} for the Maintenance Installment Count.';
    public static final String PP_ERR_DOWNPAYMENT_PCT_BELOW_MIN = 'Please enter the Downpayment % greater than or equal to {0}%.';
    public static final String PP_ERR_DOWNPAYMENT_AMOUNT_BELOW_MIN = 'Please enter the Downpayment Amount greater than or equal to {0}';
    public static final String PP_ERR_DOWNPAYMENT_AMOUNT_ABOVE_MAX = 'Please enter the Downpayment Amount less than {0}';
    public static final String PP_ERR_DOWNPAYMENT_PCT_ABOVE_MAX = 'Please enter the Downpayment % less than or equal to {0}%.';
    public static final String PP_ERR_INVALID_MODE = 'Invalid mode: {0}. Valid values: By Amount, By Years, By Installments';
    public static final String PP_ERR_INVALID_PLAN_TYPE = 'Invalid plan type: {0}. Valid values: Standard, Flexible';
    public static final String PP_ERR_AMOUNT_TOO_SMALL = 'Each Installment Amount too small — would require 120+ installments. Please increase the Each Installment Amount.';

    // Block Request Defaults
    public static final String BLOCK_COMMENT_WITH_FEE = 'Block Request With Fee';

    //User Constants
    public static final String MODON_EGYPT_SALES_MANAGEMENT_PROFILE_NAME = 'Modon Egypt - Sales Management';

    // Manage Inventory Controller Constants
    public static final String INVENTORY_KEY_LABEL = 'label';
    public static final String INVENTORY_KEY_VALUE = 'value';
    public static final String INVENTORY_KEY_CURRENCY = 'CurrencyIsoCode';
    public static final String INVENTORY_ERROR_FETCH_FIELDS = 'Error fetching fields from layout: ';
    public static final String INVENTORY_STATUS_DRAFT = 'Draft';
    public static final String INVENTORY_STATUS_UNRELEASED = 'UnReleased';
    public static final String INVENTORY_STATUS_RELEASED = 'Released';
    public static final String INVENTORY_UNIT_STATUS_AVAILABLE = 'Available';
    public static final String INVENTORY_SUBSTATUS_ASSIGNED = 'Assigned';
    public static final String INVENTORY_SUBSTATUS_UNASSIGNED = 'Un-Assigned';
    public static final String INVENTORY_ACTION_DRAFT = 'Draft';
    public static final String INVENTORY_ACTION_UNRELEASE = 'UnRelease';
    public static final String INVENTORY_ACTION_RELEASE = 'Release';
    public static final String INVENTORY_ACTION_ASSIGN = 'Assign';
    public static final String INVENTORY_ACTION_UNASSIGN = 'Un-Assign';
    public static final String INVENTORY_ACTION_BUCKET = 'Bucket';
    public static final String INVENTORY_UNLIMITED = 'Unlimited';
    public static final String INVENTORY_MIN_SUFFIX = 'Min';
    public static final String INVENTORY_SUCCESS = 'SUCCESS';
    public static final String INVENTORY_EMPTY_STRING = '';

    // Manage Bucket LWC Controller Constants
    public static final String BUCKET_INTERNAL = 'Internal';
    public static final String BUCKET_BROKER = 'Broker';
    public static final String BUCKET_PARTNER = 'Partner';
    public static final String BUCKET_USER_TYPE_STANDARD = 'Standard';
    public static final String BUCKET_USER_TYPE_POWER_PARTNER = 'PowerPartner';
    public static final String BUCKET_USER_TYPE_PARTNER = 'Partner';
    public static final String BUCKET_PROFILE_LIKE_EGYPT = '%Egypt%';
    public static final String BUCKET_ERR_BUCKET_USER_REQUIRED = 'Bucket and at least one User are required.';
    public static final String BUCKET_GROUP_TYPE_REGULAR = 'Regular';
    public static final String BUCKET_LICENSE_SF = 'Salesforce';
    public static final String BUCKET_LICENSES_PARTNER = 'Partner Community Login\', \'Partner Community'; // used to concatenate into SOQL IN clause
   //V1.5 Added Mode of Payment Constant
    public static final String MODE_OF_PAYMENT_CHEQUE = 'Cheque';

    // Currency Constants v1.6
    public static final String CURRENCY_ISOCODE_AED = 'AED';
    public static final String CURRENCY_ISOCODE_USD = 'USD';
    public static final String CURRENCY_ISOCODE_EGP = 'EGP';
    public static final String CURRENCY_ISOCODE_SAR = 'SAR';
    public static final String CURRENCY_ISOCODE_EUR = 'EUR';

    public static final String CURRENCY_UNIT = 'currencyUnit';
    public static final String CURRENCY_SUB_UNIT = 'currencySubUnit';

    public static final String CURRENCY_UNIT_EGP_POUND = 'egyptian pound';
    public static final String CURRENCY_SUB_UNIT_PIASTRES = 'piastres';
    public static final String CURRENCY_UNIT_DIRHAM = 'dirhams';
    public static final String CURRENCY_SUB_UNIT_FILS = 'fils';
    public static final String CURRENCY_UNIT_EGP_US_DOLLAR = 'us dollar';
    public static final String CURRENCY_SUB_UNIT_CENTS = 'cents';
    public static final String CURRENCY_UNIT_EGP_EURO = 'euro';
    public static final String CURRENCY_UNIT_EGP_SAUDI_RIYAL = 'saudi riyal';
    public static final String CURRENCY_SUB_UNIT_HALALAS = 'halalas';

    public static final String LABEL_ONLY_ENGLISH = 'Only';
    public static final String LABEL_ZERO_ENGLISH = 'Zero';
    public static final String LABEL_AND_ENGLISH = 'And';
    public static final String LABEL_SQUARE_METER_ENGLISH = 'Square Meter';
    public static final String LABEL_SQUARE_CENTIMETER_ENGLISH = 'Square Centimeter';

    //v1.8 Arabic currency labels (amount in words API defaults to UAE dirham / fils; replace with these per ISO code)
    public static final String CURRENCY_AR_API_DEFAULT_UNIT = 'درهماً إماراتياً';
    public static final String CURRENCY_AR_API_DEFAULT_SUBUNIT = 'فلس';

    public static final String CURRENCY_AR_UNIT_EMIRATI = 'إماراتيي';

    public static final String CURRENCY_AR_UNIT_AED = 'درهم إماراتي';
    public static final String CURRENCY_AR_SUBUNIT_AED = 'فلس';

    public static final String CURRENCY_AR_UNIT_EGP = 'جنيه مصري';
    public static final String CURRENCY_AR_SUBUNIT_EGP = 'قروش';

    public static final String CURRENCY_AR_UNIT_USD = 'دولار أمريكي';
    public static final String CURRENCY_AR_SUBUNIT_USD = 'سنت';

    public static final String CURRENCY_AR_UNIT_EUR = 'يورو';
    public static final String CURRENCY_AR_SUBUNIT_EUR = 'سنت';

    public static final String CURRENCY_AR_UNIT_SAR = 'ريال سعودي';
    public static final String CURRENCY_AR_SUBUNIT_SAR = 'هللة';

    public static final String AREA_AR_SQ_MTR = 'متر مربع';
    public static final String AREA_AR_SQ_CMTR = 'سنتيمتر مربع';

    public static final String AREA_AR_ZERO_SQ_MTR = 'صفر متر مربع';

    public static final String LABEL_ONLY_AR = ' فقط';
    public static final String LABEL_LANGUAGE_ENGLISH = 'English';
    public static final String LABEL_LANGUAGE_ARABIC = 'Arabic';
     
    //Oracle Constants
    public static final String ORACLE_INTEGRATION_STATUS_PENDING = 'Pending';
    public static final String ORACLE_INTEGRATION_STATUS_FAILED = 'Failed';
    public static final String ORACLE_INTEGRATION_STATUS_FAILURE = 'Failure';
    public static final String ORACLE_INTEGRATION_STATUS_SUCCESS = 'Success';
    public static final String ORACLE_INTEGRATION_APPLY_RECEIPT_STATUS_APPLIED = 'Applied';
    public static final String ORACLE_INTEGRATION_APPLY_RECEIPT_STATUS_UNAPPLIED = 'Unapplied';
    public static final String ORACLE_INTEGRATION_STATUS_CODE_500 = '500';
    public static final String ORACLE_INTEGRATION_STATUS_CODE_200 = '200';
    public static final String ORACLE_INTEGRATION_STATUS_CODE_400 = '400';
    public static final String ORACLE_INTEGRATION_MESSAGE_INSERT_PENDING = 'Oracle insert sync pending';
    public static final String ORACLE_INTEGRATION_MESSAGE_UPDATE_PENDING = 'Oracle update sync pending';
    public static final String ORACLE_INTEGRATION_MESSAGE_RECEIPT_APPLY_PENDING = 'Oracle receipt apply sync pending';
    public static final String ORACLE_INTEGRATION_MESSAGE_CREDS_NOT_AVAILABLE = 'Invalid Credentials or Credentials are not available in metadata records';
    public static final String ORACLE_INTEGRATION_ACCOUNT_ADDRESS_SET = '300000002800197';
    public static final String BUSINESS_UNIT = 'RAS EL HEKMA-EGYPT-BU';
    /**
     * @description Delay in minutes before Egypt_SwapCleanupScheduler executes 
     *              to update Allocation Oracle apply status, allowing rollup 
     *              and trigger execution on parent records to fully settle.
     */
    public static final Integer SWAP_DELAY_MINUTES = 2;
    public static final String EOI_STATUS_CONFIRMED = 'EOI Confirmed';
    public static final String EOI_RECEIPT = 'EOI Receipt';
    public static final String MODON_EGYPT_INTEGRATION_PROFILE = 'Modon Egypt - Salesforce Integration Profile';
    public static final String MODON_EGYPT_INTEGRATION_USER = 'Integration User (Modon - Egypt)';


    //PickList Values - SalesOrder - Status
    public static final String SALES_ORDER_STATUS_DOWNPAYMENT_COLLECTED = 'Down payment collected';
    public static final String SALES_ORDER_STATUS_SPA_SIGNED_CUSTOMER = 'SPA Signed (Customer)';
    public static final String SALES_ORDER_STATUS_PENDING_BLOCKING_FEES = 'Pending Blocking Fees';
    public static final String SALES_ORDER_STATUS_BLOCKING_FEES_COLLECTED = 'Blocking Fees Collected';
    public static final String SALES_ORDER_STATUS_DOWNPAYMENT_CLEARED = 'Downpayment Payments Cleared';
    public static final String SALES_ORDER_STATUS_VOIDED = 'Voided';
    public static final String SALES_ORDER_STATUS_CANCELLED = 'Cancelled';
    public static final String SALES_ORDER_STATUS_SYSTEM_CANCELLED = 'System Cancelled';


    // PickList Values - Unit - Status
    public static final String STATUS_AVAILABLE = 'Available';
    public static final String STATUS_RESERVED = 'Reserved';
    public static final String STATUS_CANCELLED = 'Cancelled';
    public static final String STATUS_SYSTEM_CANCELLED = 'System Cancelled';
    public static final String STATUS_VOIDED = 'Voided';
    public static final String STATUS_PENDING_BLOCKING_FEES = 'Pending Blocking Fees';
    public static final String STATUS_IN_PROGRESS = 'In Progress';

    // PickList Values - Unit - SubStatus
    public static final String SUBSTATUS_UNASSIGNED = 'Un-Assigned';
    public static final String SUBSTATUS_ASSIGNED = 'Assigned';
    public static final String APPROVAL_STATUS_RELEASED = 'Released';

    public static final string API_OBJ_UNIT = 'Unit__c';
    public static final string API_FIELD_UNIT_CLASSIFICATION = 'UnitClassification__c';
    public static final string API_FIELD_NUMBER_OF_BEDROOMS = 'Number_of_Bedrooms__c';

    public static final string MODON_EGYPT_SALES_ASSOCIATE_ROLE_SUBSTR = 'Sales Associate';

    // Rcord Types - Invoice__c
    public static final string INVOICE_RECORD_TYPE_TAX_INVOICE = 'Tax_Invoice';
    public static final string INVOICE_RECORD_TYPE_CREDIT_MEMO = 'Credit_Memo';
    public static final string INVOICE_RECORD_TYPE_DEBIT_MEMO = 'Debit_Memo';

    //Allocation__c Status__c
    public static final String ALLOCATION_STATUS_APPLIED = 'Applied';
    public static final String ALLOCATION_STATUS_UNAPPLIED = 'Unapplied';

    //SalesOrderInstallments__c PaymentStatus__c
    public static final String SALES_ORDER_INSTALLMENT_PAYMENT_STATUS_PAID = 'Paid';
    public static final String SALES_ORDER_INSTALLMENT_PAYMENT_STATUS_PARTIALLY_PAID = 'Partially Paid';
    public static final String SALES_ORDER_INSTALLMENT_PAYMENT_STATUS_NOT_PAID = 'Not Paid';

    //Egypt Sales Operations Queue Developer Name
    public static final String EGYPT_SALES_OPERATIONS_QUEUE = 'Egypt_Sales_Operations_Queue';

    // Egypt Broker portal Constant : START
    public static final string EGYPT_LIMITED_LOGIN_ACCESS = 'Egypt_Limited_Login_Access';
    public static final string EGYPT_AGENT_ACCESS         = 'Egypt_Agent_Access';
    public static final string EGYPT_AGENCY_ADMIN_ACCESS = 'Egypt_Agency_Admin_Access';
    public static final String PROFILE_EGYPT_SALES_MANAGEMENT = 'Modon Egypt - Sales Management';
    public static final String ROLE_EGYPT_SALES_ASSOCIATE = 'Modon Egypt - Sales Associate';

    public static final String LEAD_ASSIGNMENT_CLASSIFICATION_OPEN = 'Open';
    public static final String LEAD_ASSIGNMENT_CLASSIFICATION_1_1_EXCLUSIVE = '1:1 Exclusive';
    public static final String LEAD_ASSIGNMENT_CLASSIFICATION_ROUND_ROBIN = 'Round Robin';

    public static final String USERNAME_DOMAIN = '@raselhekmaportal.com';
    public static final String RT_ACCOUNT_BROKER_AGENCY = 'Broker Agency';
    public static final String RT_CONTACT_BROKER_AGENT = 'Broker Agent';
    public static final String COMMUNITY_PROFILE_NAME = 'Modon Egypt - Partner Community User';
    public static final String STATUS_PENDING_VERIFICATION = 'Pending Verification';
    public static final String STATUS_ACTIVE = 'Active';
    public static final String STATUS_BLOCKED = 'Blocked';
    public static final String STATUS_INACTIVE = 'In Active';
    public static final String BROKER_TYPE_AGENCY_ADMIN = 'Agency Admin';
    public static final String BROKER_TYPE_AGENT = 'Agent';
    public static final String LEAD_SOURCE_BROKER_PORTAL = 'Broker Portal';
    // Egypt Broker portal Constant : END

    //1.18
    public static final Set<String> RECEIPT_DUPLICATE_CHECK_STATUSES = new Set<String>{
        'In Progress',
        'Cleared'
    };
}