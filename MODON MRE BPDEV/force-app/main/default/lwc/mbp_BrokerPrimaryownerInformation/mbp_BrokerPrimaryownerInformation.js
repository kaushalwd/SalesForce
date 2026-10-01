import { LightningElement, api, wire } from 'lwc';
import getPrimaryOwner from '@salesforce/apex/MBP_BrokerAgencyLevelController.getPrimaryOwner';

export default class AgencyPrimaryOwnerCard extends LightningElement {

    @api recordId;

    ownerData = {
        hasPrimaryOwner: false,
        hasPrimaryAdmin: false
    };

    @wire(getPrimaryOwner, { accountId: '$recordId' })
    wiredOwner({ data, error }) {

        if (data) {

            this.ownerData = data;

        } else if (error) {

            console.error(
                'Error loading Agency Contacts',
                JSON.stringify(error)
            );
        }
    }

    get cardClass() {

        return (
            this.ownerData.hasPrimaryOwner &&
            this.ownerData.hasPrimaryAdmin
        )
            ? 'card-container success-card'
            : 'card-container warning-card';
    }

    get ownerSectionClass() {

        return this.ownerData.hasPrimaryOwner
            ? 'contact-section contact-success'
            : 'contact-section contact-warning';
    }

    get adminSectionClass() {

        return this.ownerData.hasPrimaryAdmin
            ? 'contact-section contact-success'
            : 'contact-section contact-warning';
    }

    get headerIcon() {

        return (
            this.ownerData.hasPrimaryOwner &&
            this.ownerData.hasPrimaryAdmin
        )
            ? '✓'
            : '⚠';
    }

    get headerIconClass() {

        return (
            this.ownerData.hasPrimaryOwner &&
            this.ownerData.hasPrimaryAdmin
        )
            ? 'success-icon-3d'
            : 'warning-icon-3d';
    }
}