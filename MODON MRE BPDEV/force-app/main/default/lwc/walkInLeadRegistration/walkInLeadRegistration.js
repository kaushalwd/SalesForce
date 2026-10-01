import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createLead from '@salesforce/apex/WalkInLeadController.createLead';
import searchBrokers from '@salesforce/apex/WalkInLeadController.getAllBrokerAccounts';
import searchLeads from '@salesforce/apex/WalkInLeadController.getLeadsForSiteUser';
import updateLeadAppointments from '@salesforce/apex/WalkInLeadController.updateLeadAppointment';
import updateAccountAppointment from '@salesforce/apex/WalkInLeadController.updateAccountAppointment';
import getBrokerContacts from '@salesforce/apex/WalkInLeadController.getBrokerContacts';
import searchAccounts from '@salesforce/apex/WalkInLeadController.searchAccounts';
import logoStatic from '@salesforce/resourceUrl/modonImg';
import backgroundImage from '@salesforce/resourceUrl/Walk_in_Lead_BG';

export default class WalkInLeadRegistration extends LightningElement {
    logoUrl = logoStatic;

    @track showToast = false;
    @track toastMessage = '';
    @track toastClass = 'toast success';

    // Form state
    @track accountName = '';
    @track activeTab = 'direct';
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track phone = '';
    @track countryCode = '+971';
    @track appointment = '';
    @track selectedBrokerId = '';
    @track brokerSearchTerm = '';

    // UI state
    @track brokerResults = [];
    @track isLoading = false;
    @track isSubmitting = false;
    @track dbAppointmentDateTime = ''; // from DB
    @track appointmentBroker = ''; // stores Yes/No for broker appointment
    @track appointmentBrokerDateTime = ''; // stores new date input
    @track dbBrokerAppointmentDateTime = ''; // DB date for broker only
    @track dbBrokerDate = '';
    @track dbBrokerTime = '';



    // Lead search results
    @track leadResults = [];
    @track leadSearchTerm = '';
    @track appointmentDateTime = '';
    @track selectedLead = null;
    @track selectedBroker = null;

    // Broker Agency lookup for Direct Customer form
    @track brokerAgencySearchTerm = '';
    @track brokerAgencyResults = [];
    @track selectedBrokerAgency = null;
    @track brokerContacts = []; // Store broker contacts
    @track selectedBrokerContact = null; // Store selected contact

    // Country codes
    get countryCodeOptions() {
        return [
            { label: '+971 (UAE)', value: '+971' },
            { label: '+91 (India)', value: '+91' },
            { label: '+44 (UK)', value: '+44' },
            { label: '+1 (USA)', value: '+1' }
        ];
    }

    get backgroundStyle() {
    return `background-image: url("${backgroundImage}"); background-size: cover; background-position: center; background-repeat: no-repeat; min-height: 100vh;`;
}


    appointmentOptions = [
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' }
    ];

    // Lead Appointment Date logic
    get showAppointmentDate() {
        return this.appointment === 'No';
    }

    get showExistingAppointmentDate() {
        return this.appointment === 'Yes' && this.dbAppointmentDateTime;
    }

    // Broker Appointment Date logic - matching lead logic
    get showExistingBrokerAppointmentDate() {
        return this.appointmentBroker === 'Yes' && this.dbBrokerAppointmentDateTime;
    }

    get showBrokerAppointmentDate() {
        return this.appointmentBroker === 'No';
    }



    // Tab button styles
    get directClass() { return this.activeTab === 'direct' ? 'active' : 'inactive'; }
    get existingLeadClass() { return this.activeTab === 'lead' ? 'active' : 'inactive'; }
    get existingBrokerClass() { return this.activeTab === 'existingBroker' ? 'active' : 'inactive'; }
    get brokerClass() { return this.activeTab === 'broker' ? 'active' : 'inactive'; }

