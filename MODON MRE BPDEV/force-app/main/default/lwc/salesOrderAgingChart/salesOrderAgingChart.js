/**
* Description: LWC for Sales order aging chart Customer 360 dashboard
* Author: Chaitanya N
* Name: SalesOrderAgingChart
* Version
* ************************************************************************************************
* Date              By                  Version             Change
* ****************  ******************  ****************    **************************************
* 22/05/2026         Chaitanya N         V1.0                Initial Version
**************************************************************************************************
*/
import { LightningElement, api, wire } from 'lwc';
import getAgingSummary from '@salesforce/apex/SalesOrderAgingController.getAgingSummary';
import { loadScript } from 'lightning/platformResourceLoader';
//import ChartJS from '@salesforce/resourceUrl/ChartJs';
import ChartJS from '@salesforce/resourceUrl/chartjsv1';
import ChartDataLabels from '@salesforce/resourceUrl/chartJsPluginDatalabels';

export default class SalesOrderAgingChart extends LightningElement {
    @api recordId;
    @api projectName;
    @api unitName;
    @api startDate;
    @api endDate;

    chartLib;
    chartPlugin;
    chart;
    chartData;
    hasData = true;
    showAgingModal = false;
    portalHost;
    movedWrapper;
    originalParent;
    originalNextSibling;
    pendingInit = false;
    scriptsLoaded = false;
    scriptsLoadingPromise;

    @wire(getAgingSummary, {
        accountId: '$recordId',
        startDate: '$startDate',
        endDate: '$endDate',
        projectName: '$projectName',
        unitName: '$unitName'
    })
    wiredAgingSummary({ data, error }) {
        if (data) {
            const total = Object.values(data).reduce((sum, val) => sum + (Number(val) || 0), 0);
            this.hasData = total > 0;

            this.destroyChart();
            this.chartData = data;
            this.pendingInit = true;
            this.kickInit(false);
        } else if (error) {
            console.error('Error fetching aging summary:', error);
            this.hasData = false;
        }
    }

    renderedCallback() {
        if (!this.scriptsLoadingPromise) {
            this.scriptsLoadingPromise = Promise.all([
                loadScript(this, ChartJS),
                loadScript(this, ChartDataLabels)
            ]).then(() => {
                this.chartLib = window.Chart;
                this.chartPlugin = window.ChartDataLabels;

                if (this.chartLib && this.chartPlugin) {
                    this.chartLib.register(this.chartPlugin);
                }

                this.scriptsLoaded = true;
                this.kickInit(false);
            }).catch((e) => {
                console.error('Chart scripts failed to load', e);
                this.scriptsLoaded = false;
            });
        }

        this.kickInit(false);

        if (this.showAgingModal) {
            this.moveWrapperToBody();
            this.pendingInit = true;
            this.kickInit(true);
        }
    }

    kickInit(isModal = false) {
        if (!this.scriptsLoaded || !this.pendingInit) return;
        this.pendingInit = false;
        setTimeout(() => this.tryInitChart(isModal), 150);
    }

