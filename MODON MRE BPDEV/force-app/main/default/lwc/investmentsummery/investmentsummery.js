/**
* Description: LWC for Investment Summary Customer 360 dashboard
* Author: Chaitanya N
* Name: InvestmentSummery
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire, track } from 'lwc';
import getProjectWiseAmounts from '@salesforce/apex/Investmentsummerycontroller.getProjectWiseAmounts';
import { loadScript } from 'lightning/platformResourceLoader';
//import ChartJS from '@salesforce/resourceUrl/ChartJs';
import ChartJS from '@salesforce/resourceUrl/chartjsv1';
export default class ProjectWiseChart extends LightningElement {
    @api recordId;
    @api startDate;
    @api endDate;
    @api projectName;  
    @api unitName;     
    @track isLoading = true;
    @track showChart = false;
    @track noData = false;
    @track legendData = [];

    chartJsInitialized = false;
    chart;
    projectLabels = [];
    projectAmounts = [];
    projectColors = [];

    @wire(getProjectWiseAmounts, { 
        accountId: '$recordId', 
        startDate: '$startDate', 
        endDate: '$endDate' ,
          projectName: '$projectName',   
        unitName: '$unitName'          
    })
    wiredData({ error, data }) {
        
        this.isLoading = false;

        if (data) {
            
            this.projectLabels = Object.keys(data);
            this.projectAmounts = Object.values(data);
            

            this.projectColors = this.generateColors(this.projectLabels.length);
            

            if (this.projectLabels.length === 0) {
                console.warn('No project data found for the given filters');
                this.noData = true;
                this.showChart = false;
            } else {
                this.legendData = this.projectLabels.map((label, index) => ({
                    label,
                    value: this.formatAmount(this.projectAmounts[index]), //  formatted value
                    style: `background-color: ${this.projectColors[index]};`
                }));
                
                this.noData = false;
                this.showChart = true;
            }

            if (this.chartJsInitialized && this.showChart) {
                
                requestAnimationFrame(() => this.renderChart());
            }
        } else if (error) {
            console.error('❌ Error fetching project data:', error);
            this.noData = true;
        }
    }

    renderedCallback() {
        if (this.chartJsInitialized) return;
        this.chartJsInitialized = true;

        
        loadScript(this, ChartJS)
            .then(() => {
                
                if (this.projectLabels.length > 0) {
                    
                    this.renderChart();
                }
            })
            .catch(error => {
                console.error('❌ Chart.js load error:', error);
                this.isLoading = false;
            });
    }

    generateColors(count) {
        const palette = [
            // '#F19D5E', '#4DCCB3', '#048D7B', '#81A9C7',
            // '#6375B7', '#22326c', '#FF9F43', '#1E90FF'
            '#1A9284', '#86D4CC', '#78cfc2', '#71d1c5',
            '#8dd5cb', '#9bdad1', '#ade0d9', '#d2abe7'
        ];

        /*const palette = [
            '#FF6361', '#58508D', '#FFA600', '#9FA368',
            '#7367F0', '#EA5455', '#FF9F43', '#1E90FF'
        ];*/
        return Array.from({ length: count }, (_, i) => palette[i % palette.length]);
    }


    formatAmount(value, withCurrency = true) {
        const num = Number(value);
        if (Number.isNaN(num)) return withCurrency ? '0.00 AED' : '0.00';

        const formatted = num.toLocaleString(undefined, {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });

        return withCurrency ? `${formatted} AED` : formatted;
    }


    renderChart() {
        const canvas = this.template.querySelector('.chart-canvas');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        if (this.chart) {
            this.chart.destroy();
        }

        const total = this.projectAmounts.reduce((sum, val) => sum + val, 0);

        
        const centerTextPlugin = {
            id: 'centerText',
            beforeDraw: (chart) => {
                const ctx = chart.ctx;

                const meta = chart.getDatasetMeta(0);
                const arc = meta?.data?.[0];
                if (!arc) return;

                const x = arc.x;
                const y = arc.y;

                // Inner hole size (what we must fit inside)
                const innerRadius = arc.innerRadius || 0;
                const maxWidth = innerRadius * 1.8; // safe usable width

                const fullText = this.formatAmount(total); // "875,323,964.00 AED"
                let line1 = fullText;
                let line2 = '';

                // Split currency into a new line for safer fit
                if (fullText.endsWith(' AED')) {
                    line1 = fullText.replace(' AED', '');
                    line2 = 'AED';
                }

                ctx.save();
                ctx.fillStyle = '#fff';
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';

                let fontSize = 16;
                const minFontSize = 10;
                const fontFamily = 'Montserrat, sans-serif';
                const fontWeight = '700';

                const fits = () => {
                    ctx.font = `${fontWeight} ${fontSize}px ${fontFamily}`;
                    const w1 = ctx.measureText(line1).width;
                    const w2 = line2 ? ctx.measureText(line2).width : 0;
                    return Math.max(w1, w2) <= maxWidth;
                };

                while (fontSize > minFontSize && !fits()) {
                    fontSize -= 1;
                }

                ctx.font = `${fontWeight} ${fontSize}px ${fontFamily}`;

                // Draw 2 lines if AED exists, else single line
                if (line2) {
                    const gap = Math.max(12, fontSize + 2);
                    ctx.fillText(line1, x, y - gap / 4);
                    ctx.fillText(line2, x, y + gap / 1.2);
                } else {
                    ctx.fillText(line1, x, y);
                }

                ctx.restore();
            }
        };

        this.chart = new window.Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: this.projectLabels,
                datasets: [{
                    data: this.projectAmounts,
                    backgroundColor: this.projectColors,
                    borderWidth: 0,        
                    hoverBorderWidth: 0,   
                }]
            },
            options: {
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: '#000',
                        titleColor: '#fff',
                        bodyColor: '#fff',
                        callbacks: {
                            label: (context) => {
                                const value = context.raw;
                                //const percent = ((value / total) * 100).toFixed(1);
                                const formatted = this.formatAmount(value); // 👈 formatted tooltip
                                //return `${context.label}: ${formatted} (${percent}%)`;
                                const percent = this.formatPercent(value, total);
                                return `${context.label}: ${formatted} (${percent})`;
                            }
                        }
                    },
                    datalabels: {
                        color: '#000',
                        font: { weight: 'bold', size: 14 },
                        formatter: (value) => {
                            const pct = ((Number(value) || 0) / (Number(total) || 1)) * 100;
                            return pct < 1 ? '' : this.formatPercent(value, total);
                        }
                    }
                },
                cutout: '50%',
                responsive: true,
                maintainAspectRatio: false
            },
            plugins: [centerTextPlugin]
        });
    }
    formatPercent(value, total) {
    const v = Number(value) || 0;
    const t = Number(total) || 0;
    if (!t || v <= 0) return '';

    const pct = (v / t) * 100;

    // show up to 2 decimals, but remove trailing zeros (so 90.00 -> 90)
    const pctText = pct.toLocaleString(undefined, {
        minimumFractionDigits: 0,
        maximumFractionDigits: 2
    });

    return `${pctText}%`;
}

}