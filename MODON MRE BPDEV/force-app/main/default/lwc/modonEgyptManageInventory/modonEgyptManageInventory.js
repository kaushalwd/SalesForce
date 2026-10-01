/**
* @description       : Lightning Web Component to manage Inventory (Units) of Modon - Egypt Source Entity.
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 03-03-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   20-01-2026   Milin Kapatel      Initial Version
* 1.1   03-03-2026   Milin Kapatel      Used Constants and Utilities from common constants and utilities files
* 1.2   05-03-2026   Milin Kapatel      Implemented Source Entity filter for Buckets to handle only buckets with 'Modon - Egypt' Source Entity
* 2.0   13-04-2026   Mirza Baig         Retrieve distinct Zones from Apex and render them as dropdown options instead of an input field
* 3.0   22-04-2026   Mirza Baig         Introduce Typology and Building Name fields in columns and filter.
* 4.0   24-04-2026   Mirza Baig         Show Release Unit button when unit status is CCMD and approval status Released.
* 5.0   12-08-2026   Shahil Sinha       Added UnitUrl assignment in mapped array to support new tab navigation (commented for reference)
**/

import { LightningElement, wire } from 'lwc';
import ModonEgyptManageInventoryModal from 'c/modonEgyptManageInventoryModal';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { gql, graphql } from 'lightning/uiGraphQLApi';
import { CONSTANTS } from 'c/modonEgyptConstants';
import UNIT_OBJECT from '@salesforce/schema/Unit__c';
import BLOCK_REQUEST_OBJECT from '@salesforce/schema/Block_Request__c';
import UNIT_CLASSIFICATION from '@salesforce/schema/Unit__c.UnitClassification__c';
import HOURS_TO_BLOCK from '@salesforce/schema/Block_Request__c.Hourstoblock__c';
import NUMBER_OF_BEDROOMS from '@salesforce/schema/Unit__c.Number_of_Bedrooms__c';
import APPROVAL_STATUS from '@salesforce/schema/Unit__c.ApprovalStatus__c';
import STATUS from '@salesforce/schema/Unit__c.Status__c';
import SUB_STATUS from '@salesforce/schema/Unit__c.Sub_Status__c';
import loadFilters from '@salesforce/apex/Modon_Egypt_ManageInventoryController.loadFilters';
import getFieldsFromLayout from '@salesforce/apex/Modon_Egypt_ManageInventoryController.getFieldsFromLayout';
import getZoneValues from '@salesforce/apex/Modon_Egypt_ManageInventoryController.getZoneValues';
import USER_CURRENCY from '@salesforce/i18n/currency';
import { showSuccessToast, showErrorToast, debounce } from 'c/modonEgyptUtilities';

export default class ModonEgyptManageInventory extends LightningElement {

    //************* loading screen *************//
    isLoading = true;

    get isScreenLoading() {
        return this.isLoading;
    }

    //************* filter values lists *************//
    timer;

    //************* filter values lists *************//
    projectValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    phaseValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    bucketValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    unitClassificationPicklistValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    numberOfBedroomsPicklistValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    approvalStatusPicklistValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    statusPicklistValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    subStatusPicklistValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    unitQualityValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    gfaValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    floorValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    currencyIsoCodeValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    hoursToBlockValues = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;

    //************* selected/input filters *************//
    selectedProject;
    selectedPhase;
    selectedBucket;
    selectedUnitClassification;
    selectedNumberOfBedrooms;
    selectedApprovalStatus;
    selectedStatus;
    selectedSubStatus;
    selectedUnitQuality;
    selectedGFA;
    selectedFloor;
    selectedCurrencyIsoCode = USER_CURRENCY;
    inputName;
    inputZone = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;//v2.0
    inputGlobalSearch;
    selectedHoursToBlock;

    tempInputName;
    tempInputZone;

    zoneOptions = [];//2.0

    unitBuilding = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;//v3.0
    unitTypology = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;//v3.0

    get disabledStatusFilter() {
        return !(this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED);
    }
    get disabledSubStatusFilter() {
        return !(
            this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED &&
            this.selectedStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE
        );
    }

    //************* Inventory Details *************//
    totalUnitCount;
    totalFilterUnitCount;
    // master list from server
    unitList;
    // client-side filtered list for datatable
    filteredUnitList;

