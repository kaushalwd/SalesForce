import { LightningElement, wire, track, api } from 'lwc';
import getApprovalTypes from '@salesforce/apex/ApprovalModalController.getApprovalTypes';
import createBusinessProcess from '@salesforce/apex/ApprovalModalController.createBusinessProcess';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { loadStyle } from 'lightning/platformResourceLoader';
import {
    IsConsoleNavigation,
    getFocusedTabInfo,
    refreshTab
} from 'lightning/platformWorkspaceApi';
import modalStyles from '@salesforce/resourceUrl/initiateBusinessProcessModal';

export default class InitiateBusinessProcess extends LightningElement {
    @api recordId;

    @track approvalTypes = [];
    @track selectedType;
    @track selectedSubCategory;
    @track subCategories = [];
    @track isLoading = false;

    rawDataMap = new Map();

    stylesLoaded = false;
    modalContainer;

    @wire(IsConsoleNavigation) isConsoleNavigation;

    renderedCallback() {
        if (!this.stylesLoaded) {
            this.stylesLoaded = true;
            loadStyle(this, modalStyles).catch(() => {
                /* Sizing is a visual enhancement only; safe to ignore a load failure. */
            });
        }

        if (!this.modalContainer) {
            const host = this.template.host;
            const container = host && host.closest('.slds-modal__container');

            if (container) {
                // Unique marker so the globally loaded stylesheet only matches this modal.
                container.classList.add('ibp-modal-scope');
                this.modalContainer = container;
            }
        }

        // The installment table needs extra width for long milestone descriptions.
        if (this.modalContainer) {
            this.modalContainer.classList.toggle(
                'ibp-modal-wide',
                this.isInsatallmentShow
            );
        }
    }

    disconnectedCallback() {
        if (this.modalContainer) {
            this.modalContainer.classList.remove(
                'ibp-modal-scope',
                'ibp-modal-wide'
            );
            this.modalContainer = null;
        }
    }