    // Tab state helpers
    get isDirect() { return this.activeTab === 'direct'; }
    get isExistingLead() { return this.activeTab === 'lead'; }
    get isExistingBroker() { return this.activeTab === 'existingBroker'; }
    get isBroker() { return this.activeTab === 'broker'; }

    // Tab button handlers
    showDirectCustomer() { this.activeTab = 'direct'; }
    showExistingLead() { this.activeTab = 'lead'; }
    showExistingBroker() { this.activeTab = 'existingBroker'; }
    showBroker() { this.activeTab = 'broker'; }

    handleChange(event) {
        const { name, value } = event.target;

        // ---- Lead Appointment ----
        if (name === 'appointment') {
            this.appointment = value;

            if (value === 'Yes') {
                // If appointment already exists → show DB datetime
                this.appointmentDateTime = this.dbAppointmentDateTime;
            } else {
                // Clear so user can enter new datetime
                this.appointmentDateTime = '';
            }
        }
        else if (name === 'appointmentDateTime') {
            this.appointmentDateTime = value;
        }

        // ---- Broker Appointment ----
        else if (name === 'appointmentBroker') {
            this.appointmentBroker = value;

            if (value === 'Yes') {
                // Show DB broker appointment datetime
                this.appointmentBrokerDateTime = this.dbBrokerAppointmentDateTime;
            } else {
                // Clear so user can enter new datetime
                this.appointmentBrokerDateTime = '';
            }
        }
        else if (name === 'appointmentBrokerDateTime') {
            this.appointmentBrokerDateTime = value;
        }

        // ---- Other fields ----
        else {
            this[name] = value;
        }
    }


    // Broker Agency Search for Direct Customer form
    handleBrokerAgencySearch(event) {
        this.brokerAgencySearchTerm = event.target.value;

        if (!this.brokerAgencySearchTerm || this.brokerAgencySearchTerm.trim() === '') {
            this.brokerAgencyResults = [];
            this.selectedBrokerAgency = null;
            return;
        }

        if (this.brokerAgencySearchTerm.length < 2) {
            this.brokerAgencyResults = [];
            return;
        }

        searchAccounts({ searchKey: this.brokerAgencySearchTerm })
            .then(result => {
                this.brokerAgencyResults = result.map(b => ({
                    Id: b.id,
                    Name: b.name
                }));
            })
            .catch(error => {
                console.error('Error searching broker agencies:', error);
                this.brokerAgencyResults = [];
            });
    }

    async selectBrokerAgency(event) {
        const brokerAgencyId = event.currentTarget.dataset.id;
        this.selectedBrokerAgency = this.brokerAgencyResults.find(b => b.Id === brokerAgencyId);

        this.selectedBrokerContact = null;
        this.brokerContacts = [];

        await this.loadBrokerContacts(brokerAgencyId);
    }

    async loadBrokerContacts(brokerAgencyId) {
        try {
            this.isLoading = true;
            const contacts = await getBrokerContacts({ accountId: brokerAgencyId });

            this.brokerContacts = contacts.map(contact => ({
                Id: contact.Id,
                Name: contact.Name,
                Email: contact.Email,
                Phone: contact.Phone,
                Title: contact.Title,
                isSelected: false
            }));
        } catch (error) {
            console.error('Error loading broker contacts:', error);
            this.showCustomMessage('Error loading broker contacts', 'error');
            this.brokerContacts = [];
        } finally {
            this.isLoading = false;
        }
    }

    selectBrokerContact(event) {
        const contactId = event.currentTarget.dataset.id;

        this.brokerContacts = this.brokerContacts.map(contact => ({
            ...contact,
            isSelected: contact.Id === contactId
        }));

        this.selectedBrokerContact = this.brokerContacts.find(contact => contact.Id === contactId);
    }

    clearBrokerAgency() {
        this.selectedBrokerAgency = null;
        this.selectedBrokerContact = null;
        this.brokerAgencySearchTerm = '';
        this.brokerAgencyResults = [];
        this.brokerContacts = [];
    }

