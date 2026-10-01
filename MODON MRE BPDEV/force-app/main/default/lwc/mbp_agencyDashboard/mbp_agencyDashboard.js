import { LightningElement, track, api, wire } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import ModonImages from "@salesforce/resourceUrl/modonImages";
import Bootstrap from "@salesforce/resourceUrl/Bootstrap";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import FilterIcon from '@salesforce/resourceUrl/Filter';
import USER_ID from '@salesforce/user/Id';
import ACCOUNT_ID from '@salesforce/schema/User.Contact.AccountId';
import getSalesByBedrooms from '@salesforce/apex/MBP_manageDashboardcontroller.getSalesByBedrooms';
import getSalesByResidence from '@salesforce/apex/MBP_manageDashboardcontroller.getSalesByResidence';
import getUnitsByNationalityData from '@salesforce/apex/MBP_manageDashboardcontroller.getUnitsByNationalityData';
import getProjectUnitClassificationBedroomData from '@salesforce/apex/MBP_manageDashboardcontroller.getProjectUnitClassificationBedroomData';
import getSalesByNationality from '@salesforce/apex/MBP_manageDashboardcontroller.getSalesByNationality';
import getFilteredLeads from '@salesforce/apex/MBP_BrokerLeadcontroller.getFilteredLeads';
import getOpportunitiesForAgency from '@salesforce/apex/MBP_BrokerOpportunityController.getOpportunitiesForAgency';

import getUnitRecords from '@salesforce/apex/MBP_ManagePropertiesController.getUnitRecords';
import getAgencyDashboardDetails from '@salesforce/apex/MBP_BrokerAgencyDashboardController.getAgencyDashboardDetails';
import getCommissionSummary from '@salesforce/apex/MBP_manageDashboardcontroller.getCommissionSummary';
// import getEventsDynamic from '@salesforce/apex/MBP_ManageEventsandActivities.getEventsDynamic';
import FULLCALENDAR from '@salesforce/resourceUrl/fullcalendar';
import getGroupedProjectSalesData from '@salesforce/apex/MBP_manageDashboardcontroller.getGroupedProjectSalesData';
import getMonthlySalesByProject from '@salesforce/apex/MBP_manageDashboardcontroller.getMonthlySalesByProject';
import getTotalSalesAmount from '@salesforce/apex/MBP_manageDashboardcontroller.getTotalSalesAmount';
import jsPdfJs from '@salesforce/resourceUrl/MBP_exportDashboard1';

import MBP_welcomeBanner from '@salesforce/resourceUrl/MBP_welcomeBanner';


// 1. Color palette for dynamic color assignment
const COLOR_PALETTE = [
  '#d2ebe7', '#6BCABA', '#bc7cf6', '#56e1cb', '#3ca57a', '#ffb54e',
  '#f8a354', '#e68a0f', '#ee6d7d', '#ff5963', '#a8df6e', '#c9f66a',
  '#d4a5a5', '#b7cbd4', '#f3c677', '#f37777', '#a3f7bf', '#8f79d5'
];

const FIXED_MONTHS = [
  'January', 'February', 'March', 'April',
  'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'
];

// 3. Y-axis tick values (in billions)
const Y_AXIS_BILLIONS = [0, 2, 5, 10, 20];
const CONTACT_FIELDS = ['Contact.Broker_Type__c'];

export default class AgencyDashboard extends NavigationMixin(LightningElement) {
 @track totalSales1 = 0;
  @track monthsData = [];   // For bars
  @track legendData = [];   // For legend
  @track yAxisTicks = [];   // For Y axis

  maxValue = 0;
  barHeightPx = 230;
    filterIcon = FilterIcon;
    
@track showFilterBox = false;
    @track selectedFilter = 'All Time';
    @track showCustomDates = false;
    @track customStartDate;
    @track customEndDate;

@track commissionValues = [];
@track commissionLabels = [];
@track commissionColors = [];
@track totalCommission = 0;
  bannerUrl1 = MBP_welcomeBanner;




  
   filterOptions = [
    { label: 'All Time', value: 'All Time' },
    { label: 'Current Year', value: 'Current Year' },
    { label: 'Previous Year', value: 'Previous Year' },
    { label: 'Current FY', value: 'Current FY' },
    { label: 'Previous FY', value: 'Previous FY' },
    { label: 'Last 12 Months', value: 'Last 12 Months' },
    { label: 'Custom', value: 'Custom' }
];

    
    @track projectLabels = [];
    @track unitCounts = [];
    @track totalSales = [];
    @track projectColors = [];

    logo = ModonImages + "/modonImages/brand-logo-black.png";
    logowhite = ModonImages + "/modonImages/brand-logo-white.png";
    backgroundImage = ModonImages + "/modonImages/bg-theme-pic.png";
    @track showWelcomePopup = true;
    @track salesValues = '[]';
    @track salesLabels = '[]';
    @api contactId;
    @api accountId;
    @api loggedInUserName;
    @api agencyName;
    @api userPhotoUrl;

    @track unitCount = 0;
    @track isBrokerTypeAgencyAdmin = false;
    @track kpiListOne = [];
    @track kpiListTwo = [];
    @track isLoading = false;
    @track accountClassification;
    @track commissionValues = '[]';
    @track propertyValues = '[]';
   

    @track leadOppLabels = ['Total Lead', 'Opportunities'];
    @track leadOppValues = [];
    @track leadOppColors = ['#00BFFF', '#1E90FF'];

     
    @track upcomingEvents = [];
    @track hasUpcomingEvents = false;
    
