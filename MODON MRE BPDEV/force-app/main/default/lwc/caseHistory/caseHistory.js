/**
* Description: LWC for Case History Customer 360 dashboard
* Author: Chaitanya N
* Name: CaseHistory
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire, track } from 'lwc';
import getCaseHistoryData from '@salesforce/apex/CaseHistoryController.getCaseHistoryData';

export default class CaseHistory extends LightningElement {
    @api recordId;
    @api startDate; // optional - passed from parent
    @api endDate;   // optional - passed from parent

    apexResponse;
    loadUI = false;
    @track groupedFields = [];

    connectedCallback() {
        document.addEventListener('click', this.handleOutsideClick);
        window.addEventListener('closeAllPopups', this.closeAllPopupHandler);
    }
    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick);
        window.removeEventListener('closeAllPopups', this.closeAllPopupHandler);
    }

    @wire(getCaseHistoryData, { recordId: "$recordId" ,
    startDate: '$startDate',  
    endDate: '$endDate' })
    wiredData({ error, data }) {
        if (error) {
            console.error('Error fetching case history:', error);
        } else if (data) {
            const totalCasesTooltip = data['Total Cases Tooltip']; 
            // Transform data and assign style classes in JS itself
            this.groupedFields = Object.keys(data)
                .filter(key => key !== 'Total Cases Tooltip')
                .map(key => ({
                    label: key,
                    value: data[key] || '0',
                    badgeClass: this.getBadgeClass(key, data[key]),
                    filterType: this.getFilterTypeForLabel(key),

                    tooltip: key === 'Total Cases' ? totalCasesTooltip : null
                }));

            this.loadUI = true;
        }
    }
    // Use arrow function to preserve `this`
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
    
        // Step 1: Close other popups across components
        window.dispatchEvent(new CustomEvent('closeAllPopups'));
    
        // Step 2: Delay this popup to allow others to close
        setTimeout(() => {
            if (!tooltip || !label) return;
    
            const rows = tooltip.split('||').map(row => row.split('##'));
            let tableHeaders = '';
            let tableRows = '';
    
            if (label === 'Total Cases') {
                tableHeaders = '<tr><th>Case Number</th><th>Status</th><th>Category</th></tr>';
                tableRows = rows.map(cols =>
                    `<tr>
                        <td><a href="/lightning/r/Case/${cols[1]}/view" target="_blank">${cols[0]}</a></td>
                        <td class="non-clickable">${cols[2]}</td>
                        <td class="non-clickable">${cols[3] || ''}</td>
                    </tr>`).join('');
            }
            else if (rows[0].length === 3 && label === 'Collected Amount') {
                tableHeaders = '<tr><th>Property</th><th>Collected</th><th>Pending</th></tr>';
                tableRows = rows.map(cols =>
                    `<tr>
                        <td class="non-clickable">${cols[0]}</td>
                        <td class="non-clickable">${cols[1]}</td>
                        <td class="non-clickable">${cols[2]}</td>
                    </tr>`).join('');
            }
            else if (rows[0].length === 2 && label === 'Total Outstanding Amount') {
                tableHeaders = '<tr><th>Property</th><th>Outstanding</th></tr>';
                tableRows = rows.map(cols =>
                    `<tr>
                        <td class="non-clickable">${cols[0]}</td>
                        <td class="non-clickable">${cols[1]}</td>
                    </tr>`).join('');
            }
            else if (rows[0].length === 2 && label === 'Owned Properties') {
                tableHeaders = '<tr><th>Unit Name</th></tr>';
                tableRows = rows.map(cols =>
                    `<tr>
                        <td><a href='/lightning/r/SalesOrder__c/${cols[1]}/view' target='_blank'>${cols[0]}</a></td>
                    </tr>`).join('');
            }
    
            const html = `
                <table class="popup-table" style="margin: 0; padding: 0;">
                    <thead class="popup-table-header">${tableHeaders}</thead>
                    <tbody>${tableRows}</tbody>
                </table>
            `;
    
            this.popupContent = html;
    
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
        }, 0); // Short delay ensures others close first
    };
    
    
    
    handleClosePopup = (event) => {
        if (event) event.stopPropagation(); // only stopPropagation if event exists
        this.groupedFields = this.groupedFields.map(field => ({
            ...field,
            showPopup: false
        }));
        this.groupedFields = [...this.groupedFields];
    };




    getBadgeClass(label, value) {
        const baseClass = 'summary-value ';

        const map = {
            'Total Cases': 'badge-blue',
            'Open Cases': 'badge-purple',
            'Closed Cases': 'badge-green',
            'SLA Breached Cases': 'badge-red'
        };

        // Exemption: Always red for breached
        if (label === 'SLA Breached Cases') {
            return baseClass + map[label];
        }

        // Grey only if value is 0 (for others)
        if (Number(value) === 0) {
            return baseClass + 'badge-green';
        }

        return baseClass + (map[label] || 'badge-default');
    }

    handleOutsideClick = (event) => {
        const popup = this.template.querySelector('.popup-card');
        const targetInsidePopup = popup?.contains(event.target);
        const clickedTrigger = event.target.closest('.owned-hover');

        if (!targetInsidePopup && !clickedTrigger) {
            this.handleClosePopup();
        }
    }

    getFilterTypeForLabel(label) {
        switch (label) {
            case 'Total Cases':
                return 'total';
            case 'Open Cases':
                return 'open';
            case 'Closed Cases':
                return 'closed';
            case 'SLA Breached':
            case 'SLA Breached Cases':
                return 'breached';
            default:
                return '';
        }
    }

    handleCardClick(event) {
        const filterType = event.currentTarget.dataset.filter;
        if (!filterType) {
            return;
        }

        this.dispatchEvent(
            new CustomEvent('opencasedrawer', {
                detail: { filterType },
                bubbles: true,
                composed: true
            })
        );
    }

    
    
}