    get showSearchBox() {
        return this.isExistingLead || this.isExistingBroker;
    }

    handleLeadSearch(event) {
        this.leadSearchTerm = event.target.value;

        if (!this.leadSearchTerm || this.leadSearchTerm.trim() === '') {
            this.leadResults = [];
            this.selectedLead = null;
            return;
        }

        if (this.leadSearchTerm.length < 2) {
            this.leadResults = [];
            return;
        }

        searchLeads({ searchKey: this.leadSearchTerm })
            .then(result => {
                this.leadResults = result.map(l => ({
                    ...l,
                    cardClass: this.selectedLead && this.selectedLead.Id === l.Id ? 'result-card selected' : 'result-card'
                }));
            })
            .catch(error => {
                console.error('Error searching leads:', error);
                this.leadResults = [];
            });
    }

    handleBrokerSearch(event) {
        this.brokerSearchTerm = event.target.value;

        if (!this.brokerSearchTerm || this.brokerSearchTerm.trim() === '') {
            this.brokerResults = [];
            this.selectedBroker = null;
            return;
        }

        if (this.brokerSearchTerm.length < 2) {
            this.brokerResults = [];
            return;
        }

        searchBrokers({ searchKey: this.brokerSearchTerm })
            .then(result => {
                this.brokerResults = result.map(b => ({
                    ...b,
                    cardClass: this.selectedBroker && this.selectedBroker.id === b.id ? 'result-card selected' : 'result-card'
                }));
            })
            .catch(error => {
                console.error('Error searching brokers:', error);
                this.brokerResults = [];
            });
    }

    async handleSubmit() {
        this.isLoading = true;
        this.isSubmitting = true;
        try {
            await createLead({
                firstName: this.firstName,
                lastName: this.lastName,
                email: this.email,
                phone: this.countryCode + this.phone,
                type: this.activeTab === 'broker' ? 'Broker' : 'Direct',
                appointment: this.appointment,
                appointmentDateTime: this.appointment === 'No' ? this.appointmentDateTime : null,
                brokerAccountId: this.selectedBrokerAgency ? this.selectedBrokerAgency.Id : null,
                brokerContactId: this.selectedBrokerContact ? this.selectedBrokerContact.Id : null
            });
            this.showCustomMessage('Lead created successfully!', 'success');
            this.refreshComponent();
        } catch (error) {
            console.error('Error creating lead:', error);
            this.showCustomMessage(this.parseError(error), 'error');
        } finally {
            this.isLoading = false;
            this.isSubmitting = false;
        }
    }

    parseError(error) {
        if (!error) return 'Unknown error occurred.';
        if (error.body && error.body.message) return error.body.message;
        if (typeof error.body === 'string') return error.body;
        if (error.message) return error.message;
        return 'Unexpected error occurred. Please try again.';
    }

    showCustomMessage(message, type) {
        this.toastMessage = message;
        this.toastClass = type === 'error' ? 'toast error' : 'toast success';
        this.showToast = true;
        setTimeout(() => this.showToast = false, 6000);
    }

    refreshComponent() {
        this.accountName = '';
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.phone = '';
        this.countryCode = '+971';
        this.selectedBrokerId = '';
        this.appointment = '';
        this.appointmentDateTime = '';
        this.selectedLead = null;
        this.selectedBroker = null;
        this.leadResults = [];
        this.brokerResults = [];
        this.leadSearchTerm = '';
        this.brokerSearchTerm = '';
        this.clearBrokerAgency();
    }

    leadCardClass(leadId) {
        return this.selectedLead && this.selectedLead.Id === leadId ? 'result-card selected' : 'result-card';
    }

    brokerCardClass(brokerId) {
        return this.selectedBroker && this.selectedBroker.id === brokerId ? 'result-card selected' : 'result-card';
    }

