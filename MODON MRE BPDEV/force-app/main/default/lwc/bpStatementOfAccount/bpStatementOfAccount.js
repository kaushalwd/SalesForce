import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import FORM_FACTOR from '@salesforce/client/formFactor';

import MODON_LOGO from '@salesforce/resourceUrl/modonLogoPlain';

import getStatementOfAccount
    from '@salesforce/apex/NewStatementOfAccountController.getStatementOfAccount';
import generateStatementOfAccountPdf
    from '@salesforce/apex/NewStatementOfAccountController.generateStatementOfAccountPdf';


/*
 * Same number format as the NewSOA page: {0,number,###,##0.00}
 */
const AMOUNT_FORMAT = new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
});

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];


function formatAmount(value) {
    return AMOUNT_FORMAT.format(Number(value) || 0);
}

/*
 * Apex Dates arrive as 'yyyy-MM-dd'. Parsed by hand so the browser
 * time zone cannot shift the day.
 */
function formatDate(value, withComma) {
    if (!value) {
        return '';
    }

    const [year, month, day] = String(value).substring(0, 10).split('-');

    if (!year || !month || !day) {
        return '';
    }

    const monthName = MONTHS[Number(month) - 1] || '';

    return withComma
        ? `${day} ${monthName}, ${year}`
        : `${day} ${monthName} ${year}`;
}


export default class BpStatementOfAccount extends NavigationMixin(LightningElement) {

    @api salesOrderId;

    soa;

    error;

    isExporting = false;

    isRefreshing = false;

    logoUrl = MODON_LOGO;

    wiredSoaResult;


    /* ============================================================
       LOAD SOA
       ============================================================ */

    @wire(
        getStatementOfAccount,
        {
            salesOrderId: '$salesOrderId'
        }
    )
    wiredSoa(result) {

        this.wiredSoaResult = result;

        const { error, data } = result;

        if (data) {

            this.soa = {

                ...data,

                paymentRows:
                    this.decorateRows(
                        data.paymentRows,
                        'installment'
                    ),

                otherPaymentRows:
                    this.decorateRows(
                        data.otherPaymentRows,
                        'other'
                    )
            };

            this.error = undefined;

        } else if (error) {

            console.error(
                'Error loading Statement of Account:',
                error
            );

            this.soa = undefined;

            this.error =
                error?.body?.message ||
                'Unable to load the Statement of Account.';
        }
    }


    /* ============================================================
       UI ROW DECORATION
       Pre-formats every value exactly as the NewSOA page shows it.
       ============================================================ */

    decorateRows(rows, prefix) {

        return (rows || []).map(
            (row, index) => {

                const rowKey =
                    prefix + '-' + (row.invoiceId || 'row') + '-' + index;

                return {

                    ...row,

                    rowKey: rowKey,

                    rowClass: row.isAltRow ? 'rowAlt' : 'rowMain',

                    amountDisplay: formatAmount(row.amount),

                    amountCollectedDisplay: formatAmount(row.amountCollected),

                    lpcAmountDisplay: formatAmount(row.lpcAmount),

                    // Cleared receipt excess is shown as <amount>
                    outstandingDisplay: row.isClearedExcessRow
                        ? '<' + formatAmount(Math.abs(row.outstandingAmount || 0)) + '>'
                        : formatAmount(row.outstandingAmount),

                    allocations: (row.allocationRows || []).map(
                        (alloc, allocIndex) => ({
                            ...alloc,
                            key: rowKey + '-alloc-' + allocIndex,
                            allocationAmountDisplay: formatAmount(alloc.allocationAmount)
                        })
                    )
                };
            }
        );
    }


    /* ============================================================
       COMMON
       ============================================================ */

    get isLoading() {
        return !this.soa && !this.error;
    }

    get showLpc() {
        return this.soa?.showLPC === true;
    }


    /* ============================================================
       HEADER / UNIT SPECIFICATION
       ============================================================ */

    get customerName() {
        return this.soa?.customerName || '';
    }

    get jointOwnerNames() {
        return this.soa?.jointOwnerNames || '';
    }

    get hasJointOwners() {
        return !!this.soa?.jointOwnerNames;
    }

    get todayDateDisplay() {
        return formatDate(this.soa?.todayDate, true);
    }

    get spaDateDisplay() {
        return formatDate(this.soa?.spaDate, false);
    }

    get projectName() {
        return this.soa?.projectName || '';
    }

