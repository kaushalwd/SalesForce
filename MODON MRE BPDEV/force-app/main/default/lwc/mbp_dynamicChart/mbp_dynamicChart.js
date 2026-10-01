import { LightningElement, api, track } from 'lwc'; 
import { loadScript } from 'lightning/platformResourceLoader';

const CHARTJS_URL = 'https://cdn.jsdelivr.net/npm/chart.js';
const CHARTJS_PLUGIN_URL = 'https://cdn.jsdelivr.net/npm/chartjs-plugin-datalabels';
import MBP_Dirham from '@salesforce/resourceUrl/MBP_Dirham';
import { loadTheme } from 'c/mbpThemeLoader';
export default class DynamicChart extends LightningElement {
    @api chartTitle;
    @api chartType;
    @api showDetails;
    @api tooltips = [];
    _labels = [];
    _values = [];
    _colors = [];
    _options = {};
    @api salesMode;  // 'price' or 'count'
dirhamIcon = MBP_Dirham;
 @api
    getCanvas() {
        // Returns the canvas inside this child component
        return this.template.querySelector('canvas');
    }
  // Format full number with Indian separators (kept for non-price or raw usage)
  formatNumber(value) {
    if (value === null || value === undefined || isNaN(value)) {
        return '0';
    }
    return Number(value).toLocaleString('en-IN'); // 68,12,033 Indian style
  }

 // New: return string in millions, e.g. "12.34M"
formatMillions(value, decimals = 2) {
    if (value === null || value === undefined || isNaN(value)) return '0M';
    const millions = Number(value) / 1_000_000;
    const fixed = Number(millions.toFixed(decimals));
    return `${fixed}M`;   // 🔹 removed space
}

// New: returns compact label for axis ticks -> "12.3M" or "0.45M"
millionLabel(value) {
    if (value === null || value === undefined || isNaN(value)) return '0M';
    const millions = value / 1_000_000;
    const decimals = Math.abs(millions) >= 1 ? 1 : 2;
    return `${Number(millions.toFixed(decimals))}M`; // 🔹 removed space
}




  @track isModalOpen = false;
handleExpand() {
    this.isModalOpen = true;

    // Delay so popup DOM is ready before rendering chart
    setTimeout(() => {
        this.initializePopupChart();
    }, 50);
}
handleClose() {
    this.isModalOpen = false;
    if (this.popupChartInstance) {
        try { this.popupChartInstance.destroy(); } catch(e) {}
        this.popupChartInstance = null;
    }
}
stopBubble(event) {
    event.stopPropagation();
}


    @api
    set labels(val) {
        this._labels = this.normalizeInput(val);
    }
    get labels() {
        return this._labels;
    }

 @api
set values(val) {
    this._values = this.normalizeInput(val).map(v => (v == null ? 0 : v)); 
    

    if (this.chartInstance) {
       
        this.chartInstance.data.labels = [...this._labels];
        this.chartInstance.data.datasets[0].data = [...this._values];
        this.chartInstance.data.datasets[0].backgroundColor = this.getSafeColors();
        this.chartInstance.update();
    }
}
   
    get values() {
        return this._values;
    }

    @api
    set colors(val) {
        this._colors = this.normalizeInput(val);

        if (this.chartInstance) {
            this.chartInstance.data.datasets[0].backgroundColor = this.getSafeColors();
            this.chartInstance.update();
        }
    }
    get colors() {
        return this._colors;
    }

    @api
    set options(val) {
        this._options =
            typeof val === 'string' ? this.tryParse(val, {}) : (val || {});
    }
    get options() {
        return this._options;
    }

    @track chartInstance;
    chartJsInitialized = false;