    formatDateTimeForInput(dateTimeString) {
        if (!dateTimeString) return '';
        const dt = new Date(dateTimeString);
        const yyyy = dt.getFullYear();
        const mm = String(dt.getMonth() + 1).padStart(2, '0');
        const dd = String(dt.getDate()).padStart(2, '0');
        const hh = String(dt.getHours()).padStart(2, '0');
        const min = String(dt.getMinutes()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}T${hh}:${min}`;
    }

    selectLead(event) {
        const leadId = event.currentTarget.dataset.id;
        this.selectedLead = this.leadResults.find(l => l.Id === leadId);

        this.dbAppointmentDateTime = this.formatDateTimeForInput(this.selectedLead.Appointment_Date_Time__c);

        this.appointment = this.selectedLead.Appointment__c || (this.dbAppointmentDateTime ? 'Yes' : 'No');

        this.leadResults = this.leadResults.map(l => ({
            ...l,
            cardClass: l.Id === leadId ? 'result-card selected' : 'result-card'
        }));
    }

    selectBroker(event) {
        const brokerId = event.currentTarget.dataset.id;
        this.selectedBroker = this.brokerResults.find(b => b.id === brokerId);

        if (!this.selectedBroker) return;

        // Format DB appointment datetime
        this.dbBrokerAppointmentDateTime = this.formatDateTimeForInput(this.dbAppointmentDateTime = this.selectedBroker.appointmentDateTime);

        // Set appointment radio → same as Lead
        this.appointmentBroker = this.selectedBroker.Appointment__c || (this.dbBrokerAppointmentDateTime ? 'Yes' : 'No');

        // Clear manual input (only needed when user selects "No")
        this.appointmentBrokerDateTime = '';

        // Highlight selected card
        this.brokerResults = this.brokerResults.map(b => ({
            ...b,
            cardClass: b.id === brokerId ? 'result-card selected' : 'result-card'
        }));
    }

    async updateLeadAppointment() {
        if (!this.selectedLead || !this.selectedLead.Id) {
            this.showCustomMessage('Please select a valid lead.', 'error');
            return;
        }

        if (this.appointment === 'Yes') {
            this.showCustomMessage('Appointment already exists in the system.', 'info');
            return;
        }

        if (!this.appointmentDateTime) {
            this.showCustomMessage('Please enter appointment date/time.', 'error');
            return;
        }

        try {
            await updateLeadAppointments({
                leadId: this.selectedLead.Id,
                appointmentDateTime: this.appointmentDateTime
            });
            this.showCustomMessage('Lead appointment updated successfully!', 'success');
            this.reloadComponent();
        } catch (error) {
            this.showCustomMessage(this.parseError(error), 'error');
        }
    }

    async updateBrokerAppointment() {
        if (!this.selectedBroker || !this.selectedBroker.id) {
            this.showCustomMessage('Please select a valid broker.', 'error');
            return;
        }

        if (this.appointmentBroker === 'Yes') {
            this.showCustomMessage('Appointment already exists in the system.', 'info');
            return;
        }

        if (!this.appointmentBrokerDateTime) {
            this.showCustomMessage('Please enter appointment date/time.', 'error');
            return;
        }

        try {
            this.isSubmitting = true;
            await updateAccountAppointment({
                brokerId: this.selectedBroker.id,
                appointmentDateTime: this.appointmentBrokerDateTime
            });
            this.showCustomMessage('Broker appointment updated successfully!', 'success');
            this.reloadComponent();
        } catch (error) {
            this.showCustomMessage(this.parseError(error), 'error');
        } finally {
            this.isSubmitting = false;
        }
    }


    reloadComponent() {
        const savedTab = this.activeTab;
        this.isLoading = true;
        setTimeout(() => {
            this.refreshComponent();
            this.activeTab = savedTab;
            this.isLoading = false;
        }, 800);
    }

    connectedCallback() {
        const savedTab = sessionStorage.getItem('activeTab');
        if (savedTab) this.activeTab = savedTab;
    }
}