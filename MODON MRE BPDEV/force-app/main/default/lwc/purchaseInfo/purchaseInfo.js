import { LightningElement, api, track, wire } from 'lwc';
import getPurchaseInformationData from '@salesforce/apex/PurchaseInformationController.getPurchaseInformationData';

export default class PurchaseInfo extends LightningElement {
    @api customerData;
    @api recordId;

    apexResponse;
    loadUI = false;
    @track groupedFields = [];
    @track popupContent = '';

    connectedCallback() {
        document.addEventListener('click', this.handleOutsideClick);
        window.addEventListener('closeAllPopups', this.handleClosePopupFromOutside);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick);
        window.removeEventListener('closeAllPopups', this.handleClosePopupFromOutside);
    }
    handleClosePopupFromOutside = () => {
        this.groupedFields = this.groupedFields.map(field => ({
            ...field,
            showPopup: false
        }));
        this.groupedFields = [...this.groupedFields];
    };

    @wire(getPurchaseInformationData, { recordId: "$recordId" })
    wiredData({ error, data }) {
        if (error) {
            console.error('Error fetching purchase info:', error);
            this.loadUI = true;
        } else if (data) {
            this.apexResponse = Object.assign({}, data);

            const collectedAmountLabel = 'Collected Amount';
            const collectedBreakdownLabel = 'Collected Breakdown Tooltip';
            const receivedPercentageLabel = 'Received Percentage';
            const ownedPropertiesLabel = 'Owned Properties';
            const ownedPropertyNamesLabel = 'Owned Property Names';
            const totalOutstandingLabel = 'Total Outstanding Amount';
            const outstandingBreakdownLabel = 'Outstanding Breakdown Tooltip';

            const skipFields = new Set([
                collectedAmountLabel,
                collectedBreakdownLabel,
                receivedPercentageLabel,
                ownedPropertiesLabel,
                ownedPropertyNamesLabel,
                totalOutstandingLabel,
                outstandingBreakdownLabel
            ]);

            let collectedAmount = '';
            let receivedPercentage = '';
            let ownedProperties = '';
            let ownedPropertyNames = '';
            let totalOutstanding = '';
            let otherFields = [];

            for (const key in this.apexResponse) {
                if (this.apexResponse.hasOwnProperty(key)) {
                    const value = this.apexResponse[key];

                    switch (key) {
                        case collectedAmountLabel:
                            collectedAmount = value;
                            break;
                        case receivedPercentageLabel:
                            receivedPercentage = value;
                            break;
                        case ownedPropertiesLabel:
                            ownedProperties = value;
                            break;
                        case ownedPropertyNamesLabel:
                            ownedPropertyNames = value;
                            break;
                        case totalOutstandingLabel:
                            totalOutstanding = value;
                            break;
                        default:
                            if (!skipFields.has(key)) {
                                otherFields.push({
                                    title: key,
                                    label: key,
                                    value: value,
                                    showPopup: false
                                });
                            }
                    }
                }
            }

            if (ownedProperties) {
                this.groupedFields.push({
                    title: ownedPropertiesLabel,
                    label: ownedPropertiesLabel,
                    value: ownedProperties,
                    tooltipData: ownedPropertyNames,
                    isOwnedProperties: true,
                    showPopup: false
                });
            }

            if (collectedAmount) {
                const combined = receivedPercentage
                    ? `${collectedAmount} (${receivedPercentage})`
                    : collectedAmount;

                this.groupedFields.push({
                    title: collectedAmountLabel,
                    label: collectedAmountLabel,
                    value: combined,
                    tooltipData: this.apexResponse[collectedBreakdownLabel],
                    isCollectedAmount: true,
                    showPopup: false
                });
            }

            if (totalOutstanding) {
                this.groupedFields.push({
                    title: totalOutstandingLabel,
                    label: totalOutstandingLabel,
                    value: totalOutstanding,
                    tooltipData: this.apexResponse[outstandingBreakdownLabel],
                    isOutstandingAmount: true,
                    showPopup: false
                });
            }

            this.groupedFields.push(...otherFields);

            this.groupedFields = this.groupedFields.map(field => ({
                ...field,
                shouldRender: !field.isOwnedProperties && !field.isCollectedAmount && !field.isOutstandingAmount
            }));

            this.loadUI = Object.keys(this.apexResponse).length > 0;
        }
    }
    // Reusable handler for event listener
    closeAllPopupHandler = () => {
        this.groupedFields = this.groupedFields.map(field => ({
            ...field,
            showPopup: false
        }));
        this.groupedFields = [...this.groupedFields];
    };

    handleClick = (event) => {
        event.stopPropagation();

        const label = event.currentTarget.dataset.label;
        const tooltip = event.currentTarget.dataset.tooltip;

         // Close all other popups
        window.dispatchEvent(new CustomEvent('closeAllPopups'));

        

        if (tooltip && label) {
            const rows = tooltip.split('||').map(row => row.split('##'));
            let tableHeaders = '';
            let tableRows = '';

            if (rows.length > 0) {
                // Collected Amount: Property | Collected | Pending
                if (rows[0].length === 4 && label === 'Collected Amount') {
                    tableHeaders = '<tr><th>Property</th><th>Unit Name</th><th>Collected</th><th>Pending</th></tr>';
                    tableRows = rows.map(cols =>
                        `<tr>
                            <td class="non-clickable">${cols[0]}</td>
                            <td class="non-clickable">${cols[1]}</td>
                            <td class="non-clickable">${cols[2]}</td>
                            <td class="non-clickable">${cols[3]}</td>
                        </tr>`).join('');
                }

                // Total Outstanding Amount: Property | Outstanding (non-clickable)
                else if (rows[0].length === 3 && label === 'Total Outstanding Amount') {
                    tableHeaders = '<tr><th>Property</th><th>Unit Name</th><th>Outstanding</th></tr>';
                    tableRows = rows.map(cols =>
                        `<tr>
                            <td class="non-clickable">${cols[0]}</td>
                            <td class="non-clickable">${cols[1]}</td>
                            <td class="non-clickable">${cols[2]}</td>
                        </tr>`).join('');
                }

                // Owned Properties: Unit Name with sales order link
                else if (rows[0].length === 3 && label === 'Owned Properties') {
                    tableHeaders = '<tr><th>Unit Name</th><th>Property</th></tr>';
                    tableRows = rows.map(cols =>
                        `<tr>
                            <td><a href='/lightning/r/SalesOrder__c/${cols[1]}/view' target='_blank'>${cols[0]}</a></td>
                            <td class="non-clickable">${cols[2]}</td>
                        </tr>`).join('');
                }

                this.popupContent = `
                    <table class="popup-table" style="margin: 0; padding: 0;">
                        <thead class="popup-table-header">${tableHeaders}</thead>
                        <tbody>${tableRows}</tbody>
                    </table>
                `;
            }

            this.groupedFields = this.groupedFields.map(field => ({
                ...field,
                showPopup: field.label === label
            }));
            this.groupedFields = [...this.groupedFields];

            setTimeout(() => {
                const container = this.template.querySelector('.popup-content');
                if (container) {
                    container.innerHTML = this.popupContent;
                }
            }, 0);
        }
    };

    handleClosePopup(event) {
        if (event) event.stopPropagation(); // only stopPropagation if event exists
        this.groupedFields = this.groupedFields.map(field => ({
            ...field,
            showPopup: false
        }));
        this.groupedFields = [...this.groupedFields];
    }

    handleOutsideClick = (event) => {
        const popup = this.template.querySelector('.popup-card');
        const targetInsidePopup = popup?.contains(event.target);
        const clickedTrigger = event.target.closest('.owned-hover');

        if (!targetInsidePopup && !clickedTrigger) {
            this.handleClosePopup();
        }
    }
}