    @track isCalendarLoading = false;

    @track hasNoEvents = false;
    calendar;
    fullCalendarJsLoaded = false;
    calendarInitialized = false;
    debounceTimer;

    accountRank = 0;
    error;

    @track eventLabels = [];
    @track eventValues = [];

    get upcomingEventLabelsString() {
        return JSON.stringify(this.eventLabels);
    }

    get upcomingEventValuesString() {
        return JSON.stringify(this.eventValues);
    }

    processUpcomingEvents(events) {
        const sortedEvents = [...events]
            .sort((a, b) => new Date(a.Start_Date_and_Time__c) - new Date(b.Start_Date_and_Time__c))
            .slice(0, 3);
        
        this.upcomingEvents = sortedEvents.map(event => ({
            id: event.Id,
            title: event.Title__c || event.Name,
            type: event.Type__c || 'Event',
            formattedDate: this.formatEventDateRange(event.Start_Date_and_Time__c, event.End_Date_and_Time__c),
            startDate: event.Start_Date_and_Time__c,
            endDate: event.End_Date_and_Time__c
        }));
    }

    formatEventDateRange(startDateString, endDateString) {
        if (!startDateString) return 'TBD';
        
        const startDate = new Date(startDateString);
        const endDate = new Date(endDateString);
        
        const startFormatted = startDate.toLocaleDateString('en-US', { 
            month: 'short', 
            day: 'numeric'
        });
        
        const endFormatted = endDate.toLocaleDateString('en-US', { 
            month: 'short', 
            day: 'numeric'
        });
        
        if (startFormatted === endFormatted) {
            return startFormatted;
        }
        
        return `${startFormatted} - ${endFormatted}`;
    }

    navigateToUpdates(event) {
        event.preventDefault();
        
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/Updates'
            }
        }).then(() => {
        }).catch(error => {
            console.error('Navigation to /events-and-activities failed:', error);
            
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'Events_And_Activities__c'
                }
            }).catch(error2 => {
                console.error('Navigation with API name also failed:', error2);
                this.showToast('Error', 'Could not navigate to Events and Activities', 'error');
            });
        });
    }
 
get filterBoxClass() {
    return this.showFilterBox ? 'filter-box visible' : 'filter-box';
}

toggleFilterBox() {
    this.showFilterBox = !this.showFilterBox;     
}

// 'Last 12 Months' is computed server-side in Apex (using the org's/server clock),
// so the LWC just forwards the selected filter label — no client date math needed.
handleFilterChange(event) {
    this.selectedFilter = event.detail.value;
    this.showCustomDates = this.selectedFilter === 'Custom';

    if (this.selectedFilter !== 'Custom') {
        this.customStartDate = null;
        this.customEndDate = null;
    }
}

// Date handlers
handleStartDateChange(event) {
    this.customStartDate = event.target.value;
}
handleEndDateChange(event) {
    this.customEndDate = event.target.value;
}

// Apply filter → refresh charts
async applyFilters() {
    this.showFilterBox = false;

    try {
        await this.loadBedroomChartData();
        await this.loadChartData();
        await this.loadNationalityChartData();
        await this.loadResidenceChartData();
        await this.loadUnitsByNationalityData();
        await this.loadChartData11();
        await this.loadTotalSales();
        await this.loadCounts();
        await this.loadProjectUnitBedChartData();
        await this.fetchDashboardMetrics();
        await this.fetchCommissionSummary();
    } catch (error) {
        console.error('Error loading chart data:', error);
    }
}

// Reset filter → back to default (All Time) and refresh
resetFilters() {
    this.selectedFilter = 'All Time';
    this.showCustomDates = false;
    this.customStartDate = null;
    this.customEndDate = null;
    this.showFilterBox = false;
   this.loadCounts();
        this.fetchDashboardMetrics();
        this.fetchCommissionSummary();
       
        this.loadChartData();
        this.loadNationalityChartData();
        this.loadBedroomChartData();
        this.loadResidenceChartData();
        this.loadUnitsByNationalityData();
        this.loadChartData11();
         this.buildYAxisTicks();
         this.loadTotalSales();

 this.loadProjectUnitBedChartData();

}

    @wire(getRecord, { recordId: '$contactId', fields: CONTACT_FIELDS })
    wiredContact({ error, data }) {
        if (data) {
            const brokerType = data.fields.Broker_Type__c.value;
            this.isBrokerTypeAgencyAdmin = brokerType === 'Owner';
        } else if (error) {
            console.error('Error fetching contact:', error);
        }
    }

    connectedCallback() {
        Promise.all([
            loadStyle(this, Bootstrap + '/css/bootstrap.min.css'),
            loadScript(this, Bootstrap + '/js/bootstrap.bundle.min.js')
        ])
        .catch(error => {
            console.error('Error loading styles/scripts', error);
        });
this.loadCounts();
this.checkFirstLogin();
        this.fetchDashboardMetrics();
        this.fetchCommissionSummary();
       
        this.loadChartData();
        this.loadNationalityChartData();
        this.loadBedroomChartData();
        this.loadResidenceChartData();
        this.loadUnitsByNationalityData();
        this.loadChartData11();
         this.buildYAxisTicks();
         this.loadTotalSales();

 this.loadProjectUnitBedChartData();
        this.addEventListener('activetab', this.handleActivateTab.bind(this));
    }


 checkFirstLogin() {
        const userKey = `welcomePopupShown_${this.loggedInUserName}`;
        const alreadyShown = localStorage.getItem(userKey);
        if (!alreadyShown) {
            this.showWelcomePopup = true;
        }
    }

    handleCloseWelcomePopup() {
        this.showWelcomePopup = false;
        const userKey = `welcomePopupShown_${this.loggedInUserName}`;
        localStorage.setItem(userKey, 'true');
    }
