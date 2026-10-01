/**
* Description: LWC for Personal Info chart Customer 360 dashboard
* Author: Chaitanya N
* Name: PersonalInfo
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, track, wire } from 'lwc';
import getPersonalInformationData from '@salesforce/apex/PersonalInformationController.getPersonalInformationData';
import updatePersonalInformation from '@salesforce/apex/PersonalInformationController.updatePersonalInformation';
import Customer360Profileicon from '@salesforce/resourceUrl/Customer360MainProfileicon';
import Customer360warningicon from '@salesforce/resourceUrl/Customer360warningicon';
import Customer360tickicon from '@salesforce/resourceUrl/Customer360tickicon';
import Customer360updateicon from '@salesforce/resourceUrl/Customer360updateicon';

export default class PersonalInfo extends LightningElement {
    @api recordId;
    @api startDate;
@api endDate;
    @track groupedFields = [];
    @track showExpiryWarning = false;
    @track expiryWarningText = '';
    @track showModal = false;
    @track modalType = '';
    @track modalNumber = '';
    @track modalExpiryDate = '';
@track eidFrontFile;
@track eidBackFile;
@track passportFile;

@track eidFrontUrl;
@track eidBackUrl;
@track passportUrl;

    profileicon = Customer360Profileicon;
    warningicon = Customer360warningicon;
    updateiocn = Customer360updateicon;
    customertickicon = Customer360tickicon;

    eidNumber;
    eidExpiry;
    passportNumber;
    passportExpiry;

connectedCallback() {
    // Prevent blur/shake effects from propagating outside
    this.template.addEventListener('mouseenter', () => {
        const allCards = document.querySelectorAll('.executive-summary-card');
        allCards.forEach(card => card.classList.remove('blur-effect'));
    });
}

    @wire(getPersonalInformationData, { recordId: "$recordId" ,startDate: "$startDate",
    endDate: "$endDate"})
    wiredData({ error, data }) {
        if (data) {
            this.prepareFields(data);
        } else if (error) {
            console.error('Error fetching data:', error);
        }
    }

    prepareFields(data) {
        this.groupedFields = [];
        this.showExpiryWarning = false;
        this.expiryWarningText = '';

        const today = new Date();
        const warningMessages = [];

        for (let key in data) {
            const rawValue = data[key];
            const value = rawValue ? rawValue : 'N/A';
            let cssClass = 'value';

            // Emirates ID logic
            if (key.includes('Emirates ID')) {
                if (key.includes('Number')) {
                    this.eidNumber = value;
                }
                if (key.includes('Expiry') && value !== 'N/A') {
                    this.eidExpiry = new Date(value);
                    const diff = this.daysLeft(this.eidExpiry, today);
                    if (diff <= 15) {
                        cssClass = 'value highlight';
                        warningMessages.push(`Emirates ID expires in ${diff} day(s)`);
                    }
                }
            }

            // Passport logic
            if (key.includes('Passport')) {
                if (key.includes('Number')) {
                    this.passportNumber = value;
                }
                if (key.includes('Expiry') && value !== 'N/A') {
                    this.passportExpiry = new Date(value);
                    const diff = this.daysLeft(this.passportExpiry, today);
                    if (diff <= 15) {
                        cssClass = 'value highlight';
                        warningMessages.push(`Passport expires in ${diff} day(s)`);
                    }
                }
            }

            this.groupedFields.push({
                label: key,
                value,
                cssClass
            });
        }

        // Expiry warning if any field expiring soon
        if (warningMessages.length > 0) {
            this.showExpiryWarning = true;
            this.expiryWarningText = warningMessages.join(', ');
        }
    }

    daysLeft(expiryDate, today) {
        const diffTime = expiryDate.getTime() - today.getTime();
        return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    }

    handleUpdateClick() {
        if (this.eidExpiry && this.daysLeft(this.eidExpiry, new Date()) <= 30) {
            this.modalType = 'Emirates ID';
            this.modalNumber = this.eidNumber === 'N/A' ? '' : this.eidNumber;
            this.modalExpiryDate = this.formatDate(this.eidExpiry);
        } else if (this.passportExpiry && this.daysLeft(this.passportExpiry, new Date()) <= 30) {
            this.modalType = 'Passport';
            this.modalNumber = this.passportNumber === 'N/A' ? '' : this.passportNumber;
            this.modalExpiryDate = this.formatDate(this.passportExpiry);
        } else {
            return;
        }
        this.showModal = true;
    }

    handleNumberChange(event) {
        this.modalNumber = event.target.value;
    }

    handleExpiryChange(event) {
        this.modalExpiryDate = event.target.value;
    }

    async handleSave() {
        try {
            await updatePersonalInformation({
                recordId: this.recordId,
                type: this.modalType,
                number1: this.modalNumber,
                expiryDate: this.modalExpiryDate
            });
            this.showModal = false;
            window.location.reload();
        } catch (error) {
            console.error('Failed to update:', error);
        }
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleUploadFileChange(event) {
    const file = event.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (e) => {
        const base64Data = e.target.result.split(',')[1];
        const fileType = event.target.dataset.type;

        if (fileType === 'front') {
            this.eidFrontFile = { name: file.name, base64: base64Data, type: file.type };
            this.eidFrontUrl = `data:${file.type};base64,${base64Data}`;
        } else if (fileType === 'back') {
            this.eidBackFile = { name: file.name, base64: base64Data, type: file.type };
            this.eidBackUrl = `data:${file.type};base64,${base64Data}`;
        } else if (fileType === 'passport') {
            this.passportFile = { name: file.name, base64: base64Data, type: file.type };
            this.passportUrl = `data:${file.type};base64,${base64Data}`;
        }
    };
    reader.readAsDataURL(file);
}

handleDeleteFile(event) {
    const type = event.target.dataset.type;
    if (type === 'front') {
        this.eidFrontFile = null;
        this.eidFrontUrl = null;
    } else if (type === 'back') {
        this.eidBackFile = null;
        this.eidBackUrl = null;
    } else if (type === 'passport') {
        this.passportFile = null;
        this.passportUrl = null;
    }
}


    formatDate(dateObj) {
        const yyyy = dateObj.getFullYear();
        const mm = String(dateObj.getMonth() + 1).padStart(2, '0');
        const dd = String(dateObj.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    get modalNumberLabel() {
        return `${this.modalType} Number`;
    }

    get modalExpiryLabel() {
        return `${this.modalType} Expiry Date`;
    }

    get isEmiratesId() {
    return this.modalType === 'Emirates ID';
}

get isPassport() {
    return this.modalType === 'Passport';
}


    get cardClass() {
        return this.showExpiryWarning
            ? 'executive-summary-card card-warning'
            : 'executive-summary-card';
    }
}