    //************* pagination state for infinite scroll *************//
    unitsPageSize = 200;
    unitsAfterCursor = null;
    unitsAfterCursorToApply = null;        // GraphQL after cursor
    unitsHasNextPage = true;        // from pageInfo
    unitsIsLoadingMore = false;     // spinner flag for datatable


    //************* columns and sorting *************//
    sortedBy = CONSTANTS.MANAGE_INVENTORY_FIELD_NAMES_NAME;
    sortedDirection = CONSTANTS.MANAGE_INVENTORY_SORT_DIRECTIONS_ASC;
    columns = CONSTANTS.MANAGE_INVENTORY_COLUMNS;


    //************* layout fields *************//
    unitLayoutFields;

    //************* Row Selection *************//
    selectedRowIds = [];

    get selectedRowIdsLength() {
        const len = this.selectedRowIds.length;
        return len;
    }

    //************* Button Action *************//
    screenWidth;
    breakpoint = CONSTANTS.MANAGE_INVENTORY_LAYOUT_BREAKPOINT;

    get isLargeScreen() {
        return this.screenWidth > this.breakpoint;
    }

    get disabledDraftButton() {
        if (
            this.selectedRowIdsLength &&
            ((this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED &&
                this.selectedStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE &&
                this.selectedSubStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_SUB_STATUS_UN_ASSIGNED) ||
                this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_UNRELEASED)
        ) {
            return false;
        }
        return true;
    };
    get disabledUnReleaseButton() {
        if (
            this.selectedRowIdsLength &&
            (this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_DRAFT ||
                (this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED &&
                    this.selectedStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE &&
                    this.selectedSubStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_SUB_STATUS_UN_ASSIGNED))
        ) {
            return false;
        }
        return true;
    };
    get disabledReleaseButton() {
        if (
            this.selectedRowIdsLength &&
            (this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_DRAFT ||
                this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_UNRELEASED ||
                //v4.0
                (this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED &&
                    this.selectedStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_CCMD)
            )
        ) {
            return false;
        }
        return true;
    };
    get disabledAssignButton() {
        if (
            this.selectedRowIdsLength &&
            this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED &&
            this.selectedStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE &&
            this.selectedSubStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_SUB_STATUS_UN_ASSIGNED
        ) {
            return false;
        }
        return true;
    };
    get disabledUnAssignButton() {
        if (
            this.selectedRowIdsLength &&
            this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED &&
            this.selectedStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE &&
            this.selectedSubStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_SUB_STATUS_ASSIGNED
        ) {
            return false;
        }
        return true;
    };
    get disabledBucketButton() {
        if (
            this.selectedBucket &&
            this.selectedRowIdsLength &&
            ((this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED &&
                this.selectedStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE &&
                this.selectedSubStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_SUB_STATUS_UN_ASSIGNED) ||
                this.selectedApprovalStatus == CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_UNRELEASED)
        ) {
            return false;
        }
        return true;
    };

    //************* getters and setters *************//

    get filteredUnitCount() {
        return this.filteredUnitList ? this.filteredUnitList.length : 0;
    }

    // Reactive variables wrapper for graphql queries

    get unitVariables() {

        // Only include 'after' when explicitly loading more and not in a guard state
        const vars = {};
        vars.where = this.unitWhereClause;
        vars.first = this.unitsPageSize;

        if (this.unitsAfterCursorToApply) {
            vars.after = this.unitsAfterCursorToApply;
        }
        if (this.selectedCurrencyIsoCode) {
            const priceWhere = {};
            priceWhere.CurrencyIsoCode = { eq: this.selectedCurrencyIsoCode };
            priceWhere.Payment_Plan__r = {
                Name: { like: CONSTANTS.MANAGE_INVENTORY_BUSINESS_PRICE_PLAN_NAME_LIKE }
            };

            vars.priceWhere = priceWhere;
        }
        return vars;
    }

    get phaseVariables() {
        const vars = {};
        const where = {};
        where.Source_Entity__c = { eq: CONSTANTS.MANAGE_INVENTORY_ENTITY_SOURCE_MODON_EGYPT };
        if (this.selectedProject) {
            where.Project__c = { eq: this.selectedProject };
        }
        vars.where = where;
        // Price filter constants
        if (this.selectedCurrencyIsoCode) {
            const priceWhere = {};
            priceWhere.CurrencyIsoCode = { eq: this.selectedCurrencyIsoCode };
            priceWhere.Payment_Plan__r = {
                Name: { like: CONSTANTS.MANAGE_INVENTORY_BUSINESS_PRICE_PLAN_NAME_LIKE }
            };
            vars.priceWhere = priceWhere;
        }
        return vars;
    }

