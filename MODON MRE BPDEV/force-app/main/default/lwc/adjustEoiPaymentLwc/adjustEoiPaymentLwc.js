/**
 * @description
 *  LWC JS Controller for AdjustEoiPaymentLwc component.
 *  - Fetches Receipt__c records linked to EOIs under Sales Order's Opportunity.
 *  - Allows selection of receipts and applies them to Milestone 1 SalesOrderInstallment__c.
 *  - Shows success/error toasts.
 */

import { LightningElement, api } from "lwc";
import getReceipts from "@salesforce/apex/AdjustEoiPaymentLwcController.getReceipts";
import applyReceipts from "@salesforce/apex/AdjustEoiPaymentLwcController.applyReceipts";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { updateRecord } from "lightning/uiRecordApi";

// Table column definitions
const COLUMNS = [
  {
    label: "Receipt Name",
    fieldName: "ReceiptLink",
    type: "url",
    typeAttributes: {
      label: { fieldName: "Name" },
      target: "_blank",
    },
  },
  {
    label: "EOI Name",
    fieldName: "ExpressionLink",
    type: "url",
    typeAttributes: {
      label: { fieldName: "ExpressionName" },
      target: "_blank",
    },
  },
  {
    label: "Receipt Amount",
    fieldName: "RemainingAmount__c",
    type: "currency",
    typeAttributes: { currencyCode: { fieldName: 'sourceCurrencyIsoCode' }, currencyDisplayAs: "code"}
  },
  {
    label: "Amount to Apply",
    fieldName: "AppliedAmount",
    type: "currency",
    editable: true,
    typeAttributes: { currencyCode: { fieldName: 'sourceCurrencyIsoCode' }, currencyDisplayAs: "code", minimumFractionDigits: 2, maximumFractionDigits: 2, step: 0.01 },
  },
  {
    label: "Status",
    fieldName: "Status__c",
  },
];

export default class AdjustEoiPaymentLwc extends LightningElement {
  @api recordId;

  receipts = [];
  columns = COLUMNS;
  selectedIds = [];
  selectedRows = [];
  error;
  isLoading = true;
  amountByReceiptIds = [];
  editedRecords = [];
  draftValues = [];
  isMultiInstallment = false;

  // Computed properties for template rendering
  get hasData() {
    return Array.isArray(this.receipts) && this.receipts.length > 0;
  }

  get showError() {
    return this.error !== undefined;
  }

  get showEmptyState() {
    return !this.isLoading && !this.hasData && !this.showError;
  }

  get isApplyDisabled() {
    return this.selectedIds.length === 0;
  }

  connectedCallback() {
    if (this.recordId) {
      this.loadReceipts();
    }
    this.styleQuickActionModal();
  }


  styleQuickActionModal() {
    let quickActionContext = document.querySelector('.runtime_platform_actionsQuickActionWrapper');
    if (!quickActionContext) return;
    let parent = quickActionContext.parentElement;
    while (parent && !parent.classList.contains("modal-container")) {
      parent = parent.parentElement;
    }
    if (parent) {
      parent.style = `width: 90vw; max-width: 90vw;`; // Adjust as needed
    }
  }

  // Load receipts from server
  async loadReceipts() {
    this.isLoading = true;
    try {
      const data = await getReceipts({ salesOrderId: this.recordId });
      this.receipts = (data || []).map((item) => ({
        ...item.receipt,
        ReceiptLink: "/" + item.receipt.Id,
        ExpressionName: item.receipt.ExpressionOfInterest__r?.Name,
        ExpressionLink: "/" + item.receipt.ExpressionOfInterest__c,
        AppliedAmount: Number(item.receipt.RemainingAmount__c).toFixed(2),
        sourceCurrencyIsoCode: item.sourceCurrencyIsoCode, 
      }));
      this.error = undefined;
    } catch (err) {
      this.error = err.body.message;
      this.receipts = [];
    } finally {
      this.isLoading = false;
    }
  }

  // Capture selected rows from datatable
  handleRowSelection(event) {
    this.selectedRows = event.detail.selectedRows || [];
    this.selectedIds = this.selectedRows.map((row) => row.Id);
  }

  // Cancel action (closes quick action/modal)
  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }

  //Empty draft values on cancel edit
  handleCancelEdit() {
    this.draftValues = [];
  }

  handleMultiInstallmentChange(event) {
    this.isMultiInstallment = event.target.checked;
  }

  // Apply selected receipts to milestone installment
  async handleApply() {
    if (!this.recordId || this.selectedIds.length === 0) return;

    if (this.draftValues.length > 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Please click on Save Button before applying the edited amount.",
          variant: "error",
        })
      );
      return;
    }

    this.amountByReceiptIds = [];
    this.selectedRows.forEach(selectedRow => {
      let finalAmount = selectedRow.AppliedAmount;
      let conversionRate = selectedRow.ConversionRate || 1;

      this.editedRecords.forEach(editedRow => {
        if (selectedRow.Id === editedRow.fields.Id) {
          finalAmount = editedRow.fields.AppliedAmount;
        }
      });
      this.amountByReceiptIds.push({ receiptId: selectedRow.Id, amount: finalAmount, conversionRate: conversionRate });
    });
    this.isLoading = true;
    try {
      await applyReceipts({
        amountList: this.amountByReceiptIds,
        salesOrderId: this.recordId,
        isMultiInstallment: this.isMultiInstallment
      });

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Receipts successfully linked to installment(s).",
          variant: "success",
        })
      );

      this.dispatchEvent(new CustomEvent("cancel"));
    } catch (error) {
      const message =
        (error.body && error.body.message) ||
        error.message ||
        "An unexpected error occurred";

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message,
          variant: "error",
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  async handleCellChange(event) {
    const newDraftValues = event.detail.draftValues;

    // Merge and update existing draft values
    newDraftValues.forEach((newDraft) => {
        const index = this.draftValues.findIndex(d => d.Id === newDraft.Id);
        if (index !== -1) {
            // Update existing draft row
            this.draftValues[index] = { ...this.draftValues[index], ...newDraft };
        } else {
            // Add new draft row
            this.draftValues = [...this.draftValues, newDraft];
        }
    });
  }

  async handleSave(event) {
    //Convert datatable draft values into record objects

    this.editedRecords = event.detail.draftValues.slice().map((draftValue) => {
      const fields = Object.assign({}, draftValue);
      return { fields };
    });

    let throwError = false;
    this.receipts.forEach((receipt) => {
      this.editedRecords.forEach((editRow) => {
        if (editRow.fields.Id === receipt.Id && (receipt.RemainingAmount__c < editRow.fields.AppliedAmount || editRow.fields.AppliedAmount <= 0)) {
          throwError = true;
        }
        else{
          // Update the local data to reflect the changes
          if (editRow.fields.Id === receipt.Id) {
            receipt.AppliedAmount = editRow.fields.AppliedAmount;
          }
        }
      });
    });

    if (throwError === true) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          //message: 'Applied amount should not be greater than Receipt Amount.',
          message: 'Applied Amount must be greater than zero and cannot exceed the Receipt Amount.',
          variant: "error",
        })
      );
    } else {
      this.draftValues = [];
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Draft Saved",
          message: "Your drafted value is Saved.",
          variant: "success",
        })
      );

    }
  }
}