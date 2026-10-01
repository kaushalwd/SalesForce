import { LightningElement, track } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import FULLCALENDAR from '@salesforce/resourceUrl/fullcalendar';
import getEventsDynamic from '@salesforce/apex/MBP_ManageEventsandActivities.getEventsDynamic';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MbpCalendarComponent extends LightningElement {
    @track calendarInitialized = false;
    @track isLoading = false;
    @track hasNoEvents = false;
    @track currentView = 'dayGridMonth';
    @track todayEvents = [];
    @track futureEvents = [];
    @track pastEvents = [];
    @track filteredTodayEvents = [];
    @track filteredFutureEvents = [];
    @track filteredPastEvents = [];
    @track showModal = false;
    @track selectedEvent = {};
    @track typeFilter = '';
    @track allCalendarEvents = [];
    fullCalendarJsLoaded = false;
    calendar;
    debounceTimer;
    typeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Open House', value: 'Open House' },
        { label: 'Annual Awards', value: 'Annual Awards' },
        { label: 'Training Academy', value: 'Training Academy' },
        { label: 'Broker Training', value: 'Broker Training' },
        { label: 'Broker Meeting', value: 'Broker Meeting' },
        { label: 'Webinar', value: 'Webinar' },
        { label: 'Presentation', value: 'Presentation' },
        { label: 'Seminars', value: 'Seminars' },
        { label: 'Launch', value: 'Launch' },
        { label: 'Exhibition', value: 'Exhibition' },
        { label: 'Kiosks', value: 'Kiosks' },
        { label: 'Road Show', value: 'Road Show'}
    ];

    activateEventsTab() {
        this.dispatchEvent(new CustomEvent('activetab', {
            detail: { tabName: 'events-and-activities' },
            bubbles: true,
            composed: true
        }));
    }
    
    get hasTodayEvents() {
        return this.filteredTodayEvents && this.filteredTodayEvents.length > 0;
    }
    
    get hasFutureEvents() {
        return this.filteredFutureEvents && this.filteredFutureEvents.length > 0;
    }
    
    get hasPastEvents() {
        return this.filteredPastEvents && this.filteredPastEvents.length > 0;
    }

    get todayColumns() {
        return [
            { label: 'Event', fieldName: 'shortTitle', type: 'text', wrapText: true },
            { label: 'Date & Time', fieldName: 'formattedDateTime', type: 'text', wrapText: false, cellAttributes: { style: 'white-space: normal;' } },
            { label: 'Type', fieldName: 'shortType', type: 'text', wrapText: false }
        ];
    }
    
    get futureColumns() {
        return this.todayColumns;
    }
    
    get pastColumns() {
        return this.todayColumns;
    }

  /*  get selectedEventTitle() {
        return this.selectedEvent.Title__c || this.selectedEvent.Name || 'Event Details';
    }*/

    get selectedEventTitle() {
    return this.selectedEvent.Name || 'Event Details';
}

    
    get selectedEventDateTime() {
        if (!this.selectedEvent.Start_Date_and_Time__c) return '';
        
        const startDate = new Date(this.selectedEvent.Start_Date_and_Time__c);
        let formatted = startDate.toLocaleDateString() + ' ' + startDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        
        if (this.selectedEvent.End_Date_and_Time__c) {
            const endDate = new Date(this.selectedEvent.End_Date_and_Time__c);
            formatted += ' - ' + endDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }
        
        return formatted;
    }
    
    get selectedEventType() {
        return this.selectedEvent.Type__c || 'N/A';
    }
    
    get selectedEventStatus() {
        return this.selectedEvent.Status__c || 'N/A';
    }
    
    get selectedEventLocation() {
        return this.selectedEvent.Location__c || 'N/A';
    }
    
    get selectedEventDescription() {
        return this.selectedEvent.Description__c || 'No description available';
    }

    connectedCallback() {
        this.loadEventsData();
        window.addEventListener('resize', this.handleResize.bind(this));
    }

    async loadEventsData() {
        try {
            this.isLoading = true;
            
            // Use the consolidated method for all event types
            const [todayResult, futureResult, pastResult] = await Promise.all([
                getEventsDynamic({ mode: 'Today' }),
                getEventsDynamic({ mode: 'Future' }),
                getEventsDynamic({ mode: 'Past' })
            ]);
            
            this.todayEvents = this.processEvents(todayResult);
            this.futureEvents = this.processEvents(futureResult);
            this.pastEvents = this.processEvents(pastResult);
            this.filteredTodayEvents = [...this.todayEvents];
            this.filteredFutureEvents = [...this.futureEvents];
            this.filteredPastEvents = [...this.pastEvents];
        } catch (error) {
            this.showToast('Error', 'Failed to load events: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    processEvents(events) {
        return events.map(event => {
            let dateTimeString = '';
            if (event.Start_Date_and_Time__c) {
                const startDate = new Date(event.Start_Date_and_Time__c);
                dateTimeString = startDate.toLocaleDateString() + ' ' + 
                                startDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                if (event.End_Date_and_Time__c) {
                    const endDate = new Date(event.End_Date_and_Time__c);
                    if (startDate.toDateString() === endDate.toDateString()) {
                        dateTimeString += ' - ' + endDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                    } else {
                        dateTimeString += ' - ' + endDate.toLocaleDateString() + ' ' + 
                                        endDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                    }
                }
            }
            return {
                ...event,
                formattedDateTime: dateTimeString,
               // shortTitle: this.truncateText(event.Title__c, 25),
               shortTitle: this.truncateText(event.Name, 25),

                shortType: this.truncateText(event.Type__c, 15)
            };
        });
    }

    truncateText(text, maxLength) {
        if (!text) return '';
        return text.length > maxLength ? text.substring(0, maxLength) + '...' : text;
    }

    handleTypeChange(event) {
        this.typeFilter = event.detail.value;
        this.applyFilters();
        this.filterCalendarEvents();
    }

    applyFilters() {
        this.filteredTodayEvents = this.todayEvents.filter(event => this.matchesType(event));
        this.filteredFutureEvents = this.futureEvents.filter(event => this.matchesType(event));
        this.filteredPastEvents = this.pastEvents.filter(event => this.matchesType(event));
    }

    filterCalendarEvents() {
        if (this.calendar) {
            this.calendar.removeAllEvents();
            
            const filteredEvents = this.allCalendarEvents.filter(event => {
                if (!this.typeFilter) return true;
                
                const matchingEvent = this.todayEvents.find(e => e.Id === event.id) || 
                                    this.futureEvents.find(e => e.Id === event.id) || 
                                    this.pastEvents.find(e => e.Id === event.id);
                
                return matchingEvent && matchingEvent.Type__c === this.typeFilter;
            });
            
            this.calendar.addEventSource(filteredEvents);
        }
    }

    matchesType(event) {
        return !this.typeFilter || event.Type__c === this.typeFilter;
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this.selectedEvent = row;
        this.showModal = true;
        this.activateEventsTab();
    }

    handleCloseModal() {
        this.showModal = false;
        this.selectedEvent = {};
    }

    renderedCallback() {
        if (this.calendarInitialized) return;
        this.calendarInitialized = true;
        Promise.all([
            loadScript(this, FULLCALENDAR + '/lib/main.js'),
            loadStyle(this, FULLCALENDAR + '/lib/main.css')
        ])
        .then(() => {
            this.fullCalendarJsLoaded = true;
            this.initializeCalendar();
        })
        .catch(error => {
            this.showToast('Error', 'Failed to load FullCalendar: ' + this.getErrorMessage(error), 'error');
            console.error('FullCalendar load error:', error);
        });
    }

    initializeCalendar() {
        if (!this.fullCalendarJsLoaded) return;
        const calendarEl = this.template.querySelector('.calendar-container');
        if (!calendarEl) return;

        this.calendar = new FullCalendar.Calendar(calendarEl, {
            initialView: window.innerWidth < 768 ? 'listWeek' : this.currentView,
            aspectRatio: 1.35,
            contentHeight: 'auto',
            headerToolbar: {
                left: 'prev,next today',
                center: 'title',
                right: 'dayGridMonth,timeGridWeek,timeGridDay,listWeek'
            },
            views: {
                listWeek: {
                    type: 'list',
                    duration: { weeks: 1 },
                    buttonText: 'List'
                },
                dayGridMonth: {
                    fixedWeekCount: false,
                    dayHeaderFormat: { weekday: 'short' }
                }
            },
            events: (info, successCallback, failureCallback) => {
                this.loadCalendarEvents(info.start, info.end, successCallback, failureCallback);
            },
            eventClick: (info) => {
                this.handleCalendarEventClick(info.event);
            },
            eventDidMount: (info) => {
                this.styleEvent(info);
            },
            nowIndicator: true,
            dayMaxEvents: true,
            navLinks: true,
            editable: false,
            selectable: false,
            eventDisplay: 'block',
            eventContent: this.renderEventContent.bind(this),
            datesSet: (info) => {
                this.handleDatesChange(info);
            },
            viewDidMount: (info) => {
                this.currentView = info.view.type;
            },
            eventTimeFormat: {
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            },
            showNonCurrentDates: true
        });

        this.calendar.render();
    }

    loadCalendarEvents(start, end, successCallback, failureCallback) {
        this.isLoading = true;
        this.hasNoEvents = false;
        
        getEventsDynamic({
            mode: 'Range',
            startDate: start.toISOString(),
            endDate: end.toISOString()
        })
        .then(result => {
            const calendarEvents = this.transformEventsToCalendarFormat(result);
            this.allCalendarEvents = calendarEvents;
            this.hasNoEvents = calendarEvents.length === 0;
            successCallback(calendarEvents);
            this.isLoading = false;
        })
        .catch(error => {
            this.hasNoEvents = true;
            this.showToast('Error', 'Failed to load events: ' + this.getErrorMessage(error), 'error');
            failureCallback(error);
            this.isLoading = false;
        });
    }

    transformEventsToCalendarFormat(events) {
        return events.map(evt => {
            const startDate = evt.Start_Date_and_Time__c ? new Date(evt.Start_Date_and_Time__c) : new Date(evt.CreatedDate);
            const endDate = evt.End_Date_and_Time__c ? new Date(evt.End_Date_and_Time__c) : null;
            
            const isAllDay = this.isAllDayEvent(startDate, endDate);
            return {
                id: evt.Id,
               // title: evt.Title__c || evt.Name,
               title: evt.Name,
                start: startDate,
                end: endDate,
                allDay: isAllDay,
                backgroundColor: '#6BCABA !important',
                borderColor: '#6BCABA !important',
                textColor: '#ffffff',
                extendedProps: {
                    description: evt.Description__c,
                    location: evt.Location__c,
                    externalLink: evt.External_Link__c,
                    socialMediaLink: evt.Social_Media_Link__c,
                    virtualTourLink: evt.Virtual_Tour_Link__c,
                    startDateTime: evt.Start_Date_and_Time__c,
                    endDateTime: evt.End_Date_and_Time__c,
                    createdDate: evt.CreatedDate,
                    type: evt.Type__c
                }
            };
        });
    }

    getEventColor(eventType) {
        const colorMap = {
            'Open House': '#0070d2',
            'Annual Awards': '#4b0082',
            'Training Academy': '#008080',
            'Broker Training': '#ff8c00',
            'Broker Meeting': '#9370db',
            'Webinar': '#32cd32',
            'Presentation': '#ff4500',
            'Seminars': '#20b2aa',
            'Launch': '#da70d6',
            'Exhibition': '#ff6347',
            'Kiosks': '#4682b4',
            'Road Show': '#9acd32'
        };
        return colorMap[eventType] || '#808080';
    }

    isAllDayEvent(startDate, endDate) {
        if (!startDate || !endDate) return false;
        
        const duration = endDate - startDate;
        const hours = duration / (1000 * 60 * 60);
        
        const startsAtMidnight = startDate.getHours() === 0 && startDate.getMinutes() === 0;
        const endsAtMidnight = endDate.getHours() === 0 && endDate.getMinutes() === 0;
        
        return (hours >= 24 && hours < 48) || (startsAtMidnight && endsAtMidnight);
    }

    renderEventContent(eventInfo) {
        const event = eventInfo.event;
        const isListView = eventInfo.view.type === 'listWeek';
        const isMonthView = eventInfo.view.type === 'dayGridMonth';

        if (isListView) {
            return {
                html: `
                    <div class="fc-list-event-content">
                        <div class="fc-list-event-title">${this.truncateText(event.title, 40)}</div>
                        <div class="fc-list-event-time">${this.formatEventTime(event)}</div>
                    </div>
                `
            };
        }
        if (isMonthView) {
            return {
                html: `
                    <div class="fc-event-main">
                        <div class="fc-event-title">${this.truncateText(event.title, 20)}</div>
                    </div>
                `
            };
        }
        return {
            html: `
                <div class="fc-event-main">
                    <div class="fc-event-title">${this.truncateText(event.title, 30)}</div>
                    ${!event.allDay ? `<div class="fc-event-time">${this.formatCalendarTime(event.start)}</div>` : ''}
                </div>
            `
        };
    }

    styleEvent(info) {
        const event = info.event;
        const element = info.el;
        if (event.allDay) {
            element.classList.add('fc-event-allday');
        }
        element.title = this.getEventTooltip(event);
    }

getEventTooltip(event) {
    let tooltip = event.title;

    if (event.extendedProps.description) {
        tooltip += `\nDescription: ${event.extendedProps.description}`;
    }

    if (event.start) tooltip += `\nStart: ${event.start.toLocaleString()}`;
    if (event.end) tooltip += `\nEnd: ${event.end.toLocaleString()}`;
    if (event.extendedProps.location) tooltip += `\nLocation: ${event.extendedProps.location}`;
    if (event.extendedProps.type) tooltip += `\nType: ${event.extendedProps.type}`;

    return tooltip;
}


    formatEventTime(event) {
        if (event.allDay) return 'All Day';
        const startTime = this.formatCalendarTime(event.start);
        let endTime = '';
        if (event.end) {
            endTime = this.formatCalendarTime(event.end);
        }
        return endTime ? `${startTime} - ${endTime}` : startTime;
    }

    formatCalendarTime(date) {
        return date.toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true 
        });
    }

    handleCalendarEventClick(event) {
        const eventDetail = event.extendedProps;
        let message = '';

        if (event.start) message += `Start: ${event.start.toLocaleString()}\n`;
        if (event.end) message += `End: ${event.end.toLocaleString()}\n`;
        if (eventDetail.location) message += `Location: ${eventDetail.location}\n`;
        if (eventDetail.description) message += `Description: ${eventDetail.description}\n`;
        if (eventDetail.type) message += `Type: ${eventDetail.type}\n`;

        const links = [];
        if (eventDetail.externalLink) links.push(`External Link: ${eventDetail.externalLink}`);
        if (eventDetail.socialMediaLink) links.push(`Social Media: ${eventDetail.socialMediaLink}`);
        if (eventDetail.virtualTourLink) links.push(`Virtual Tour: ${eventDetail.virtualTourLink}`);

        if (links.length > 0) message += `\nLinks:\n${links.join('\n')}`;

        this.showEventDetails(event.title, message, eventDetail);
        this.activateEventsTab();
    }

    showEventDetails(title, message, eventDetail) {
        this.dispatchEvent(new CustomEvent('eventclick', {
            detail: {
                title,
                message,
                eventDetail,
                showModal: true
            }
        }));
        this.showToast(title, message, 'info');
    }

    handleDatesChange(info) {
        clearTimeout(this.debounceTimer);
    }

    handleResize() {
        if (this.calendar) this.calendar.updateSize();
    }

    showToast(title, message, variant) {
        const maxLength = 500;
        const truncatedMessage = message.length > maxLength ?
            message.substring(0, maxLength) + '...' : message;

        this.dispatchEvent(new ShowToastEvent({
            title,
            message: truncatedMessage,
            variant,
            mode: variant === 'info' ? 'sticky' : 'dismissible'
        }));
    }

    getErrorMessage(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Unknown error occurred';
    }

    disconnectedCallback() {
        if (this.calendar) this.calendar.destroy();
        clearTimeout(this.debounceTimer);
        window.removeEventListener('resize', this.handleResize);
    }
}