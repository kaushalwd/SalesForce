import { LightningElement, api } from 'lwc';

const FEATURES = [
    { id: 'f1', icon: '🏗️', title: 'Plot Management', desc: 'View and manage all your plots across Modon communities in one place.' },
    { id: 'f2', icon: '📋', title: 'Service Requests', desc: 'Raise and track development control service requests end to end.' },
    { id: 'f3', icon: '📄', title: 'Document Library', desc: 'Upload, store and retrieve approvals, drawings and certificates securely.' },
    { id: 'f4', icon: '💳', title: 'Online Payments', desc: 'Pay fees in AED and download receipts instantly, anytime.' },
    { id: 'f5', icon: '🔔', title: 'Real-Time Notifications', desc: 'Stay informed with live status updates on every submission.' },
    { id: 'f6', icon: '👥', title: 'User Management', desc: 'Manage owners, service providers and delegated access with ease.' }
];

const SERVICES = [
    {
        id: 's1', heading: 'SPA & Ownership',
        items: [
            { id: 's1a', name: 'Transfer of Land' },
            { id: 's1b', name: 'Subdivision' },
            { id: 's1c', name: 'Amalgamation' },
            { id: 's1d', name: 'Land Use Change' }
        ]
    },
    {
        id: 's2', heading: 'Building Design',
        items: [
            { id: 's2a', name: 'Concept Design Review' },
            { id: 's2b', name: 'Height Increase' },
            { id: 's2c', name: 'Additional GFA' },
            { id: 's2d', name: 'Internal Modification' }
        ]
    },
    {
        id: 's3', heading: 'Site Works',
        items: [
            { id: 's3a', name: 'Hoarding' },
            { id: 's3b', name: 'Enabling Works' },
            { id: 's3c', name: 'Soil Surveys' },
            { id: 's3d', name: 'Physical Handover' }
        ]
    },
    {
        id: 's4', heading: 'NOCs',
        items: [
            { id: 's4a', name: 'Modon Building Permit NOC' },
            { id: 's4b', name: 'GFA Verification' },
            { id: 's4c', name: 'Elevation & Perspectives' },
            { id: 's4d', name: 'Authorization' }
        ]
    },
    {
        id: 's5', heading: 'Planning',
        items: [
            { id: 's5a', name: 'Master Planning' },
            { id: 's5b', name: 'Traffic & Car Parking' },
            { id: 's5c', name: 'Landscape' }
        ]
    },
    {
        id: 's6', heading: 'Others',
        items: [
            { id: 's6a', name: 'Power of Attorney' },
            { id: 's6b', name: 'Issuance of Site Plan' },
            { id: 's6c', name: 'Temporary Allocation' },
            { id: 's6d', name: 'Change Request' }
        ]
    }
];

export default class PortalLanding extends LightningElement {
    @api loginUrl = '#';
    @api registerOwnerUrl = '#';
    @api registerSpUrl = '#';

    features = FEATURES;
    services = SERVICES;
}