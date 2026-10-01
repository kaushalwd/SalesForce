import { LightningElement, track, wire,api } from 'lwc';
import getSOAData from '@salesforce/apex/SOAController.getSOAData';
import ChartJS from '@salesforce/resourceUrl/ChartJs';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import logowhite from '@salesforce/resourceUrl/logowhite';
import getPDF from '@salesforce/apex/CommunityHomeController.getPDF';
import instagram from '@salesforce/resourceUrl/instagram'
import youtubeicon from '@salesforce/resourceUrl/youtubeicon';
import linkedinicon from '@salesforce/resourceUrl/linkedinicon';
import facebook from '@salesforce/resourceUrl/facebook';
import twitterx from '@salesforce/resourceUrl/Twitterx';
import { NavigationMixin } from 'lightning/navigation';
import MODONURL from '@salesforce/label/c.CP_ModonUrl';
import PROFILEURL from '@salesforce/label/c.CP_ProfileUrl';
import LOGOUTURL from '@salesforce/label/c.CP_LogoutUrl';
import PROPURL from '@salesforce/label/c.CP_MyPropertiesUrl';
import HOMEPAGE from '@salesforce/label/c.Customer_Portal_URL';

import basePath from "@salesforce/community/basePath";
import FORM_FACTOR from '@salesforce/client/formFactor';

