import { LightningElement, track } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import leafletResource from '@salesforce/resourceUrl/leaflet1';
import getAddressFromLatLong from '@salesforce/apex/GeoapifyLocationController.getAddressFromLatLong';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchLocation from '@salesforce/apex/GeoapifyLocationController.searchLocation';


export default class GeoLocationPicker extends LightningElement {

    map;
    marker;
    leafletLoaded = false;

    @track locationDetails;
    @track isLoading = false;

   searchText = '';
   searchResults = [];

    handleSearchChange(event) {
    this.searchText = event.target.value;

    if (!this.searchText || this.searchText.length < 3) {
        this.searchResults = [];
        return;
    }

    searchLocation({ searchText: this.searchText })
        .then(result => {
            this.searchResults = result;
        })
        .catch(error => {
            console.error(error);
        });
}

handleLocationSelect(event) {
    const latitude = parseFloat(event.currentTarget.dataset.lat);
    const longitude = parseFloat(event.currentTarget.dataset.lon);

    this.searchResults = [];
    this.searchText = event.currentTarget.innerText;

    this.setMarker(latitude, longitude);
    this.getAddress(latitude, longitude);
}

    renderedCallback() {
        if (this.leafletLoaded) {
            return;
        }

        this.leafletLoaded = true;

        Promise.all([
            loadStyle(this, leafletResource + '/dist/leaflet.css'),
            loadScript(this, leafletResource + '/dist/leaflet.js')
        ])
        .then(() => {
            alert('HII **');
            this.initializeMap();
        })
        .catch(error => {
            this.showToast('Error', 'Failed to load map library', 'error');
            console.error('*** Script ***'+ error);
        });
    }

    initializeMap() {
        const mapElement = this.template.querySelector('.map-container');

        // Default location: Dubai
       this.map = window.L.map(mapElement).setView([25.2048, 55.2708], 12);

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19
        }).addTo(this.map);

        this.map.on('click', (event) => {
            const latitude = event.latlng.lat;
            const longitude = event.latlng.lng;

            this.setMarker(latitude, longitude);
            this.getAddress(latitude, longitude);
        });
    }

    setMarker(latitude, longitude) {
        if (this.marker) {
            this.map.removeLayer(this.marker);
        }

        this.marker = L.marker([latitude, longitude]).addTo(this.map);
        this.map.setView([latitude, longitude], 15);
    }

    getAddress(latitude, longitude) {
        this.isLoading = true;

        getAddressFromLatLong({
            latitude: latitude,
            longitude: longitude
        })
        .then(result => {
            this.locationDetails = result;
        })
        .catch(error => {
            console.error(error);
            this.showToast(
                'Error',
                error.body ? error.body.message : 'Failed to get address',
                'error'
            );
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}