    get unitType() {
        return this.soa?.unitType || '';
    }

    get unitName() {
        return this.soa?.unitName || '';
    }

    get priceDisplay() {
        return formatAmount(this.soa?.price);
    }

    get admDistrict() {
        return this.soa?.admDistrict || '';
    }

    get admPlotNo() {
        return this.soa?.admPlotNo || '';
    }


    /* ============================================================
       PAYMENT PLAN DETAIL
       ============================================================ */

    get paymentRows() {
        return this.soa?.paymentRows || [];
    }

    get totalAmountDisplay() {
        return formatAmount(this.soa?.totalAmount);
    }

    get totalAmountCollectedDisplay() {
        return formatAmount(this.soa?.totalAmountCollected);
    }

    get totalAmountOutstandingDisplay() {
        return formatAmount(this.soa?.totalAmountOutstanding);
    }

    get totalLatePaymentDisplay() {
        return formatAmount(this.soa?.totalLatePayment);
    }


    /* ============================================================
       OTHER PAYMENT DETAILS
       ============================================================ */

    get otherPaymentRows() {
        return this.soa?.otherPaymentRows || [];
    }

    get totalOtherAmountCollectedDisplay() {
        return formatAmount(this.soa?.totalOtherAmountCollected);
    }

    get totalOtherAmountOutstandingDisplay() {
        return formatAmount(this.soa?.totalOtherAmountOutstanding);
    }


    /* ============================================================
       TOTAL OUTSTANDING
       Same visibility rules as the NewSOA page.
       ============================================================ */

    get showUnclearedReceipts() {
        return (this.soa?.unclearedReceiptsAmount || 0) > 0;
    }

    get unclearedReceiptsAmountDisplay() {
        return formatAmount(this.soa?.unclearedReceiptsAmount);
    }

    get showTotalExcess() {
        return (this.soa?.totalExcessAmount || 0) > (this.soa?.grandTotalOutstanding || 0);
    }

    get totalExcessAmountDisplay() {
        return formatAmount(this.soa?.totalExcessAmount);
    }

    get grandTotalOutstandingDisplay() {
        return formatAmount(this.soa?.grandTotalOutstanding);
    }


    /* ============================================================
       ESCROW ACCOUNT DETAILS
       ============================================================ */

    get escrowAccountName() {
        return this.soa?.escrowAccountName || '';
    }

    get escrowBankName() {
        return this.soa?.escrowBankName || '';
    }

    get virtualAccountNumber() {
        return this.soa?.virtualAccountNumber || '';
    }

    get virtualIbanNumber() {
        return this.soa?.virtualIbanNumber || '';
    }

    get swiftCode() {
        return this.soa?.swiftCode || '';
    }


    /* ============================================================
       REFRESH
       ============================================================ */

    async handleRefresh() {

        if (!this.wiredSoaResult) {
            return;
        }

        this.isRefreshing = true;

        try {
            await refreshApex(this.wiredSoaResult);
        }
        finally {
            this.isRefreshing = false;
        }
    }


    /* ============================================================
       DOWNLOAD (PDF)
       Renders the NewSOAPDF Visualforce page, whose content is kept
       identical to the NewSOA page and this component.
       ============================================================ */

    get isDownloadDisabled() {
        return !this.soa || this.isExporting;
    }

    get downloadLabel() {
        return this.isExporting ? 'Generating PDF…' : 'Download PDF';
    }

    async handleDownload() {

        if (!this.salesOrderId) {
            return;
        }

        this.isExporting = true;

        try {
            const downloadUrl = await generateStatementOfAccountPdf({
                salesOrderId: this.salesOrderId
            });

            /*
             * Desktop: open the shepherd download URL in a new tab (direct download).
             * Mobile app: window.open hands the URL to an external browser with no
             * Salesforce session (login screen), so open the native file preview
             * instead. The ContentDocumentId is the last segment of the URL.
             */
            const contentDocumentId = downloadUrl.split('/').pop();

            if (FORM_FACTOR === 'Large' || !contentDocumentId) {
                window.open(downloadUrl, '_blank');
            }
            else {
                this[NavigationMixin.Navigate]({
                    type: 'standard__namedPage',
                    attributes: { pageName: 'filePreview' },
                    state: { selectedRecordId: contentDocumentId }
                });
            }
        }
        catch (error) {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Unable to generate the Statement of Account PDF.',
                    variant: 'error'
                })
            );
        }
        finally {
            this.isExporting = false;
        }
    }

}