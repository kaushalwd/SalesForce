/**
* Description: LWC for Investment Summary units Customer 360 dashboard
* Author: Chaitanya N
* Name: UnitTypeChart
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire, track } from 'lwc'; 
import getUnitClassificationCounts from '@salesforce/apex/Investmentsummerycontroller.getUnitClassificationCounts';
import getUnitTypeCounts from '@salesforce/apex/Investmentsummerycontroller.getUnitTypeCounts';

import { loadScript } from 'lightning/platformResourceLoader';
//import ChartJS from '@salesforce/resourceUrl/ChartJs';
import ChartJS from '@salesforce/resourceUrl/chartjsv1';

export default class UnitTypeChart extends LightningElement {
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
    unitLabels = [];
    unitCounts = [];
    unitColors = [];

    @wire(getUnitTypeCounts, {
    accountId: '$recordId',
    startDate: '$startDate',
    endDate: '$endDate',
    projectName: '$projectName',
    unitName: '$unitName'
    })
    wiredData({ error, data }) {
        this.isLoading = false;

        if (data) {
            this.unitLabels = Object.keys(data);          // now these are types: Villa, Apartment...
            this.unitCounts = this.unitLabels.map(t => Number(data[t]) || 0);

            this.unitColors = this.generateColors(this.unitLabels.length);

            // legend just shows count (or percent)
            this.legendData = this.unitLabels.map((t, i) => ({
            label: t,
            details: String(this.unitCounts[i]),        // or `${this.unitCounts[i]} Units`
            style: `background-color: ${this.unitColors[i]};`
            }));

            this.showChart = this.unitLabels.length > 0;
            this.noData = !this.showChart;

            if (this.chartJsInitialized && this.showChart) {
            requestAnimationFrame(() => this.renderChart());
            }
        } else if (error) {
            console.error('❌ Error fetching unit type data:', error);
            this.noData = true;
            this.showChart = false;
        }
    }


    renderedCallback() {
        if (this.chartJsInitialized) return;
        this.chartJsInitialized = true;

        
        loadScript(this, ChartJS)
            .then(() => {
                
                if (this.unitLabels.length > 0) {
                    
                    this.renderChart();
                }
            })
            .catch(error => {
                console.error('❌ Chart.js load error:', error);
                this.isLoading = false;
            });
    }

    generateColors(count) {
        /*const palette = [
            '#FF6361', '#58508D', '#FFA600', '#9FA368',
            '#7367F0', '#EA5455', '#FF9F43', '#1E90FF'
        ];*/
        const palette = [
            // '#F19D5E', '#4DCCB3', '#048D7B', '#81A9C7',
            // '#6375B7', '#22326c', '#FF9F43', '#1E90FF'
            '#1A9284', '#86D4CC', '#78cfc2', '#71d1c5',
            '#8dd5cb', '#9bdad1', '#ade0d9', '#d2abe7'
        ];
        return Array.from({ length: count }, (_, i) => palette[i % palette.length]);
    }

    //  Same as ProjectWiseChart — formats large numbers
    formatAmount(value) {
        if (value >= 1_000_000_000) return (value / 1_000_000_000).toFixed(1) + 'B';
        if (value >= 1_000_000) return (value / 1_000_000).toFixed(1) + 'M';
        if (value >= 1_000) return (value / 1_000).toFixed(1) + 'K';
        return value?.toFixed ? value.toFixed(0) : value;
    }

    renderChart() {
        const canvas = this.template.querySelector('.chart-canvas');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        if (this.chart) {
            this.chart.destroy();
        }

        const total = this.unitCounts.reduce((sum, val) => sum + val, 0);

        const centerTextPlugin = {
            id: 'centerText',
            beforeDraw: (chart) => {
                const { width, height } = chart;
                const ctx = chart.ctx;
                ctx.save();
                ctx.font = 'bold 18px sans-serif';
                ctx.fillStyle = '#fff';
                ctx.textBaseline = 'middle';
                const text = this.formatAmount(total);
                const textX = Math.round((width - ctx.measureText(text).width) / 2);
                const textY = height / 2;
                ctx.fillText(text, textX, textY);
                ctx.restore();
            }
        };

        this.chart = new window.Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: this.unitLabels,
                datasets: [{
                    data: this.unitCounts,
                    backgroundColor: this.unitColors,
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
                                const formatted = this.formatAmount(value);
                                //return `${context.label}: ${formatted} (${percent}%)`;
                                const percent = this.formatPercent(value, total);
                                return `${context.label}: ${formatted} (${percent})`;
                            }
                        }
                    },
                    datalabels: {
                        color: '#000',
                        //formatter: (value) => `${((value / total) * 100).toFixed(1)}%`,
                        formatter: (value) => this.formatPercent(value, total),
                        font: { weight: 'bold', size: 14 }
                    }
                },
                cutout: '50%',
                responsive: true,
                maintainAspectRatio: false
            },
            plugins: [centerTextPlugin]
        });
    }
    resizeAllCharts() {
  // if you stored chart instances, iterate them:
  this._charts?.forEach(ch => {
    try { ch.resize(); ch.update('none'); } catch (e) {}
  });
}
formatPercent(value, total) {
    const v = Number(value) || 0;
    const t = Number(total) || 0;
    if (!t || v <= 0) return '';

    const pct = (v / t) * 100;

    // up to 2 decimals; remove trailing zeros (90.00 -> 90)
    const pctText = pct.toLocaleString(undefined, {
        minimumFractionDigits: 0,
        maximumFractionDigits: 2
    });

    return `${pctText}%`;
}


}