export default class SoaStatementLWC extends NavigationMixin(LightningElement) {
    instagramUrl = instagram;
    youtubeiconUrl = youtubeicon;
    linkediniconUrl = linkedinicon;
    facebookUrl = facebook;
    twitterxUrl = twitterx;
    showSearch = false;
    showNotif = false;
    menuOpen = false;
    contactid=null;
    menuOpen = false;
    showNotif=false;
     isMobile = false;
    isTablet = false;
    isDesktop = false;
  // properties = [];
    allProperties = [];
    searchProjectName = '';
    searchUnitName = '';
    isLoading = false;
    @api recordId;
    @track salesOrder = {};
    @track installments = [];
    @track otherPayments = [];
    @track grandTotalOutstanding;
    @track totalCollected = 0;
    @track totalInstallments = 1;       // Added
    @track totalPaidInstallments = 0;    // Added
    @track installmentColumns = [];
    @track otherPaymentColumns = [];
    @track isLoading = true;
    isChartJsInitialized = false;
    logowhiteUrl = logowhite;
    dateval;
    paidpercent = 0;
    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        this.recordId = urlParams.get('recordId');
        if (FORM_FACTOR === 'Large') {
            this.isDesktop = true;
        } else {
            this.isMobile = true;
        }
    }

    @wire(getSOAData, { salesOrderId: '$recordId' })
    soaData({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.salesOrder = data.salesOrder;
            this.dateval=data.currentdate;
            this.installments = data.installments.map(i => ({
                id: i.Id,
                milestoneDescription: i.SalesOrderInstallment__r?.MilestoneDescription__c,
                milestoneNumber: i.SalesOrderInstallment__r?.MilestoneNumber__c,
                milestone: i.SalesOrderInstallment__r?.Milestone__c,
                milestoneDate: i.SalesOrderInstallment__r?.MilestoneDate__c,
                invoiceAmount: i.InvoiceAmount__c,
                appliedAmount: i.AppliedAmount__c,
                invoiceBalance: i.InvoiceBalance__c,
               /* allocationDate: i.Allocations__r?.length > 0 ? i.Allocations__r[0].AllocationDate__c : null*/
            }));

            this.otherPayments = data.otherPayments.map(i => ({
                id: i.Id,
                name: i.Name,
                type: i.Charge__r?.Type__c,
                invoiceAmount: i.InvoiceAmount__c,
                appliedAmount: i.AppliedAmount__c,
                invoiceBalance: i.InvoiceBalance__c
            }));

            this.grandTotalOutstanding = data.grandTotalOutstanding;
            this.totalCollected = data.totalCollected;

            this.totalPaidInstallments = data.installmentSummary?.totalPaidInstallments || 0;
            this.totalInstallments = data.installmentSummary?.totalInstallments || 1;

            this.initializeColumns();

            if (!this.isChartJsInitialized) {
                loadScript(this, ChartJS)
                    .then(() => {
                        this.initializeCharts();
                        this.isChartJsInitialized = true;
                    })
                    .catch(err => console.error('Chart.js load failed', err));
            } else {
                this.initializeCharts();
            }
        } else if (error) {
            console.error('Error loading SOA data', error);
        }
    }

    initializeColumns() {
        this.installmentColumns = [
            { label: 'Installment Name', fieldName: 'milestoneDescription', type: 'text',cellAttributes: { alignment: 'center' } },
            { label: 'Installment', fieldName: 'milestoneNumber', type: 'number',cellAttributes: { alignment: 'center' } },
            { label: '%', fieldName: 'milestone', type: 'number' ,cellAttributes: { alignment: 'center' }},
            { label: 'Due Date', fieldName: 'milestoneDate', type: 'date',cellAttributes: { alignment: 'center' }},
            { label: 'Amount Due', fieldName: 'invoiceAmount', type: 'currency', typeAttributes: { currencyCode: 'AED' },cellAttributes: { alignment: 'center' } },
            { label: 'Amount Collected', fieldName: 'appliedAmount', type: 'currency', typeAttributes: { currencyCode: 'AED' } ,cellAttributes: { alignment: 'center' }},
            { label: 'Date Received', fieldName: 'allocationDate', type: 'date',cellAttributes: { alignment: 'center' }},
           /* { label: 'Amount Outstanding (AED)', fieldName: 'invoiceBalance', type: 'currency', typeAttributes: { currencyCode: 'AED' }, initialWidth: 200 } */
        ];
        
        
        this.otherPaymentColumns = [
            { label: 'Transaction #', fieldName: 'name', type: 'text',cellAttributes: { alignment: 'center' } },
            { label: 'Transaction Type', fieldName: 'type', type: 'text',cellAttributes: { alignment: 'center' } },
            { label: 'Amount', fieldName: 'invoiceAmount', type: 'currency', typeAttributes: { currencyCode: 'AED' } ,cellAttributes: { alignment: 'center' }},
            { label: 'Amount Collected', fieldName: 'appliedAmount', type: 'currency', typeAttributes: { currencyCode: 'AED',cellAttributes: { alignment: 'center' } } },
            { label: 'Amount Outstanding', fieldName: 'invoiceBalance', type: 'currency', typeAttributes: { currencyCode: 'AED',cellAttributes: { alignment: 'center' } } }
        ];
    }

    initializeCharts() {
        const installmentsCompleted = this.totalPaidInstallments || 0;
        const installmentsTotal = this.totalInstallments || 1;
        const percentCompleted = Math.round((installmentsCompleted / installmentsTotal) * 100);
    
        const equityPaid = this.totalCollected || 0;
        const equityTotal = this.salesOrder.TotalAmount__c || 1;
        const percentEquity = Math.round((equityPaid / equityTotal) * 100);
        this.paidpercent = percentEquity;
    
        const drawDonut = (canvasSelector, paidValue, totalValue, color, type) => {
            const canvas = this.template.querySelector(canvasSelector);
            if (!canvas) return;
            const ctx = canvas.getContext('2d');
    
            const remainingValue = totalValue - paidValue;
    
            new Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: ['Paid', 'Remaining'],
                    datasets: [{
                        data: [paidValue, remainingValue],
                        backgroundColor: [color, '#ede6db'],
                        borderWidth: 3
                    }]
                },
                options: {
                    cutout: '70%',
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        tooltip: { 
                            enabled: true,
                            callbacks: {
                                label: function(context) {
                                    const label = context.label || '';
                                    const value = context.raw;
                                    return `${label}: ${value}`; // show actual value, not percent
                                }
                            }
                        },
                        legend: { display: false }
                    }
                },
                plugins: [{
                    id: 'centerText',
                    beforeDraw(chart) {
                        const { width, height, ctx } = chart;
                        ctx.restore();
                        ctx.font = `${(height / 5).toFixed(2)}px Arial`;
                        ctx.textBaseline = 'middle';
                        let text = '';
                        if (type === 'installment') {
                            text = `${paidValue}/${totalValue}`;
                        } else if (type === 'equity') {
                            text = `${Math.round((paidValue/totalValue)*100)}%`;
                        }
                        const textX = Math.round((width - ctx.measureText(text).width) / 2);
                        const textY = height / 2;
                        ctx.fillText(text, textX, textY);
                        ctx.save();
                    }
                }]
            });
        };
        const drawDonut1 = (canvasSelector, percent, color) => {
            const canvas = this.template.querySelector(canvasSelector);
            if (!canvas) return;
            const ctx = canvas.getContext('2d');
    
            new Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: ['Paid', 'Remaining'],
                    datasets: [{
                        data: [percent, 100 - percent],
                        backgroundColor: [color, '#ede6db'],
                        borderWidth: 3
                    }]
                },
                options: {
                    cutout: '70%',
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        tooltip: { 
                            enabled: true, // Enable hover tooltip
                            callbacks: {
                                label: function(context) {
                                    let label = context.label || '';
                                    let value = context.raw;
                                    return `${label}: ${value}%`;
                                }
                            }
                        },
                        legend: { display: false }
                    }
                },
                plugins: [{
                    id: 'centerText',
                    beforeDraw(chart) {
                        const { width, height, ctx } = chart;
                        ctx.restore();
                        ctx.font = `${(height / 5).toFixed(2)}px Arial`;
                        ctx.textBaseline = 'middle';
                        const text = percent + '%';
                        const textX = Math.round((width - ctx.measureText(text).width) / 2);
                        const textY = height / 2;
                        ctx.fillText(text, textX, textY);
                        ctx.save();
                    }
                }]
            });
        };
    
        // For Installments (like 3/8)
        drawDonut('canvas.donut-chart-installments', installmentsCompleted, installmentsTotal, '#d3b88a', 'installment');
        // For Equity (percent)
        drawDonut1('canvas.donut-chart-equity', percentEquity, '#d3b88a');

    }
    
    

    handleDownloadPDF() {
        window.print();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    copyAccountNumber() {
        navigator.clipboard.writeText(this.salesOrder.VirtualAccount__r.VirtualAccountNumber__c);
        this.showToast('Copied!', 'Account number copied.', 'success');
    }

    copyIBAN() {
        navigator.clipboard.writeText(this.salesOrder.VirtualAccount__r.VirtualIBANNumber__c);
        this.showToast('Copied!', 'IBAN copied.', 'success');
    }

    copySwift() {
        navigator.clipboard.writeText(this.salesOrder.VirtualAccount__r.SwiftCode__c);
        this.showToast('Copied!', 'Swift code copied.', 'success');
    }
    toggleMenu() {
        this.showSearch = false;
        this.showNotif = false;
        this.menuOpen = !this.menuOpen;
    }
    toggleSearch() {
        this.menuOpen = false;
        this.showNotif = false;
        this.showSearch = !this.showSearch;
    }

    toggleNotif() {
        this.menuOpen = false;
        this.showSearch = false;
        this.showNotif = !this.showNotif;
    }
    handleMenuSelect(event) {
        const selectedValue =  event.target.dataset.id;// Correct way to access the selected item value

       if (selectedValue === 'home') {
            window.location.href = HOMEPAGE;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/'; // Navigate to profile settings
        } else if(selectedValue === 'logout') {
            const sitePrefix = basePath.replace("/", "");
            window.location.href = LOGOUTURL; //'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/secur/logout.jsp';
        } else if (selectedValue === 'profile') {
            window.location.href = PROFILEURL; //'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/myprofile'; // Navigate to profile settings
        }else {
            console.warn('Unknown option selected:', selectedValue);
        }
    }
     handleButtonMethod(event) {
            this.isLoading = true;
            this.selectedSalesOrderId =event.target.dataset.id;
            let msg = 'ButtonName : ' + event.target.label + ' Id : ' + event.target.dataset.id;
            if(event.target.dataset.value === 'SOA'){
                getPDF({recId: this.selectedSalesOrderId})
                    .then(result =>{
                        const byteCharacters = atob(result);
                        const byteNumbers = new Array(byteCharacters.length);
                        for (let i = 0; i < byteCharacters.length; i++) {
                            byteNumbers[i] = byteCharacters.charCodeAt(i);
                        }
                        const byteArray = new Uint8Array(byteNumbers);
                        const fileBlob = new Blob([byteArray], { type: 'application/pdf' });
    
                        // Create a download link
                        const link = document.createElement('a');
                        link.href = URL.createObjectURL(fileBlob);
                        link.target = '_blank';
                        //link.download = 'StatementOfAccount.pdf';
                        document.body.appendChild(link);
                        link.click();
                    })
                    .catch(() => {})
            } 
            this.isLoading = false;
        }

        handleContactUs(){
            const url = 'https://www.modon.com/contact-us';
            window.open(url,'_blank');
        }
        handleModon(){
            const url = 'https://www.modon.com/';
            window.open(url,'_blank');
        }
        handleinstagram(){
            const url = 'https://www.instagram.com/modonproperties/#';
            window.open(url,'_blank');
        }
        homepage(){
            const url = HOMEPAGE;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/';
            window.open(url,'_blank');
        }
        handlelinkedin(){
            const url = 'https://www.linkedin.com/company/modon/';
            window.open(url,'_blank');
        }
        handleMyProperties(){
            window.location.href= PROPURL;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/my-properties';
        }
        handleyoutube(){
            const url = 'https://www.youtube.com/channel/UCkF7MWvWZsty6udHa-ykATQ';
            window.open(url,'_blank');
        }
        handlefacebook(){
            const url = 'https://www.facebook.com/modonproperties';
            window.open(url,'_blank');
        }
        handletwitterx(){
            const url = 'https://x.com/ModonProperties';
            window.open(url,'_blank');
        }
}