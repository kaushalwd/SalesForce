import { LightningElement } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import fullcalendar from '@salesforce/resourceUrl/fullcalendar';

export default class MbpCalendarComponent extends LightningElement {
    fullCalendarJsInitialized = false;

    renderedCallback() {
        if (this.fullCalendarJsInitialized) {
            return;
        }
        this.fullCalendarJsInitialized = true;

        Promise.all([
            loadScript(this, fullcalendar + '/index.global.min.js'),  // Latest JS
            loadStyle(this, fullcalendar + '/main.min.css')          // Latest CSS
        ])
        .then(() => {
            this.initializeCalendar();
        })
        .catch(error => {
            console.error('Error loading FullCalendar', error);
        });
    }

    initializeCalendar() {
        const calendarEl = this.template.querySelector('.calendar-container');

        // Initialize the FullCalendar (v6 global bundle)
        const calendar = new window.FullCalendar.Calendar(calendarEl, {
            initialView: 'dayGridMonth',
            headerToolbar: {
                left: 'prev,next today',
                center: 'title',
                right: 'dayGridMonth,timeGridWeek,timeGridDay'
            },
            selectable: true,
            editable: true,
            events: [
                { title: 'Event 1', start: '2025-08-20' },
                { title: 'Event 2', start: '2025-08-22', end: '2025-08-24' }
            ]
        });

        calendar.render();
    }
}