import { LightningElement } from 'lwc';

export default class Updatespage extends LightningElement {

    contactUsTabClass = 'active-tab'; // Set initial active tab

    // In parent component
handleEventSelect(event) {
    const eventDetail = event.detail;
    // Display event details in a modal or separate component
}

// Handle the activate tab event from the calendar component
    handleActivateTab(event) {
        // This will ensure the tab stays active when events are clicked
        // You can add additional logic here if needed
        this.contactUsTabClass = 'active-tab';
    }

    showContactUsTab() {
        // This method will be called when the tab is clicked
        this.contactUsTabClass = 'active-tab';
    }

    // In parent component
    handleEventSelect(event) {
        const eventDetail = event.detail;
        // Display event details in a modal or separate component
    }
}