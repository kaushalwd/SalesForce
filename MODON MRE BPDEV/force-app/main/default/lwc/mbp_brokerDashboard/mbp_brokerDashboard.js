import { LightningElement ,track, api, wire} from 'lwc';
import {loadScript,loadStyle} from 'lightning/platformResourceLoader';
import ModonImages from "@salesforce/resourceUrl/modonImages";
import Bootstrap from "@salesforce/resourceUrl/Bootstrap";
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import ToastContainer from 'lightning/toastContainer';
import getLoggedInUserDetail from '@salesforce/apex/MBP_BrokerAgencyDashboardController.getLoggedInUserDetail';
// Reuse Draftstagecontroller's Fast Track / needs-more-info logic (the same
// class that decides whether the real "My Agency" nav tab shows) instead of
// re-deriving it here - keeps the restricted-access card in sync with the
// actual nav.
import findRegistrationWithReviewComment from '@salesforce/apex/Draftstagecontroller.findRegistrationWithReviewComment';

export default class BrokerDashboard extends LightningElement {
    accountId;
    ContactId;
    loggedInUserName;
    agencyName;
    kpiList = [];
    error;
    userPhotoUrl;
    isOwner = false;
    isAgent = false;
    isAdmin = false;
    isLimitedLogin = false;

    // From Draftstagecontroller.findRegistrationWithReviewComment:
    // isFastTrack mirrors `showSales` (only ever true when the broker's
    // Service Request is Fast Track) and drives which restricted-access
    // message shows, plus whether the "Go to my leads" button appears at all.
    @track isFastTrack = false;

    @track kpiListOne = [];
    @track kpiListTwo = [];
    @track isLoading = false;

    connectedCallback() { 
        Promise.all([
        loadStyle(this, Bootstrap+ '/css/bootstrap.min.css'),
        loadScript(this, Bootstrap + '/js/bootstrap.bundle.min.js')
            ])
            .catch(error => {
                console.error('Error loading styles', error);
            });
    }

    @wire(getLoggedInUserDetail)
    wiredUser({ error, data }) {
        if (data) {
            
            this.accountId = data.user.AccountId;
            this.ContactId = data.user.ContactId;
            this.loggedInUserName = data.user.Name ? data.user.Name :'Partner';
            this.agencyName = data.user.Account.Name;
            this.userPhotoUrl = data.user.FullPhotoUrl;
            this.isLimitedLogin = data.isLimitedLoginAccess;
            
            if(data.user.Contact.Broker_Type__c=='Owner'){
                this.isOwner = true;
            }else if(data.user.Contact.Broker_Type__c=='Agent'){
                this.isAgent = true;
            }else if(data.user.Contact.Broker_Type__c=='Agency Admin'){
                this.isAdmin = true;
            }

        } else if (error) {
            console.error('Error fetching user details:', error);
        }
    }

    @wire(findRegistrationWithReviewComment)
    wiredRegistration({ error, data }) {
        if (data) {
            // showSales is only ever set true inside Draftstagecontroller's
            // Fast Track branch, so it's a reliable proxy for "is Fast Track".
            this.isFastTrack = !!data.showSales;
        } else if (error) {
            console.error('Error fetching registration details:', error);
        }
    }

}