    /*
     * Refresh the parent Sales Order / Case page so the new Business Process
     * (and any related changes) are reflected without a manual reload.
     * RefreshEvent alone does not reach the record page from a quick action
     * modal, so the whole tab (console) or page (standard nav) is reloaded.
     */
    async closeAndRefresh() {
        const isConsole = this.isConsoleNavigation === true;
        let tabId;

        try {
            if (this.recordId) {
                await notifyRecordUpdateAvailable([
                    { recordId: this.recordId }
                ]);
            }
            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            console.error('Record refresh notification error:', error);
        }

        if (isConsole) {
            try {
                const tabInfo = await getFocusedTabInfo();
                tabId = tabInfo?.tabId;
            } catch (error) {
                console.error('getFocusedTabInfo error:', error);
            }
        }

        this.dispatchEvent(new CloseActionScreenEvent());

        // Short delay so the modal closes and the success toast renders first.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            if (isConsole && tabId) {
                refreshTab(tabId, { includeAllSubtabs: true }).catch(
                    (error) => {
                        console.error('refreshTab error:', error);
                        window.location.reload();
                    }
                );
            } else {
                window.location.reload();
            }
        }, isConsole ? 500 : 1500);
    }

    @wire(getApprovalTypes)
    wiredTypes({ data, error }) {
        if (data) {
            this.rawDataMap.clear();

            this.approvalTypes = data.map((item) => {
                this.rawDataMap.set(
                    item.Category__c,
                    item.Sub_Categories__c
                );

                return {
                    label: item.MasterLabel,
                    value: item.Category__c,
                    isSelected: false,
                    cssClass: 'option-card'
                };
            });
        } else if (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    handleChange(event) {
        const selectedValue =
            event.currentTarget.dataset.value;

        this.selectedType = selectedValue;
        this.selectedSubCategory = null;

        this.approvalTypes = this.approvalTypes.map(
            (item) => {
                const isSelected =
                    item.value === selectedValue;

                return {
                    ...item,
                    isSelected,
                    cssClass: isSelected
                        ? 'option-card selected'
                        : 'option-card'
                };
            }
        );

        const rawSubCategories =
            this.rawDataMap.get(selectedValue);

        this.subCategories = rawSubCategories
            ? rawSubCategories
                  .split(';')
                  .map((item) => item.trim())
                  .filter((item) => item)
                  .map((item) => ({
                      label: item,
                      value: item,
                      isSelected: false,
                      cssClass: 'subcategory-card'
                  }))
            : [];
    }

    handleSubCategoryChange(event) {
        const selectedValue =
            event.currentTarget.dataset.value;

        this.selectedSubCategory = selectedValue;

        this.subCategories = this.subCategories.map(
            (item) => {
                const isSelected =
                    item.value === selectedValue;

                return {
                    ...item,
                    isSelected,
                    cssClass: isSelected
                        ? 'subcategory-card selected'
                        : 'subcategory-card'
                };
            }
        );
    }

    handleReset() {
        this.selectedType = null;
        this.selectedSubCategory = null;
        this.subCategories = [];

        this.approvalTypes = this.approvalTypes.map(
            (item) => ({
                ...item,
                isSelected: false,
                cssClass: 'option-card'
            })
        );
    }

    handleInstallmentSuccess(event) {
    const message =
        event.detail?.message ||
        'Payment Extension process has been initiated successfully.';

    this.showToast(
        'Success',
        message,
        'success'
    );

    if (event.detail?.warning) {
        this.showToast(
            'Proof of Request Not Attached',
            event.detail.warning,
            'warning'
        );
    }

    this.closeAndRefresh();
}

handleInstallmentError(event) {
    const {
        title = 'Error',
        message = 'An unexpected error occurred.',
        variant = 'error'
    } = event.detail || {};

    this.showToast(
        title,
        message,
        variant
    );
}

    async handleSubmit() {
        if (!this.recordId) {
            this.showToast(
                'Error',
                'Record ID is not available.',
                'error'
            );
            return;
        }

        if (!this.selectedType) {
            this.showToast(
                'Required Field',
                'Please select an approval type.',
                'warning'
            );
            return;
        }

        if (!this.selectedSubCategory) {
            this.showToast(
                'Required Field',
                'Please select a subcategory before submitting.',
                'warning'
            );
            return;
        }

        this.isLoading = true;

        try {
            await createBusinessProcess({
                recId: this.recordId,
                processName: this.selectedSubCategory
            });

            this.showToast(
                'Success',
                'Business process initiated successfully.',
                'success'
            );

            this.closeAndRefresh();
        } catch (error) {
            console.error(
                'Create business process error:',
                error
            );

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode:
                    variant === 'error'
                        ? 'sticky'
                        : 'dismissable'
            })
        );
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (Array.isArray(error?.body)) {
            return error.body
                .map((item) => item.message)
                .join(', ');
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred while initiating the business process.';
    }

    get hasSubCategories() {
        return this.subCategories.length > 0;
    }

    get isSubmitDisabled() {
        return (
            !this.selectedType ||
            !this.selectedSubCategory ||
            this.isLoading
        );
    }

    get selectedApprovalTypeLabel() {
        const selectedItem =
            this.approvalTypes.find(
                (item) =>
                    item.value === this.selectedType
            );

        return selectedItem
            ? selectedItem.label
            : '';
    }

    get selectedSubCategoryLabel() {
        const selectedItem =
            this.subCategories.find(
                (item) =>
                    item.value ===
                    this.selectedSubCategory
            );

        return selectedItem
            ? selectedItem.label
            : '';
    }

    get isInsatallmentShow() {
        return (
            this.selectedSubCategory ===
            'Payment Extension'
        );
    }


    get showParentSubmitButton() {
    return !this.isInsatallmentShow;
}
}