loadTotalSales() {
    this.isLoading = true; // Show spinner

    getTotalSalesAmount({
        filterType: this.selectedFilter,
        startDate: this.customStartDate,
        endDate: this.customEndDate
    })
    .then(result => {
        this.totalSales1 = result;
    })
    .catch(error => {
        console.error('❌ Error fetching total sales', error);
    })
    .finally(() => {
        this.isLoading = false; // Hide spinner
    });
}

 handleRefresh() {
        this.loadTotalSales();
    }

get formattedTotalSales() {
  return this.formatCurrency(this.totalSales1);
}

    get currentDateTime() {
        return new Date().toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    }
buildYAxisTicks() {
  const maxVal = this.maxValue;
  const numTicks = 5;

  this.yAxisTicks = [];

  for(let i = 0; i <= numTicks; i++) {
    const value = maxVal * (i / numTicks);
    // position from top, 0 value at bottom of chart
    const top = this.barHeightPx - (value / maxVal) * this.barHeightPx;

    this.yAxisTicks.push({
      label: this.formatCurrency(value),
      style: `top: ${top}px;` // changed from bottom to top
    });
  }
}

async loadChartData11() { 
    this.isLoading = true; // Show spinner

    try {
        const rawData = await getMonthlySalesByProject({
            filterType: this.selectedFilter,
            startDate: this.customStartDate,
            endDate: this.customEndDate
        });

        // Collect unique project names
        const projectsSet = new Set();
        Object.values(rawData).forEach(projectMap => {
            Object.keys(projectMap).forEach(project => projectsSet.add(project));
        });
        const projectNames = Array.from(projectsSet);

        // Assign colors dynamically
        const projectColors = {};
        projectNames.forEach((name, index) => {
            projectColors[name] = COLOR_PALETTE[index % COLOR_PALETTE.length];
        });

        // Find global max value for Y axis scaling
        this.maxValue = 0;
        // rawData keys still have year info
        Object.keys(rawData).forEach(monthWithYear => {
            const projectMap = rawData[monthWithYear] || {};
            const total = Object.values(projectMap).reduce((sum, val) => sum + val, 0);
            if (total > this.maxValue) this.maxValue = total;
        });

        // Build monthsData with stacks
        this.monthsData = FIXED_MONTHS.map(month => {
            // Find rawData key that starts with this month
            const rawKey = Object.keys(rawData).find(k => k.startsWith(month)) || month;
            const projectMap = rawData[rawKey] || {};
            const stacks = Object.entries(projectMap).map(([project, value]) => {
                const heightPercent = this.maxValue > 0 ? (value / this.maxValue) * 100 : 0;
                return {
                    name: project,
                    value,
                    style: `height: ${heightPercent}%; background-color: ${projectColors[project]};`,
                    title: `${project}: ${this.formatCurrency(value)} AED`
                };
            });

            return {
                name: month,
                label: month, // <-- UI label without year
                barStyle: `height: ${this.barHeightPx}px;`,
                stacks
            };
        });

        // Build legend
        this.legendData = projectNames.map(name => ({
            name,
            colorStyle: `background-color: ${projectColors[name]};`
        }));

        this.buildYAxisTicks();

    } catch(error) {
        console.error('❌ Error loading monthly sales data', error);
    } finally {
        this.isLoading = false; // Hide spinner
    }
}
formatCurrency(value) {
  const num = Number(value) || 0;
  if (num >= 1_000_000_000) {
    return (num / 1_000_000_000).toFixed(1) + 'B';
  } else if (num >= 1_000_000) {
    return (num / 1_000_000).toFixed(1) + 'M';
  } else {
    return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(num);
  }
}


get formattedTotalSales() {
  return this.formatCurrency(this.totalSales1);
}

get formattedTotalSales1() {
  const num = Number(this.totalSales1) || 0;
  return new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(num);
}



loadUnitsByNationalityData() {
    this.isLoading = true; // Show spinner for this method

    return getUnitsByNationalityData({
        filterType: this.selectedFilter,
        startDate: this.customStartDate,
        endDate: this.customEndDate
    })
    .then((data) => {

        const nationalitySet = new Set();
        const unitMap = {};
        const salesMap = {};

        for (const nationality in data) {
            nationalitySet.add(nationality);
            unitMap[nationality] = data[nationality].unitCount || 0;
            salesMap[nationality] = data[nationality].totalSales || 0;
        }

        this.nationalityLabels = Array.from(nationalitySet);
        this.nationalityUnitCounts = this.nationalityLabels.map(label => unitMap[label]);
        this.nationalitySales = this.nationalityLabels.map(label => salesMap[label]);
        this.nationalityColors = this.generateColorPalette(this.nationalityLabels.length);

    })
    .catch((error) => {
        console.error('❌ Error loading nationality chart data:', JSON.stringify(error));
    })
    .finally(() => {
        this.isLoading = false; // Hide spinner after this method finishes
    });
}

