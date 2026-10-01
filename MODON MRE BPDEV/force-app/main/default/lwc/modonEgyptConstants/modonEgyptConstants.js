/**
* @description       : Centralized constants for Modon Egypt LWCs
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 03-03-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   03-03-2026   Milin Kapatel      Initial Version
* 1.1   05-03-2026   Milin Kapatel      Added constant Multiseect Picklist Component
* 1.2   07-04-2026   Milin Kapatel      Added flexible payment plan constants
* 1.3   20-04-2026   Milin Kapatel      Updated column configuration for unit search lwc
* 1.4   20-04-2026   Mirza Baig         Updated column configuration for unit search lwc and added a constant for unit status 'CCMD'
* 1.5   02-05-2026   Mirza Baig         Added constants for Add Joint Owner functionality
* 1.6   14-07-2026   Mirza Baig         Added Generic constants for all option dropdown
* 1.7   12-08-2026   Shahil Sinha       Added UnitUrl column config for opening units natively in a new tab (commented for reference)
**/

const COL_WIDTH_DEFAULT = 160;
const COL_WIDTH_LARGE = 300;


export const CONSTANTS = {
    // Centralized single-level constants for Modon Egypt LWCs

    // ::::: UTILITIES :::::

    SUCCESS_UPPER: 'SUCCESS',
    SUCCESS_LOWER: 'success',
    SUCCESS_NORMAL: 'Success',
    ERROR_UPPER: 'ERROR',
    ERROR_LOWER: 'error',
    ERROR_NORMAL: 'Error',
    CANCEL_UPPER: 'CANCEL',
    CANCEL_LOWER: 'cancel',
    CANCEL_NORMAL: 'Cancel',

    BUTTON_BACK: 'Back',
    BUTTON_FORWARD: 'Forward',
    BUTTON_PROCEED: 'Proceed',
    BUTTON_REFRESH: 'Refresh',
    BUTTON_SAVE: 'Save',
    BUTTON_CANCEL: 'Cancel',
    BUTTON_CLOSE: 'Close',

    EMPTY_STRING: '',

    // ::::: MANAGE INVENTORY :::::

    // Entity and source
    MANAGE_INVENTORY_ENTITY_SOURCE_MODON_EGYPT: 'Modon - Egypt',

    // Column configuration
    MANAGE_INVENTORY_COLUMNS: [
        {
            label: 'Name',
            fieldName: 'UnitUrl',
            sortable: true,
            initialWidth: COL_WIDTH_DEFAULT,
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            },
            hideDefaultActions: true
        },
        /* 
        // Previous logic: Opened a modal when clicking the Unit Name
        {
            label: 'Name',
            fieldName: 'Name',
            sortable: true,
            initialWidth: COL_WIDTH_DEFAULT,
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'Name' },
                name: 'viewUnit',
                variant: 'base'
            },
            hideDefaultActions: true
        },
        */
        { label: 'Approval Status', fieldName: 'ApprovalStatus', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Status', fieldName: 'Status', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Sub Status', fieldName: 'Sub_Status', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Price in Currency', fieldName: 'Price', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Bucket', fieldName: 'Bucket', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Blocked For', fieldName: 'BlockedFor', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_LARGE },
        {
            label: 'Block Until', fieldName: 'BlockUntil',
            type: "date-local", typeAttributes: {
                month: "2-digit",
                day: "2-digit"
            }, sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT
        },
        { label: 'Unit Type', fieldName: 'UnitClassification', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Typology', fieldName: 'Typology', sortable: false, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },//v1.4
        { label: 'Number of Bedrooms', fieldName: 'Number_of_Bedrooms', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Unit Quality', fieldName: 'Unit_Quality', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Gross Floor Area', fieldName: 'GrossFloorAreaGFA', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Floor', fieldName: 'FloorNumber', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Zone', fieldName: 'Zone', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Building Name', fieldName: 'BuildingName', sortable: false, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Phase', fieldName: 'Phase', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_DEFAULT },
        { label: 'Project', fieldName: 'Project', sortable: true, hideDefaultActions: true, initialWidth: COL_WIDTH_LARGE },
    ],

    // UI labels (datatable columns and general UI)
    MANAGE_INVENTORY_LABELS_NAME: 'Name',
    MANAGE_INVENTORY_LABELS_APPROVAL_STATUS: 'Approval Status',
    MANAGE_INVENTORY_LABELS_STATUS: 'Status',
    MANAGE_INVENTORY_LABELS_SUB_STATUS: 'Sub Status',
    MANAGE_INVENTORY_LABELS_PRICE_IN_CURRENCY: 'Price in Currency',
    MANAGE_INVENTORY_LABELS_BUCKET: 'Bucket',
    MANAGE_INVENTORY_LABELS_BLOCKED_FOR: 'Blocked For',
    MANAGE_INVENTORY_LABELS_BLOCK_UNTIL: 'Block Until',
    MANAGE_INVENTORY_LABELS_UNIT_TYPE: 'Unit Type',
    MANAGE_INVENTORY_LABELS_NUMBER_OF_BEDROOMS: 'Number of Bedrooms',
    MANAGE_INVENTORY_LABELS_UNIT_QUALITY: 'Unit Quality',
    MANAGE_INVENTORY_LABELS_GFA: 'Gross Floor Area',
    MANAGE_INVENTORY_LABELS_FLOOR: 'Floor',
    MANAGE_INVENTORY_LABELS_ZONE: 'Zone',
    MANAGE_INVENTORY_LABELS_PHASE: 'Phase',
    MANAGE_INVENTORY_LABELS_PROJECT: 'Project',
    MANAGE_INVENTORY_LABELS_VIEW_UNIT: 'viewUnit',
    MANAGE_INVENTORY_LABELS_VIEW_UNIT_VARIANT: 'base',

    // Field names used in columns
    MANAGE_INVENTORY_FIELD_NAMES_PROJECT: 'Project',
    MANAGE_INVENTORY_FIELD_NAMES_PHASE: 'Phase',
    MANAGE_INVENTORY_FIELD_NAMES_BUCKET: 'Bucket',
    MANAGE_INVENTORY_FIELD_NAMES_UNIT_CLASSIFICATION: 'UnitClassification',
    MANAGE_INVENTORY_FIELD_NAMES_NUMBER_OF_BEDROOMS: 'Number_of_Bedrooms',
    MANAGE_INVENTORY_FIELD_NAMES_APPROVAL_STATUS: 'ApprovalStatus',
    MANAGE_INVENTORY_FIELD_NAMES_STATUS: 'Status',
    MANAGE_INVENTORY_FIELD_NAMES_SUB_STATUS: 'Sub_Status',
    MANAGE_INVENTORY_FIELD_NAMES_UNIT_QUALITY: 'Unit_Quality',
    MANAGE_INVENTORY_FIELD_NAMES_GFA: 'GrossFloorAreaGFA',
    MANAGE_INVENTORY_FIELD_NAMES_FLOOR: 'FloorNumber',
    MANAGE_INVENTORY_FIELD_NAMES_NAME: 'Name',
    MANAGE_INVENTORY_FIELD_NAMES_ZONE: 'Zone',
    MANAGE_INVENTORY_FIELD_NAMES_BLOCK_UNTIL: 'BlockUntil',
    MANAGE_INVENTORY_FIELD_NAMES_BLOCKED_FOR: 'BlockedFor',
    MANAGE_INVENTORY_FIELD_NAMES_PRICE: 'Price',

    MANAGE_INVENTORY_SORT_DIRECTIONS_ASC: 'asc',
    MANAGE_INVENTORY_SORT_DIRECTIONS_DESC: 'desc',


    // Types
    MANAGE_INVENTORY_TYPES_DATE_LOCAL: 'date-local',
    MANAGE_INVENTORY_TYPES_BUTTON: 'button',

    // Date formats
    MANAGE_INVENTORY_DATE_FORMATS_MONTH_2_DIGIT: '2-digit',
    MANAGE_INVENTORY_DATE_FORMATS_DAY_2_DIGIT: '2-digit',

    // Generic "-- All --" option for picklists
    MANAGE_INVENTORY_ALL_OPTION_LABEL: '-- All --',
    MANAGE_INVENTORY_ALL_OPTION_VALUE: '',

    // Filter names (used with event.target.name)
    MANAGE_INVENTORY_FILTER_NAMES_PROJECT: 'Project',
    MANAGE_INVENTORY_FILTER_NAMES_PHASE: 'Phase',
    MANAGE_INVENTORY_FILTER_NAMES_BUCKET: 'Bucket',
    MANAGE_INVENTORY_FILTER_NAMES_UNIT_CLASSIFICATION: 'Unit Classification',
    MANAGE_INVENTORY_FILTER_NAMES_NUMBER_OF_BEDROOMS: 'Number of Bedrooms',
    MANAGE_INVENTORY_FILTER_NAMES_APPROVAL_STATUS: 'Approval Status',
    MANAGE_INVENTORY_FILTER_NAMES_STATUS: 'Status',
    MANAGE_INVENTORY_FILTER_NAMES_SUB_STATUS: 'Sub Status',
    MANAGE_INVENTORY_FILTER_NAMES_UNIT_QUALITY: 'Unit Quality',
    MANAGE_INVENTORY_FILTER_NAMES_GFA: 'GFA',
    MANAGE_INVENTORY_FILTER_NAMES_FLOOR: 'Floor',
    MANAGE_INVENTORY_FILTER_NAMES_CURRENCY: 'Currency',
    MANAGE_INVENTORY_FILTER_NAMES_NAME: 'Name',
    MANAGE_INVENTORY_FILTER_NAMES_ZONE: 'Zone',
    // Status values used throughout logic
    MANAGE_INVENTORY_STATUSES_APPROVAL_DRAFT: 'Draft',
    MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED: 'Released',
    MANAGE_INVENTORY_STATUSES_APPROVAL_UNRELEASED: 'UnReleased',
    MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE: 'Available',
    MANAGE_INVENTORY_STATUSES_STATUS_CCMD: 'CCMD',//v1.4
    MANAGE_INVENTORY_STATUSES_SUB_STATUS_ASSIGNED: 'Assigned',
    MANAGE_INVENTORY_STATUSES_SUB_STATUS_UN_ASSIGNED: 'Un-Assigned',

    // Actions
    MANAGE_INVENTORY_ACTIONS_RELEASE: 'Release',
    MANAGE_INVENTORY_ACTIONS_ASSIGN: 'Assign',

    // Toast fragments
    MANAGE_INVENTORY_TOAST_SUCCESS: 'Success',
    MANAGE_INVENTORY_TOAST_ERROR: 'Error',
    MANAGE_INVENTORY_TOAST_DISMISSABLE: 'dismissable',
    MANAGE_INVENTORY_TOAST_STICKY: 'sticky',
    MANAGE_INVENTORY_TOAST_FETCH_PROJECT_VALUES_TITLE: 'Error fetching project values',
    MANAGE_INVENTORY_TOAST_FETCH_PROJECT_VALUES_MSG: 'Not able to fetch project values',
    MANAGE_INVENTORY_TOAST_FETCH_PHASE_VALUES_TITLE: 'Error fetching phase values',
    MANAGE_INVENTORY_TOAST_FETCH_PHASE_VALUES_MSG: 'Not able to fetch phase values',
    MANAGE_INVENTORY_TOAST_FETCH_FILTER_VALUES_TITLE: 'Error fetching filter values',
    MANAGE_INVENTORY_TOAST_FETCH_FILTER_VALUES_MSG: 'Not able to fetch filter values',
    MANAGE_INVENTORY_TOAST_FETCH_HOURS_TO_BLOCK_TITLE: 'Error fetching picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_HOURS_TO_BLOCK_MSG: 'Not able to fetch Hours To Block picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_UNIT_CLASSIFICATION_TITLE: 'Error fetching picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_UNIT_CLASSIFICATION_MSG: 'Not able to fetch Unit Classification picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_NUMBER_OF_BEDROOMS_TITLE: 'Error fetching picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_NUMBER_OF_BEDROOMS_MSG: 'Not able to fetch Number of Bedrooms picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_APPROVAL_STATUS_TITLE: 'Error fetching picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_APPROVAL_STATUS_MSG: 'Not able to fetch Approval Status picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_STATUS_TITLE: 'Error fetching picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_STATUS_MSG: 'Not able to fetch Status picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_SUB_STATUS_TITLE: 'Error fetching picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_SUB_STATUS_MSG: 'Not able to fetch Sub Status picklist values',
    MANAGE_INVENTORY_TOAST_FETCH_UNIT_LIST_TITLE: 'Error fetching unit list',
    MANAGE_INVENTORY_TOAST_FETCH_UNIT_LIST_MSG: 'Not able to fetch unit list',
    MANAGE_INVENTORY_TOAST_UNIT_UPDATE_SUCCESS_TITLE: 'Success',
    MANAGE_INVENTORY_TOAST_UNIT_UPDATE_SUCCESS_MSG: 'Unit record updated successfully',
    MANAGE_INVENTORY_TOAST_UNIT_UPDATE_ERROR_TITLE: 'Error',
    MANAGE_INVENTORY_TOAST_UNIT_UPDATE_ERROR_MSG: 'Unable to update unit record',
    MANAGE_INVENTORY_TOAST_ACTION_PERFORMED_SUCCESS_TITLE: 'Success',
    MANAGE_INVENTORY_TOAST_ACTION_PERFORMED_SUCCESS_MSG: 'Action performed successfully',
    MANAGE_INVENTORY_TOAST_ACTION_PERFORMED_ERROR_TITLE: 'Error',
    MANAGE_INVENTORY_TOAST_ACTION_PERFORMED_ERROR_MSG: 'Action failed',
    MANAGE_INVENTORY_TOAST_SAME_BUCKET_ERROR_TITLE: 'Error',
    MANAGE_INVENTORY_TOAST_SAME_BUCKET_ERROR_MSG: 'Please select units from the same bucket.',
    MANAGE_INVENTORY_TOAST_ASSIGNED_BUCKET_REQUIRED_ERROR_TITLE: 'Error',
    MANAGE_INVENTORY_TOAST_ASSIGNED_BUCKET_REQUIRED_ERROR_MSG: 'Please select units that are assigned to a bucket.',
    MANAGE_INVENTORY_TOAST_FETCH_UNIT_LAYOUT_ERROR_TITLE: 'Error fetching unit layout fields',
    MANAGE_INVENTORY_TOAST_FETCH_UNIT_LAYOUT_ERROR_MSG: 'Not able to fetch unit layout fields',

    // Miscellaneous business constants
    MANAGE_INVENTORY_BUSINESS_PRICE_PLAN_NAME_LIKE: '%8 Years%',
    MANAGE_INVENTORY_BUSINESS_UNLIMITED: 'Unlimited',

    // Client search fields
    MANAGE_INVENTORY_GLOBAL_SEARCH_FIELDS: [
        'Name',
        'Zone',
        'Phase',
        'Project',
        'Price',
        'Bucket',
        'BlockedFor',
        'BlockedBy',
        'BlockUntil',
        'UnitClassification',
        'Number_of_Bedrooms',
        'ApprovalStatus',
        'Status',
        'Sub_Status',
        'Unit_Quality',
        'GrossFloorAreaGFA',
        'FloorNumber',
        'Typology',
        'BuildingName'
    ],

    MANAGE_INVENTORY_DEBOUNCE_MS: 400,
    MANAGE_INVENTORY_DEBOUNCE_KEY_GLOBAL_SEARCH: 'globalSearch',
    MANAGE_INVENTORY_DEBOUNCE_KEY_NAME_SEARCH: 'nameSearch',
    MANAGE_INVENTORY_DEBOUNCE_KEY_ZONE_SEARCH: 'zoneSearch',

    MANAGE_INVENTORY_UNIT_API_NAME: 'Unit__c',
    MANAGE_INVENTORY_UNIT_EGYPT_LAYOUT: 'Unit Layout - Egypt',



    // Layout constants and UI measurements
    MANAGE_INVENTORY_LAYOUT_BREAKPOINT: 1024,
    MANAGE_INVENTORY_EMPTY_STRING: '',

    // ::::: MANAGE INVENTORY MODAL :::::

    MANAGE_INVENTORY_MODAL_ACTIONS_RELEASE: 'Release',
    MANAGE_INVENTORY_MODAL_ACTIONS_UNRELEASE: 'UnRelease',
    MANAGE_INVENTORY_MODAL_ACTIONS_BACK_TO_DRAFT: 'Back to Draft',
    MANAGE_INVENTORY_MODAL_ACTIONS_ASSIGN: 'Assign',
    MANAGE_INVENTORY_MODAL_ACTIONS_UN_ASSIGN: 'Un-Assign',
    MANAGE_INVENTORY_MODAL_ACTIONS_BUCKET_TRANSFER: 'Bucket Transfer',
    MANAGE_INVENTORY_MODAL_ACTIONS_BUCKET: 'Bucket',
    MANAGE_INVENTORY_MODAL_ACTIONS_DRAFT: 'Draft',

    MANAGE_INVENTORY_MODAL_UI_MODAL_HEADER_SELECT_OPTION: 'Please select an option',
    MANAGE_INVENTORY_MODAL_UI_MODAL_HEADER_UPDATE_UNIT_RECORD: 'Update Unit Record',

    MANAGE_INVENTORY_MODAL_FILTER_IDS_NEW_BUCKET_COMBOBOX: 'newBucketCombobox',
    MANAGE_INVENTORY_MODAL_FILTER_IDS_RELEASE_STATUS: 'releaseStatus',
    MANAGE_INVENTORY_MODAL_FILTER_IDS_USER_COMBOBOX: 'userCombobox',
    MANAGE_INVENTORY_MODAL_FILTER_IDS_HOURS_COMBOBOX: 'hoursCombobox',
    MANAGE_INVENTORY_MODAL_FILTER_IDS_BLOCK_COMMENTS_TEXTAREA: 'blockCommentsTextArea',

    MANAGE_INVENTORY_MODAL_RELEASE_STATUSES_ASSIGNED: 'Assigned',

    MANAGE_INVENTORY_MODAL_TOAST_ERROR_PARSING_JSON_TITLE: 'Error parsing JSON String',
    MANAGE_INVENTORY_MODAL_TOAST_ERROR_PARSING_JSON_MSG: 'Not able to parse the JSON string in the modal.',
    MANAGE_INVENTORY_MODAL_TOAST_ERROR_FETCHING_USERS_TITLE: 'Error fetching User values',
    MANAGE_INVENTORY_MODAL_TOAST_ERROR_FETCHING_USERS_MSG: 'Not able to fetch User values',
    MANAGE_INVENTORY_MODAL_TOAST_ERROR_FILL_ALL_FIELDS_TITLE: 'Error',
    MANAGE_INVENTORY_MODAL_TOAST_ERROR_FILL_ALL_FIELDS_MSG: 'Please fill all fields to proceed...',
    MANAGE_INVENTORY_MODAL_TOAST_ERROR_SELECT_BUCKET_TITLE: 'Error',
    MANAGE_INVENTORY_MODAL_TOAST_ERROR_SELECT_BUCKET_MSG: 'Please select a bucket',
    MANAGE_INVENTORY_MODAL_TOAST_ERROR_BUCKET_SAME_TITLE: 'Error',
    MANAGE_INVENTORY_MODAL_TOAST_ERROR_BUCKET_SAME_MSG: 'New Bucket can\'t be same as previous Bucket. Please select a different bucket',

    MANAGE_INVENTORY_MODAL_USER_ID_INITIALS: '005',
    MANAGE_INVENTORY_MODAL_EMPTY_STRING: '',

    // ::::: MANAGE BUCKET :::::

    MANAGE_BUCKET_VIEW_STATES_VIEW: 'view',
    MANAGE_BUCKET_VIEW_STATES_CREATE: 'create',
    MANAGE_BUCKET_VIEW_STATES_EDIT: 'edit',

    MANAGE_BUCKET_USER_TYPES_INTERNAL: 'Internal',
    MANAGE_BUCKET_USER_TYPES_BROKER: 'Broker',

    MANAGE_BUCKET_USER_TYPE_OPTIONS: [
        { label: 'Internal Users', value: 'Internal' },
        { label: 'Brokers', value: 'Broker' }
    ],

    MANAGE_BUCKET_BUTTONS_CREATE_BUCKET: 'CreateBucket',
    MANAGE_BUCKET_BUTTONS_EDIT_BUCKET: 'EditBucket',
    MANAGE_BUCKET_BUTTONS_CANCEL_NEW_BUCKET: 'cancelNewBucket',
    MANAGE_BUCKET_BUTTONS_CANCEL_EDIT_BUCKET: 'cancelEditBucket',
    MANAGE_BUCKET_BUTTONS_SAVE_NEW_BUCKET: 'saveNewBucket',
    MANAGE_BUCKET_BUTTONS_SAVE_UPDATED_BUCKET: 'saveUpdatedBucket',

    MANAGE_BUCKET_LABELS_INTERNAL_USERS: 'Internal Users',
    MANAGE_BUCKET_LABELS_BROKERS: 'Brokers',
    MANAGE_BUCKET_LABELS_HIDE_USERS: 'Hide Users',
    MANAGE_BUCKET_LABELS_SHOW_USERS: 'Show Users',
    MANAGE_BUCKET_LABELS_SAVE: 'Save',
    MANAGE_BUCKET_LABELS_NEXT: 'Next>>',
    MANAGE_BUCKET_LABELS_NO_BUCKET_SELECTED_TITLE: 'No bucket selected',
    MANAGE_BUCKET_LABELS_NO_BUCKET_SELECTED_MSG: 'Please select a bucket first.',
    MANAGE_BUCKET_LABELS_NO_USERS_SELECTED_TITLE: 'No users selected',
    MANAGE_BUCKET_LABELS_NO_USERS_SELECTED_MSG: 'Select at least one user to add.',
    MANAGE_BUCKET_LABELS_SUCCESS_TITLE: 'Success',
    MANAGE_BUCKET_LABELS_USERS_ADDED_MSG: 'Users added to the bucket.',
    MANAGE_BUCKET_LABELS_ERROR_TITLE: 'Error',
    MANAGE_BUCKET_LABELS_FAILED_TO_ADD_USERS_MSG: 'Failed to add users to the bucket.',

    MANAGE_BUCKET_TOAST_VARIANTS_SUCCESS: 'success',
    MANAGE_BUCKET_TOAST_VARIANTS_WARNING: 'warning',
    MANAGE_BUCKET_TOAST_VARIANTS_ERROR: 'error',
    MANAGE_BUCKET_TOAST_TITLE_SUCCESS: 'Success',
    MANAGE_BUCKET_TOAST_TITLE_WARNING: 'Warning',
    MANAGE_BUCKET_TOAST_TITLE_ERROR: 'Error',
    MANAGE_BUCKET_TOAST_MESSAGE_SUCCESS_CREATE: 'Bucket created successfully',
    MANAGE_BUCKET_TOAST_MESSAGE_SUCCESS_UPDATE: 'Bucket updated successfully',
    MANAGE_BUCKET_TOAST_TITLE_ERROR_LOADING_USERS: 'Error loading users',
    MANAGE_BUCKET_TOAST_MESSAGE_ERROR_LOADING_USERS: 'Not able to fetch users',
    MANAGE_BUCKET_TOAST_TITLE_ERROR_LOADING_BUCKETS: 'Error loading buckets',
    MANAGE_BUCKET_TOAST_MESSAGE_ERROR_LOADING_BUCKETS: 'Not able to fetch buckets',

    MANAGE_BUCKET_EMPTY_STRING: '',
    MANAGE_BUCKET_CUSTOM_EVENT_BUCKET_SELECT: 'bucketselect',

    // ::::: CREATE NEW BUCKET :::::

    CREATE_NEW_BUCKET_LIGHTNING_INPUT_TAG: 'lightning-input',

    CREATE_NEW_BUCKET_EVENTS_SAVE: 'savenewbucket',
    CREATE_NEW_BUCKET_EVENTS_CANCEL: 'cancelnewbucket',

    CREATE_NEW_BUCKET_USER_TYPES_ALL: 'All',
    CREATE_NEW_BUCKET_USER_TYPES_INTERNAL: 'Internal',
    CREATE_NEW_BUCKET_USER_TYPES_BROKER: 'Broker',

    CREATE_NEW_BUCKET_USER_TYPE_OPTIONS: [
        { label: 'All', value: 'All' },
        { label: 'Internal Users', value: 'Internal' },
        { label: 'Brokers', value: 'Broker' }
    ],

    CREATE_NEW_BUCKET_AVAILABLE_USER_COLUMNS: [
        { label: 'User Name', fieldName: 'Name', hideDefaultActions: true },
        { label: 'Profile', fieldName: 'profileName', hideDefaultActions: true },
        { label: 'Broker Agency', fieldName: '', hideDefaultActions: true }
    ],

    CREATE_NEW_BUCKET_LABELS_EDIT_BUCKET: 'Edit Bucket',
    CREATE_NEW_BUCKET_LABELS_CREATE_NEW_BUCKET: 'Create New Bucket',
    CREATE_NEW_BUCKET_LABELS_ERROR_TITLE: 'Error',
    CREATE_NEW_BUCKET_LABELS_FIELD_INVALID_MSG: 'Field cannot be empty or contain special characters!',
    CREATE_NEW_BUCKET_LABELS_SELECT_ONE_USER_MSG: 'Please select at least one user',
    CREATE_NEW_BUCKET_LABELS_SELECTED_USER_TYPE: 'selectedUserType',

    CREATE_NEW_BUCKET_TOAST_VARIANTS_SUCCESS: 'success',
    CREATE_NEW_BUCKET_TOAST_VARIANTS_ERROR: 'error',

    CREATE_NEW_BUCKET_LISTBOX_CLASSES_OPTION_BASE:
        'slds-listbox__option slds-listbox__option_plain slds-media slds-media_small slds-media_inline ',
    CREATE_NEW_BUCKET_LISTBOX_CLASSES_SELECTED_SUFFIX: ' slds-is-selected',
    CREATE_NEW_BUCKET_EMPTY_STRING: '',

    // ::::: MULTI SELECT PICKLIST COMPONENT :::::

    MULTI_SELECT_EVENTS_USER_SELECTION: 'userselection',
    MULTI_SELECT_SEARCH_DEBOUNCE_MS: 500,
    MULTI_SELECT_LISTBOX_CLASSES_OPTION_BASE:
        'slds-listbox__option slds-listbox__option_plain slds-media slds-media_small slds-media_inline ',
    MULTI_SELECT_LISTBOX_CLASSES_SELECTED_SUFFIX: ' slds-is-selected',
    //v1.1
    MULTI_SELECT_DEBOUCE_SEARCH_KEY: 'multiSelectSearch',
    MULTI_SELECT_EMPTY_STRING: '',
}

export const MODON_EGYPT_OPERATION_PROFILE = 'Modon Egypt - Sales Operations';

export const UNIT_SEARCH_BASE_COLUMNS = [
    {
        label: 'Milestone #',
        fieldName: 'milestoneNumber',
        type: 'number',
        hideDefaultActions: true,
        initialWidth: 50
    },
    {
        label: 'Milestone',
        fieldName: 'milestoneDescription',
        type: 'text',
        hideDefaultActions: true,
        initialWidth: 130
    },
    {
        label: 'Installment Percentage',
        fieldName: 'milestoneEgyptPercentText',
        type: 'text',
        hideDefaultActions: true,
        initialWidth: 150
    },
    {
        label: 'Maintenance Fees', 
        fieldName: 'maintainancefeeText',
        type: 'text',
        hideDefaultActions: true,
        initialWidth: 150
    },
    {
        label: 'Installment amount', 
        fieldName: 'amountText',
        type: 'text',
        hideDefaultActions: true,
        initialWidth: 150
    },
    {
        label: 'Installment Date', 
        fieldName: 'milestoneDate',
        type: 'date-local',
        hideDefaultActions: true,
        typeAttributes: {
            year: '2-digit',
            month: '2-digit',
            day: '2-digit'
        },
        minColumnWidth: 120
    }
];

//v1.5
export const ADD_JOINT_OWNERS_COLUMNS = [
    { label: 'Name', fieldName: 'name', type: 'text', hideDefaultActions: true },
    { 
        label: 'Ownership %', 
        fieldName: 'ownership', 
        type: 'number',
        editable: true,
        cellAttributes: { alignment: 'left' },
        hideDefaultActions: true
    }
];

export const ERROR_TOTAL_EXCEED = 'The total ownership must not exceed 100%';//v1.5

export const EGYPT_MANAGE_INVENTORY_CONSTANTS = {
    PAGE_SIZE: 50,
    SEARCH_DELAY: 300,
    MOBILE_BREAKPOINT: 768,
    GFA_RANGES: [
        { label: '0 – 200 sqm',   min: 0,    max: 200  },
        { label: '200 – 400 sqm', min: 200,  max: 400  },
        { label: '400 – 600 sqm', min: 400,  max: 600  },
        { label: '600 – 800 sqm', min: 600,  max: 800  },
        { label: '800 – 1000 sqm',min: 800,  max: 1000 },
        { label: '1000+ sqm',     min: 1000, max: null  }
    ],
    UNIT_STATUS: [
        { label: '-- All --',   value: ''  },
        { label: 'CCMD',   value: 'CCMD'  },
        { label: 'Available',   value: 'Available'  },
    ],
    FULL_COLUMNS: [
        { label: 'Unit Name',           fieldName: 'Name',                  type: 'text', hideDefaultActions: true },
        { label: 'Project',             fieldName: 'Project_Name__c',        type: 'text', hideDefaultActions: true },
        { label: 'Phase',               fieldName: 'PhaseName',             type: 'text', hideDefaultActions: true },
        { label: 'Zone',                fieldName: 'Zone__c',               type: 'text', hideDefaultActions: true },
        { label: 'Bucket',              fieldName: 'BucketName',            type: 'text', hideDefaultActions: true },
        { label: 'Unit Classification', fieldName: 'UnitClassification__c', type: 'text', hideDefaultActions: true },
        { label: 'Bedrooms',            fieldName: 'Number_of_Bedrooms__c', type: 'text', hideDefaultActions: true },
        { label: 'Unit Quality',        fieldName: 'Unit_Quality__c',       type: 'text', hideDefaultActions: true },
        { label: 'Gross Floor Area',    fieldName: 'GrossFloorAreaGFA__c',  type: 'text', hideDefaultActions: true },
        { label: 'Floor',               fieldName: 'FloorNumber__c',        type: 'text', hideDefaultActions: true },
        { label: 'Block Reason',        fieldName: 'BlockReason__c',        type: 'text', hideDefaultActions: true },
        { label: 'Block Comment',       fieldName: 'BlockComment__c',        type: 'text', hideDefaultActions: true },
        { label: 'Approval Status',     fieldName: 'ApprovalStatus__c',     type: 'text', hideDefaultActions: true },
        { label: 'Status',              fieldName: 'Status__c',             type: 'text', hideDefaultActions: true }
    ],
    COMPACT_COLUMNS: [
        { label: 'Unit Name', fieldName: 'Name',       type: 'text' },
        { label: 'Bucket',    fieldName: 'BucketName', type: 'text' },
        { label: 'Status',    fieldName: 'Status__c',  type: 'text' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [{ label: 'View Details', name: 'view_details' }]
            }
        }
    ],
    DETAIL_FIELDS: [
        { label: 'Unit Name',           fieldName: 'Name' },
        { label: 'Project',             fieldName: 'Project_Name__c' },
        { label: 'Phase',               fieldName: 'PhaseName' },
        { label: 'Zone',                fieldName: 'Zone__c' },
        { label: 'Bucket',              fieldName: 'BucketName' },
        { label: 'Unit Classification', fieldName: 'UnitClassification__c' },
        { label: 'Bedrooms',            fieldName: 'Number_of_Bedrooms__c' },
        { label: 'Unit Quality',        fieldName: 'Unit_Quality__c' },
        { label: 'Gross Floor Area',    fieldName: 'GrossFloorAreaGFA__c' },
        { label: 'Floor',               fieldName: 'FloorNumber__c' },
        { label: 'Status',              fieldName: 'Status__c' },
        { label: 'Approval Status',     fieldName: 'ApprovalStatus__c' },
        { label: 'Block Reason',        fieldName: 'BlockReason__c' },
        { label: 'Block Comment',       fieldName: 'BlockComment__c' }
    ]
}

export const ALL_OPTION = { label: '--All--', value: '' }; //v1.6