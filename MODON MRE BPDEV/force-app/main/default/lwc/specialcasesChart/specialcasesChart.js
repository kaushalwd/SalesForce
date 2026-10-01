/**
* Description: LWC for Special Cases chart Customer 360 dashboard
* Author: Chaitanya N
* Name: ServiceRequestChart
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire, track } from 'lwc';
import getServiceRequestSummary from '@salesforce/apex/SalesOrderAgingController.getServiceRequestSummary';
import { loadScript } from 'lightning/platformResourceLoader';

const ChartJS =
    'https://cdn.jsdelivr.net/npm/chart.js@3.9.1/dist/chart.min.js';
const ChartDataLabels =
    'https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels@2.2.0/dist/chartjs-plugin-datalabels.min.js';

export default class ServiceRequestChart extends LightningElement {
    @api recordId;
    @api startDate;
    @api endDate;

    @track legendItems = [];
    @track showSpecialCasesModal = false;
    portalHost;
    movedWrapper;
    @track rerenderTabs = true;
    originalParent;
    originalNextSibling;
    pendingInit = false;
    scriptsLoaded = false;
    scriptsLoadingPromise;



    chart;
    chartJsInitialized = false;
    chartData;
    hasData = true; // ✅ flag to track data state

    selectedRange = 'YTD';

    effectiveStartDate;
    effectiveEndDate;
    ytdFallbackApplied = false;
    @track isModalOpen = false;
    _chartRetryCount = 0;



    

    connectedCallback() {
        //this.selectedRange = 'YTD';
        this.applyRangeDates(this.selectedRange);
    }


    get lastYearClass() {
        return this.selectedRange === 'LAST_YEAR' ? 'range active' : 'range';
    }


    handleRangeClick(event) {
        const range = event.currentTarget.dataset.range;
        if (!range || range === this.selectedRange) return;

        this.selectedRange = range;
        this.ytdFallbackApplied = false; 
        this.applyRangeDates(range);
        this.hasData = true;
        

        this.destroyChart();
        this.pendingInit = true;  
        


    }
    get todayClass() {
        return this.selectedRange === 'TODAY' ? 'range active' : 'range';
    }
    get yesterdayClass() {
        return this.selectedRange === 'YESTERDAY' ? 'range active' : 'range';
    }
    get mtdClass() {
        return this.selectedRange === 'MTD' ? 'range active' : 'range';
    }
    get ytdClass() {
        return this.selectedRange === 'YTD' ? 'range active' : 'range';
    }

    applyRangeDates(range) {
        const today = new Date();

        // Normalize to local date (avoid time issues)
        const t = new Date(today.getFullYear(), today.getMonth(), today.getDate());

        let start;
        let end;

        if (range === 'TODAY') {
            start = t;
            end = t;
        } else if (range === 'YESTERDAY') {
            const y = new Date(t);
            y.setDate(y.getDate() - 1);
            start = y;
            end = y;
        } else if (range === 'MTD') {
            start = new Date(t.getFullYear(), t.getMonth(), 1);
            end = t;
        } else if (range === 'YTD') {
            start = new Date(t.getFullYear(), 0, 1);
            end = t;
        } else if (range === 'LAST_YEAR') {
            start = new Date(t);
            start.setFullYear(start.getFullYear() - 1);
            end = t;
        }else {
            // fallback
            start = t;
            end = t;
        }

        this.effectiveStartDate = this.formatDate(start);
        this.effectiveEndDate = this.formatDate(end);
    }

    formatDate(dateObj) {
        const yyyy = dateObj.getFullYear();
        const mm = String(dateObj.getMonth() + 1).padStart(2, '0');
        const dd = String(dateObj.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`; // Apex Date friendly
    }


    @wire(getServiceRequestSummary, {
        accountId: '$recordId',
        startDate: '$effectiveStartDate',
        endDate: '$effectiveEndDate'
    })
    wiredServiceRequestSummary({ data, error }) {
        if (data) {
            this.chartData = data;
            this._chartRetryCount = 0;

            const total = Object.values(data).reduce((sum, val) => sum + (Number(val) || 0), 0);

            if (this.selectedRange === 'YTD' && total === 0 && !this.ytdFallbackApplied) {
                this.ytdFallbackApplied = true;
                this.effectiveStartDate = '2025-01-01';
                this.effectiveEndDate = this.formatDate(new Date());
                return;
            }

            this.hasData = total > 0;

            this.destroyChart();

            if (!this.hasData) {
                this.legendItems = [];
                return;
            }


            this.pendingInit = true;
            this.kickInit(false);

        } else if (error) {
            console.error('Error fetching Service Request Summary:', error);
            this.hasData = false;
            this.legendItems = [];
            this.destroyChart();
        }

    }


    renderedCallback() {
        // ✅ Load scripts ONCE
        if (!this.scriptsLoadingPromise) {
            this.scriptsLoadingPromise = Promise.all([
                loadScript(this, ChartJS),
                loadScript(this, ChartDataLabels)
            ])
            .then(() => {
                if (window.Chart && window.ChartDataLabels) {
                    window.Chart.register(window.ChartDataLabels);
                }
                this.scriptsLoaded = true;
                this.kickInit(false);
                if (this.showSpecialCasesModal) this.kickInit(true);
            })
            .catch((error) => {
                console.error('Chart.js or DataLabels load error:', error);
                this.scriptsLoaded = false;
            });
        }

        // ✅ If data is ready, try init (safe to call multiple times)
        this.kickInit(false);

        if (this.showSpecialCasesModal) {
            this.moveWrapperToBody();
            this.kickInit(true);
        }
    }



    openSpecialCasesModal(event) {
        event.stopPropagation();
        this.destroyChart();
        this.restoreWrapper();

        this.isModalOpen = true;
        this.showSpecialCasesModal = false;

        requestAnimationFrame(() => {
            this.showSpecialCasesModal = true;


            requestAnimationFrame(() => {
                this.moveWrapperToBody();

                setTimeout(() => {
                    this.destroyChart();
                    this.pendingInit = true;
                    this.kickInit(true);
                }, 100);
            });
        });
    }


    closeSpecialCasesModal() {
        this.isModalOpen = false;
        this.showSpecialCasesModal = false;
        this.destroyChart();
        this.restoreWrapper();

        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                if (this.chartData && this.hasData) {
                    this.pendingInit = true;
                    this.kickInit(false);
                }
            });
        });

        
    }

    stopModalClose(event) {
        event.stopPropagation();
    }

    moveWrapperToBody() {
        const wrapper = this.template.querySelector('[data-portal-wrapper]');
        if (!wrapper) return;

        if (!this.originalParent) {
            this.originalParent = wrapper.parentNode;
            this.originalNextSibling = wrapper.nextSibling;
        }

        if (!this.portalHost) {
            this.portalHost = document.createElement('div');
            this.portalHost.style.position = 'fixed';
            this.portalHost.style.inset = '0';
            this.portalHost.style.zIndex = '9999999';
            //this.portalHost.style.background = 'rgba(0,0,0,0.45)'; 

            this.portalHost.style.display = 'flex';
            this.portalHost.style.alignItems = 'center';
            this.portalHost.style.justifyContent = 'center';
            this.portalHost.style.padding = '16px';

            document.body.appendChild(this.portalHost);
        }

        if (this.movedWrapper === wrapper) return;

        this.movedWrapper = wrapper;
        this.portalHost.appendChild(wrapper);
        document.body.style.overflow = 'hidden';
    }

    restoreWrapper() {
        document.body.style.overflow = '';
        if (this.movedWrapper && this.originalParent) {
            try {
                this.originalParent.insertBefore(this.movedWrapper, this.originalNextSibling);
            } catch (e) {
                
            }
        }
        if (this.portalHost) {
            this.portalHost.remove();
            this.portalHost = null;
        }
        this.movedWrapper = null;
        this.originalParent = null;
        this.originalNextSibling = null;
    }

    disconnectedCallback() {
        this.destroyChart();
        this.restoreWrapper();
    }

    initializeChart(isModal = false) {
        if (!window.Chart || !this.chartData || !this.hasData) return;

        //const labels = Object.keys(this.chartData);
        //const values = Object.values(this.chartData);

        const pairs = Object.entries(this.chartData)
        .map(([label, value]) => ({ label, value: Number(value) || 0 }));


        const ORDER = 'DESC'; // change to 'ASC' if you want

        pairs.sort((a, b) => ORDER === 'ASC' ? a.value - b.value : b.value - a.value);


        const labels = pairs.map(p => p.label);
        const values = pairs.map(p => p.value);


        //const dynamicHeight = labels.length * 55;
        //const dynamicHeight = Math.max(labels.length * 55, 320);

        //const ROW_GAP = 14;
        const ROW_GAP = isModal ? 22 : 14;
        const barThickness = Math.max(
            14,
            Math.min(34, Math.floor((650 / labels.length) - ROW_GAP))
        );

        const dynamicHeight = Math.max(labels.length * (barThickness + ROW_GAP), 360);




        /*const colors = [
            '#58508D','#FFA600','#9FA368','#ffb703','#94d2bd',
            '#ef476f','#118ab2', '#06d6a0','#8338ec','#ffd166'
        ];*/

        // const colors = ["#61f3c0","#d7a57a","#acc3f2","#f19d5e","#f5f6f2","#088c7a","#969b9d","#50cbb3","#223169"];
        const colors = ["#6acabd","#76ccbe","#78cfc2","#71d1c5","#8dd5cb","#9bdad1","#ade0d9","#cbe9e4","#d2abe7"];
       

        this.legendItems = labels.map((label, index) => ({
            label,
            value: values[index],
            colorStyle: `background-color: ${colors[index % colors.length]}`
        }));
        let canvas;
        if (isModal) {
            
            canvas = (this.portalHost && this.portalHost.querySelector('.modal-canvas'))
                ? this.portalHost.querySelector('.modal-canvas')
                : this.template.querySelector('.modal-canvas');
        } else {
            canvas = this.template.querySelector('.chart-canvas:not(.modal-canvas)');
        }


        if (!canvas) {
            if (this._chartRetryCount < 5) {
                this._chartRetryCount++;
                requestAnimationFrame(() => this.initializeChart(isModal));
            } else {
                this._chartRetryCount = 0;
            }
            return;
        }
        this._chartRetryCount = 0;

        canvas.height = Math.min(dynamicHeight, 900);
        //canvas.style.height = `${dynamicHeight}px`;
        const wrap = canvas.closest('.canvas-wrap');
        if (wrap) {
        wrap.style.height = isModal ? '70vh' : `${Math.min(dynamicHeight, 900)}px`;
        }

         //if (!isModal) {
            //canvas.height = dynamicHeight;
        //}

        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        if (this.chart) this.chart.destroy();

        const chartPlugins = window.ChartDataLabels ? [window.ChartDataLabels] : [];

        const maxValue = Math.max(...values);
        const xAxisMax = maxValue < 8 ? 8 : maxValue;

        
        const tickColor = '#ffffff';
        const axisTickColor = '#ffffff';
        const gridColor = isModal ? 'rgba(255,255,255,0.15)' : '#9e9e9e';
        const axisTickSize  = isModal ? 13 : 12;


        this.chart = new window.Chart(ctx, {
            type: 'bar',
            data: {
                labels,
                datasets: [
                    {
                        data: values,
                        backgroundColor: colors,
                        borderRadius: 0,
                        barThickness: barThickness
                    }
                ]
            },
            plugins: chartPlugins, 
            options: {
                indexAxis: 'y',
                responsive: true,
                maintainAspectRatio: false,
                layout: { padding: { right: 80 } },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: (context) => `${context.raw || 0} Requests`
                        }
                    },
                    datalabels: {
                        color: '#ffffff',
                        backgroundColor: 'rgba(0,0,0,0.35)',
                        borderRadius: 4,
                        padding: { top: 2, right: 6, bottom: 2, left: 6 },
                        font: { weight: 'bold', size: 12 },
                        anchor: 'end',
                        align: 'end',
                        offset: 6,
                        clamp: true,
                        clip: false,
                        formatter: (value) => (value > 0 ? value : '')
                    }
                },
                
                scales: {
                    x: {
                        min: 0,
                        max: xAxisMax,
                        ticks: {
                            color: tickColor,
                            stepSize: 1,
                            beginAtZero: true
                        },
                        grid: { color: gridColor }
                    },
                    y: {
                        afterFit: (scale) => {
                        if (isModal) scale.width = 360; 
                        },
                        ticks: {
                            color: axisTickColor,
                            font: { weight: '700', size: axisTickSize },
                            padding: 8
                        },
                        grid: {
                            display: true,
                            color: gridColor,
                        }
                    }
                }
            }
        });
    }
    destroyChart() {
        if (this.chart) {
            this.chart.destroy();
            this.chart = null;
        }
    }
    kickInit(isModal = false) {
    if (!this.scriptsLoaded || !this.pendingInit || !this.chartData || !this.hasData) return;

    // ✅ prevent multiple init calls
    this.pendingInit = false;

    // small delay to allow DOM canvas to exist after rerender
    setTimeout(() => this.tryInitChart(isModal), 150);
}

tryInitChart(isModal = false) {
    if (!window.Chart || !this.chartData || !this.hasData) return;

    const canvas = isModal
        ? ((this.portalHost && this.portalHost.querySelector('.modal-canvas')) || this.template.querySelector('.modal-canvas'))
        : this.template.querySelector('.chart-canvas:not(.modal-canvas)');

    if (!canvas) {
        // canvas not yet in DOM → retry
        requestAnimationFrame(() => this.tryInitChart(isModal));
        return;
    }
    if (!isModal && canvas.offsetParent === null) {
    requestAnimationFrame(() => this.tryInitChart(isModal));
    return;
}

    const rect = canvas.getBoundingClientRect();
    if (rect.width < 10 || rect.height < 10) {
        requestAnimationFrame(() => this.tryInitChart(isModal));
        return;
    }

    this.initializeChart(isModal);
}

}