loadResidenceChartData() {
    this.isLoading = true; // Show spinner

    return getSalesByResidence({
        filterType: this.selectedFilter,
        startDate: this.customStartDate,
        endDate: this.customEndDate
    })
    .then((data) => {

        const labels = [];
        const unitCounts = [];
        const totalSales = [];

        for (const residency in data) {
            labels.push(residency);
            unitCounts.push(data[residency].unitCount || 0);
            totalSales.push(data[residency].totalSales || 0);
        }

        this.residencyLabels = labels;
        this.residencyUnitCounts = unitCounts;
        this.residencySales = totalSales;
        this.residencyColors = this.generateColorPalette(labels.length);
    })
    .catch((error) => {
        console.error('❌ Error loading residency chart:', JSON.stringify(error));
    })
    .finally(() => {
        this.isLoading = false; // Hide spinner
    });
}

loadBedroomChartData() { 
    this.isLoading = true; // Show spinner

    getSalesByBedrooms({
        filterType: this.selectedFilter,
        startDate: this.customStartDate,
        endDate: this.customEndDate
    })
    .then((data) => {

        const labels = [];
        const unitCounts = [];
        const totalSales = [];

        for (const bedroom in data) {
    const entry = data[bedroom];

    // Format: "No of Bedrooms: X"
    const bedroomLabel = `No of Bedrooms: ${bedroom}`;

    labels.push(bedroomLabel);
    unitCounts.push(entry.unitCount || 0);
    totalSales.push(entry.totalSales || 0);
}


        this.bedroomLabels = labels;
        this.bedroomUnitCounts = unitCounts;
        this.bedroomSales = totalSales;
        this.bedroomColors = this.generateColorPalette(labels.length);

    })
    .catch((error) => {
        console.error('❌ Error loading bedroom chart data:', JSON.stringify(error));
    })
    .finally(() => {
        this.isLoading = false; // Hide spinner
    });
}



loadNationalityChartData() {
    this.isLoading = true; // Show spinner

    getSalesByNationality({
        filterType: this.selectedFilter,
        startDate: this.customStartDate,
        endDate: this.customEndDate
    })
    .then((data) => {

        const labels = [];
        const unitCounts = [];
        const totalSales = [];

        for (const nationality in data) {
            const entry = data[nationality];
            labels.push(nationality);
            unitCounts.push(entry.unitCount || 0);
            totalSales.push(entry.totalSales || 0);
        }

        this.nationalityLabels = labels;
        this.nationalityUnitCounts = unitCounts;
        this.nationalitySales = totalSales;
        this.nationalityColors = this.generateColorPalette(labels.length);

    })
    .catch((error) => {
        console.error('❌ Error loading nationality chart data:', JSON.stringify(error));
    })
    .finally(() => {
        this.isLoading = false; // Hide spinner
    });
}


loadProjectUnitBedChartData() {
    this.isLoading = true; // Show spinner

    getProjectUnitClassificationBedroomData({
        filterType: this.selectedFilter,
        startDate: this.customStartDate,
        endDate: this.customEndDate
    })
    .then((data) => {

        const classificationSet = new Set();
        const unitMap = {};
        const salesMap = {};

        for (const project in data) {
            const classificationMap = data[project];

            for (const classification in classificationMap) {
                const bedroomMap = classificationMap[classification];

                for (const bedroom in bedroomMap) {
                    const label = classification;

                    if (!classificationSet.has(label)) {
                        classificationSet.add(label);
                        unitMap[label] = 0;
                        salesMap[label] = 0;
                    }

                    const entry = bedroomMap[bedroom];
                    unitMap[label] += entry.unitCount || 0;
                    salesMap[label] += entry.totalSales || 0;
                }
            }
        }

        this.unitBedLabels = Array.from(classificationSet);
        this.unitBedCounts = this.unitBedLabels.map(label => unitMap[label]);
        this.unitBedSales = this.unitBedLabels.map(label => salesMap[label]);
        this.unitBedColors = this.generateColorPalette(this.unitBedLabels.length);

    })
    .catch((error) => {
        console.error('❌ Error loading new chart data:', JSON.stringify(error));
    })
    .finally(() => {
        this.isLoading = false; // Hide spinner
    });
}

loadChartData() {
    this.isLoading = true;

    getGroupedProjectSalesData({
        filterType: this.selectedFilter,
        startDate: this.customStartDate,
        endDate: this.customEndDate
    })
    .then((data) => {

        const labels = [];
        const unitCountMap = {};
        const totalSalesMap = {};

        for (const project in data) {
            labels.push(project);
            const entry = data[project];
            unitCountMap[project] = entry.unitCount || 0;
            totalSalesMap[project] = entry.totalSales || 0;
        }

        this.projectLabels = labels;
        this.unitCounts = labels.map(name => unitCountMap[name]);
        this.totalSales = labels.map(name => totalSalesMap[name]);
        this.projectColors = this.generateColorPalette(labels.length);

    })
    .catch((error) => {
        console.error('❌ Error loading chart data:', JSON.stringify(error));
    })
    .finally(() => {
        this.isLoading = false;
    });
}


generateColorPalette(count) {
  const basePalette = [
    '#4A9BEA', '#7DB8F2', '#8F4BE8', '#1565C0', '#2AA7A8', '#5ED3D1',
    '#F5A347', '#F8C58C', '#43A047', '#8DD34F', '#B8E66A', '#6E8EF6',
    '#00ACC1', '#5B6EE1', '#0277BD', '#00897B', '#2E7D32', '#37474F'
  ];
  return Array.from({ length: count }, (_, i) => basePalette[i % basePalette.length]);
}

isLibrariesLoaded = false;

