import { LightningElement, api, wire,track } from 'lwc';
import getAccountDetails from '@salesforce/apex/CustomerKYCHandler.getAccountDetails';

const BASE_ICON_CLASS = 'icon-container';

export default class ExpiryTracker extends LightningElement {
    @api recordId;

    @track emiratesIdStatus = {};
    @track passportStatus = {};
    @track kycStatus = {};
    @track error;
    isLoading = true;

    @wire(getAccountDetails, { recordId: '$recordId' })
    wiredAccount({ error, data }) {
        if (data) {
            if(data.objectName == 'Account' && data.accountData != null) {
                this.emiratesIdStatus = this.calculateStatus(data.accountData.EmiratesIDExpiryDate__pc);
                this.passportStatus = this.calculateStatus(data.accountData.PassportExpiryDate__pc);
                this.kycStatus = this.calculateKycStatus(data.accountData.KYC_Completed_Date__c);
                this.error = undefined;
                this.isLoading = false;
            }else if(data.objectName == 'Contact' && data.contactData != null){
                this.emiratesIdStatus = this.calculateStatus(data.contactData.EmiratesIDExpiryDate__c);
                this.passportStatus = this.calculateStatus(data.contactData.PassportExpiryDate__c);
                this.kycStatus = this.calculateKycStatus(data.contactData.KYC_Completed_Date__c);
                this.error = undefined;
                this.isLoading = false;
            }
        } else if (error) {
            this.error = 'Failed to load data. Please check field permissions and component configuration.';
            console.error('Error fetching record data via Apex:', JSON.stringify(error));
            this.isLoading = false;
        }
    }

    calculateStatus(expiryDateString) {
    if (!expiryDateString) {
        return { 
            message: `No data provided`, 
            className: 'status-no-date',
            iconContainerClass: `${BASE_ICON_CLASS} icon-background-gray`
        };
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const expiryDate = new Date(expiryDateString);
    expiryDate.setMinutes(expiryDate.getMinutes() + expiryDate.getTimezoneOffset());
    expiryDate.setHours(0, 0, 0, 0);

    const iconClass = `${BASE_ICON_CLASS} icon-background-blue`;

    if (expiryDate.getTime() === today.getTime()) {
        return { 
            message: 'Expires today!', 
            className: 'status-expiring-soon',
            iconContainerClass: iconClass
        };
    }

    const isPast = expiryDate.getTime() < today.getTime();
    const diffString = this.formatDiff(isPast ? today : expiryDate, isPast ? expiryDate : today);

    if (isPast) {
        return { 
            message: diffString === '0 days' ? 'Expired today!' : `Expired ${diffString} ago`, 
            className: 'status-expired',
            iconContainerClass: iconClass
        };
    } else {
        const msDiff = expiryDate.getTime() - today.getTime();
        const className = msDiff <= 30 * 24 * 60 * 60 * 1000 ? 'status-expiring-soon' : 'status-valid';
        return { 
            message: diffString === '0 days' ? 'Expires today!' : `Expires in ${diffString}`, 
            className,
            iconContainerClass: iconClass
        };
    }
}

formatDiff(laterDate, earlierDate) {
    let years = laterDate.getFullYear() - earlierDate.getFullYear();
    let months = laterDate.getMonth() - earlierDate.getMonth();
    let days = laterDate.getDate() - earlierDate.getDate();

    if (days < 0) {
        months -= 1;
        const prevMonthDays = new Date(laterDate.getFullYear(), laterDate.getMonth(), 0).getDate();
        days += prevMonthDays;
    }

    if (months < 0) {
        years -= 1;
        months += 12;
    }

    const parts = [];
    if (years > 0) parts.push(`${years} year${years > 1 ? 's' : ''}`);
    if (months > 0) parts.push(`${months} month${months > 1 ? 's' : ''}`);
    if (days > 0) parts.push(`${days} day${days > 1 ? 's' : ''}`);

    return parts.length > 0 ? parts.join(' ') : '0 days';
}


    calculateKycStatus(completedDateString) {
        if (!completedDateString) {
             return { 
                message: 'KYC not completed.', 
                className: 'status-no-date',
                iconContainerClass: `${BASE_ICON_CLASS} icon-background-gray`
            };
        }

        const completedDate = new Date(completedDateString);
        completedDate.setMinutes(completedDate.getMinutes() + completedDate.getTimezoneOffset());
        
        const kycExpiryDate = new Date(completedDate);
        kycExpiryDate.setDate(kycExpiryDate.getDate() + 90);

        return this.calculateStatus(kycExpiryDate.toISOString());
    }
}