    initializeChart(isModal = false) {
        if (!this.chartLib || !this.chartData || !this.hasData) return;

        let canvas;
        if (isModal) {
            canvas = (this.portalHost && this.portalHost.querySelector('.modal-canvas'))
                ? this.portalHost.querySelector('.modal-canvas')
                : this.template.querySelector('.modal-canvas');
        } else {
            canvas = this.template.querySelector('.chart-canvas:not(.modal-canvas)');
        }

        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        if (this.chart) this.chart.destroy();

        const labels = Object.keys(this.chartData);
        const rawValues = Object.values(this.chartData).map(v => Number(v) || 0);
        const maxValue = Math.max(...rawValues, 0);
        const minVisible = maxValue * 0.01;
        const values = rawValues.map(v => (v > 0 && v < minVisible ? minVisible : v));
        const suggestedMax = maxValue * 1.15;

        const tickColor = '#ffffff';
        const gridColor = isModal ? 'rgba(255,255,255,0.15)' : '#9e9e9e';

        this.chart = new this.chartLib(ctx, {
            type: 'bar',
            data: {
                labels,
                datasets: [{
                    label: '',
                    data: values,
                    backgroundColor: ['#2acbba', '#71d1c5', '#9bdad1', '#2acbba'],
                    borderRadius: 0,
                    barThickness: 40
                }]
            },
            options: {
                indexAxis: 'y',
                responsive: true,
                maintainAspectRatio: false,
                interaction: {
                    mode: 'nearest',
                    intersect: true,
                    axis: 'y'
                },
                hover: {
                    mode: 'nearest',
                    intersect: true
                },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        enabled: true,
                        mode: 'nearest',
                        intersect: true,
                        callbacks: {
                            label: context => {
                                const rawVal = rawValues[context.dataIndex] || 0;
                                return rawVal > 0 ? `${rawVal.toLocaleString(undefined, {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2
                                })} AED` : '';
                            }
                        }
                    },
                    datalabels: { display: false }
                },
                scales: {
                    x: {
                        beginAtZero: true,
                        suggestedMax: suggestedMax,
                        grid: { color: gridColor },
                        ticks: {
                            color: tickColor,
                            maxRotation: 30,
                            minRotation: 30,
                            callback: (val) => {
                                const num = Number(val);
                                if (Number.isNaN(num)) return val;
                                return num.toLocaleString(undefined, {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2
                                });
                            }
                        }
                    },
                    y: {
                        grid: { display: true, color: gridColor },
                        reverse: true,
                        ticks: {
                            color: tickColor,
                            padding: 8
                        },
                        afterFit: (scale) => {
                            const ctx2 = scale.ctx;
                            const labels2 = scale.getLabels ? scale.getLabels() : (scale.ticks || []).map(t => t.label);

                            ctx2.save();
                            const font = scale.options?.ticks?.font;
                            if (font) {
                                const f = this.chartLib.helpers.toFont(font);
                                ctx2.font = f.string;
                            }

                            let max = 0;
                            labels2.forEach((l) => {
                                max = Math.max(max, ctx2.measureText(String(l)).width);
                            });
                            ctx2.restore();

                            scale.width = Math.ceil(max + 30);
                        }
                    }
                }
            }
        });
    }

    openAgingModal(event) {
    event.stopPropagation();
    this.destroyChart();
    this.restoreWrapper();

    this.showAgingModal = false;

    requestAnimationFrame(() => {
        this.showAgingModal = true;

        requestAnimationFrame(() => {
            this.moveWrapperToBody();

            setTimeout(() => {
                this.destroyChart();
                this.pendingInit = true;
                this.kickInit(true);

                if (this.chart) {
                    this.chart.resize();
                    this.chart.update('none');
                }
            }, 100);
        });
    });
}

closeAgingModal() {
    this.showAgingModal = false;
    this.destroyChart();
    this.restoreWrapper();

    requestAnimationFrame(() => {
        requestAnimationFrame(() => {
            if (this.chartData && this.hasData) {
                this.pendingInit = true;
                this.kickInit(false);

                requestAnimationFrame(() => {
                    if (this.chart) {
                        this.chart.resize();
                        this.chart.update('none');
                    }
                });
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
        } catch (e) {}
    }
    if (this.portalHost) {
        this.portalHost.remove();
        this.portalHost = null;
    }
    this.movedWrapper = null;
    this.originalParent = null;
    this.originalNextSibling = null;
}

    tryInitChart(isModal = false) {
        if (!this.scriptsLoaded || !this.chartLib || !this.chartData || !this.hasData) return;

        const canvas = isModal
            ? ((this.portalHost && this.portalHost.querySelector('.modal-canvas')) || this.template.querySelector('.modal-canvas'))
            : this.template.querySelector('.chart-canvas:not(.modal-canvas)');

        if (!canvas) return;

        const rect = canvas.getBoundingClientRect();
        if (rect.width < 10 || rect.height < 10) return;

        this.initializeChart(isModal);
    }

    destroyChart() {
        if (this.chart) {
            this.chart.destroy();
            this.chart = null;
        }
    }
    disconnectedCallback() {
        this.destroyChart();
        this.restoreWrapper();
    }
}