/*renderedCallback() {
    if (this.isLibrariesLoaded) return;

    loadScript(this, jsPdfJs)
    .then(() => {
        this.isLibrariesLoaded = true;
    })
    .catch(error => {
        console.error('❌ Error loading jsPDF library:', error);
    });
}*/


renderedCallback() {
    if (!this.isLibrariesLoaded) {
        loadScript(this, jsPdfJs)
            .then(() => {
                this.isLibrariesLoaded = true;
            })
            .catch(error => {
                console.error('Error loading jsPDF library:', error);
            });
    }

    if (!this._outsideClickHandlerAdded) {
        this._outsideClickHandler = this.handleOutsideClick.bind(this);
        document.addEventListener('mousedown', this._outsideClickHandler);
        this._outsideClickHandlerAdded = true;
    }
}


exportAllCharts() {
 this.isLoading = true;
    const chartComps = this.template.querySelectorAll('c-mbp_dynamic-chart');
    if (!chartComps || chartComps.length === 0) {
        console.error('❌ No dynamic charts found on page');
        return;
    }


    try {
        const pdf = new window.jspdf.jsPDF('p', 'mm', 'a4');

        // === PAGE 1 ===

// Get page dimensions
const pageWidth1 = pdf.internal.pageSize.getWidth();
const margin = 15;
const cardSpacing = 10;
const cardWidth = (pageWidth1 - margin * 2 - cardSpacing) / 2;
const cardHeight = 90;
const cardY = 30;

// Heading
pdf.setFontSize(20);
pdf.setFont('helvetica', 'bold');
pdf.setTextColor('#0d47a1');
pdf.text('MODON Dashboard Report', pageWidth1 / 2, 20, { align: 'center' });

// Total Sales Card (Left)
this.addTotalSalesToPdf(pdf, margin, cardY, cardWidth, cardHeight);


// Bar Chart Card (Right)


       pdf.addPage();

this.drawBarChartInPdf(pdf, margin + cardWidth + cardSpacing, cardY, cardWidth, 40);

        // Page 3+: Doughnut Charts (existing logic unchanged)
        chartComps.forEach((chartComp, index) => {
            const title = chartComp.chartTitle || `Chart ${index + 1}`;
            const canvas = chartComp.getCanvas();
            const labels = chartComp.labels || [];
            const values = chartComp.values || [];

            if (!canvas) {
                console.warn(`⚠️ Skipping chart "${title}" – no canvas found`);
                return;
            }

            pdf.addPage(); // new page per chart
            let yPosition = 20;

            const pageWidth = pdf.internal.pageSize.getWidth();
            const pageHeight = pdf.internal.pageSize.getHeight();
            const boxMargin = 15;
            const boxWidth = pageWidth - boxMargin * 2;
            let boxHeight = 200;
            const boxX = boxMargin;
            const boxY = yPosition;

            pdf.setDrawColor('#fff');
            pdf.setLineWidth(0.5);
            pdf.roundedRect(boxX, boxY, boxWidth, boxHeight, 5, 5);

            let innerY = boxY + 15;

            pdf.setFontSize(16);
            pdf.setTextColor('#212121');
            pdf.setFont('helvetica', 'bold');
            pdf.text(title, pageWidth / 2, innerY, { align: 'center' });
            innerY += 10;

            const imgData = canvas.toDataURL('image/png', 1.0);
            const maxImgWidth = boxWidth - 30;
            const maxImgHeight = 90;
            let imgWidth = maxImgWidth;
            let imgHeight = (canvas.height * imgWidth) / canvas.width;
            if (imgHeight > maxImgHeight) {
                imgHeight = maxImgHeight;
                imgWidth = (canvas.width * imgHeight) / canvas.height;
            }

            const xCentered = (pageWidth - imgWidth) / 2;
            pdf.addImage(imgData, 'PNG', xCentered, innerY, imgWidth, imgHeight);
            innerY += imgHeight + 15;

            if (labels.length && values.length) {
                const tableX = boxX + 10;
                let rowY = innerY;

                const colCategoryWidth = boxWidth * 0.6;
                const colValueWidth = boxWidth * 0.3;
                const rowHeight = 10;

                pdf.setFillColor('#1976d2');
                pdf.setTextColor('#fff');
                pdf.setFont('helvetica', 'bold');
                pdf.rect(tableX, rowY, colCategoryWidth, rowHeight, 'F');
                pdf.rect(tableX + colCategoryWidth, rowY, colValueWidth, rowHeight, 'F');
                pdf.text('Category', tableX + 3, rowY + 7);
                pdf.text('Value', tableX + colCategoryWidth + colValueWidth - 3, rowY + 7, { align: 'right' });
                rowY += rowHeight;

                pdf.setFont('helvetica', 'normal');
                pdf.setFontSize(11);

                labels.forEach((label, i) => {
                    const value = values[i] || 0;
                    const formatted = (typeof value === 'number') ? value.toLocaleString('en-US') : value;

                    pdf.setFillColor(i % 2 === 0 ? '#f5f5f5' : '#ffffff');
                    pdf.rect(tableX, rowY, colCategoryWidth + colValueWidth, rowHeight, 'F');

                    pdf.setTextColor('#000');
                    pdf.text(String(label), tableX + 3, rowY + 7);
                    pdf.text(String(formatted), tableX + colCategoryWidth + colValueWidth - 3, rowY + 7, { align: 'right' });

                    rowY += rowHeight;
                });

                innerY = rowY + 10;
            }

            boxHeight = innerY - boxY + 15;
            pdf.setDrawColor('#1976d2');
            pdf.roundedRect(boxX, boxY, boxWidth, boxHeight, 5, 5);
        });

        const pageWidth = pdf.internal.pageSize.getWidth();
        const pageHeight = pdf.internal.pageSize.getHeight();
        pdf.setFontSize(10);
        pdf.setTextColor('#555');
        pdf.text(`Generated on: ${new Date().toLocaleString()}`, pageWidth / 2, pageHeight - 10, { align: 'center' });

        pdf.save('MODON_Dashboard_Report.pdf');
     } catch (error) {
        console.error('❌ Error generating PDF:', error);
    } finally {
        this.isLoading = false; // Hide spinner after work completes
    }
}
addTotalSalesToPdf(doc, x, y, width, height) {
    doc.setDrawColor('#21232c');
    doc.setFillColor('#0f172a');
    doc.setLineWidth(1);
    doc.roundedRect(x, y, width, height, 5, 5, 'F');

    doc.setFontSize(14);
    doc.setTextColor('#ffffff');
    doc.text('Total Sales Amount', x + width / 2, y + 12, { align: 'center' });

    doc.setFontSize(20);
    doc.setTextColor('#00ffcc');
    doc.text(`AED ${this.formattedTotalSales}`, x + width / 2, y + 32, { align: 'center' });

    doc.setFontSize(10);
    doc.setTextColor('#ffffff');
    doc.text(`As of ${this.currentDateTime}`, x + width / 2, y + 48, { align: 'center' });
}