    renderedCallback() {
        if (this.chartJsInitialized) return;

        Promise.all([
            loadScript(this, CHARTJS_URL),
            loadScript(this, CHARTJS_PLUGIN_URL)
        ])
            .then(() => {
                this.initializeChart();
                this.chartJsInitialized = true;
            })
            .catch((error) => {
                console.error('❌ Error loading Chart.js or DataLabels plugin', error);
            });
    }




initializePopupChart() {
    const canvas = this.template.querySelector('.popup-chart');
    if (!canvas) {
        console.error('❌ No popup canvas element found');
        return;
    }

    const ctx = canvas.getContext('2d');
    const type = (this.chartType || 'bar').toLowerCase();

   const centerTextPlugin = {
    id: 'centerText',
    afterDraw: (chart) => {
        if (chart.config.type !== 'doughnut') return;

        const { width, height } = chart;
        const ctx = chart.ctx;
        const dataset = chart.config.data.datasets[0];
        const total = dataset.data.reduce((sum, val) => sum + val, 0);

        // inside centerTextPlugin after computing `total`
let text;
if (total === 0) {
    text = 'No Data';
} else if (this.salesMode === 'price') {
  text = `AED ${this.formatMillions(total)}`; // ✅ AED 6M

} else {
    text = this.formatNumber(total);
}


        const centerX = chart.chartArea.left + (chart.chartArea.right - chart.chartArea.left) / 2;
        const centerY = chart.chartArea.top + (chart.chartArea.bottom - chart.chartArea.top) / 2;

        // Circle background only when data > 0
        if (total > 0) {
            const radius = 30;
            ctx.save();
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false);
            ctx.fillStyle = 'transparent';
            ctx.fill();
            ctx.closePath();
            ctx.restore();

            ctx.fillStyle = '#000';
        } else {
            ctx.fillStyle = 'transparent'; // Black text only, no circle
        }

        ctx.save();
        ctx.font = total === 0 ? 'bold 16px sans-serif' : 'bold 18px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(text, centerX, centerY);
        ctx.restore();
    }
};


    let datasetConfig;
    if (this.isLineChart) {
        datasetConfig = {
            label: this.chartTitle || '',
            data: [...this.values],
            borderColor: this.getSafeColors()[0] || '#C4A249',
            backgroundColor: 'transparent',
            tension: 0.4,
            fill: false,
            pointRadius: 4,
            pointHoverRadius: 6
        };
    } else {
        datasetConfig = {
            label: this.chartTitle || '',
            data: [...this.values],
            backgroundColor: this.getSafeColors(),
            borderWidth: 1,
            borderColor: '#fff'
        };
    }

    let finalLabels = [...this._labels];
    if ((this.chartTitle || '').toLowerCase() === 'projects & units') {
        finalLabels = ['Projects', 'Units'];
    }

