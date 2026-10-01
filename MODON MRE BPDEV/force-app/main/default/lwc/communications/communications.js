import { LightningElement, api, wire, track } from 'lwc';
import getCommunicationsData from '@salesforce/apex/CommunicationsController.getCommunicationsData';

export default class Communications extends LightningElement {
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

    @wire(getCommunicationsData, { recordId: "$recordId" })
    wiredData({ error, data }) {
        if (error) {
            console.error('Error fetching communications data:', error);
            this.loadUI = true;
        } else if (data) {
            this.apexResponse = Object.assign({}, data);
            this.groupedFields = Object.keys(this.apexResponse)
                .filter(key => key !== 'Email Tooltip')
                .map(key => {
                    let field = {
                        title: key,
                        label: key,
                        value: this.apexResponse[key],
                        showPopup: false
                    };
                    if (key === 'Emails') {
                        field.tooltipData = this.apexResponse['Email Tooltip'];
                        field.isEmail = true;
                    }
                    if (key === 'Document Control') {
                        field.isDocumentControl = true;
                    }
                    field.shouldRenderNormally = !field.isEmail && !field.isDocumentControl;
                    return field;
                });

            this.loadUI = this.groupedFields.length > 0;
        }
    }

    handleClick = (event) => {
        event.stopPropagation();
        const label = event.currentTarget.dataset.label;
        const tooltip = event.currentTarget.dataset.tooltip;
    
        window.dispatchEvent(new CustomEvent('closeAllPopups'));
    
        setTimeout(() => {
            if (label === 'Emails' && tooltip) {
                const rows = tooltip.split('||').map(row => row.split('##'));
    
                let tableHeader = '<tr><th>Email</th><th>Subject</th></tr>';
                let tableRows = rows.map((cols, index) =>
                    `<tr>
                        <td><a href='/lightning/r/EmailMessage/${cols[0]}/view' target='_blank'>Email #${index + 1}</a></td>
                        <td class="non-clickable">${cols[1]}</td>
                    </tr>`).join('');
    
                this.popupContent = `
                    <table class="popup-table">
                        <thead class="popup-table-header">${tableHeader}</thead>
                        <tbody>${tableRows}</tbody>
                    </table>
                `;
    
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
        }, 0);
    }
    

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