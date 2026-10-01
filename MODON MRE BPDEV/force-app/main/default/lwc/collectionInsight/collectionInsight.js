/**
* Description: LWC for Collection Insights Customer 360 dashboard
* Author: Chaitanya N
* Name: GaugeChart
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire, track } from 'lwc';
import ChartJSResource from '@salesforce/resourceUrl/ChartJs';
//import ChartDataLabelsResource from '@salesforce/resourceUrl/chartJsPluginDatalabels';
//import ChartDataLabelsResource from '@salesforce/resourceUrl/ChartJs';
import ChartDataLabelsResource from '@salesforce/resourceUrl/chartjsv1';
import { loadScript } from 'lightning/platformResourceLoader';
import getSalesOrderData from '@salesforce/apex/CollectionInsightSalesOrderController.getSalesOrderData';
import { refreshApex } from '@salesforce/apex';


export default class GaugeChart extends LightningElement {
    @api recordId;
    @api startDate;
    @api endDate;
    @api projectName;
    @api unitName;

    @track betweenLabelText = '';
    @track betweenLabelStyle = 'display:none;';


    chartOuter;
    chartInner;
    wiredResult;

    scriptsLoaded = false;
    chartData;

    @track legendItems = [];

    noData = false;
    showLegend = false;

    chartJsUrl = `${ChartJSResource}/chart.min.js`;
    dataLabelsUrl = `${ChartDataLabelsResource}/chartjs-plugin-datalabels.min.js`;

    /*COLORS = {
        orange: '#f5a623',
        purple: '#bd4c9d',
        green: '#b2b672',
        red: '#f26b6b'
    };*/
    COLORS = {
        // orange: '#F19D5E',
        // purple: '#81A9C7',
        // green: '#4DCCB3',
        // red: '#D74B4B'
        // orange: '#86D4CC',
        // purple: '#d2ebe7',
        // green: '#f2aa3c',
        // red: '#c75550'
        orange: '#f2aa3c', // dark green
        purple: '#86D4CC',  // light green
        green: '#1A9284',  //Orange
        red: '#c75550' // red
    };
    connectedCallback() {
        this._handleResize = () => {
            if (this.chartOuter) {
                requestAnimationFrame(() => this.positionBetweenLabel());
            }
        };
        window.addEventListener('resize', this._handleResize);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._handleResize);
        this.destroyCharts();
    }


    renderedCallback() {
        if (this.scriptsLoaded) return;

        this.scriptsLoaded = true;
        Promise.all([loadScript(this, this.chartJsUrl), loadScript(this, this.dataLabelsUrl)])
            .then(() => {

                try {
                    if (window.ChartDataLabels) {
                        if (window.Chart && typeof window.Chart.register === 'function') {
                            window.Chart.register(window.ChartDataLabels); // v3+
                        } else if (window.Chart && window.Chart.plugins && typeof window.Chart.plugins.register === 'function') {
                            window.Chart.plugins.register(window.ChartDataLabels); // v2
                        }
                    }
                } catch (e) {
                    // ignore
                }

                if (this.chartData && !this.noData) {
                    requestAnimationFrame(() => this.renderCharts());
                }
            })
            .catch((e) => {

                console.error('❌ Chart.js / DataLabels load error:', e);
                this.noData = true;
                this.showLegend = false;
                this.destroyCharts();
            });
    }

    @wire(getSalesOrderData, {
        salesOrderId: '$recordId',
        startDate: '$startDate',
        endDate: '$endDate',
        projectName: '$projectName',
        unitName: '$unitName'
    })
    wiredData(result) {
        this.wiredResult = result;
        const { error, data } = result;
        if (data) {
            this.chartData = data;

            

            const collected = Number(data.totalPaidAmount) || 0;
            const outstanding = Number(data.outstandingAmount) || 0;
            const future = Number(data.futureCollectionAmount) || 0;

            // Amount Billed = Paid + Outstanding (Invoices raised for past-due installments)
            //const billed = (Number(data.billedAmount) || 0) || (collected + outstanding);
            const billed = Number(data.totalAmount) || (collected + outstanding);

            const hasData = billed > 0 || collected > 0 || outstanding > 0 || future > 0;

            this.legendItems = [
                { label: 'Amount Billed', color: this.COLORS.orange, value: this.formatAmount(billed) },
                { label: 'Collected Amt', color: this.COLORS.green, value: this.formatAmount(collected) },
                { label: 'Outstanding Amt', color: this.COLORS.red, value: this.formatAmount(outstanding) },
                { label: 'Future Collection', color: this.COLORS.purple, value: this.formatAmount(future) }
            ];


            this.noData = !hasData;
            this.showLegend = hasData;

            this.destroyCharts();

            if (!this.noData && this.scriptsLoaded) {
                requestAnimationFrame(() => this.renderCharts());
            }
        } else if (error) {

            console.error('❌ Error fetching data:', error);
            this.chartData = null;
            this.noData = true;
            this.showLegend = false;
            this.destroyCharts();
        }
    }

    renderCharts() {
        if (!window.Chart || !this.chartData) return;

        const outerCanvas = this.template.querySelector('.gauge-outer');
        const innerCanvas = this.template.querySelector('.gauge-inner');

        if (!outerCanvas || !innerCanvas) return;

        /*const totalAmount = Number(this.chartData.totalAmount) || 0;
        const totalPaid = Number(this.chartData.totalPaidAmount) || 0;
        const outstanding = Number(this.chartData.outstandingAmount) || 0;
        const futureCollection = Number(this.chartData.futureCollectionAmount) || 0;*/

        const collected = Number(this.chartData.totalPaidAmount) || 0;
        const outstanding = Number(this.chartData.outstandingAmount) || 0;
        const futureCollection = Number(this.chartData.futureCollectionAmount) || 0;

        // billed = paid + outstanding
        //const billed = (Number(this.chartData.billedAmount) || 0) || (collected + outstanding);
        const billed = Number(this.chartData.totalAmount) || (collected + outstanding);


        // ✅ OUTER
        const outerData = {
            datasets: [
                {
                    //data: [totalAmount, futureCollection],
                    data: [billed, futureCollection],
                    backgroundColor: [this.COLORS.orange, this.COLORS.purple],
                    borderWidth: 0,
                    cutout: '68%',
                    circumference: 180,
                    rotation: -90
                }
            ]
        };

        this.chartOuter = new window.Chart(outerCanvas, {
            type: 'doughnut',
            data: outerData,
            options: {
                responsive: true,
                animation: false,
                //aspectRatio: 2,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: { enabled: false },


                    datalabels: {
                        color: '#000',
                        font: { weight: '700', size: 13, family: 'Arial' },
                        clamp: true,
                        clip: false,
                        anchor: 'center',
                        align: 'center',

                        // ✅ move purple inward; orange stays normal
                        offset: (ctx) => {
                            // purple slice index = 1
                            if (ctx.dataIndex === 1) return -32; // try -26, -32, -38
                            return 6;
                        },

                        formatter: (value, ctx) => {
                            if (ctx.dataIndex === 1) return '';
                            const total = outerData.datasets[0].data.reduce((a, b) => a + (Number(b) || 0), 0);
                            if (!total || value <= 0) return '';
                            //const pct = Math.round((value / total) * 100);
                            //return `${pct}%`;
                            //const pct = (value / total) * 100;
                            return this.formatPercent(value, total);

                        }
                    }
                }
            }
        });
        requestAnimationFrame(() => {
            requestAnimationFrame(() => this.positionBetweenLabel());
        });

        // ✅ INNER
        const innerData = {
            labels: ['Paid', 'Pending', 'Future'],
            datasets: [
                {
                    //data: [totalPaid, futureCollection, outstanding],
                    data: [collected, outstanding, futureCollection],
                    backgroundColor: [this.COLORS.green, this.COLORS.red, this.COLORS.purple],
                    borderWidth: 0,
                    cutout: '12%',
                    circumference: 180,
                    rotation: -90
                }
            ]
        };

        this.chartInner = new window.Chart(innerCanvas, {
            type: 'doughnut',
            data: innerData,
            options: {
                responsive: true,
                animation: false,
                //aspectRatio: 2,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: { enabled: false },

                    // ✅ hide purple label in INNER chart (so only ONE purple % shows)
                    datalabels: {
                        color: '#000',
                        font: { weight: '700', size: 13, family: 'Arial' },
                        clamp: true,
                        clip: false,
                        anchor: 'center',

                        align: (ctx) => {
                            // green (0) + red (1) -> push toward inner center
                            if (ctx.dataIndex === 0 || ctx.dataIndex === 1) return 'start';
                            return 'center';
                        },
                        offset: (ctx) => {
                            if (ctx.dataIndex === 0 || ctx.dataIndex === 1) return 10; // try -14 .. -24
                            return 0;
                        },
                        formatter: (value, context) => {
                            const dataArr = context.chart.data.datasets[0].data || [];
                            const total = dataArr.reduce((a, b) => a + (Number(b) || 0), 0);
                            if (!total || value <= 0) return '';

                            // purple slice inside INNER = index 2 → hide it
                            if (context.dataIndex === 2) return '';

                            //const pct = Math.round((value / total) * 100);
                            //return `${pct}%`;
                            //const pct = (value / total) * 100;
                            return this.formatPercent(value, total);
                        }
                    }
                }
            }
        });
        requestAnimationFrame(() => {
            requestAnimationFrame(() => this.positionBetweenLabel());
        });
    }

    destroyCharts() {
        try {
            if (this.chartOuter) {
                this.chartOuter.destroy();
                this.chartOuter = null;
            }
            if (this.chartInner) {
                this.chartInner.destroy();
                this.chartInner = null;
            }
        } catch (e) {
            // eslint-disable-next-line no-console
            console.warn('⚠️ Chart destroy failed:', e);
        }
    }


    get billedValue() {
        return this.legendItems[0]?.value || 'AED 0';
    }
    get collectedValue() {
        return this.legendItems[1]?.value || 'AED 0';
    }
    get outstandingValue() {
        return this.legendItems[2]?.value || 'AED 0';
    }
    get futureValue() {
        return this.legendItems[3]?.value || 'AED 0';
    }

    get showLegendBlock() {
        return this.showLegend && !this.noData;
    }

    get totalStyle() {
        return `background-color:${this.COLORS.orange};`;
    }
    get paidStyle() {
        return `background-color:${this.COLORS.green};`;
    }
    get pendingStyle() {
        //return `background-color:${this.COLORS.purple};`;
        return `background-color:${this.COLORS.red};`;
    }
    get futureStyle() {
        //return `background-color:${this.COLORS.red};`;
        return `background-color:${this.COLORS.purple};`;
    }

    formatAmount(amount) {
        const amt = Number(amount);
        if (Number.isNaN(amt)) return 'AED 0.00';

        return `${amt.toLocaleString(undefined, {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        })} AED `;
    }


    positionBetweenLabel() {
        this.betweenLabelText = '';
        this.betweenLabelStyle = 'display:none;';
        try {
            if (!this.chartOuter) return;

            const canvasEl = this.template.querySelector('.gauge-outer');
            if (!canvasEl) return;

            const meta = this.chartOuter.getDatasetMeta(0);
            if (!meta?.data?.length) return;

            const arc = meta.data[1];
            if (!arc) return;

            const startAngle = arc.startAngle ?? arc._model?.startAngle;
            const endAngle = arc.endAngle ?? arc._model?.endAngle;
            const x0 = arc.x ?? arc._model?.x;
            const y0 = arc.y ?? arc._model?.y;
            const innerR = arc.innerRadius ?? arc._model?.innerRadius;

            if ([startAngle, endAngle, x0, y0, innerR].some(v => v == null)) return;

            const dataArr = this.chartOuter.data.datasets[0].data || [];
            const value = Number(dataArr[1]) || 0;
            const total = dataArr.reduce((a, b) => a + (Number(b) || 0), 0);
            if (!total || value <= 0) return;

            //const pct = Math.round((value / total) * 100);
            //const pct = (value / total) * 100;
            //this.betweenLabelText = `${pct.toFixed(2)}%`;
            this.betweenLabelText = this.formatPercent(value, total);

            const angle = (startAngle + endAngle) / 2;

            const GAP_INSET = 14;      // tweak 10..18
            const r = innerR - GAP_INSET;

            const cx = x0 + Math.cos(angle) * r;
            const cy = y0 + Math.sin(angle) * r;

            // ✅ convert chart internal pixels -> CSS pixels using final chart size
            const scaleX = canvasEl.clientWidth / this.chartOuter.width;
            const scaleY = canvasEl.clientHeight / this.chartOuter.height;

            const cssX = cx * scaleX;
            const cssY = cy * scaleY;

            /*const left = canvasEl.offsetLeft + cssX;
            const top  = canvasEl.offsetTop + cssY;
            this.betweenLabelStyle = `display:block; left:${left}px; top:${top}px;`;*/
            const wrapper = this.template.querySelector('.gauge-wrapper');
            if (!wrapper) return;

            const canvasRect = canvasEl.getBoundingClientRect();
            const wrapperRect = wrapper.getBoundingClientRect();

            // wrapper-relative position (stable even with padding/scroll)
            const padLeft = 15;
            const left = (canvasRect.left - wrapperRect.left) + cssX + padLeft;
            const top = (canvasRect.top - wrapperRect.top) + cssY;

            this.betweenLabelStyle = `display:block; left:${left}px; top:${top}px;`;

        } catch (e) {
            this.betweenLabelStyle = 'display:none;';
        }
    }
    formatPercent(value, total) {
        if (!total || !value) return '';

        const pct = (value / total) * 100;

        // Show up to 2 decimals, remove trailing zeros
        return `${pct.toLocaleString(undefined, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        })}%`;
    }

}