drawBarChartInPdf(pdf, startX = 50, startY = 60, chartWidth = 140, chartHeight = 80) {
    const months = this.monthsData || [];
    const legend = this.legendData || [];
    const maxValue = this.maxValue || 1;

    const barWidth = chartWidth / months.length - 4;
    const barSpacing = 4;

    // --- Container Box (smaller size) ---
    const totalHeight = chartHeight + 90;
    const totalWidth = chartWidth + 60;
    const containerX = startX - 30;
    const containerY = startY - 40;

    pdf.setDrawColor('#cccccc');
    pdf.setFillColor('#1e1e1e');  // Dark background
    pdf.setLineWidth(0.5);
    pdf.roundedRect(containerX, containerY, totalWidth, totalHeight, 4, 4, 'FD');

    // --- Title ---
    pdf.setFontSize(11);
    pdf.setFont(undefined, 'bold');
    pdf.setTextColor('#ffffff');
    pdf.text('Projects by Units', startX + chartWidth / 2, containerY + 12, { align: 'center' });

    // --- Y-axis values (in millions) ---
    const yTicks = 5;
    const tickStep = maxValue / yTicks;
    const tickHeight = chartHeight / yTicks;

    pdf.setFontSize(7);
    for (let i = 0; i <= yTicks; i++) {
        const value = (tickStep * i) / 1_000_000;
        const y = startY + chartHeight - i * tickHeight;
        pdf.setTextColor('#ffffff');
        pdf.text(`${value.toFixed(1)}M`, startX - 8, y + 2, { align: 'right' });

        pdf.setDrawColor('#444');
        pdf.setLineWidth(0.2);
        pdf.line(startX, y, startX + chartWidth, y);
    }

    // --- Bars ---
    let currentX = startX;

    months.forEach((month) => {
        let currentY = startY + chartHeight;

        month.stacks.forEach((stack) => {
            const height = (stack.value / maxValue) * chartHeight;
            const colorMatch = stack.style.match(/background-color:\s*(#[0-9a-fA-F]+)/);
            const color = colorMatch ? colorMatch[1] : '#999999';

            pdf.setFillColor(color);
            pdf.rect(currentX, currentY - height, barWidth, height, 'F');
            currentY -= height;
        });

        // Month label
        pdf.setFontSize(6.5);
        pdf.setTextColor('#ffffff');
        pdf.text(month.label, currentX + barWidth / 2, startY + chartHeight + 7, { align: 'center' });

        currentX += barWidth + barSpacing;
    });

    // --- Y-axis Label ---
    pdf.saveGraphicsState();
    pdf.setFontSize(7);
    pdf.setTextColor('#ffffff');
    pdf.text('Sum of Total Amount (AED)', startX - 20, startY + chartHeight / 2, {
        angle: 270,
    });
    pdf.restoreGraphicsState();

    // --- Legend ---
    let legendX = startX;
    let legendY = startY + chartHeight + 20;
    const legendSpacing = 50;

    legend.forEach((item, index) => {
        const colorMatch = item.colorStyle.match(/background-color:\s*(#[0-9a-fA-F]+)/);
        const color = colorMatch ? colorMatch[1] : '#ffffff';

        pdf.setFillColor(color);
        pdf.rect(legendX, legendY, 5, 5, 'F');

        pdf.setFontSize(7);
        pdf.setTextColor('#ffffff');
        pdf.text(item.name, legendX + 8, legendY + 4);

        legendX += legendSpacing;
        if ((index + 1) % 3 === 0) {
            legendX = startX;
            legendY += 10;
        }
    });
}



    // renderedCallback() {
    //     if (!this.hasRenderedMini) {
    //         this.renderCalendar();
    //         this.hasRenderedMini = true;
    //     }

    //     if (this.calendarInitialized) return;
    //     this.calendarInitialized = true;

    //     Promise.all([
    //         loadScript(this, FULLCALENDAR + '/lib/main.js'),
    //         loadStyle(this, FULLCALENDAR + '/lib/main.css')
    //     ])
    //     .then(() => {
    //         this.fullCalendarJsLoaded = true;
    //         this.initializeFullCalendar();
    //     })
    //     .catch(error => {
    //         console.error('FullCalendar load error:', error);
    //         this.showToast('Error', 'Failed to load FullCalendar: ' + this.getErrorMessage(error), 'error');
    //     });
    // }

    handleCreateLead() {
        sessionStorage.setItem('triggerAddLeadModal', 'true');
        window.location.href = '/Brokers/Leads';
    }
async loadCounts() {
    try {

        const leads = await getFilteredLeads({
            userId: USER_ID,
            startDate: null,
            endDate: null,
            filterType:  this.selectedFilter
        });

        const leadCount = leads ? leads.length : 0;

        const opps = await getOpportunitiesForAgency({
            accountId: this.accountId,
            startDate: null,
            endDate: null,
            filterType:  this.selectedFilter
        });

        const oppCount = opps ? opps.length : 0;

        this.leadOppValues = [leadCount, oppCount];

    } catch (error) {
        console.error('❌ Error loading counts:', error);
    }
}


    
  fetchDashboardMetrics() {
    this.isCalendarLoading = true;
    this.isLoading = true;

    // Pass filters and custom dates to Apex
    let startDate = this.customStartDate ? this.customStartDate : null;
    let endDate = this.customEndDate ? this.customEndDate : null;

    getAgencyDashboardDetails({
        accountId: this.accountId,
        filterType: this.selectedFilter,
        startDate: startDate,
        endDate: endDate
    })
    .then(result => {
        const allKpis = result.kpiList || [];
        this.kpiListOne = [];
        this.kpiListTwo = [];
        this.accountClassification = result.accountClassification;
        this.accountRank = result.accountRank;

        // Separate KPIs into two lists
        allKpis.forEach(kpi => {
            const label = (kpi.label || '').toLowerCase();
            if (label === 'open leads' || label === 'open opportunities') {
                this.kpiListOne.push(kpi);
            } else {
                this.kpiListTwo.push(kpi);
            }
        });

        return getUnitRecords({ objectName: 'Unit__c' });
    })
    .then(unitData => {
        const totalProjects = unitData.totalProjects || 0;
        const totalUnits = unitData.totalUnits || 0;
        const availableUnits = unitData.availableUnits || 0;

        this.unitCount = totalUnits;
        this.propertyValues = JSON.stringify([totalProjects, totalUnits]);

        // --- LEADS & OPPS CHART DATA ---
        let openLeads = 0;
        let openOpps = 0;

        this.kpiListOne.forEach(kpi => {
            const label = (kpi.label || '').toLowerCase();
            if (label === 'open leads') openLeads = Number(kpi.value || 0);
            if (label === 'open opportunities') openOpps = Number(kpi.value || 0);
        });

        // Make sure chart always receives arrays for labels, values, colors
       

        // --- TOTAL SALES (Optional) ---
        let totalSales = 0;
        if (this.commissionValues) {
            try {
                const commissionArr = JSON.parse(this.commissionValues);
                totalSales = commissionArr.reduce((sum, val) => sum + val, 0);
            } catch (e) {
                console.warn('Error parsing commissionValues:', e);
            }
        }

        // Hide spinners
        this.isLoading = false;
        this.isCalendarLoading = false;
    })
    .catch(error => {
        this.isLoading = false;
        this.isCalendarLoading = false;
        console.error('Error fetching dashboard metrics:', error);
        this.error = error;
    });
}



    @track salesMode = 'price';
    @track salesLabels;
    @track salesValues;

    salesModeOptions = [
        { label: 'Unit Price', value: 'price' },
        { label: 'Unit Count', value: 'count' }
    ];

    handleModeChange(event) {
        this.salesMode = event.detail.value;
        this.loadMonthlySales(new Date().getFullYear());
    }


fetchCommissionSummary() { 
    let startDate = this.customStartDate ? this.customStartDate : null;
    let endDate = this.customEndDate ? this.customEndDate : null;

    this.isLoading = true; // Show spinner


    getCommissionSummary({
        accountId: this.accountId,
        contactId: this.contactId,
        filterType: this.selectedFilter,
        startDate: startDate,
        endDate: endDate
    })
    .then(result => {

        const paid = Number(result.Paid) || 0;
        const pending = Number(result.Pending) || 0;
        const total = Number(result.Total) || 0;
        const eligible = Number(result.eligible) || 0;

        const formattedPaid = this.formatCurrency1(paid);
        const formattedPending = this.formatCurrency1(pending);
        const formattedTotal = this.formatCurrency1(total);
        const formattedEligible = this.formatCurrency1(eligible);

        this.commissionValues = [paid, pending, total, eligible];
        this.commissionColors = this.generateColorPalette(4);
        this.totalCommission = total; 

        this.commissionLabels = [
            `Commission Paid`,
            `Commission Pending`,
            `Total Commission`,
            `Eligible Commission`
        ];

    })
    .catch(error => {
        console.error('Error fetching commission summary:', error);

        this.commissionLabels = [
            'Commission Paid: AED 0',
            'Commission Pending: AED 0',
            'Total Commission: AED 0',
            'Eligible Commission: AED 0'
        ];
        this.commissionValues = [0, 0, 0, 0];
        this.commissionColors = this.generateColorPalette(4);
        this.totalCommission = 0;
    })
    .finally(() => {
        this.isLoading = false;
    });
}

// 🔹 Formatter: AED prefix + comma separation
formatCurrency1(value) {
    const n = Number(value) || 0;
    return `AED ${n.toLocaleString('en-US')}`;
}

// 🔹 New formatter method (with AED prefix + comma separation)
formatCurrency1(value) {
    const n = Number(value) || 0;
    // Use Intl or toLocaleString for comma separation. No decimals shown.
    return `AED ${Math.abs(n).toLocaleString('en-US')}${n < 0 ? ' (negative)' : ''}`;
}



    @track currentDate = new Date();
    events = { "2025-08-26": "T", "2025-08-15": "P" };

    renderCalendar() {
        const currentMonthEl = this.template.querySelector(".current-month");
        const datesGrid = this.template.querySelector(".dates-grid");
        if (!currentMonthEl || !datesGrid) return;

        const year = this.currentDate.getFullYear();
        const month = this.currentDate.getMonth();

        currentMonthEl.textContent = this.currentDate.toLocaleString('default', { month: 'long', year: 'numeric' });

        const firstDay = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();

        datesGrid.innerHTML = "";

        const dow = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
        const headerRow = document.createElement('div');
        headerRow.classList.add('dow-row');
        dow.forEach(d => {
            const el = document.createElement('div');
            el.classList.add('dow');
            el.textContent = d;
            headerRow.appendChild(el);
        });
        datesGrid.appendChild(headerRow);

        for (let i = 0; i < firstDay; i++) {
            const emptyDiv = document.createElement("div");
            emptyDiv.classList.add('date','empty');
            datesGrid.appendChild(emptyDiv);
        }

        for (let day = 1; day <= daysInMonth; day++) {
            const dateDiv = document.createElement("div");
            dateDiv.classList.add("date");
            const fullDate = `${year}-${String(month+1).padStart(2,'0')}-${String(day).padStart(2,'0')}`;

            if (fullDate === new Date().toISOString().split('T')[0]) {
                dateDiv.classList.add("today");
            }

            dateDiv.textContent = day;

            if (this.events && this.events[fullDate]) {
                dateDiv.classList.add("event");
                const span = document.createElement("span");
                span.classList.add("event-label");
                span.textContent = this.events[fullDate];
                dateDiv.appendChild(span);
            }

            datesGrid.appendChild(dateDiv);
        }
    }

    handlePrevMonth() {
        this.currentDate.setMonth(this.currentDate.getMonth() - 1);
        this.renderCalendar();
    }

    handleNextMonth() {
        this.currentDate.setMonth(this.currentDate.getMonth() + 1);
        this.renderCalendar();
    }

    initializeFullCalendar() {
        if (!this.fullCalendarJsLoaded) return;
        const calendarEl = this.template.querySelector('.calendar-container');
        if (!calendarEl) return;

        this.calendar = new FullCalendar.Calendar(calendarEl, {
            initialView: window.innerWidth < 768 ? 'listWeek' : 'dayGridMonth',
            headerToolbar: {
                left: 'prev,next today',
                center: 'title',
                right: 'dayGridMonth,timeGridWeek,timeGridDay,listWeek'
            },
            events: (info, successCallback, failureCallback) => {
                this.loadCalendarEvents(info.start, info.end, successCallback, failureCallback);
            },
            eventClick: (info) => {
                this.handleCalendarEventClick(info.event);
            },
            eventDidMount: (info) => {
                const el = info.el;
                el.title = this.getEventTooltip(info.event);
                el.style.borderLeft = '4px solid #6BCABA';
                el.style.borderRadius = '4px';
                el.style.margin = '2px 0';
                el.style.padding = '2px 4px';
                el.style.backgroundColor = '#f8f9fa';
                el.style.border = 'none';
            },
            nowIndicator: true,
            dayMaxEvents: true,
            navLinks: true,
            editable: false,
            selectable: false,
            eventDisplay: 'block',
            eventTimeFormat: null,
            displayEventTime: false,
            datesSet: (info) => {
                clearTimeout(this.debounceTimer);
                this.debounceTimer = setTimeout(() => {
                }, 250);
            }
        });

        this.calendar.render();
    }

    showToast(title, message, variant = 'info') {
        const maxLength = 500;
        const truncatedMessage = message && message.length > maxLength ? message.substring(0, maxLength) + '...' : message;
        this.dispatchEvent(new ShowToastEvent({
            title,
            message: truncatedMessage,
            variant,
            mode: variant === 'info' ? 'sticky' : 'dismissible'
        }));
    }

    getErrorMessage(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }

    disconnectedCallback() {
        if (this.calendar) {
            try { this.calendar.destroy(); } catch (e) { }
        }
        clearTimeout(this.debounceTimer);


        if (this._outsideClickHandlerAdded) {
            document.removeEventListener('mousedown', this._outsideClickHandler);
            this._outsideClickHandlerAdded = false;
        }
    }

    handleOutsideClick(event) {
        if (!this.showFilterBox) return;

        const filterWrapper = this.template.querySelector('.filter-wrapper');
        const filterIcon = this.template.querySelector('.filter-icon');

        const path = event.composedPath ? event.composedPath() : [];
        const clickedInside =
            (filterWrapper && path.includes(filterWrapper)) ||
            (filterIcon && path.includes(filterIcon));

        if (!clickedInside) {
            this.showFilterBox = false;
        }
    }

    stopEvent(event) {
        event.stopPropagation();
    }

    toggleFilterBox(event) {
        event.stopPropagation();
        this.showFilterBox = !this.showFilterBox;
    }

    closeFilterBox(event) {
        if (event) event.stopPropagation();
        this.showFilterBox = false;
    }
}