    get unitWhereClause() {
        // Build filter with correct API names that match the GraphQL fields requested above
        const where = {};
        where.Source_Entity__c = { eq: CONSTANTS.MANAGE_INVENTORY_ENTITY_SOURCE_MODON_EGYPT };
        if (this.selectedPhase) {
            where.Phase__c = { eq: this.selectedPhase };
        }
        if (!this.selectedPhase && this.phaseValues && this.phaseValues.length > 0) {
            const phaseValueList = [];
            this.phaseValues.forEach(phaseMap => {
                if (phaseMap?.value != null && phaseMap?.value != CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING) {
                    phaseValueList.push(phaseMap.value);
                }
            });
            where.Phase__c = { in: phaseValueList };
        }
        if (this.inputName) {
            where.Name = { like: `%${String(this.inputName)}%` };
        }
        else {

            if (this.selectedBucket) {
                where.Bucket__c = { eq: this.selectedBucket };
            }
            if (this.selectedUnitClassification) {
                where.UnitClassification__c = { eq: this.selectedUnitClassification };
            }
            if (this.selectedNumberOfBedrooms) {
                where.Number_of_Bedrooms__c = { eq: this.selectedNumberOfBedrooms };
            }
            if (this.selectedApprovalStatus) {
                where.ApprovalStatus__c = { eq: this.selectedApprovalStatus };
            }
            if (this.selectedStatus) {
                where.Status__c = { eq: this.selectedStatus };
            }
            if (this.selectedSubStatus) {
                where.Sub_Status__c = { eq: this.selectedSubStatus };
            }
            if (this.selectedUnitQuality) {
                where.Unit_Quality__c = { eq: this.selectedUnitQuality };
            }
            if (this.selectedGFA) {
                let minGFA;
                let maxGFA;
                const cleanedRange = this.selectedGFA.replace('X', CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING).replace('_', '-');
                if (cleanedRange.includes('-')) {
                    // Case: "100-200"
                    const rangeParts = cleanedRange.split('-', 2);
                    if (rangeParts.length == 2) {
                        minGFA = Number(rangeParts[0].trim());
                        maxGFA = Number(rangeParts[1].trim());
                    }
                } else {
                    // Case: "1000"
                    minGFA = Number(cleanedRange.trim());
                    maxGFA = null; // or maxGFA = minGFA if needed
                }
                if (minGFA)
                    where.GrossFloorAreaGFA__c = { gte: minGFA };
                if (maxGFA)
                    where.GrossFloorAreaGFA__c = { lte: maxGFA };
            }
            if (this.selectedFloor) {
                where.FloorNumber__c = { eq: this.selectedFloor };
            }
            if (this.inputZone) {
                where.Zone__c = { like: `%${String(this.inputZone)}%` };
            }
            //v3.0
            if (this.unitBuilding) {
                where.Building_Name__c = { like: `%${String(this.unitBuilding)}%` };
            }
            if (this.unitTypology) {
                where.Typology__c = { like: `%${String(this.unitTypology)}%` };
            }
        }
        // Always return a valid filter object. An empty object means "no filters".
        return Object.keys(where).length ? where : {};
    }

    //************* Callbacks *************//

    connectedCallback() {
        this.screenWidth = window.innerWidth;
        this.isLoading = true;
        // Subscribe to the window resize event
        window.addEventListener('resize', this.handleResizeWindow.bind(this));
    }

    disconnectedCallback() {
        clearTimeout(this.timer);
        window.removeEventListener('resize', this.handleResizeWindow.bind(this));
    }


    //************* wire methods *************//

    get projectBucketListVariables() {
        const projectWhere = {};
        const bucketWhere = { 
            Active__c: { eq: true },
            //v1.2 - added Source Entity filter for Buckets to only pull buckets relevant to Modon - Egypt
            Source_Entity__c: {eq: CONSTANTS.MANAGE_INVENTORY_ENTITY_SOURCE_MODON_EGYPT}
        };
        const unitWhere = {};
        if(CONSTANTS.MANAGE_INVENTORY_ENTITY_SOURCE_MODON_EGYPT) {
            projectWhere.Source_Entity__c = { eq: CONSTANTS.MANAGE_INVENTORY_ENTITY_SOURCE_MODON_EGYPT };
            unitWhere.Source_Entity__c = { eq: CONSTANTS.MANAGE_INVENTORY_ENTITY_SOURCE_MODON_EGYPT };
        }
        return { 
            projectWhere: Object.keys(projectWhere).length ? projectWhere : {},
            bucketWhere: Object.keys(bucketWhere).length ? bucketWhere : {},
            unitWhere: Object.keys(unitWhere).length ? unitWhere : {}
        };
    }