    const config = {
        type,
        data: {
            labels: finalLabels,
            datasets: [datasetConfig]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: true, position: 'right' },
                tooltip: {
                    callbacks: {
                        label: (context) => {
                            const label = context.label || '';
                            const value = context.parsed || 0;
                            const dataset = context.chart.data.datasets[0];
                            const total = dataset.data.reduce((a, b) => a + b, 0);
                            const percentage = ((value / total) * 100).toFixed(2);
            if (this.salesMode === 'price') {
    return `${label}: AED ${this.formatMillions(value)} (${percentage}%)`;
}
return `${label}: ${this.formatNumber(value)} (${percentage}%)`;
                        }
                    }
                },
                datalabels: {
    display: (context) => context.hovered ? true : false,
    color: '#fff',
    formatter: (value, context) => {
        const dataset = context.chart.data.datasets[0];
        const total = dataset.data.reduce((a, b) => a + b, 0);
        const percentage = ((value / total) * 100).toFixed(2);

        if (this.salesMode === 'price') {
            return `د.إ ${this.formatNumber(value)} (${percentage}%)`;
        }
        return `${this.formatNumber(value)} (${percentage}%)`;
    },
    font: {
        weight: 'bold',
        size: 12,
    }
}

            },
            ...(type !== 'doughnut' ? {
                scales: {
                    x: {
                        title: {
                            display: true,
                            text: 'Months'
                        }
                    },
                    y: {
                        title: {
                            display: true,
                            text: this.salesMode === 'price' ? 'AED M' : 'Unit Count'
                        },
                        beginAtZero: true,
                        
                            ticks: {
    callback: (value) => {
        if (this.salesMode === 'price') {
            return this.millionLabel(value);
        }
        return value;
    }


                        }
                    }
                }
            } : {}),
            cutout: type === 'doughnut' ? '60%' : undefined
        },
        plugins: [centerTextPlugin, window.ChartDataLabels]
    };

    if (this.popupChartInstance) {
        this.popupChartInstance.destroy();
    }

    this.popupChartInstance = new window.Chart(ctx, config);
}


    initializeChart() {
        const canvas = this.template.querySelector('.commission-chart');
        if (!canvas) {
            console.error('❌ No canvas element found');
            return;
        }

        const ctx = canvas.getContext('2d');
        const type = (this.chartType || 'bar').toLowerCase();

        const centerTextPlugin = {
            id: 'centerText',
            afterDraw: (chart) => {
                if (chart.config.type !== 'doughnut') return;

                const { width, height } = chart;
                const ctx = chart.ctx;
                const dataset = chart.config.data.datasets[0];
                const total = dataset.data.reduce((sum, val) => sum + val, 0);

              // inside centerTextPlugin after computing `total`
let text;
if (total === 0) {
    text = 'No Data';
} else if (this.salesMode === 'price') {
    text = `AED ${this.formatMillions(total)}`; // ✅ AED 6M

} else {
    text = this.formatNumber(total);
}
                const centerX = chart.chartArea.left + (chart.chartArea.right - chart.chartArea.left) / 2;
                const centerY = chart.chartArea.top + (chart.chartArea.bottom - chart.chartArea.top) / 2;

                const radius = 30; // Adjust radius as needed
                ctx.save();
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false);
                ctx.fillStyle = 'transparent';  // Black background
                ctx.fill();
                ctx.closePath();
                ctx.restore();

                ctx.save();
                ctx.font = 'bold 18px sans-serif';
                ctx.fillStyle = '#000';  // White text
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText(text, centerX, centerY);
                ctx.restore();
            }
        };

        let datasetConfig;
        if (this.isLineChart) {
            datasetConfig = {
                label: this.chartTitle || '',
                data: [...this.values],
                borderColor: this.getSafeColors()[0] || '#C4A249',
                backgroundColor: 'transparent',
                tension: 0.4,
                fill: false,
                pointRadius: 4,
                pointHoverRadius: 6
            };
        } else {
            datasetConfig = {
                label: this.chartTitle || '',
                data: [...this.values],
                backgroundColor: this.getSafeColors(),
                borderWidth: 1,
                borderColor: '#fff'
            };
        }

        let finalLabels = [...this._labels];
        if ((this.chartTitle || '').toLowerCase() === 'projects & units') {
            finalLabels = ['Projects', 'Units'];
        }

        const config = {
            type,
            data: {
                labels: finalLabels,
                datasets: [datasetConfig]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: (context) => {
                                const label = context.label || '';
                                const value = context.parsed || 0;
                                const dataset = context.chart.data.datasets[0];
                                const total = dataset.data.reduce((a, b) => a + b, 0);
                                const percentage = ((value / total) * 100).toFixed(2);
                     if (this.salesMode === 'price') {
    return `${label}: AED ${this.formatMillions(value)} (${percentage}%)`;
}
return `${label}: ${this.formatNumber(value)} (${percentage}%)`;
                            }
                            
                        }
                    },
                    datalabels: {
    display: (context) => context.hovered ? true : false,
    color: '#fff',
    formatter: (value, context) => {
        const dataset = context.chart.data.datasets[0];
        const total = dataset.data.reduce((a, b) => a + b, 0);
        const percentage = ((value / total) * 100).toFixed(2);

     if (this.salesMode === 'price') {
    return `د.إ ${this.formatMillions(value)} (${percentage}%)`;
}
return `${this.formatNumber(value)} (${percentage}%)`;
    }
,
    font: {
        weight: 'bold',
        size: 12,
    }
}

                },
                ...(type !== 'doughnut' ? {
                    scales: {
                        x: {
                            title: {
                                display: true,
                                text: 'Months'
                            }
                        },
                        y: {
                            title: {
                                display: true,
                                text: this.salesMode === 'price' ? 'AED M' : 'Unit Count'
                            },
                            beginAtZero: true,
                            ticks: {
                                callback: (value) => {
                                    if (this.salesMode === 'price') {
                                        const millionValue = value / 1000000;
                                        return millionValue < 1
                                            ? millionValue.toFixed(2) + ' M'
                                            : millionValue.toFixed(1) + ' M';
                                    }
                                    return value;
                                }
                            }
                        }
                    }
                } : {}),
                cutout: type === 'doughnut' ? '60%' : undefined
            },
            plugins: [centerTextPlugin, window.ChartDataLabels] // Added datalabels plugin here
        };

        if (this.chartInstance) {
            this.chartInstance.destroy();
        }

        this.chartInstance = new window.Chart(ctx, config);
    }

    get details() {
    if (this.isLineChart) {
        return [];
    }

    let finalLabels = [...this._labels];
    if ((this.chartTitle || '').toLowerCase() === 'projects & units') {
        finalLabels = ['Projects', 'Units'];
    }

    return finalLabels.map((label, idx) => {
        const rawValue = this._values[idx] || 0;
        const formatted = this.salesMode === 'price' ? this.formatMillions(rawValue) : this.formatNumber(rawValue);


        return {
            label,
            value: formatted,
            showIcon: this.salesMode === 'price', // 👈 true for price mode
            dotStyle: `background-color:${this.getSafeColors()[idx]}; 
                       width:10px; height:10px; border-radius:50%; 
                       display:inline-block; margin-right:6px;`
        };
    });
}