    @wire(graphql, {
        query: gql`
            query projectList($projectWhere: Project__c_Filter, $bucketWhere: Bucket__c_Filter, $unitWhere: Unit__c_Filter) {
                uiapi {
                    query {
                        Project__c(where: $projectWhere) { 
                            edges {
                                node {
                                    Id
                                    Name {
                                        value
                                    }
                                }
                            }
                        }
                        Bucket__c(
                            first: 200
                            where: $bucketWhere
                        ) {
                            edges {
                                node {
                                    Id
                                    Name {
                                        value
                                    }
                                }
                            }
                        }
                        Unit__c(where: $unitWhere) {
                            totalCount
                        }
                    }
                }
            }
        `,
        variables: '$projectBucketListVariables'
    })
    wiredProjectBucketValues({ data, errors }) {

        if (data) {
            this.projectValues = [
                {
                    label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL,
                    value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE
                },
                ...data.uiapi.query.Project__c.edges.map(edge => ({
                    label: edge.node.Name.value,
                    value: edge.node.Id
                }))
            ];
            this.bucketValues = [
                {
                    label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL,
                    value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE
                },
                ...data.uiapi.query.Bucket__c.edges.map(edge => ({
                    label: edge.node.Name.value,
                    value: edge.node.Id
                }))
            ];
            this.selectedProject = this.projectValues[1].value || CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
            this.selectedBucket = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
            this.totalUnitCount = data.uiapi.query.Unit__c.totalCount;
        } else if (errors) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_PROJECT_VALUES_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_PROJECT_VALUES_MSG
            );
        }
    }


    @wire(graphql, {
        query: gql`
            query phaseList($where: Phase__c_Filter) {
                uiapi {
                    query {
                        Phase__c(
                            first: 200
                            where: $where
                            ) { 
                            edges {
                                node {
                                    Id
                                    Name {
                                        value
                                    }
                                }
                            }
                        }
                    }
                }
            }
        `,
        variables: "$phaseVariables",
    })
    wiredPhaseValues({ data, errors }) {
        if (data) {
            this.phaseValues = [
                {
                    label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL,
                    value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE
                },
                ...data.uiapi.query.Phase__c.edges.map(edge => ({
                    label: edge.node.Name.value,
                    value: edge.node.Id
                }))
            ];
            this.selectedPhase = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        } else if (errors) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_PHASE_VALUES_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_PHASE_VALUES_MSG
            );
        }
    }

    @wire(loadFilters)
    wiredFilterMap({ data, error }) {
        if (data) {
            this.unitQualityValues = data.Quality_Type
                ? [{ label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL, value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE }, ...data.Quality_Type]
                : [];
            this.gfaValues = data.Gross_Floor_Area_GFA
                ? [{ label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL, value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE }, ...data.Gross_Floor_Area_GFA]
                : [];
            this.floorValues = data.Floor
                ? [{ label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL, value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE }, ...data.Floor]
                : [];
            this.currencyIsoCodeValues = data.CurrencyIsoCode ? data.CurrencyIsoCode : [];

            this.selectedUnitQuality = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
            this.selectedGFA = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
            this.selectedFloor = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
            this.selectedCurrencyIsoCode = this.selectedCurrencyIsoCode;

        } else if (error) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_FILTER_VALUES_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_FILTER_VALUES_MSG
            );
        }
    }

    @wire(getObjectInfo, { objectApiName: BLOCK_REQUEST_OBJECT })
    brObjectInfo;

    @wire(getPicklistValues, { recordTypeId: '$brObjectInfo.data.defaultRecordTypeId', fieldApiName: HOURS_TO_BLOCK })
    wiredHoursToBlockPicklistValues({ data, error }) {
        if (data) {

            this.hoursToBlockValues = data.values.slice().sort((a, b) => {
                return this.toMinutes(a) - this.toMinutes(b);
            });
            this.selectedHoursToBlock = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        } else if (error) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_HOURS_TO_BLOCK_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_HOURS_TO_BLOCK_MSG
            );
        }
    };

    @wire(getObjectInfo, { objectApiName: UNIT_OBJECT })
    unitObjectInfo;

    @wire(getPicklistValues, { recordTypeId: '$unitObjectInfo.data.defaultRecordTypeId', fieldApiName: UNIT_CLASSIFICATION })
    wiredClassificationPicklistValues({ data, error }) {
        if (data) {
            this.unitClassificationPicklistValues = [
                { label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL, value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE },
                ...data.values
            ];
            this.selectedUnitClassification = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        } else if (error) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_UNIT_CLASSIFICATION_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_UNIT_CLASSIFICATION_MSG
            );
        }
    };

    @wire(getPicklistValues, { recordTypeId: '$unitObjectInfo.data.defaultRecordTypeId', fieldApiName: NUMBER_OF_BEDROOMS })
    wiredNumberOfBedroomsPicklistValues({ data, error }) {
        if (data) {
            this.numberOfBedroomsPicklistValues = [
                { label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL, value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE },
                ...data.values
            ];
            this.selectedNumberOfBedrooms = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        } else if (error) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_NUMBER_OF_BEDROOMS_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_NUMBER_OF_BEDROOMS_MSG
            );
        }
    };

    @wire(getPicklistValues, { recordTypeId: '$unitObjectInfo.data.defaultRecordTypeId', fieldApiName: APPROVAL_STATUS })
    wiredApprovalStatusPicklistValues({ data, error }) {
        if (data) {
            this.approvalStatusPicklistValues = [
                { label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL, value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE },
                ...data.values
            ];
            this.selectedApprovalStatus = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        } else if (error) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_APPROVAL_STATUS_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_APPROVAL_STATUS_MSG
            );
        }
    };

    @wire(getPicklistValues, { recordTypeId: '$unitObjectInfo.data.defaultRecordTypeId', fieldApiName: STATUS })
    wiredStatusPicklistValues({ data, error }) {
        if (data) {
            this.statusPicklistValues = [
                { label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL, value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE },
                ...data.values
            ];
        } else if (error) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_STATUS_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_STATUS_MSG
            );
        }
    };

    @wire(getPicklistValues, { recordTypeId: '$unitObjectInfo.data.defaultRecordTypeId', fieldApiName: SUB_STATUS })
    wiredSubStatusPicklistValues({ data, error }) {
        if (data) {
            this.subStatusPicklistValues = [
                { label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL, value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE },
                ...data.values
            ];
        } else if (error) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_SUB_STATUS_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_SUB_STATUS_MSG
            );
        }
    };

    @wire(graphql, {
        query: gql`
            query unitList($where: Unit__c_Filter, $first: Int, $after: String, $priceWhere: UnitPaymentPlanMapping__c_Filter){
                uiapi {
                    query {
                        Unit__c(
                            first: $first
                            after: $after
                            where: $where
                        ) {
                            totalCount
                            edges {
                                cursor
                                node {
                                    Id
                                    Name { value }
                                    Phase__r {
                                        Id
                                        Name { value }
                                        Project__r {
                                            Id
                                            Name { value }
                                        }
                                    }
                                    Bucket__r {
                                        Id
                                        Name { value }
                                    }
                                    BlockedFor__r {
                                        Name { value }
                                    }
                                    BlockedBy__r {
                                        Name { value }
                                    }
                                    BlockUntil__c { value }
                                    UnitClassification__c { value }
                                    Number_of_Bedrooms__c { value }
                                    ApprovalStatus__c { value }
                                    Status__c { value }
                                    Sub_Status__c { value }
                                    Unit_Quality__c { value }
                                    GrossFloorAreaGFA__c { value }
                                    FloorNumber__c { value }
                                    Zone__c { value }
                                    Building_Name__c { value }
                                    Typology__c { value }
                                    UnitPaymentPlanMappings__r( where: $priceWhere ) {
                                        edges {
                                            node {
                                                Base_Price__c { value }
                                            }
                                        }
                                    }
                                }
                            }
                            pageInfo {
                                endCursor
                                hasNextPage
                            }
                        }
                    }
                }
            }
        `,
        variables: '$unitVariables'
    })
    wiredUnitList({ data, errors }) {
        this.isLoading = false;
        // Debug logs to inspect filters and response
        if (errors) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_UNIT_LIST_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_UNIT_LIST_MSG
            );
            this.unitsIsLoadingMore = false;
            return;
        }
        if (!data) {
            return;
        }
        this.totalFilterUnitCount = data.uiapi?.query?.Unit__c?.totalCount || 0;
        const conn = data.uiapi?.query?.Unit__c;
        const edges = conn?.edges || [];
        const pageInfo = conn?.pageInfo || { hasNextPage: false, endCursor: null };

        const mapped = edges.map(edge => ({
            Id: edge.node.Id,
            UnitUrl: '/' + edge.node.Id, // Added to allow the Name column to open the unit natively in a new tab
            Name: edge.node.Name?.value,
            Phase: edge.node.Phase__r?.Name?.value,
            Project: edge.node.Phase__r?.Project__r?.Name?.value,
            Bucket: edge.node.Bucket__r?.Name?.value,
            BlockedFor: edge.node.BlockedFor__r?.Name?.value,
            BlockedBy: edge.node.BlockedBy__r?.Name?.value,
            BlockUntil: edge.node.BlockUntil__c?.value,
            UnitClassification: edge.node.UnitClassification__c?.value,
            Number_of_Bedrooms: edge.node.Number_of_Bedrooms__c?.value,
            ApprovalStatus: edge.node.ApprovalStatus__c?.value,
            Status: edge.node.Status__c?.value,
            Sub_Status: edge.node.Sub_Status__c?.value,
            Unit_Quality: edge.node.Unit_Quality__c?.value,
            GrossFloorAreaGFA: edge.node.GrossFloorAreaGFA__c?.value,
            FloorNumber: edge.node.FloorNumber__c?.value,
            Zone: edge.node.Zone__c?.value,
            Typology: edge.node.Typology__c?.value,//v3.0
            BuildingName: edge.node.Building_Name__c?.value,//v3.0
            Price: this.selectedCurrencyIsoCode + ' ' + ((edge.node.UnitPaymentPlanMappings__r?.edges[0]?.node?.Base_Price__c?.value) || 0),
        }));

        // If we were explicitly loading more (unitsIsLoadingMore true and _lastRequestedAfter set), append.
        // Otherwise, treat as fresh load and reset.
        if (this.unitsIsLoadingMore && this.unitsHasNextPage) {
            this.unitList = [...(this.unitList || []), ...mapped];
        } else {
            this.unitList = mapped;
        }

        // Update pagination state from pageInfo
        this.unitsHasNextPage = pageInfo.hasNextPage;
        this.unitsAfterCursor = pageInfo.endCursor || null;

        // Re-apply client search
        this.unitsIsLoadingMore = false;
        this.applyGlobalSearch();
        // this.sortData();
    }

    @wire(getFieldsFromLayout, { objectApiName: 'Unit__c', layoutName: 'Unit Layout - Egypt' })
    wiredUnitLayoutFields({ data, errors }) {
        if (data) {
            this.unitLayoutFields = data;
        } else if (errors) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_UNIT_LAYOUT_ERROR_TITLE, 
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_UNIT_LAYOUT_ERROR_MSG
            );
        }
    }

    //v2.0
    @wire(getZoneValues)
    wiredUnitZoneDetails({ data, errors }) {
        if (data) {
            this.zoneOptions = [
                {
                    label: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_LABEL,
                    value: CONSTANTS.MANAGE_INVENTORY_ALL_OPTION_VALUE
                },
                ...data.map(zone => ({
                    label: zone,
                    value: zone
                }))
            ];
        } else if (errors) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_UNIT_LAYOUT_ERROR_TITLE, 
                CONSTANTS.MANAGE_INVENTORY_TOAST_FETCH_UNIT_LAYOUT_ERROR_MSG
            );
        }
    }

    // Reset pagination on any filter change
    resetUnitsPagination() {
        this.unitsAfterCursor = null;
        this.unitsAfterCursorToApply = null;
        this.unitsHasNextPage = true;
        this.unitsIsLoadingMore = false;
        this.selectedRowIds = [];
        this.sortedBy = CONSTANTS.MANAGE_INVENTORY_FIELD_NAMES_NAME;
        this.sortedDirection = CONSTANTS.MANAGE_INVENTORY_SORT_DIRECTIONS_ASC;
        this.sortData();
    }

    handleFilterValueChange(event) {
        if (!this.inputName || (this.inputName && (event.target.name === 'Name' || event.target.Name === 'Phase'))) {
            this.isLoading = true;
        }
        switch (event.target.name) {
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_PROJECT:
                this.selectedProject = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_PHASE:
                this.selectedPhase = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_BUCKET:
                this.selectedBucket = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_UNIT_CLASSIFICATION:
                this.selectedUnitClassification = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_NUMBER_OF_BEDROOMS:
                this.selectedNumberOfBedrooms = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_APPROVAL_STATUS:
                this.selectedApprovalStatus = event.target.value;
                if (this.selectedApprovalStatus != CONSTANTS.MANAGE_INVENTORY_STATUSES_APPROVAL_RELEASED) {
                    this.selectedStatus = undefined;
                    this.selectedSubStatus = undefined;
                }
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_STATUS:
                this.selectedStatus = event.target.value;
                if (this.selectedStatus != CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE) {
                    this.selectedSubStatus = undefined;
                }
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_SUB_STATUS:
                this.selectedSubStatus = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_UNIT_QUALITY:
                this.selectedUnitQuality = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_GFA:
                this.selectedGFA = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_FLOOR:
                this.selectedFloor = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_CURRENCY:
                this.selectedCurrencyIsoCode = event.target.value;
                this.resetUnitsPagination();
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_NAME:
                this.tempInputName = event.target.value;
                debounce(CONSTANTS.MANAGE_INVENTORY_DEBOUNCE_KEY_NAME_SEARCH, () => {
                    this.applyInputFilter();
                    this.resetUnitsPagination();
                }, CONSTANTS.MANAGE_INVENTORY_DEBOUNCE_MS);
                break;
            case CONSTANTS.MANAGE_INVENTORY_FILTER_NAMES_ZONE:
                this.tempInputZone = event.target.value;
                debounce(CONSTANTS.MANAGE_INVENTORY_DEBOUNCE_KEY_ZONE_SEARCH, () => {
                    this.applyInputFilter();
                    this.resetUnitsPagination();
                }, CONSTANTS.MANAGE_INVENTORY_DEBOUNCE_MS);
                break;
        }
    }



    applyInputFilter() {
        this.inputName = this.tempInputName || CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.inputZone = this.tempInputZone || CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
    }
    handleGlobalSearchChange(event) {
        // store raw input and filter
        const val = event.target.value || CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.inputGlobalSearch = val.trim();
        debounce(CONSTANTS.MANAGE_INVENTORY_DEBOUNCE_KEY_GLOBAL_SEARCH, () => {
            this.applyGlobalSearch();
            // no server pagination reset since search is client-side
        }, CONSTANTS.MANAGE_INVENTORY_DEBOUNCE_MS);
    }

    // Load next page when reaching end
    handleLoadMoreUnits() {
        // Only load more when user actually reached the end and the global search is empty
        if (this.unitsIsLoadingMore || this.inputGlobalSearch) return;

        // Require a valid cursor after the first page; if null, we cannot request next page yet
        if (!this.unitsAfterCursor) return;

        this.unitsAfterCursorToApply = this.unitsAfterCursor;
        this.unitsIsLoadingMore = true;
    }

    // Applies client-side global search across all displayed fields
    applyGlobalSearch() {
        const q = (this.inputGlobalSearch || CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING).toLowerCase();
        const source = Array.isArray(this.unitList) ? this.unitList : [];

        if (!q) {
            this.filteredUnitList = [...source];
            this.isLoading = false;
            return;
        }

        // fields to search across
        const fields = CONSTANTS.MANAGE_INVENTORY_GLOBAL_SEARCH_FIELDS || [];

        this.filteredUnitList = source.filter(row => {
            return fields.some(f => {
                const v = row[f];
                if (v === null || v === undefined) return false;
                return this.selectedRowIds.some(selectedRowId => selectedRowId === row.Id) || String(v).toLowerCase().includes(q);
            });
        });
        this.isLoading = false;
    }

    handleRefresh() {
        this.isLoading = true;
        this.selectedProject = this.projectValues[1]?.value || CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.selectedPhase = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.selectedBucket = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.selectedUnitClassification = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.selectedNumberOfBedrooms = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.selectedApprovalStatus = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.selectedStatus = undefined;
        this.selectedSubStatus = undefined;
        this.selectedUnitQuality = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.selectedGFA = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.selectedFloor = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.selectedCurrencyIsoCode = USER_CURRENCY;
        this.inputZone = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.inputName = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.inputGlobalSearch = CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
        this.resetUnitsPagination();
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedRowIds = selectedRows.map(row => row.Id);
    }

    async handleUnitClick(event) {
        const recordId = event.detail.row.Id;
        const jsonString = JSON.stringify({
            recordId,
            objectAPIName: CONSTANTS.MANAGE_INVENTORY_UNIT_API_NAME,
            recordFieldList: this.unitLayoutFields,
        });
        const result = await ModonEgyptManageInventoryModal.open({ jsonString });


        if (result === 'success') {
            showSuccessToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_UNIT_UPDATE_SUCCESS_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_UNIT_UPDATE_SUCCESS_MSG
            );
            this.handleRefresh();
        }
        else if (result === 'error') {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_UNIT_UPDATE_ERROR_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_UNIT_UPDATE_ERROR_MSG
            );
        }
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.sortData();
    }

    sortData() {
        const data = [...this.unitList];

        data.sort((a, b) => {
            const valA = a[this.sortedBy] ?? CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;
            const valB = b[this.sortedBy] ?? CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING;

            return this.sortedDirection === CONSTANTS.MANAGE_INVENTORY_SORT_DIRECTIONS_ASC
                ? (valA > valB ? 1 : -1)
                : (valA < valB ? 1 : -1);
        });

        this.unitList = data;
        this.filteredUnitList = [...this.unitList];
    }

    async handleButtonAction(event) {
        const action = event.target.name;
        let firstBucket;
        if (action === CONSTANTS.MANAGE_INVENTORY_ACTIONS_RELEASE || action === CONSTANTS.MANAGE_INVENTORY_ACTIONS_ASSIGN) {
            const selectedUnits = this.filteredUnitList.filter(unit => this.selectedRowIds.includes(unit.Id));
            if (!selectedUnits.length) {
                return;
            }
            firstBucket = selectedUnits[0]?.Bucket;
            const differentBucketsSelected = selectedUnits.some(selectedUnit => selectedUnit.Bucket !== firstBucket);

            if (differentBucketsSelected) {
                showErrorToast(
                    CONSTANTS.MANAGE_INVENTORY_TOAST_SAME_BUCKET_ERROR_TITLE,
                    CONSTANTS.MANAGE_INVENTORY_TOAST_SAME_BUCKET_ERROR_MSG
                );
                return;
            }
        }
        if (action === CONSTANTS.MANAGE_INVENTORY_ACTIONS_ASSIGN && !firstBucket) {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_ASSIGNED_BUCKET_REQUIRED_ERROR_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_ASSIGNED_BUCKET_REQUIRED_ERROR_MSG
            );
            return;
        }

        const selectedBucket =
            action === CONSTANTS.MANAGE_INVENTORY_ACTIONS_ASSIGN
                ? this.bucketValues.filter(bucket => bucket.label == firstBucket)[0]
                : this.bucketValues.filter(bucket => bucket.value == this.selectedBucket)[0];
        const jsonString = JSON.stringify({
            action,
            selectedUnitIds: this.selectedRowIds,
            selectedBucketName: selectedBucket,
            hoursToBlock: this.hoursToBlockValues,
            buckets: this.bucketValues.filter(bucket => bucket.value != CONSTANTS.MANAGE_INVENTORY_EMPTY_STRING),
            releaseStatuses: [
                {
                    label: CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE,
                    value: CONSTANTS.MANAGE_INVENTORY_STATUSES_STATUS_AVAILABLE
                },
                {
                    label: CONSTANTS.MANAGE_INVENTORY_STATUSES_SUB_STATUS_ASSIGNED,
                    value: CONSTANTS.MANAGE_INVENTORY_STATUSES_SUB_STATUS_ASSIGNED
                }
            ]
        });
        const result = await ModonEgyptManageInventoryModal.open({ jsonString });


        if (result === 'success') {
            showSuccessToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_ACTION_PERFORMED_SUCCESS_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_ACTION_PERFORMED_SUCCESS_MSG
            );
            this.handleRefresh();
        }
        else if (result === 'error') {
            showErrorToast(
                CONSTANTS.MANAGE_INVENTORY_TOAST_ACTION_PERFORMED_ERROR_TITLE,
                CONSTANTS.MANAGE_INVENTORY_TOAST_ACTION_PERFORMED_ERROR_MSG
            );
        }

    }

    toMinutes(item) {
        const val = item.value;

        if (val === CONSTANTS.MANAGE_INVENTORY_BUSINESS_UNLIMITED) return Number.MAX_SAFE_INTEGER;

        // "20 Min"
        if (val.toLowerCase().includes('min')) {
            return parseInt(val, 10);
        }

        // hours → minutes
        return parseInt(val, 10) * 60;
    };

    handleResizeWindow() {
        this.screenWidth = window.innerWidth;
    }

}