createGradient(ctx, color) {
    const gradient = ctx.createLinearGradient(0, 0, 0, 300);
    
    // lighter top shade
    gradient.addColorStop(0, this.lightenColor(color, 0.3));  
    
    // base color
    gradient.addColorStop(0.5, color);  
    
    // darker bottom shade (for 3D feel)
    gradient.addColorStop(1, this.darkenColor(color, 0.3));  
    
    return gradient;
}

lightenColor(color, percent) {
    const num = parseInt(color.replace('#',''),16),
        amt = Math.round(2.55 * (percent * 100)),
        R = (num >> 16) + amt,
        G = (num >> 8 & 0x00FF) + amt,
        B = (num & 0x0000FF) + amt;
    return "#" + (
        0x1000000 + 
        (R<255?R<1?0:R:255)*0x10000 + 
        (G<255?G<1?0:G:255)*0x100 + 
        (B<255?B<1?0:B:255)
    ).toString(16).slice(1).toUpperCase();
}

darkenColor(color, percent) {
    const num = parseInt(color.replace('#',''),16),
        amt = Math.round(2.55 * (percent * 100)),
        R = (num >> 16) - amt,
        G = (num >> 8 & 0x00FF) - amt,
        B = (num & 0x0000FF) - amt;
    return "#" + (
        0x1000000 + 
        (R<255?R<1?0:R:255)*0x10000 + 
        (G<255?G<1?0:G:255)*0x100 + 
        (B<255?B<1?0:B:255)
    ).toString(16).slice(1).toUpperCase();
}

    // Replace the old colorPalette with blue shades
colorPalette = [
    '#2596BE', // base
    '#1F85A3',
    '#339CCB',
    '#4AB3E0',
    '#1C7DA3',
    '#3AA0C7',
    '#2B8FB3',
    '#5BB8E5',
    '#1B7490',
    '#3FA7D1',
    '#2E91B0',
    '#4DAFD6',
    '#1A6980',
    '#2290B0',
    '#37B0E0'
];
getSafeColors() {
    const canvas = this.template.querySelector('.commission-chart') 
                 || this.template.querySelector('.popup-chart');
    if (!canvas) return this._colors.length ? [...this._colors] : this.colorPalette;

    const ctx = canvas.getContext('2d');
    const baseColors = this._colors.length > 0 
        ? [...this._colors] 
        : this.labels.map((_, i) => this.colorPalette[i % this.colorPalette.length]);

    // generate gradients for each base color
    return baseColors.map(c => this.createGradient(ctx, c));
}


    get isLineChart() {
        return (this.chartType || '').toLowerCase() === 'line';
    }

    normalizeInput(val) {
        if (!val) return [];
        if (Array.isArray(val)) return [...val];
        if (typeof val === 'string') return this.tryParse(val, []);
        if (typeof val === 'object') return Object.values(val);
        return [];
    }

    tryParse(str, fallback) {
        try {
            return JSON.parse(str);
        } catch (e) {
            console.error('❌ Invalid JSON', str, e);
            return fallback;
        }
    }

    connectedCallback() {
        loadTheme(this);
    }

}