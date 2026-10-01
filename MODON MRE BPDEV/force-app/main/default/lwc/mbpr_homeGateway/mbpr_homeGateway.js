import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import basePath from '@salesforce/community/basePath';
import USER_ID from '@salesforce/user/Id';
import JSZIP from '@salesforce/resourceUrl/JSZip';
import ASPIRE_BADGES from '@salesforce/resourceUrl/AspireBadges';
import PROJECT_LOGOS from '@salesforce/resourceUrl/MBPR_ProjectLogos';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import THEME_ALIGNMENT from '@salesforce/resourceUrl/mbprThemeAlignment';

import getCurrentUserInfo from '@salesforce/apex/MBP_utilityclass.getCurrentUserInfo';
import getBrokerDashboardData from '@salesforce/apex/MBP_BrokerClassificationProgram.getBrokerDashboardData';
import getTotalSalesAmount from '@salesforce/apex/MBP_manageDashboardcontroller.getTotalSalesAmount';
import getUnitRecords from '@salesforce/apex/MBP_ManagePropertiesController.getRecords';
import getFieldSetColumns from '@salesforce/apex/MBP_PropertiesFieldSetController.getFieldSetColumns';
import getRecordsWithImages from '@salesforce/apex/MBP_ManagePropertiesController.getRecordsWithImages';
import getDocumentsAndFilesByProject from '@salesforce/apex/MBP_ManagePropertiesController.getDocumentsAndFilesByProject';
import getFileContentAsBase64 from '@salesforce/apex/MBP_ManagePropertiesController.getFileContentAsBase64';
import getFilteredLeads from '@salesforce/apex/MBP_BrokerLeadcontroller.getFilteredLeads';
import shouldShowBrokerContent from '@salesforce/apex/MBP_BrokerAgencyInformationController.shouldShowBrokerContent';
import getEditableAccount from '@salesforce/apex/MBP_BrokerAgencyInformationController.getEditableAccount';
import findRegistrationWithReviewComment from '@salesforce/apex/Draftstagecontroller.findRegistrationWithReviewComment';
import getEOIRecords from '@salesforce/apex/MBP_ExpressionOfInterestsController.getEOIRecords';
import MBP_EnableEoi from '@salesforce/label/c.MBP_EnableEoi';
import MBP_EnableNewEoi from '@salesforce/label/c.MBP_EnableNewEoi';
import MARKETING_BROCHURES_LINK from '@salesforce/label/c.MBPR_Marketing_Brochures_Link';
import MARKETING_GALLERY_LINK from '@salesforce/label/c.MBPR_Marketing_Gallery_Link';
import MARKETING_FLOOR_PLANS_LINK from '@salesforce/label/c.MBPR_Marketing_Floor_Plans_Link';
import MARKETING_LINKS_PROJECT from '@salesforce/label/c.MBPR_Marketing_Links_Project';
import MADHMOUN_PERMITS_LINK
    from '@salesforce/label/c.MBPR_Madhmoun_Permits_Link';
    import FAQ_LINK
    from '@salesforce/label/c.MBPR_FAQ_Link';
    import BROCHURE_LINK
    from '@salesforce/label/c.MBPR_Brochure_Link';
const TIER_SEQUENCE = ['Standard', 'Principal', 'Maestro', 'Ambassador'];
const ZIP_SIZE_THRESHOLD = 15 * 1024 * 1024; 

const FALLBACK_TIER_THRESHOLDS = {
    Standard: 0,
    Principal: 60000000,
    Maestro: 200000000,
    Ambassador: 500000000
};

const TIER_BADGE_IMAGES = {
    Principal: `${ASPIRE_BADGES}/Principal.png`,
    Maestro: `${ASPIRE_BADGES}/Maestro.png`,
    Ambassador: `${ASPIRE_BADGES}/Ambassador.png`
};

const TIER_SHORT_LABELS = {
    Standard: 'ST',
    Principal: 'PR',
    Maestro: 'MA',
    Ambassador: 'AM'
};

/* Aspire programme membership. Standard is the floor of the ladder, not a
   tier of the programme (business, 2026-09-08), so it is deliberately absent.
   Apex also returns 'Standard' for an agency with no classification at all
   and on every error path, so those hide through the same check. */
const ASPIRE_TIERS = ['Principal', 'Maestro', 'Ambassador'];

const UNIT_FIELDS = [
    'CreatedDate',
    'Status__c',
    'BasePrice__c',
    'TotalPrice__c',
    'Number_of_Bedrooms__c',
    'Phase__r.Name',
    'Project_Name__c',
    'UnitClassification__c',
    'Typology__c',
    'View__c',
    'TotalArea__c',
    'PlotAreasqm__c',
    'GrossFloorAreaGFA__c',
    'FloorNumber__c',
    'floor__c',
    'Masterplan_URL__c',
    'Masterplan_Status__c',
    'DPG_Unit_Image_URL__c'
];

// Real signal, not decoration: MBP_manageDashboardcontroller already groups
// production sales data by Unit__r.UnitClassification__c, so this is a
// genuine field on the record, not a guess derived from bedroom count.
//
// Each icon is one hand-built line-art glyph on a shared 24x24 grid, drawn
// as closed building silhouettes (roofline + walls + base) so the whole
// family reads consistently at a glance. Every icon is a single <path> -
// multiple "M" subpaths let one path element draw disconnected shapes
// (walls, windows, doors) so the template can stay one generic <svg><path>
// per card instead of switching between markup per type.
const UNIT_TYPE_ICONS = {
    villa: {
        label: 'Villa',
        path: 'M3 12 L12 4 L21 12 M5.5 11 L18.5 11 L18.5 20 L5.5 20 L5.5 11 M10.5 20 L10.5 14.5 L13.5 14.5 L13.5 20'
    },
    townhouse: {
        label: 'Townhouse',
        path: 'M3 11 L7.5 5 L12 11 M12 11 L16.5 5 L21 11 M4.5 11 L19.5 11 L19.5 20 L4.5 20 L4.5 11 M12 11 L12 20 M7 20 L7 16 L9 16 L9 20 M15 20 L15 16 L17 16 L17 20'
    },
    apartment: {
        label: 'Apartment',
        path: 'M6 5 L18 5 L18 20 L6 20 L6 5 M8.5 8 L11 8 L11 10.2 L8.5 10.2 Z M13 8 L15.5 8 L15.5 10.2 L13 10.2 Z M8.5 12.4 L11 12.4 L11 14.6 L8.5 14.6 Z M13 12.4 L15.5 12.4 L15.5 14.6 L13 14.6 Z M8.5 16.8 L11 16.8 L11 19 L8.5 19 Z M13 16.8 L15.5 16.8 L15.5 19 L13 19 Z'
    },
    penthouse: {
        label: 'Penthouse',
        path: 'M5 10 L19 10 L19 20 L5 20 L5 10 M8 10 L8 5 L16 5 L16 10 M9 5 L9 3.2 M12 5 L12 3.2 M15 5 L15 3.2 M9 3.2 L15 3.2'
    },
    studio: {
        label: 'Studio',
        path: 'M6 9 L18 9 L18 20 L6 20 L6 9 M9 12 L15 12 L15 16 L9 16 Z M11 20 L11 17.5 L13 17.5 L13 20'
    },
    duplex: {
        label: 'Duplex',
        path: 'M5 6 L19 6 L19 20 L5 20 L5 6 M5 13 L19 13 M8 20 L8 17 L10 17 L10 20 M14 20 L14 17 L16 17 L16 20 M8.5 8.5 L10.5 8.5 L10.5 10.5 L8.5 10.5 Z M13.5 8.5 L15.5 8.5 L15.5 10.5 L13.5 10.5 Z'
    },
    plot: {
        label: 'Plot',
        path: 'M4 8 L19 6 L20 18 L5 19 Z M12 11 L12 15 M10 13 L14 13'
    }
};

const UNIT_TYPE_ICON_FALLBACK = {
    path: 'M6 8 L18 8 L18 20 L6 20 L6 8 M9 11 L11 11 L11 13.2 L9 13.2 Z M13 11 L15 11 L15 13.2 L13 13.2 Z'
};

const SALES_PERIODS = [
    { value: 'All Time', label: 'All Time' },
    { value: 'Last 12 Months', label: 'Last 12 Months' },
    { value: 'Current FY', label: 'Current FY' },
    { value: 'Previous FY', label: 'Previous FY' },
    { value: 'Current Year', label: 'This Year' },
    { value: 'This Month', label: 'This Month' },
    { value: 'This Week', label: 'This Week' }
];

const SALES_COUNT_DURATION_MS = 700;
/* BP-033: the home Leads card follows the Manage Leads tab default (All Time).
   getFilteredLeads only resolves FY / calendar names itself, so the period
   travels as explicit dates - same definition as the workspaces. */
const LEADS_PERIOD = 'All Time';
function resolveLeadsPeriodRange() {
    const today = new Date();
    const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
    const iso = (d) =>
        `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    return { startDate: '1900-01-01', endDate: iso(tomorrow) };
}
const UNIT_PAGE_SIZE = 6;

const UNIT_SORT_OPTIONS = [
    { value: 'newest', label: 'Newest' },
    { value: 'priceHigh', label: 'Price high to low' },
    { value: 'priceLow', label: 'Price low to high' },
    { value: 'bedroomsHigh', label: 'Bedrooms high to low' }
];

const MARKETING_FIELDS = ['Id', 'Name'];

const MARKETING_SECTION_CONFIG = [
    { 
        key: 'Brochures', 
        label: 'Factsheet', 
        emptyLabel: 'No factsheet available' 
    },
    { 
        key: 'gallery', 
        label: 'ADIB approval link', 
        emptyLabel: 'No ADIB approval link available' 
    },
    { 
        key: 'floorPlans', 
        label: 'Payment plan', 
        emptyLabel: 'No payment plan available' 
    },
    { 
        key: 'madhmounPermits', 
        label: 'Madhmoun Permits', 
        emptyLabel: 'No Madhmoun Permits available' 
    },
    {
    key: 'brochure',
    label: 'Brochure',
    emptyLabel: 'No Brochure available'
},
    { 
        key: 'faqs', 
        label: 'FAQs', 
        emptyLabel: 'No FAQs available' 
    }
];

/* BP-077 (13 Sep 2026): each Marketing library section is one "Open in Dropbox"
   button instead of a file list. Links live in custom labels, keyed by the section
   keys above, and apply only to the project named in MBPR_Marketing_Links_Project;
   every other project gets the buttons disabled. */
const MARKETING_SECTION_LINKS = {
    Brochures: MARKETING_BROCHURES_LINK,
    gallery: MARKETING_GALLERY_LINK,
    floorPlans: MARKETING_FLOOR_PLANS_LINK,
    madhmounPermits: MADHMOUN_PERMITS_LINK,
     brochure: BROCHURE_LINK,
    faqs: FAQ_LINK
};

// BP-077: the per-project file list is no longer loaded. Set to true (and restore
// the commented markup in the section cards) to bring the file list back.
const MARKETING_FILE_LIST_ENABLED = false;

function marketingLinkFor(sectionKey) {
    const value = String(MARKETING_SECTION_LINKS[sectionKey] || '').trim();
    return /^https:\/\/\S+$/i.test(value) ? value : '';
}

const MONTH_NAMES = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
];
const MONTH_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

const THEME_STORAGE_KEY = 'modon-broker-revamp-theme';

/* Windows renders light scrollbars whatever the page colours, so dark theme
   opts into this thumb/track pair. Absent from the light map, so the CSS
   falls back to `auto` and light keeps native scrollbars. */
const DARK_SCROLLBAR_COLOR = 'rgba(255, 255, 255, 0.28) transparent';

const THEME_TOKENS = {
    light: {
        /* The photographic background was replaced with a vertical gradient, so
           the page keeps a light source instead of a flat slab.
           --mbpr-page-bg must stay a solid colour: syncDocumentCanvas writes
           it into document.body.style.backgroundColor for the Windows bottom
           hairline, where a gradient is silently rejected. It carries the
           gradient's bottom stop, since that hairline sits at the bottom. The
           gradient lives in its own token, read only by.mbpr-page-bg. */
        '--mbpr-page-bg': '#e7e3dc',
        '--mbpr-page-gradient': 'linear-gradient(180deg, #f5f3ef 0%, #e7e3dc 100%)',
        '--mbpr-paper': '#f0ede9',
        '--mbpr-paper-strong': '#e8e2da',
        '--mbpr-surface': '#ffffff',
        '--mbpr-surface-solid': '#ffffff',
        '--mbpr-surface-raised': '#ffffff',
        '--mbpr-surface-soft': '#f8f6f2',
        '--mbpr-control-bg': '#f7f5f1',
        '--mbpr-row-bg': '#f8f6f2',
        '--mbpr-row-bg-hover': '#f1ece4',
        '--mbpr-input-bg': '#f7f5f1',
        '--mbpr-input-border': 'rgba(0, 0, 0, 0.2)',
        '--mbpr-input-disabled-bg': '#f3f0ea',
        '--mbpr-ink': '#0f0f0f',
        '--mbpr-ink-soft': '#2e2e2e',
        '--mbpr-ink-faint': '#4a4a4a',
        '--mbpr-ink-line': 'rgba(0, 0, 0, 0.14)',
        '--mbpr-ink-line-strong': 'rgba(0, 0, 0, 0.24)',
        '--mbpr-inverse-ink': '#ffffff',
        '--mbpr-on-dark': '#ffffff',
        '--mbpr-overlay': 'rgba(0, 0, 0, 0.28)',
        '--mbpr-overlay-strong': 'rgba(0, 0, 0, 0.58)',
        /* The overlay only existed to soften the photograph, and any tint would
           wash the gradient back to a flat fill. The layer is kept so the
           markup and stacking order are untouched. */
        '--mbpr-background-overlay': 'transparent',
        '--mbpr-bar': 'rgba(255, 255, 255, 0.96)',
        '--mbpr-bar-border': 'rgba(0, 0, 0, 0.15)',
        '--mbpr-tooltip-bg': '#101112',
        '--mbpr-tooltip-border': 'rgba(255, 255, 255, 0.08)',
        '--mbpr-tooltip-ink': '#ffffff',
        '--mbpr-skeleton-start': 'rgba(0, 0, 0, 0.055)',
        '--mbpr-skeleton-mid': 'rgba(11, 119, 114, 0.11)',
        '--mbpr-shadow-sm': '0 1px 2px rgba(16, 17, 18, 0.06)',
        '--mbpr-shadow-md': '0 16px 32px rgba(16, 17, 18, 0.08)',
        '--mbpr-shadow-lg': '0 28px 64px rgba(16, 17, 18, 0.22)',
        '--mbpr-shadow-elevated': '0 22px 54px rgba(16, 17, 18, 0.16)',
        '--mbpr-home-card-surface': 'linear-gradient(145deg, #ffffff 0%, #ffffff 50%, #f7f3ec 100%)',
        '--mbpr-home-card-border': 'rgba(16, 17, 18, 0.18)',
        '--mbpr-home-card-edge': 'rgba(16, 17, 18, 0.28)',
        '--mbpr-home-card-highlight': 'rgba(255, 255, 255, 0.86)',
        '--mbpr-home-card-lowlight': 'rgba(16, 17, 18, 0.06)',
        '--mbpr-home-card-sheen': 'rgba(255, 255, 255, 0.72)',
        '--mbpr-home-card-corner-glow': 'rgba(11, 119, 114, 0.08)',
        '--mbpr-home-card-foot-shade': 'rgba(16, 17, 18, 0.075)',
        '--mbpr-home-card-shadow': '0 1px 0 var(--mbpr-home-card-highlight) inset, 0 -1px 0 var(--mbpr-home-card-lowlight) inset, 0 10px 18px -16px rgba(16, 17, 18, 0.72), 0 28px 58px -26px rgba(16, 17, 18, 0.42), 0 70px 120px -48px rgba(16, 17, 18, 0.32)',
        '--mbpr-home-card-shadow-hover': '0 1px 0 var(--mbpr-home-card-highlight) inset, 0 -1px 0 var(--mbpr-home-card-lowlight) inset, 0 16px 26px -18px rgba(16, 17, 18, 0.78), 0 42px 86px -30px rgba(16, 17, 18, 0.5), 0 92px 150px -52px rgba(16, 17, 18, 0.36)',
        '--mbpr-accent': '#0b7772',
        '--mbpr-accent-ink': '#06504c',
        '--mbpr-accent-soft': 'rgba(11, 119, 114, 0.1)',
        '--mbpr-accent-line': 'rgba(11, 119, 114, 0.28)',
        '--mbpr-gold': '#b69a68',
        '--mbpr-gold-ink': '#7a6540',
        '--mbpr-gold-soft': 'rgba(182, 154, 104, 0.16)',
        '--mbpr-gold-line': 'rgba(182, 154, 104, 0.28)',
        '--mbpr-icon-gray': '#7f7f80',
        '--mbpr-success': '#176443',
        '--mbpr-success-soft': 'rgba(32, 131, 92, 0.1)',
        '--mbpr-success-line': 'rgba(32, 131, 92, 0.24)',
        '--mbpr-warning': '#7a4d00',
        '--mbpr-warning-soft': 'rgba(177, 111, 0, 0.12)',
        '--mbpr-warning-line': 'rgba(177, 111, 0, 0.24)',
        '--mbpr-error': '#8b2f2f',
        '--mbpr-error-soft': 'rgba(139, 47, 47, 0.1)',
        '--mbpr-error-line': 'rgba(139, 47, 47, 0.22)',
        /* Client-approved data-viz palette: navy, gold, slate blue, mauve, gray,
           identical in both themes. Slots 1-5 are the categorical sequence,
           largest category first. Gray is both the fifth slot and the
           overflow bucket, so slots 6-10 repeat it and consumers fold
           everything past the four named hues into one gray; two adjacent
           grays must never appear. No value may be lightened, darkened or
           substituted, and no other colour may appear in a chart. */
        '--mbpr-chart-1': '#1F3A5F',
        '--mbpr-chart-2': '#B5893E',
        '--mbpr-chart-3': '#4C6B8A',
        '--mbpr-chart-4': '#7A6E8C',
        '--mbpr-chart-5': '#74787A',
        '--mbpr-chart-6': '#74787A',
        '--mbpr-chart-7': '#74787A',
        '--mbpr-chart-8': '#74787A',
        '--mbpr-chart-9': '#74787A',
        '--mbpr-chart-10': '#74787A',
        /* Status tones: active/new navy, success gold, pending slate, inactive
           gray. Mauve carries no status meaning, so free tones like 'info'
           borrow it. */
        '--mbpr-viz-active': '#1F3A5F',
        '--mbpr-viz-success': '#B5893E',
        '--mbpr-viz-pending': '#4C6B8A',
        '--mbpr-viz-neutral': '#74787A',
        /* BP-065: the marketing library's project cards. Every project mark is a flat WHITE wordmark,
           so the card has always been near-black to carry it. In light theme the card is white and the
           mark is inverted to black instead - one flat colour inverts cleanly to the other. The hover
           brightness is a token too, because 1.12 does nothing to a white card. */
        '--mbpr-project-card-bg': '#ffffff',
        '--mbpr-project-card-border': '1px solid rgba(16, 17, 18, 0.12)',
        '--mbpr-project-card-invert': '1',
        '--mbpr-project-card-hover': '0.97'
    },
    dark: {
        /* See the light block for why this must stay solid and carry the
           gradient's bottom stop. The dark card runs L*8.2 down to L*2.5, so
           a pure-black ground sat below the card's own floor and the lower
           half of every card melted into the page once the photo was gone.
           This gradient starts above the card at L*11.1 and ends below it at
           L*2.4. */
        '--mbpr-page-bg': '#08090b',
        '--mbpr-page-gradient': 'linear-gradient(180deg, #1a1e24 0%, #08090b 100%)',
        '--mbpr-scrollbar': DARK_SCROLLBAR_COLOR,
        '--mbpr-paper': '#000000',
        '--mbpr-paper-strong': '#111111',
        '--mbpr-surface': '#111111',
        '--mbpr-surface-solid': '#111111',
        '--mbpr-surface-raised': '#151515',
        '--mbpr-surface-soft': '#1a1a1a',
        '--mbpr-control-bg': '#1b1b1b',
        '--mbpr-row-bg': '#171717',
        '--mbpr-row-bg-hover': '#222222',
        '--mbpr-input-bg': '#1b1b1b',
        '--mbpr-input-border': 'rgba(255, 255, 255, 0.16)',
        '--mbpr-input-disabled-bg': '#161616',
        '--mbpr-ink': '#fafafa',
        '--mbpr-ink-soft': '#a3a3a3',
        '--mbpr-ink-faint': '#8a8a8a',
        '--mbpr-ink-line': 'rgba(255, 255, 255, 0.13)',
        '--mbpr-ink-line-strong': 'rgba(255, 255, 255, 0.22)',
        '--mbpr-inverse-ink': '#111111',
        '--mbpr-on-dark': '#ffffff',
        '--mbpr-overlay': 'rgba(0, 0, 0, 0.58)',
        '--mbpr-overlay-strong': 'rgba(0, 0, 0, 0.68)',
        '--mbpr-background-overlay': 'transparent',
        '--mbpr-bar': '#111111',
        '--mbpr-bar-border': 'rgba(255, 255, 255, 0.12)',
        '--mbpr-tooltip-bg': '#fafafa',
        '--mbpr-tooltip-border': 'rgba(0, 0, 0, 0.1)',
        '--mbpr-tooltip-ink': '#111111',
        '--mbpr-skeleton-start': 'rgba(255, 255, 255, 0.055)',
        '--mbpr-skeleton-mid': 'rgba(255, 255, 255, 0.11)',
        '--mbpr-shadow-sm': '0 1px 2px rgba(0, 0, 0, 0.36)',
        '--mbpr-shadow-md': '0 16px 32px rgba(0, 0, 0, 0.42)',
        '--mbpr-shadow-lg': '0 28px 64px rgba(0, 0, 0, 0.58)',
        '--mbpr-shadow-elevated': '0 22px 54px rgba(0, 0, 0, 0.48)',
        '--mbpr-home-card-surface': 'linear-gradient(145deg, #181818 0%, #111111 54%, #090909 100%)',
        '--mbpr-home-card-border': 'rgba(255, 255, 255, 0.2)',
        '--mbpr-home-card-edge': 'rgba(255, 255, 255, 0.28)',
        '--mbpr-home-card-highlight': 'rgba(255, 255, 255, 0.12)',
        '--mbpr-home-card-lowlight': 'rgba(0, 0, 0, 0.36)',
        '--mbpr-home-card-sheen': 'rgba(255, 255, 255, 0.1)',
        '--mbpr-home-card-corner-glow': 'rgba(15, 159, 152, 0.12)',
        '--mbpr-home-card-foot-shade': 'rgba(0, 0, 0, 0.32)',
        '--mbpr-home-card-shadow': '0 1px 0 var(--mbpr-home-card-highlight) inset, 0 -1px 0 var(--mbpr-home-card-lowlight) inset, 0 10px 18px -14px rgba(0, 0, 0, 0.82), 0 30px 64px -26px rgba(0, 0, 0, 0.78), 0 74px 128px -50px rgba(0, 0, 0, 0.62)',
        '--mbpr-home-card-shadow-hover': '0 1px 0 var(--mbpr-home-card-highlight) inset, 0 -1px 0 var(--mbpr-home-card-lowlight) inset, 0 16px 28px -16px rgba(0, 0, 0, 0.9), 0 46px 92px -32px rgba(0, 0, 0, 0.88), 0 98px 164px -54px rgba(0, 0, 0, 0.7)',
        '--mbpr-accent': '#0f9f98',
        '--mbpr-accent-ink': '#59d6ce',
        '--mbpr-accent-soft': 'rgba(15, 159, 152, 0.14)',
        '--mbpr-accent-line': 'rgba(15, 159, 152, 0.36)',
        '--mbpr-gold': '#d2b77e',
        '--mbpr-gold-ink': '#e7d3a8',
        '--mbpr-gold-soft': 'rgba(210, 183, 126, 0.16)',
        '--mbpr-gold-line': 'rgba(210, 183, 126, 0.32)',
        '--mbpr-icon-gray': '#a3a3a3',
        '--mbpr-success': '#4ade80',
        '--mbpr-success-soft': 'rgba(74, 222, 128, 0.12)',
        '--mbpr-success-line': 'rgba(74, 222, 128, 0.26)',
        '--mbpr-warning': '#fbbf24',
        '--mbpr-warning-soft': 'rgba(251, 191, 36, 0.14)',
        '--mbpr-warning-line': 'rgba(251, 191, 36, 0.28)',
        '--mbpr-error': '#f87171',
        '--mbpr-error-soft': 'rgba(248, 113, 113, 0.14)',
        '--mbpr-error-line': 'rgba(248, 113, 113, 0.28)',
        /* Repeats the light values exactly; the client supplied one set for
           both themes. Measured on the dark card (#111111): gold 5.95, gray
           4.24, mauve 3.99 and slate 3.40 clear 3:1, but navy is 1.64 and is
           close to invisible. Navy is slot 1, so it carries the largest
           category, the active status and the trend bar. Reported to the
           business and left as supplied: the brief forbids altering any of
           the five values, so only the client can fix it. On light grounds
           everything clears 3:1 except gold on the page tone, at 2.94. */
        '--mbpr-chart-1': '#1F3A5F',
        '--mbpr-chart-2': '#B5893E',
        '--mbpr-chart-3': '#4C6B8A',
        '--mbpr-chart-4': '#7A6E8C',
        '--mbpr-chart-5': '#74787A',
        '--mbpr-chart-6': '#74787A',
        '--mbpr-chart-7': '#74787A',
        '--mbpr-chart-8': '#74787A',
        '--mbpr-chart-9': '#74787A',
        '--mbpr-chart-10': '#74787A',
        '--mbpr-viz-active': '#1F3A5F',
        '--mbpr-viz-success': '#B5893E',
        '--mbpr-viz-pending': '#4C6B8A',
        '--mbpr-viz-neutral': '#74787A',
        /* BP-065: dark theme keeps the card exactly as it shipped - same gradient, no border, the mark
           not inverted. These same values are the CSS fallbacks, so if a token ever fails to reach the
           card it renders as it does today rather than as anything new. */
        '--mbpr-project-card-bg': 'linear-gradient(155deg, #1a1d22, #101216 58%, #0b0d10)',
        '--mbpr-project-card-border': '0',
        '--mbpr-project-card-invert': '0',
        '--mbpr-project-card-hover': '1.12'
    }
};

/* The utility drawer's panels. Module scope so the open-request whitelist and
   the drawer's own chrome read the same definition - see
   handleOpenUtilityPanelRequest. */
const UTILITY_PANELS = {
    training: { eyebrow: '', title: 'Training', subtitle: '' },
    updates: { eyebrow: '', title: 'Updates', subtitle: '' },
    myagency: { eyebrow: '', title: 'My Agency', subtitle: '' },
    profile: { eyebrow: '', title: 'My Profile', subtitle: '' },
    help: { eyebrow: '', title: 'Help', subtitle: '' }
};

/* Fallback mark used when a project has no "Logo"-named Documents__c file of
   its own yet (see getRecordsWithImages()'s new logoUrl). Points at the
   Modon corporate mark in the existing static resource, so no project falls
   back to a bare colour block while its real logo is uploaded. */
const PROJECT_LOGO_FALLBACK_URL = `${PROJECT_LOGOS}/modon.svg`;

function coerceImageMime(url) {
    if (!url || !url.startsWith('data:')) return url;
    const [head, b64] = url.split(',', 2);
    if (head.includes('application/octet-stream')) {
        if (b64?.startsWith('/9j/')) return `data:image/jpeg;base64,${b64}`;
        if (b64?.startsWith('iVBORw0')) return `data:image/png;base64,${b64}`;
        if (b64?.startsWith('R0lGOD')) return `data:image/gif;base64,${b64}`;
    }
    return url;
}


/* Lead status 'Qualified' is shown as 'Converted To Opportunity'. Exact
   match on the whole trimmed value, because 'Lead Qualified' is a separate
   status that keeps its own name. Presentation only: the raw value still
   drives filtering and tones. */
function leadStatusLabel(status) {
    const raw = String(status || '').trim();
    return raw.toLowerCase() === 'qualified' ? 'Converted To Opportunity' : raw;
}

/* BP-037: a converted lead ('Qualified' is the org's only converted status)
   is left out of the home Leads card, the same rule Manage Leads applies
   (BP-023, mbpr_salesWorkspace.isConvertedLead), so the card and the tab
   always show the same number. */
function isConvertedLead(lead) {
    return String(lead?.Status || '').trim().toLowerCase() === 'qualified';
}

export default class MbprHomeGateway extends NavigationMixin(LightningElement) {
    // Routes to the rest of the portal, configurable from Experience Builder.
    @api dashboardUrl = '/dashboard?tab=dashboard';
    @api aspireUrl = '/dashboard?tab=aspire';
    @api propertiesUrl = '/properties?tab=units';
    @api salesUrl = '/Leads';
    @api commissionsUrl = '/commissions';
    @api marketingUpdatesUrl = '/Updates';
    @api agencyUrl = '/myagency';
    @api helpUrl = '/help';

    // Not read anywhere below - kept only so the existing Experience Builder page
    // placement (which has stored values against these names) doesn't break on deploy.
    // Safe to delete once that placement is re-saved without them.
    @api userName;
    @api agencyName;
    @api roleLabel;
    @api environmentLabel;
    @api productLabel;
    @api consoleLabel;
    @api audienceLabel;
    @api locationLabel;
    @api availableUnitsValue;
    @api availableUnitsDetail;
    @api openLeadsValue;
    @api openLeadsDetail;
    @api totalSalesValue;
    @api totalSalesDetail;
    @api eoiValue;
    @api eoiDetail;
    @api signOutUrl;

    // Identity
    agentName = '';
    accountName = '';
    accountId = '';
    contactId = '';
    brokerType = '';
    brokerContentAllowed = false;
    isUserLoading = true;
    dismissedQuickAccessTooltip = '';
    isAccountMenuOpen = false;
    activeUtilityPanel = null;
    activeCommandWorkspace = null;
    salesWorkspaceIntent = '';
    isDirectEoiFormOpen = false;
    directEoiFormToken = '';
    salesWorkspaceIntentToken = '';
    revenueView = 'dashboard';
    isDirectLeadFormOpen = false;
    directLeadFormToken = '';
    _directLeadFormLastFocusedElement = null;
    eoiRecordCount = 0;
    isEoiCountLoading = false;
    eoiCountError = false;
    complianceWrapper = null;
    agencyAccount = null;
    unitFieldSetColumns = [];
    _unitColumnsPromise = null;
    isGuidedOfferOpen = false;
    guidedOfferLeadId = '';
    guidedOfferUnitIds = [];
    guidedOfferLaunchToken = '';
    /* Dark is the portal default (business decision); a
       user's cached toggle choice still wins in connectedCallback. */
    theme = 'dark';
    _utilityLastFocusedElement = null;
    _workspaceLastFocusedElement = null;
    _salesWorkspaceRefreshTimer = null;
    _boundAccountMenuDocumentClick = null;
    _compactWorkspaceMedia = null;
    _desktopWorkspaceMedia = null;
    _screenshotBusy = false;
    /* Smart agent picker state. Plain fields: LWC already
       re-renders on primitive reassignment, and this component does not
       import the track decorator. */
    isSalesAgentPickerOpen = false;
    salesAgentSearch = '';
    salesAgentActiveIndex = 0;
    _salesAgentBlurTimeout;
    isDesktopWorkspaceViewport = false;
    _boundCompactWorkspaceMediaChange = null;
    isCompactWorkspaceViewport = false;

    // Aspire tier
    currentTier = 'Standard';
    nextTier = null;
    tierCurrentSales = 0;
    nextMilestone = null;
    tierBounds = { Standard: 0, Principal: null, Maestro: null, Ambassador: null };
    isTierLoading = true;
    tierError = false;
    _shouldAnimateTier = false;

    // Aspire status smart card (hero pill popover) - Owners and Agency Admins.
    isAspirePopoverOpen = false;
    _aspirePillReturnFocus = null;

    // Total sales
    totalSales = 0;
    displaySalesValue = 0;
    /* Same default period as the dashboard workspace, so the home card and the
       dashboard show the same number. Both call getTotalSalesAmount, so any
       difference between them was purely this default. BP-033: All Time. */
    salesPeriod = 'All Time';
    isSalesLoading = true;
    salesError = false;

    // Units
    unitRecords = [];
    isUnitsLoading = true;
    unitsError = false;
    propertiesWorkspaceTab = 'units';
    searchQuery = '';
    unitTypeFilter = 'all';
    unitProjectFilter = 'all';
    unitBedroomFilter = 'all';
    unitStatusFilter = 'all';
    unitSortMode = 'newest';
    unitFilterPanelOpen = false;
    pendingUnitTypeFilter = 'all';
    pendingUnitProjectFilter = 'all';
    pendingUnitBedroomFilter = 'all';
    pendingUnitStatusFilter = 'all';
    pendingUnitSortMode = 'newest';
    unitPage = 1;
    selectedWorkspaceUnitIds = [];
    workspaceSelectedUnitId = null;
    expandedUnitCardId = '';

    // Marketing library - uses existing project/file Apex from the legacy Properties module.
    marketingProjects = [];
    isMarketingLoading = false;
    marketingError = false;
    marketingSearchQuery = '';
    selectedMarketingProjectId = '';
    marketingDocuments = { floorPlans: [], gallery: [], Brochures: [] };
    isMarketingDocumentsLoading = false;
    marketingDocumentsError = false;
    selectedMarketingSections = [];
    marketingDownloadBusy = false;
    _zipPromise = null;

    // Leads - uses MBP_BrokerLeadcontroller role filtering:
    // Agent sees own leads; Owner / Agency Admin see agency leads.
    leadRecords = [];
    isLeadsLoading = true;
    leadsError = false;

    // Unit inspector modal

    connectedCallback() {
        loadStyle(this, THEME_ALIGNMENT).catch(() => {});
        this.theme = this.readCachedTheme() || 'dark';
        this.syncDocumentScrollbars(this.isDarkTheme);
        this.syncDocumentCanvas(true);
        this._boundAccountMenuDocumentClick = this.handleAccountMenuDocumentClick.bind(this);
        document.addEventListener('click', this._boundAccountMenuDocumentClick);
        this.setupCompactWorkspaceMedia();
        this.loadUser();
        this.loadTier();
        this.loadSales(this.salesPeriod);
        this.loadUnits();
        this.ensureMarketingLibraryLoaded();
        this.loadEoiCardCount();
        this.loadComplianceFacts();
        this.loadLeads();
    }

    disconnectedCallback() {
        this.syncDocumentScrollbars(false);
        this.syncDocumentCanvas(false);
        this.clearSalesWorkspaceRefresh();
        if (this._boundAccountMenuDocumentClick) {
            document.removeEventListener('click', this._boundAccountMenuDocumentClick);
        }
        this.teardownCompactWorkspaceMedia();
    }

    setupCompactWorkspaceMedia() {
        if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return;

        this._compactWorkspaceMedia = window.matchMedia(
            '(max-width: 767px), (min-width: 768px) and (max-width: 1199px) and (pointer: coarse), (min-width: 768px) and (max-width: 1199px) and (hover: none)'
        );
        this._boundCompactWorkspaceMediaChange = (event) => {
            this.isCompactWorkspaceViewport = Boolean(event.matches);
        };
        this.isCompactWorkspaceViewport = Boolean(this._compactWorkspaceMedia.matches);

        if (typeof this._compactWorkspaceMedia.addEventListener === 'function') {
            this._compactWorkspaceMedia.addEventListener('change', this._boundCompactWorkspaceMediaChange);
        } else if (typeof this._compactWorkspaceMedia.addListener === 'function') {
            this._compactWorkspaceMedia.addListener(this._boundCompactWorkspaceMediaChange);
        }

        /* Desktop band: the sales workspace header chrome swaps
           in at >=1200 - the touch band's canonical query never reaches that
           width, so the two flags can never both be true. */
        this._desktopWorkspaceMedia = window.matchMedia('(min-width: 1200px)');
        this._boundDesktopWorkspaceMediaChange = (event) => {
            this.isDesktopWorkspaceViewport = Boolean(event.matches);
        };
        this.isDesktopWorkspaceViewport = Boolean(this._desktopWorkspaceMedia.matches);

        if (typeof this._desktopWorkspaceMedia.addEventListener === 'function') {
            this._desktopWorkspaceMedia.addEventListener('change', this._boundDesktopWorkspaceMediaChange);
        } else if (typeof this._desktopWorkspaceMedia.addListener === 'function') {
            this._desktopWorkspaceMedia.addListener(this._boundDesktopWorkspaceMediaChange);
        }
    }

    teardownCompactWorkspaceMedia() {
        if (this._compactWorkspaceMedia && this._boundCompactWorkspaceMediaChange) {
            if (typeof this._compactWorkspaceMedia.removeEventListener === 'function') {
                this._compactWorkspaceMedia.removeEventListener('change', this._boundCompactWorkspaceMediaChange);
            } else if (typeof this._compactWorkspaceMedia.removeListener === 'function') {
                this._compactWorkspaceMedia.removeListener(this._boundCompactWorkspaceMediaChange);
            }
            this._compactWorkspaceMedia = null;
            this._boundCompactWorkspaceMediaChange = null;
        }

        if (this._desktopWorkspaceMedia && this._boundDesktopWorkspaceMediaChange) {
            if (typeof this._desktopWorkspaceMedia.removeEventListener === 'function') {
                this._desktopWorkspaceMedia.removeEventListener('change', this._boundDesktopWorkspaceMediaChange);
            } else if (typeof this._desktopWorkspaceMedia.removeListener === 'function') {
                this._desktopWorkspaceMedia.removeListener(this._boundDesktopWorkspaceMediaChange);
            }
            this._desktopWorkspaceMedia = null;
            this._boundDesktopWorkspaceMediaChange = null;
        }
    }

    renderedCallback() {
        if (this._shouldAnimateTier) {
            this._shouldAnimateTier = false;
            this.animateTierFillIn();
        }
    }

    /* ---------------------------------------------------------------- */
    /* Data loading                                                     */
    /* ---------------------------------------------------------------- */

    async loadUser() {
        this.isUserLoading = true;
        try {
            const [data, brokerContentAllowed] = await Promise.all([
                getCurrentUserInfo(),
                shouldShowBrokerContent().catch(() => false)
            ]);
            this.agentName = (data && data.userName) || '';
            this.accountName = (data && data.accountName) || '';
            this.accountId = (data && data.accountId) || '';
            this.contactId = (data && data.contactId) || '';
            this.brokerType = (data && data.brokerType) || '';
            this.brokerContentAllowed = brokerContentAllowed === true;
        } catch (error) {
            // Identity is decorative copy only - fail quiet, keep defaults.
            this.brokerContentAllowed = false;
        } finally {
            this.isUserLoading = false;
        }
    }

    async loadTier() {
        this.isTierLoading = true;
        this.tierError = false;
        try {
            const data = await getBrokerDashboardData();
            if (data && data.error) {
                this.tierError = true;
            }
            this.currentTier = (data && data.currentTier) || 'Standard';
            this.nextTier = data ? data.nextTier : null;
            this.tierCurrentSales = this.toNumber(data && data.currentSales);
            this.nextMilestone =
                data && data.nextMilestone != null ? this.toNumber(data.nextMilestone) : null;
            this.tierBounds = {
                Standard: 0,
                Principal: data && data.principalMin != null ? this.toNumber(data.principalMin) : null,
                Maestro: data && data.maestroMin != null ? this.toNumber(data.maestroMin) : null,
                Ambassador: data && data.ambassadorMin != null ? this.toNumber(data.ambassadorMin) : null
            };
        } catch (error) {
            this.tierError = true;
        } finally {
            this.isTierLoading = false;
            this._shouldAnimateTier = true;
        }
    }

    async loadSales(period) {
        this.isSalesLoading = true;
        this.salesError = false;
        try {
            const request = this.getSalesPeriodRequest(period);
            const result = await getTotalSalesAmount(request);
            const nextValue = this.toNumber(result);
            const startValue = this.totalSales;
            this.totalSales = nextValue;
            this.animateSalesValue(startValue, nextValue);
        } catch (error) {
            this.salesError = true;
        } finally {
            this.isSalesLoading = false;
        }
    }

    async loadUnits() {
        this.isUnitsLoading = true;
        this.unitsError = false;
        try {
            await this.ensureUnitFieldSetColumns();
            const fields = Array.from(
                new Set([
                    ...UNIT_FIELDS,
                    ...this.unitFieldSetColumns.map((column) => column.fieldName),
                    'Allocate_to_Agent__c',
                    'Allocate_to_Agent__r.Name'
                ])
            );
            const records = await getUnitRecords({
                objectName: 'Unit__c',
                filters: {},
                fields
            });
            this.unitRecords = records || [];
        } catch (error) {
            this.unitsError = true;
        } finally {
            this.isUnitsLoading = false;
        }
    }

    // The org's Unit__c Properties_Fields field set decides WHICH fields the
    // units table, preview facts, and CSV export show - same contract as the
    // legacy units page. Presentation stays the revamp's own.
    ensureUnitFieldSetColumns() {
        if (!this._unitColumnsPromise) {
            this._unitColumnsPromise = getFieldSetColumns({ objectName: 'Unit__c', fieldSetName: 'Properties_Fields' })
                .then((columns) => {
                    this.unitFieldSetColumns = (columns || [])
                        .filter((column) => (column.label || '').trim() !== '')
                        .map((column) =>
                            column.fieldName === 'BasePrice__c'
                                ? { label: 'Total Price', fieldName: 'BasePrice__c', isCurrency: true }
                                : { label: column.label, fieldName: column.fieldName, isCurrency: false }
                        );
                })
                .catch(() => {
                    this.unitFieldSetColumns = [];
                });
        }
        return this._unitColumnsPromise;
    }

    async loadMarketingProjects() {
        if (this.isMarketingLoading) return;
        this.isMarketingLoading = true;
        this.marketingError = false;
        try {
            const result = await getRecordsWithImages({
                objectName: 'Project__c',
                filters: {},
                fields: MARKETING_FIELDS
            });
            this.marketingProjects = (Array.isArray(result) ? result : []).map((wrapper, index) => {
                const record = wrapper.recordData || {};
                const imageUrls = Array.isArray(wrapper.imageUrls) ? wrapper.imageUrls.map(coerceImageMime) : [];
                const name = record.Name || 'Project';
                return {
                    id: record.Id,
                    key: record.Id || `project-${index}`,
                    name,
                    imageUrl: imageUrls[0] || '',
                    hasImage: Boolean(imageUrls[0]),
                    // Dynamic per-project logo, sourced from Apex (a "Logo"-named
                    // Documents__c file on the project) instead of the old hardcoded
                    // project-name -> static-resource-file lookup. Falls back to the
                    // Modon mark until a project's own logo file is uploaded.
                    logoUrl: coerceImageMime(wrapper.logoUrl) || PROJECT_LOGO_FALLBACK_URL,
                    cardStyle: `--reveal-index: ${index}`
                };
            });
            if (!this.selectedMarketingProjectId && this.marketingProjects.length) {
                this.selectedMarketingProjectId = this.marketingProjects[0].id;
                this.loadMarketingDocuments(this.selectedMarketingProjectId);
            }
        } catch (error) {
            this.marketingError = true;
            this.marketingProjects = [];
        } finally {
            this.isMarketingLoading = false;
        }
    }

    get marketingProjectCount() {
        return this.marketingProjects.length;
    }

    get isEoiFeatureEnabled() {
        return String(MBP_EnableEoi || '').toLowerCase() === 'true';
    }

    /* MBP_EnableNewEoi shows or hides only the New EOI pill; the EOI card
       itself stays under MBP_EnableEoi. */
    get isNewEoiEnabled() {
        return String(MBP_EnableNewEoi || '').toLowerCase() === 'true';
    }

    /* ---------------------------------------------------------------- */
    /* Compliance facts: Limited Login guidance + Needs attention.      */
    /* Same existing reads the agency workspace uses - no new backend.  */
    /* ---------------------------------------------------------------- */

    async loadComplianceFacts() {
        try {
            this.complianceWrapper = (await findRegistrationWithReviewComment()) || null;
        } catch (error) {
            this.complianceWrapper = null;
        }
        try {
            this.agencyAccount = (await getEditableAccount()) || null;
        } catch (error) {
            this.agencyAccount = null;
        }
    }

    get isLimitedUser() {
        return Boolean(this.complianceWrapper && this.complianceWrapper.isLimitedOnly);
    }

    /* Draftstagecontroller already returns showSales = Fast_Track__c for a
       limited-access user, but this component only read isLimitedOnly, so a
       Fast-Track owner landed in the same bucket as a "needs more information"
       user and lost the New lead action, the one thing Fast-Track grants.
       Both are the same permission set; showSales is all that separates them. */
    get isFastTrack() {
        return Boolean(
            this.complianceWrapper &&
            this.complianceWrapper.isLimitedOnly &&
            this.complianceWrapper.showSales
        );
    }

    /* Limited, but NOT Fast-Track - the "we need more information" state. */
    get isRestrictedOnly() {
        return this.isLimitedUser && !this.isFastTrack;
    }

    /* Neither limited mode gets the full card set. Fast-Track keeps Leads and
       nothing else; "needs more information" keeps nothing, with only the
       Registration Form reachable inside the My Agency panel as
       mbpr_registrationWorkspace mode="continuation". */
    get showFullDashboard() {
        return !this.isLimitedUser;
    }

    get showLeadsCard() {
        return !this.isRestrictedOnly;
    }

    /* Collapses the row entirely rather than leaving an empty grid behind. */
    get showCommandRow() {
        return this.showFullDashboard || this.showLeadsCard;
    }

    /* Panels a Fast-Track user may still reach. Account stays because sign-out
       lives inside it, and Help because a blocked user needs a way to ask for
       help; My Agency and Updates are hidden as the meeting requires. */
    get allowedUtilityPanels() {
        // Training reads no records and is useful to every persona, so it stays
        // reachable in both narrowed lists.
        if (this.isFastTrack) return ['training', 'profile', 'help'];
        // My Agency hosts the onboarding continuation, so it is the
        // one destination a limited user must still reach.
        if (this.isRestrictedOnly) return ['training', 'myagency', 'profile', 'help'];
        return null;
    }

    get showMyAgencyEntry() {
        return this.canOpenUtilityPanel('myagency');
    }

    get showUpdatesEntry() {
        return this.canOpenUtilityPanel('updates');
    }

    get showTrainingEntry() {
        return this.canOpenUtilityPanel('training');
    }

   get allowedCommandWorkspaces() {
    if (this.isFastTrack) return ['sales', 'eoi'];
    if (this.isRestrictedOnly) return [];
    return null;
}

    canOpenCommandWorkspace(workspace) {
        const allowed = this.allowedCommandWorkspaces;
        return !allowed || allowed.includes(workspace);
    }

    canOpenUtilityPanel(panel) {
        const allowed = this.allowedUtilityPanels;
        return !allowed || allowed.includes(panel);
    }

    get guidanceComment() {
        return (this.complianceWrapper && this.complianceWrapper.taskComment) || '';
    }

    get showGuidanceHero() {
        return this.isLimitedUser;
    }

    /* canCreateLead is Agent and Owner only, so an Agency Admin used to be told
       to "start creating leads now" while the action was correctly hidden.
       They do see agency-wide leads, so their copy points at that instead. */
    get guidanceTitle() {
        if (!this.isFastTrack) return 'Complete your agency onboarding';
        return this.canCreateLead
            ? 'Create leads and EOIs while your onboarding completes'
            : 'Lead Access During Onboarding';
    }

    get guidanceLine() {
        if (!this.isFastTrack) {
            return "Your access is limited until your agency's registration is completed and approved.";
        }
        return this.canCreateLead
            ? 'Your agency has early access, so you can start creating leads now. The rest of the portal unlocks once your registration is approved.'
            : 'Your agency can create and manage leads during onboarding. You can monitor all agency lead activity, and full portal access will be available once your registration is approved.';
    }

    /* Fast-Track cannot open My Agency, so the hero must not offer it. */
    get showGuidanceAgencyAction() {
        return !this.isFastTrack;
    }

    get showNewLeadCard() {
        return this.canCreateLead && (!this.isLimitedUser || this.isFastTrack);
    }

    /* Same gate as the leads card's pill, plus MBP_EnableNewEoi. The EOI card
       itself only renders when MBP_EnableEoi is on. */
    get showNewEoiCardAction() {
        return this.showNewLeadCard && this.isNewEoiEnabled;
    }

 get showEoiCard() {
    return this.isEoiFeatureEnabled && (!this.isLimitedUser || this.isFastTrack);
}
    get needsAttentionItems() {
        if (this.isLimitedUser) return [];
        const items = [];
        const wrapper = this.complianceWrapper;
        if (wrapper && wrapper.isEidExpiredForContact) {
            items.push({ key: 'eid', label: 'Your Emirates ID on file has expired.', action: 'Open My Agency', panel: 'myagency' });
        }
        if (wrapper && wrapper.taskComment) {
            items.push({ key: 'review', label: 'Your registration has review comments to resolve.', action: 'Open My Agency', panel: 'myagency' });
        }
        if (wrapper && wrapper.isBrokerAgencyBlocked) {
            items.push({ key: 'blocked', label: 'Your agency account is currently blocked.', action: 'Get help', panel: 'help' });
        }
        if (this.canSeeCommissionLanguage && this.agencyAccount) {
            /* VAT expiry is no longer surfaced anywhere in the portal
               (business request, 2026-09-04), so it raises no alert either.
               Trade licence expiry is unaffected. */
            const trade = this.buildExpiryAttentionItem('trade', 'trade license', this.agencyAccount.TradeLicenseExpiryDate__c);
            if (trade) items.push(trade);
        }
        return items;
    }

    buildExpiryAttentionItem(key, noun, rawDate) {
        if (!rawDate) return null;
        const expiry = new Date(`${rawDate}T00:00:00`);
        if (Number.isNaN(expiry.getTime())) return null;
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const days = Math.round((expiry.getTime() - today.getTime()) / 86400000);
        if (days > 30) return null;
        // '2-digit' day so this reads "05 Aug 2026", matching the portal standard.
        const dateLabel = expiry.toLocaleDateString('en-AE', { day: '2-digit', month: 'short', year: 'numeric' });
        const label = days < 0 ? `Your ${noun} expired on ${dateLabel}.` : `Your ${noun} expires on ${dateLabel}.`;
        return { key, label, action: 'Open My Agency', panel: 'myagency' };
    }

    get showNeedsAttention() {
        return this.needsAttentionItems.length > 0;
    }

    get canCreateLead() {
        return this.brokerType === 'Agent' || this.brokerType === 'Owner';
    }

    async loadEoiCardCount() {
        if (!this.isEoiFeatureEnabled) return;
        this.isEoiCountLoading = true;
        this.eoiCountError = false;
        try {
            const records = await getEOIRecords();
            this.eoiRecordCount = Array.isArray(records) ? records.length : 0;
        } catch (error) {
            this.eoiCountError = true;
        } finally {
            this.isEoiCountLoading = false;
        }
    }

    handleRetryEoiCount() {
        this.loadEoiCardCount();
    }

    handleOpenNewLead(event) {
        event?.preventDefault?.();
        event?.stopPropagation?.();
        if (!this.canCreateLead) return;
        this._directLeadFormLastFocusedElement = event?.currentTarget || null;
        this.activeUtilityPanel = null;
        this.activeCommandWorkspace = null;
        this.salesWorkspaceIntent = '';
        this.salesWorkspaceIntentToken = '';
        this.isDirectLeadFormOpen = true;
        this.directLeadFormToken = String(Date.now());
    }

    /* EOI card fast path (mirrors the leads card's New lead pill exactly):
       a standalone chrome-less workspace instance hosts ONLY the EOI form
       drawer - no EOI workspace opens behind it. */
    handleOpenNewEoi(event) {
        event?.preventDefault?.();
        event?.stopPropagation?.();
        if (!this.canCreateLead || !this.isNewEoiEnabled) return;
        this._directEoiFormLastFocusedElement = event?.currentTarget || null;
        this.activeUtilityPanel = null;
        this.activeCommandWorkspace = null;
        this.salesWorkspaceIntent = '';
        this.salesWorkspaceIntentToken = '';
        this.isDirectEoiFormOpen = true;
        this.directEoiFormToken = String(Date.now());
    }

    handleCloseDirectEoiForm() {
        this.isDirectEoiFormOpen = false;
        this.directEoiFormToken = '';
        if (this._directEoiFormLastFocusedElement && this._directEoiFormLastFocusedElement.isConnected) {
            this._directEoiFormLastFocusedElement.focus();
        }
        this._directEoiFormLastFocusedElement = null;
    }

    handleCloseDirectLeadForm() {
        this.isDirectLeadFormOpen = false;
        this.directLeadFormToken = '';
        if (this._directLeadFormLastFocusedElement && this._directLeadFormLastFocusedElement.isConnected) {
            this._directLeadFormLastFocusedElement.focus();
        }
        this._directLeadFormLastFocusedElement = null;
    }

    ensureMarketingLibraryLoaded() {
        if (this.marketingProjects.length || this.isMarketingLoading || this.marketingError) return;
        this.loadMarketingProjects();
    }

    async loadMarketingDocuments(projectId) {
        if (!projectId) return;
        if (!MARKETING_FILE_LIST_ENABLED) {
            // BP-077: sections show Dropbox buttons; no file query, so no loading or error state.
            this.isMarketingDocumentsLoading = false;
            this.marketingDocumentsError = false;
            this.selectedMarketingSections = [];
            this.marketingDocuments = { floorPlans: [], gallery: [], Brochures: [] };
            return;
        }
        this.isMarketingDocumentsLoading = true;
        this.marketingDocumentsError = false;
        this.selectedMarketingSections = [];
        try {
            const docs = await getDocumentsAndFilesByProject({ projectId });
            const normalized = (Array.isArray(docs) ? docs : [])
                // The Logo document feeds the sidebar project mark via getRecordsWithImages()'s
                // logoUrl (rendered as an <img>) only — it must never be treated as a downloadable
                // Brochure/Gallery/Floor plan file, even though Apex already excludes it too.
                .filter((doc) => !(doc.documentName || '').toLowerCase().includes('logo'))
                .map((doc) => ({
                    ...doc,
                    documentName: doc.documentName || '',
                    files: Array.isArray(doc.files)
                        ? doc.files.map((file, index) => ({
                              key: `${doc.documentName || 'file'}-${file.title || index}-${index}`,
                              title: file.title || `File ${index + 1}`,
                              fileExtension: file.fileExtension || '',
                              downloadUrl: this.normalizeDownloadUrl(file.downloadUrl),
                              thumbnailUrl: this.normalizeDownloadUrl(file.thumbnailUrl),
                              // Needed by the zip download's server-side fallback
                              // (getFileContentAsBase64) when the browser's own
                              // fetch() of the public link fails.
                              contentVersionId: file.contentVersionId || ''
                          }))
                        : []
                }));

            const floorDocs = normalized.filter((doc) => doc.documentName.toLowerCase().includes('floor plan'));
            const galleryDocs = normalized.filter((doc) => doc.documentName.toLowerCase().includes('gallery'));
            const brochureDocs = normalized.filter((doc) => {
                const name = doc.documentName.toLowerCase();
                return !name.includes('floor plan') && !name.includes('gallery') && !name.includes('thumbnail');
            });

            this.marketingDocuments = {
                floorPlans: this.aggregateMarketingFiles('floorPlans', floorDocs),
                gallery: this.aggregateMarketingFiles('gallery', galleryDocs),
                Brochures: this.aggregateMarketingFiles('Brochures', brochureDocs)
            };
        } catch (error) {
            this.marketingDocumentsError = true;
            this.marketingDocuments = { floorPlans: [], gallery: [], Brochures: [] };
        } finally {
            this.isMarketingDocumentsLoading = false;
        }
    }

    aggregateMarketingFiles(section, docs) {
        const files = (Array.isArray(docs) ? docs : [])
            .flatMap((doc) => doc.files || [])
            .filter((file) => Boolean(file.downloadUrl));
        return [
            {
                section,
                files,
                hasFiles: files.length > 0
            }
        ];
    }

    async loadLeads() {
        this.isLeadsLoading = true;
        this.leadsError = false;
        try {
            const leadsRange = resolveLeadsPeriodRange();
            const records = await getFilteredLeads({
                userId: USER_ID,
                filterType: LEADS_PERIOD,
                startDate: leadsRange.startDate,
                endDate: leadsRange.endDate
            });
            // A row is one customer, and children holds each of their leads. The card has to match
            // the Leads tab, so it counts the same way. Converted ones are still dropped further
            // down by activeLeadRecords.
            this.leadRecords = (records || []).reduce((all, row) => {
                const group = Array.isArray(row.children) && row.children.length ? row.children : [row];
                return all.concat(group);
            }, []);
        } catch (error) {
            this.leadsError = true;
            this.leadRecords = [];
        } finally {
            this.isLeadsLoading = false;
        }
    }

    handleRetryTier() {
        this.loadTier();
    }

    handleRetrySales() {
        this.loadSales(this.salesPeriod);
    }

    handleRetryUnits() {
        this.loadUnits();
    }

    handleRetryLeads() {
        this.loadLeads();
    }

    handleSalesWorkspaceDataChange(event) {
        const scope = event?.detail?.scope || 'sales';
        this.clearSalesWorkspaceRefresh();
        this._salesWorkspaceRefreshTimer = window.setTimeout(() => {
            this._salesWorkspaceRefreshTimer = null;
            this.refreshSalesWorkspaceSummary(scope).catch(() => {
                // Each loader already owns its visible error state.
            });
        }, 250);
    }

    handleOpenGuidedOfferWorkspace(event) {
        const detail = event?.detail || {};
        const unitIds = Array.isArray(detail.unitIds)
            ? detail.unitIds
            : detail.unitId
              ? [detail.unitId]
              : [];
        this.openGuidedOfferWorkspace({
            leadId: detail.leadId || '',
            unitIds
        });
    }

    handleOpenGuidedOfferFromUnits(event) {
        event?.preventDefault?.();
        if (!this.hasSelectedWorkspaceUnits) return;
        const unitIds = this.selectedWorkspaceUnitIds;
        this.openGuidedOfferWorkspace({ unitIds });
    }

    openGuidedOfferWorkspace({ leadId = '', unitIds = [] } = {}) {
        this.guidedOfferLeadId = leadId || '';
        this.guidedOfferUnitIds = [...new Set((Array.isArray(unitIds) ? unitIds : []).filter(Boolean))];
        this.guidedOfferLaunchToken = String(Date.now());
        this.isGuidedOfferOpen = true;
    }

    handleCloseGuidedOfferWorkspace() {
        this.isGuidedOfferOpen = false;
    }

    handleGuidedOfferComplete(event) {
        this.handleSalesWorkspaceDataChange(event);
        const salesWorkspace = this.template.querySelector('c-mbpr_sales-workspace');
        if (salesWorkspace && typeof salesWorkspace.refreshWorkspaceData === 'function') {
            salesWorkspace.refreshWorkspaceData({ scope: 'offer' }).catch(() => {
                // The home summary refresh above remains the fallback.
            });
        }
    }

    async refreshSalesWorkspaceSummary(scope) {
        const loaders = [this.loadLeads()];
        if (scope === 'eoi' || scope === 'sales') {
            loaders.push(this.loadEoiCardCount());
        }
        if (scope === 'eoi' || scope === 'offer' || scope === 'sales') {
            loaders.push(this.loadTier());
            loaders.push(this.loadSales(this.salesPeriod));
        }
        if (scope === 'offer' || scope === 'sales') {
            loaders.push(this.loadUnits());
        }
        await Promise.all(loaders);
    }

    clearSalesWorkspaceRefresh() {
        if (this._salesWorkspaceRefreshTimer) {
            clearTimeout(this._salesWorkspaceRefreshTimer);
            this._salesWorkspaceRefreshTimer = null;
        }
    }

    /* ---------------------------------------------------------------- */
    /* Identity                                                         */
    /* ---------------------------------------------------------------- */

    /* Hero eyebrow shows the broker's own agency; portal name is the
       fallback while the user loads or if there is no account. */
    get headLabel() {
        return this.accountName || 'Modon Broker Portal';
    }

    get greeting() {
        const hour = new Date().getHours();
        if (hour < 12) return 'Good Morning';
        if (hour < 17) return 'Good Afternoon';
        return 'Good Evening';
    }

    get firstName() {
        if (!this.agentName) return '';
        return this.agentName.split(' ')[0];
    }

    get greetingLine() {
        return this.firstName ? `${this.greeting}, ${this.firstName}` : this.greeting;
    }

    get identityInitials() {
        return this.getInitials(this.agentName || this.firstName || 'B');
    }

    get todayLabel() {
        const now = new Date();
        return `${DAY_NAMES[now.getDay()]}, ${now.getDate()} ${MONTH_NAMES[now.getMonth()]} ${now.getFullYear()} · Abu Dhabi, UAE`;
    }

    get isDarkTheme() {
        return this.theme === 'dark';
    }

    get themeToggleLabel() {
        return this.isDarkTheme ? 'Switch to light theme' : 'Switch to dark theme';
    }

    get themeToggleAriaLabel() {
        return `${this.themeToggleLabel}. Current theme: ${this.themeStateLabel}`;
    }

    get themeStateLabel() {
        return this.isDarkTheme ? 'Dark' : 'Light';
    }

    get themePreferenceDescription() {
        return this.isDarkTheme ? 'Dark mode active' : 'Light mode active';
    }

    get themeOptionIconClass() {
        return `theme-option__icon ${this.isDarkTheme ? 'theme-option__icon--moon' : 'theme-option__icon--sun'}`;
    }

    get themeOptionIconSymbol() {
        return this.isDarkTheme ? '☾' : '☀';
    }

    get themeButtonIconSymbol() {
        return this.isDarkTheme ? '☀' : '☾';
    }

    get themeButtonIconClass() {
        return `theme-action__icon ${this.isDarkTheme ? 'theme-action__icon--sun' : 'theme-action__icon--moon'}`;
    }

    get themeButtonLabel() {
        return this.isDarkTheme ? 'Light mode' : 'Dark mode';
    }

    get accountMenuThemeLabel() {
        return this.isDarkTheme ? 'Switch to light' : 'Switch to dark';
    }

    get accountMenuTitle() {
        return this.agentName || this.brokerTypeLabel || 'Broker User';
    }

    get themeSwitchTargetLabel() {
        return this.isDarkTheme ? 'Light' : 'Dark';
    }

    get profileThemeSwitchClass() {
        return `profile-theme-switch ${this.isDarkTheme ? 'profile-theme-switch--dark' : 'profile-theme-switch--light'}`;
    }

    get themeStyle() {
        const tokens = THEME_TOKENS[this.theme] || THEME_TOKENS.dark;
        const declarations = [];
        Object.entries(tokens).forEach(([key, value]) => {
            declarations.push(`${key}: ${value}`);
            if (key.startsWith('--mbpr-')) {
                declarations.push(`${key.replace('--mbpr-', '--mbpr-theme-')}: ${value}`);
            }
        });
        declarations.push(`--mbpr-line: ${tokens['--mbpr-ink-line']}`);
        return declarations.join('; ');
    }

    /* Its own getter rather than binding themeStyle directly, so the template is
       untouched and the background layer has one named source. The ground is
       painted by CSS from --mbpr-page-gradient, carried here with the rest. */
    get backgroundStyle() {
        return this.themeStyle;
    }

    get quickLinks() {
        const links = [
            {
                id: 'training',
                label: 'Training',
                tooltip: 'Training',
                icon: '',
                panel: 'training',
                isTraining: true
            },
            {
                id: 'updates',
                label: 'Updates',
                tooltip: 'Updates',
                icon: 'utility:announcement',
                panel: 'updates',
                isUpdates: true
            },
            {
                id: 'myagency',
                label: 'My Agency',
                tooltip: 'My Agency',
                icon: '',
                panel: 'myagency',
                isMyAgency: true
            },
            {
                id: 'help',
                label: 'Help',
                tooltip: 'Help',
                icon: 'utility:question_mark',
                panel: 'help',
                isHelp: true
            },
            {
                id: 'profile',
                label: 'Account',
                tooltip: 'Account',
                icon: '',
                action: 'accountMenu',
                isAvatar: true
            }
        ];

        const visibleLinks = this.allowedUtilityPanels
            ? links.filter((link) => link.isAvatar || this.canOpenUtilityPanel(link.panel))
            : links;

        return visibleLinks.map((link, index) => {
            const itemClass = ['quick-access__item'];
            const buttonClass = ['quick-access__btn'];
            if (link.isAvatar) {
                itemClass.push('quick-access__item--account');
                buttonClass.push('quick-access__btn--avatar');
                if (this.isAccountMenuOpen) {
                    itemClass.push('quick-access__item--menu-open');
                    buttonClass.push('quick-access__btn--active');
                }
            }
            if (index === visibleLinks.length - 1) itemClass.push('quick-access__item--edge');
            if (this.dismissedQuickAccessTooltip === link.id) itemClass.push('quick-access__item--tooltip-dismissed');

            return {
                ...link,
                ariaLabel: `Open ${link.label}`,
                ariaExpanded: link.isAvatar ? String(this.isAccountMenuOpen) : undefined,
                ariaHasPopup: link.isAvatar ? 'menu' : undefined,
                buttonClass: buttonClass.join(' '),
                itemClass: itemClass.join(' '),
                menuId: link.isAvatar ? 'account-menu-card account-menu-sheet' : undefined,
                tooltipId: `quick-access-tooltip-${link.id}`
            };
        });
    }

    handleThemeToggle() {
        this.theme = this.isDarkTheme ? 'light' : 'dark';
        this.cacheTheme(this.theme);
        this.syncDocumentScrollbars(this.isDarkTheme);
        this.syncDocumentCanvas(true);
    }

    /* Windows leaves a white hairline along the viewport's bottom edge: the site
       canvas stays white behind this page and fractional scaling can leave the
       background layers' last device pixel unpainted. Painting the canvas the
       current theme's page colour removes the mismatch; restored on disconnect
       so no other site page inherits it. */
    syncDocumentCanvas(active) {
        try {
            const root = document.documentElement;
            const body = document.body;
            if (active) {
                if (this._prevRootBg === undefined) {
                    this._prevRootBg = root.style.backgroundColor;
                    this._prevBodyBg = body.style.backgroundColor;
                }
                const tokens = THEME_TOKENS[this.theme] || THEME_TOKENS.dark;
                const canvas = tokens['--mbpr-page-bg'];
                root.style.backgroundColor = canvas;
                body.style.backgroundColor = canvas;
            } else {
                root.style.backgroundColor = this._prevRootBg || '';
                body.style.backgroundColor = this._prevBodyBg || '';
                this._prevRootBg = undefined;
                this._prevBodyBg = undefined;
            }
        } catch (error) {
            // Best effort - the component's own background layers remain.
        }
    }

    /* Component scroll areas inherit their dark scrollbars from the themed
       carriers, but the viewport scrollbar belongs to the document root, which
       component CSS cannot reach. Synced inline while the theme applies and
       cleared in light theme and on disconnect. */
    syncDocumentScrollbars(enable) {
        try {
            const rootStyle = document.documentElement.style;
            if (enable) {
                rootStyle.setProperty('scrollbar-color', DARK_SCROLLBAR_COLOR);
            } else {
                rootStyle.removeProperty('scrollbar-color');
            }
        } catch (error) {
            // Best effort - the component-level scrollbar CSS still applies.
        }
    }

    cacheTheme(theme) {
        try {
            window.localStorage.setItem(THEME_STORAGE_KEY, theme);
        } catch (error) {
            // Theme persistence is best effort; visual toggle still works.
        }
    }

    readCachedTheme() {
        try {
            const theme = window.localStorage.getItem(THEME_STORAGE_KEY);
            return theme === 'dark' || theme === 'light' ? theme : null;
        } catch (error) {
            return null;
        }
    }

    /* ---------------------------------------------------------------- */
    /* Aspire tier / ascent                                             */
    /* ---------------------------------------------------------------- */

    get normalizedCurrentTier() {
        const storedTier = this.normalizeTierName(this.currentTier) || 'Standard';
        const earnedTier = this.earnedTierFromSales;
        return this.tierRank(earnedTier) > this.tierRank(storedTier) ? earnedTier : storedTier;
    }

    get effectiveTierBounds() {
        return TIER_SEQUENCE.reduce((bounds, tier) => {
            const rawValue = this.tierBounds ? this.tierBounds[tier] : null;
            const parsedValue = Number(rawValue);
            const hasUsableValue = tier === 'Standard'
                ? Number.isFinite(parsedValue) && parsedValue >= 0
                : Number.isFinite(parsedValue) && parsedValue > 0;
            bounds[tier] = hasUsableValue
                ? parsedValue
                : FALLBACK_TIER_THRESHOLDS[tier];
            return bounds;
        }, {});
    }

    get earnedTierFromSales() {
        const sales = this.toNumber(this.tierCurrentSales);
        const bounds = this.effectiveTierBounds;
        return TIER_SEQUENCE.reduce((highestTier, tier) => {
            if (tier === 'Standard') return highestTier;
            const threshold = bounds[tier];
            if (threshold != null && sales >= threshold && this.tierRank(tier) > this.tierRank(highestTier)) {
                return tier;
            }
            return highestTier;
        }, 'Standard');
    }

    get normalizedNextTier() {
        const currentIndex = TIER_SEQUENCE.indexOf(this.normalizedCurrentTier);
        if (currentIndex >= 0 && currentIndex < TIER_SEQUENCE.length - 1) {
            return TIER_SEQUENCE[currentIndex + 1];
        }
        return null;
    }

    get currentTierLabel() {
        return this.normalizedCurrentTier;
    }

    get tierBadgeImageUrl() {
        return TIER_BADGE_IMAGES[this.normalizedCurrentTier] || '';
    }

    get tierBadgeHasImage() {
        return Boolean(this.tierBadgeImageUrl);
    }

    get tierBadgeAlt() {
        return `${this.normalizedCurrentTier} Aspire status badge`;
    }

    get tierBadgeInitial() {
        return TIER_SHORT_LABELS[this.normalizedCurrentTier] || 'AS';
    }

    get showNextTierPath() {
        return Boolean(this.normalizedNextTier);
    }

    get nextTierPathStop() {
        return this.normalizedNextTier
            ? this.buildTierPathStop(this.normalizedNextTier, 'next')
            : this.buildTierPathStop(this.normalizedCurrentTier, 'current');
    }

    buildTierPathStop(name, state) {
        const imageUrl = TIER_BADGE_IMAGES[name] || '';
        return {
            key: `${state}-${name}`,
            label: name,
            state,
            kicker: state === 'current' ? 'Current' : 'Next',
            imageUrl,
            hasImage: Boolean(imageUrl),
            shortLabel: TIER_SHORT_LABELS[name] || name.slice(0, 2).toUpperCase()
        };
    }

    get tierProgress() {
        const currentTier = this.normalizedCurrentTier;
        const nextTier = this.normalizedNextTier;
        const idx = TIER_SEQUENCE.indexOf(currentTier);
        if (idx === -1) {
            return { percent: 0, remainingLabel: '', remaining: 0, target: 0, hasProgress: false };
        }
        if (!nextTier) {
            return {
                percent: 100,
                remainingLabel: 'Highest tier reached',
                remaining: 0,
                target: this.tierCurrentSales,
                hasProgress: true
            };
        }
        const end = this.effectiveTierBounds[nextTier];
        if (end == null || end <= 0) {
            return { percent: 0, remainingLabel: '', remaining: 0, target: 0, hasProgress: false };
        }
        const raw = (this.tierCurrentSales / end) * 100;
        const percent = Math.min(100, Math.max(0, raw));
        const remaining = Math.max(0, end - this.tierCurrentSales);
        return {
            percent,
            remainingLabel: remaining > 0
                ? `${this.formatCurrencyCompact(remaining)} to ${nextTier}`
                : `${nextTier} target reached`,
            remaining,
            target: end,
            hasProgress: true
        };
    }

    get tierTrackStyle() {
        return `--ascent-fill: ${this.tierProgress.percent}%`;
    }

    get tierRemainingLabel() {
        return this.tierProgress.remainingLabel;
    }

    get tierProgressPercentRounded() {
        return Math.round(this.tierProgress.percent);
    }

    get tierAchievedBarLabel() {
        return this.formatCurrencyCompact(this.tierCurrentSales);
    }

    get tierRemainingBarLabel() {
        const progress = this.tierProgress;
        return this.formatCurrencyCompact(progress.remaining);
    }

    get tierProgressAriaLabel() {
        const nextTier = this.normalizedNextTier;
        const progress = this.tierProgress;
        if (!nextTier) {
            return `${this.tierAchievedBarLabel} achieved. Highest Aspire tier reached.`;
        }
        const remainingText = progress.remaining > 0
            ? `${this.tierRemainingBarLabel} remaining`
            : 'Target reached';
        return `${this.tierAchievedBarLabel} achieved toward ${nextTier}. ${remainingText}. ${Math.round(progress.percent)}% complete.`;
    }

    get showTierProgress() {
        return this.tierProgress.hasProgress && !this.normalizedNextTier;
    }

    // Each tier gets its own colour, mixed only from the existing teal/gold
    // tokens (Standard stays neutral ink - nothing "earned" yet) - the CSS
    // selectors this drives live under.ascent--standard/--principal/
    // --maestro/--top-tier.
    get showTierContent() {
        return !this.isTierLoading && !this.tierError;
    }

    get isHighestTier() {
        return Boolean(this.normalizedCurrentTier) && !this.normalizedNextTier;
    }

    /* ---------------------------------------------------------------- */
    /* Aspire status pill + smart card (hero)                           */
    /* ---------------------------------------------------------------- */

    get aspirePillClassName() {
        return this.isAspirePopoverOpen ? 'aspire-pill aspire-pill--open' : 'aspire-pill';
    }

    handleAspirePillClick(event) {
        if (this.isTierLoading) return;
        if (this.tierError) {
            this.handleRetryTier();
            return;
        }
        event.stopPropagation();
        this.isAspirePopoverOpen = !this.isAspirePopoverOpen;
        if (this.isAspirePopoverOpen) {
            this._aspirePillReturnFocus = event.currentTarget;
            this._shouldAnimateTier = true;
        }
    }

    handleAspirePillKeydown(event) {
        if (event.key !== 'Escape' || !this.isAspirePopoverOpen) return;
        event.preventDefault();
        event.stopPropagation();
        this.closeAspirePopover(true);
    }

    handleAspirePopoverClick(event) {
        event.stopPropagation();
    }

    handleAspirePopoverKeydown(event) {
        if (event.key !== 'Escape') return;
        event.preventDefault();
        event.stopPropagation();
        this.closeAspirePopover(true);
    }

    handleAspireCloseClick() {
        this.closeAspirePopover(true);
    }

    handleAspireBackdropClick() {
        this.closeAspirePopover(false);
    }

    closeAspirePopover(returnFocus) {
        this.isAspirePopoverOpen = false;
        if (returnFocus && this._aspirePillReturnFocus?.isConnected) {
            this._aspirePillReturnFocus.focus();
        }
        this._aspirePillReturnFocus = null;
    }

    // Grows the track fill from zero on load/tier-change instead of it just
    // appearing at its final width - mirrors the trend chart's draw-in
    // technique, since a plain CSS transition has no "before" state to
    // animate from the first time this content replaces the loading skeleton.
    animateTierFillIn() {
        if (this.prefersReducedMotion()) return;
        const track = this.template.querySelector('.aspire-pop__meter');
        if (!track) return;
        const progress = this.tierProgress;
        track.style.setProperty('--ascent-fill', '0%');
        // Force layout so the browser commits the 0% starting state before animating.
        track.getBoundingClientRect();
        requestAnimationFrame(() => {
            track.style.setProperty('--ascent-fill', `${progress.percent}%`);
        });
    }

    /* ---------------------------------------------------------------- */
    /* Total sales                                                      */
    /* ---------------------------------------------------------------- */

    get formattedTotalSales() {
        return this.formatCurrencyCompact(this.displaySalesValue);
    }

    get formattedTotalSalesFull() {
        return this.formatCurrencyFull(this.totalSales);
    }

    get currentSalesPeriodLabel() {
        const match = SALES_PERIODS.find((period) => period.value === this.salesPeriod);
        return match ? match.label : 'This period';
    }

    getSalesPeriodRequest(period) {
        const today = new Date();
        if (period === 'This Month') {
            return {
                filterType: 'Custom',
                startDate: this.formatDateForApex(new Date(today.getFullYear(), today.getMonth(), 1)),
                endDate: this.formatDateForApex(today)
            };
        }

        if (period === 'This Week') {
            const mondayOffset = (today.getDay() + 6) % 7;
            const weekStart = new Date(today.getFullYear(), today.getMonth(), today.getDate() - mondayOffset);
            return {
                filterType: 'Custom',
                startDate: this.formatDateForApex(weekStart),
                endDate: this.formatDateForApex(today)
            };
        }

        return { filterType: period, startDate: null, endDate: null };
    }

    animateSalesValue(startValue, targetValue) {
        if (this.prefersReducedMotion()) {
            this.displaySalesValue = targetValue;
            return;
        }
        const startTime = Date.now();
        const step = () => {
            const elapsed = Date.now() - startTime;
            const progress = Math.min(1, elapsed / SALES_COUNT_DURATION_MS);
            const eased = 1 - (1 - progress) ** 3;
            this.displaySalesValue = startValue + (targetValue - startValue) * eased;
            if (progress < 1) {
                requestAnimationFrame(step);
            } else {
                this.displaySalesValue = targetValue;
            }
        };
        requestAnimationFrame(step);
    }

    /* ---------------------------------------------------------------- */
    /* Units                                                            */
    /* ---------------------------------------------------------------- */

    get unitsCount() {
        return this.unitRecords.length;
    }

    get hasUnits() {
        return !this.isUnitsLoading && !this.unitsError && this.unitRecords.length > 0;
    }

    get showUnitsEmpty() {
        return !this.isUnitsLoading && !this.unitsError && this.unitRecords.length === 0;
    }

    get unitCards() {
        return [...this.unitRecords].sort(this.sortUnitsByNewest).map((record, index) => {
            const price = record.TotalPrice__c != null ? record.TotalPrice__c : record.BasePrice__c;
            const phase = record.Phase__r ? record.Phase__r.Name : null;
            /* The Project filter lists projects, not phases. Phase__r.Name is a
               phase; the project comes from the Project_Name__c formula on
               Unit__c, not Phase__r.Project__r.Name, which the Apex field
               whitelist silently drops for being two hops deep. Falls back to
               the phase when a unit has no project, so it stays filterable. */
            const projectName = record.Project_Name__c || phase || null;
            const icon = this.getUnitTypeIcon(record.UnitClassification__c);
            const tourUrl = this.normalizeTourUrl(record.Masterplan_URL__c);
            const imageUrl = this.normalizeHttpUrl(record.DPG_Unit_Image_URL__c);
            const viewLabel = record.View__c || record.Typology__c || icon.label || 'Unit';
            const bedroomShortLabel = this.formatBedroomsShort(record.Number_of_Bedrooms__c);
            const areaLabel = this.formatAreaSqft(record.TotalArea__c);
            const choiceMeta = [bedroomShortLabel, areaLabel]
                .filter((label) => label && label !== '-' && label !== 'Not specified')
                .join(' · ');
            return {
                id: record.Id,
                key: record.Id,
                name: record.Name,
                raw: record,
                phaseLabel: phase || '-',
                projectLabel: projectName || '-',
                bedroomLabel: this.formatBedrooms(record.Number_of_Bedrooms__c),
                bedroomShortLabel,
                choiceMeta: choiceMeta || 'Details not specified',
                statusLabel: record.Status__c || 'Available',
                priceCompact: this.formatCurrencyCompact(price),
                priceFull: this.formatCurrencyFull(price),
                priceValue: this.toNumber(price),
                markIcon: icon.path,
                markLabel: icon.label,
                typeKey: this.normalizeKey(icon.label),
                viewLabel,
                viewKey: this.normalizeKey(viewLabel),
                typologyLabel: record.Typology__c || 'Not specified',
                totalAreaLabel: areaLabel,
                plotAreaLabel: this.formatAreaSqm(record.PlotAreasqm__c),
                gfaLabel: this.formatAreaSqm(record.GrossFloorAreaGFA__c),
                floorLabel: record.FloorNumber__c || record.floor__c || 'Not specified',
                bedroomValue: this.toNumber(record.Number_of_Bedrooms__c),
                projectKey: this.normalizeKey(projectName || 'project'),
                statusKey: this.normalizeKey(record.Status__c || 'Available'),
                createdTime: Date.parse(record.CreatedDate || '') || 0,
                tourUrl,
                hasTour: Boolean(tourUrl),
                tourTitle: `Virtual tour of unit ${record.Name}`,
                imageUrl,
                hasImage: Boolean(imageUrl),
                masterplanStatusLabel: this.formatPlanStatus(record.Masterplan_Status__c, Boolean(tourUrl)),
                masterplanTone: tourUrl ? 'active' : 'warning',
                cardStyle: `--reveal-index: ${index}`
            };
        });
    }

    sortUnitsByNewest(a, b) {
        const aDate = Date.parse(a.CreatedDate || '');
        const bDate = Date.parse(b.CreatedDate || '');
        const aTime = Number.isNaN(aDate) ? 0 : aDate;
        const bTime = Number.isNaN(bDate) ? 0 : bDate;
        return bTime - aTime;
    }

    // Maps the real UnitClassification__c value to one of the hand-built
    // icon glyphs above - falls back to a generic building icon for any
    // classification not in the map, so an unmapped value still renders a
    // sensible icon instead of nothing.
    getUnitTypeIcon(classification) {
        if (!classification) return { path: UNIT_TYPE_ICON_FALLBACK.path, label: 'Unit' };
        const key = String(classification).trim().toLowerCase();
        const match = UNIT_TYPE_ICONS[key];
        if (match) return match;
        return { path: UNIT_TYPE_ICON_FALLBACK.path, label: classification };
    }

    get filteredUnitCards() {
        const query = this.searchQuery.trim().toLowerCase();
        const typeFilter = this.unitTypeFilter;
        const projectFilter = this.unitProjectFilter;
        const bedroomFilter = this.unitBedroomFilter;
        const statusFilter = this.unitStatusFilter;

        return this.unitCards.filter((unit) => {
            const matchesType = typeFilter === 'all' || unit.typeKey === typeFilter;
            const matchesProject = projectFilter === 'all' || unit.projectKey === projectFilter;
            const matchesBedroom = bedroomFilter === 'all' || String(unit.bedroomValue) === bedroomFilter;
            const matchesStatus = statusFilter === 'all' || unit.statusKey === statusFilter;
            const matchesSearch =
                !query ||
                [unit.name, unit.phaseLabel, unit.bedroomLabel, unit.statusLabel, unit.markLabel, unit.typologyLabel, unit.viewLabel].some(
                    (field) => (field || '').toLowerCase().includes(query)
                );
            return matchesType && matchesProject && matchesBedroom && matchesStatus && matchesSearch;
        }).sort((a, b) => this.sortUnitCards(a, b));
    }

    sortUnitCards(a, b) {
        if (this.unitSortMode === 'priceHigh') return b.priceValue - a.priceValue;
        if (this.unitSortMode === 'priceLow') return a.priceValue - b.priceValue;
        if (this.unitSortMode === 'bedroomsHigh') return b.bedroomValue - a.bedroomValue;
        return b.createdTime - a.createdTime;
    }

    get showUnitsNoMatch() {
        return this.hasUnits && this.hasActiveUnitFilters && this.filteredUnitCards.length === 0;
    }

    get hasActiveUnitFilters() {
        return Boolean(this.searchQuery.trim()) ||
            this.unitTypeFilter !== 'all' ||
            this.unitProjectFilter !== 'all' ||
            this.unitBedroomFilter !== 'all' ||
            this.unitStatusFilter !== 'all';
    }

    handleSearchInput(event) {
        this.searchQuery = event.target.value || '';
        this.resetUnitPage();
    }

    handleSearchClear() {
        this.searchQuery = '';
        this.resetUnitPage();
        const input = this.template.querySelector('.unit-search__input');
        if (input) input.focus();
    }

    handleUnitTypeFilter(event) {
        this.unitTypeFilter = event.currentTarget.dataset.type || 'all';
        this.resetUnitPage();
    }

    handleUnitProjectFilter(event) {
        this.unitProjectFilter = event.target.value || 'all';
        this.reconcileAppliedUnitTypeFilter();
        this.resetUnitPage();
    }

    handleUnitBedroomFilter(event) {
        this.unitBedroomFilter = event.target.value || 'all';
        this.reconcileAppliedUnitTypeFilter();
        this.resetUnitPage();
    }

    handleUnitStatusFilter(event) {
        this.unitStatusFilter = event.target.value || 'all';
        this.reconcileAppliedUnitTypeFilter();
        this.resetUnitPage();
    }

    handleUnitSortChange(event) {
        this.unitSortMode = event.target.value || 'newest';
        this.resetUnitPage();
    }

    handleToggleUnitFilterPanel() {
        const shouldOpen = !this.unitFilterPanelOpen;
        if (shouldOpen) {
            this.syncPendingUnitFilters();
        }
        this.unitFilterPanelOpen = shouldOpen;
    }

    handleCloseUnitFilterPanel() {
        this.unitFilterPanelOpen = false;
    }

    handleUnitFilterPanelKeydown(event) {
        // Stop the Escape from bubbling into the workspace modal's own
        // keydown handler, which would close the whole workspace with it.
        if (event.key !== 'Escape' || !this.unitFilterPanelOpen) return;
        event.stopPropagation();
        this.handleCloseUnitFilterPanel();
    }

    syncPendingUnitFilters() {
        this.pendingUnitTypeFilter = this.unitTypeFilter;
        this.pendingUnitProjectFilter = this.unitProjectFilter;
        this.pendingUnitBedroomFilter = this.unitBedroomFilter;
        this.pendingUnitStatusFilter = this.unitStatusFilter;
        this.pendingUnitSortMode = this.unitSortMode;
    }

    handlePendingUnitTypeFilter(event) {
        this.pendingUnitTypeFilter = event.currentTarget.dataset.type || 'all';
    }

    handlePendingUnitProjectFilter(event) {
        this.pendingUnitProjectFilter = event.target.value || 'all';
        this.reconcilePendingUnitFilters();
    }

    handlePendingUnitBedroomFilter(event) {
        this.pendingUnitBedroomFilter = event.target.value || 'all';
        this.reconcilePendingUnitFilters();
    }

    handlePendingUnitStatusFilter(event) {
        this.pendingUnitStatusFilter = event.target.value || 'all';
        this.reconcilePendingUnitFilters();
    }

    handlePendingUnitSortChange(event) {
        this.pendingUnitSortMode = event.target.value || 'newest';
    }

    handleResetUnitFilterPanel() {
        this.pendingUnitTypeFilter = 'all';
        this.pendingUnitProjectFilter = 'all';
        this.pendingUnitBedroomFilter = 'all';
        this.pendingUnitStatusFilter = 'all';
        this.pendingUnitSortMode = 'newest';
        this.unitTypeFilter = 'all';
        this.unitProjectFilter = 'all';
        this.unitBedroomFilter = 'all';
        this.unitStatusFilter = 'all';
        this.unitSortMode = 'newest';
        this.resetUnitPage();
    }

    handleApplyUnitFilters() {
        this.reconcilePendingUnitFilters();
        const hasChanged =
            this.unitTypeFilter !== this.pendingUnitTypeFilter ||
            this.unitProjectFilter !== this.pendingUnitProjectFilter ||
            this.unitBedroomFilter !== this.pendingUnitBedroomFilter ||
            this.unitStatusFilter !== this.pendingUnitStatusFilter ||
            this.unitSortMode !== this.pendingUnitSortMode;

        this.unitTypeFilter = this.pendingUnitTypeFilter || 'all';
        this.unitProjectFilter = this.pendingUnitProjectFilter || 'all';
        this.unitBedroomFilter = this.pendingUnitBedroomFilter || 'all';
        this.unitStatusFilter = this.pendingUnitStatusFilter || 'all';
        this.unitSortMode = this.pendingUnitSortMode || 'newest';
        this.unitFilterPanelOpen = false;

        if (hasChanged) {
            this.resetUnitPage();
        }
    }

    resetUnitPage() {
        this.unitPage = 1;
    }

    handleSelectWorkspaceUnit(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this.workspaceSelectedUnitId = id;
        if (this.isCompactWorkspaceViewport) {
            // Card tap reveals/hides the details (one card at a time);
            // adding to the offer is exclusively the +/check action
            // (user decision - the old tap-to-select confused people).
            this.expandedUnitCardId = this.expandedUnitCardId === id ? '' : id;
        }
    }

    handleToggleUnitSelection(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this.workspaceSelectedUnitId = id;
        this.toggleWorkspaceUnitSelection(id);
    }

    toggleWorkspaceUnitSelection(id) {
        const selected = new Set(this.selectedWorkspaceUnitIds);
        if (selected.has(id)) {
            selected.delete(id);
        } else {
            const unit = this.unitCards.find((candidate) => candidate.id === id);
            if (!unit || unit.statusKey !== 'available') return;
            selected.add(id);
        }
        this.selectedWorkspaceUnitIds = [...selected];
    }

    handleClearUnitFilters() {
        this.searchQuery = '';
        this.unitTypeFilter = 'all';
        this.unitProjectFilter = 'all';
        this.unitBedroomFilter = 'all';
        this.unitStatusFilter = 'all';
        this.unitSortMode = 'newest';
        this.handleResetUnitFilterPanel();
        this.unitFilterPanelOpen = false;
        this.resetUnitPage();
    }

    handlePreviousUnitPage() {
        this.unitPage = Math.max(1, this.unitPage - 1);
        this.resetUnitListScroll();
    }

    handleNextUnitPage() {
        this.unitPage = Math.min(this.unitTotalPages, this.unitPage + 1);
        this.resetUnitListScroll();
    }

    resetUnitListScroll() {
        // After a page flip the new records should be read from the top.
        // rAF runs after the re-render: reset the list's own scrollers
        // (desktop cards/table) and walk every scrollable ancestor - on
        // phones that is the workspace modal's body - via scrollIntoView.
        requestAnimationFrame(() => {
            ['.workspace-unit-grid', '.unit-table-wrap'].forEach((selector) => {
                const scroller = this.template.querySelector(selector);
                if (scroller) {
                    scroller.scrollTop = 0;
                }
            });
            const workspace = this.template.querySelector('.units-workspace');
            if (workspace && typeof workspace.scrollIntoView === 'function') {
                workspace.scrollIntoView({ behavior: 'auto', block: 'start' });
            }
        });
    }

    get unitTypeOptions() {
        return this.buildUnitTypeOptions(this.unitCards, {
            projectFilter: this.unitProjectFilter,
            bedroomFilter: this.unitBedroomFilter,
            statusFilter: this.unitStatusFilter
        });
    }

    get pendingUnitTypeOptions() {
        return this.buildUnitTypeOptions(this.unitCards, {
            projectFilter: this.pendingUnitProjectFilter,
            bedroomFilter: this.pendingUnitBedroomFilter,
            statusFilter: this.pendingUnitStatusFilter
        });
    }

    buildUnitTypeOptions(items, filters = {}) {
        const counts = {};
        const filteredItems = this.filterUnitCardsByCoreFilters(items, filters);
        filteredItems.forEach((unit) => {
            const key = unit.typeKey || 'unit';
            if (!counts[key]) {
                counts[key] = { key, label: unit.markLabel || 'Unit', count: 0 };
            }
            counts[key].count += 1;
        });

        const options = [
            {
                key: 'all',
                label: 'All unit types',
                count: filteredItems.length
            },
            ...Object.values(counts).sort((a, b) => a.label.localeCompare(b.label))
        ];

        return options.map((option) => ({
            ...option,
            className:
                option.key === this.unitTypeFilter
                    ? 'workspace-filter workspace-filter--active'
                    : 'workspace-filter',
            isActive: option.key === this.unitTypeFilter
        }));
    }

    filterUnitCardsByCoreFilters(items, { projectFilter = 'all', bedroomFilter = 'all', statusFilter = 'all' } = {}) {
        return items.filter((unit) => {
            const matchesProject = projectFilter === 'all' || unit.projectKey === projectFilter;
            const matchesBedroom = bedroomFilter === 'all' || String(unit.bedroomValue) === bedroomFilter;
            const matchesStatus = statusFilter === 'all' || unit.statusKey === statusFilter;
            return matchesProject && matchesBedroom && matchesStatus;
        });
    }

    reconcileAppliedUnitTypeFilter() {
        if (this.unitTypeFilter === 'all') return;
        const availableTypes = new Set(this.unitTypeOptions.map((option) => option.key));
        if (!availableTypes.has(this.unitTypeFilter)) {
            this.unitTypeFilter = 'all';
        }
    }

    reconcilePendingUnitFilters() {
        const resetIfUnavailable = (fieldName, options) => {
            const value = this[fieldName] || 'all';
            if (value !== 'all' && !options.some((option) => option.key === value)) {
                this[fieldName] = 'all';
            }
        };

        resetIfUnavailable('pendingUnitProjectFilter', this.pendingUnitProjectOptions);
        resetIfUnavailable('pendingUnitBedroomFilter', this.pendingUnitBedroomOptions);
        resetIfUnavailable('pendingUnitStatusFilter', this.pendingUnitStatusOptions);
        resetIfUnavailable('pendingUnitTypeFilter', this.pendingUnitTypeOptions);
    }

    get hasUnitFieldSetColumns() {
        return this.unitFieldSetColumns.length > 0;
    }

    get showAllocatedToColumn() {
        return this.brokerType === 'Owner' || this.brokerType === 'Agency Admin';
    }

    get unitCsvColumns() {
        const columns = [...this.unitFieldSetColumns];
        if (this.showAllocatedToColumn) {
            columns.push({ label: 'Unit Allocated To', fieldName: 'allocatedAgentName', isCurrency: false });
        }
        return columns;
    }

    get unitTableColumns() {
        return this.unitCsvColumns.filter((column) => column.fieldName !== 'Name');
    }

    resolveUnitFieldValue(raw, column) {
        if (!raw) return null;
        if (column.fieldName === 'allocatedAgentName') {
            return raw.Allocate_to_Agent__r ? raw.Allocate_to_Agent__r.Name : null;
        }
        return column.fieldName.split('.').reduce((value, part) => (value == null ? value : value[part]), raw);
    }

    formatUnitFieldValue(raw, column) {
        const value = this.resolveUnitFieldValue(raw, column);
        if (value === null || value === undefined || value === '') return '-';
        if (column.isCurrency) return this.formatCurrencyFull(value);
        if (value === true) return 'Yes';
        if (value === false) return 'No';
        return String(value);
    }

    get selectedUnitFieldFacts() {
        const unit = this.selectedWorkspaceUnit;
        if (!unit) return [];
        const facts = this.unitCsvColumns
            .filter((column) => column.fieldName !== 'Name')
            .map((column) => ({
                key: column.fieldName,
                label: column.label,
                value: this.formatUnitFieldValue(unit.raw, column)
            }));
        // The header above the plan iframe is gone; its view descriptor lives
        // in this grid instead - unless the field set already surfaces one.
        const hasViewFact = facts.some((fact) => /view/i.test(fact.label) || /view/i.test(fact.key));
        if (!hasViewFact) {
            facts.push({ key: '__unit-view__', label: 'View', value: unit.viewLabel || '-' });
        }
        return facts;
    }

    get workspaceUnitCards() {
        const selected = this.selectedWorkspaceUnit;
        const selectedId = selected ? selected.id : '';
        const selectedForExport = new Set(this.selectedWorkspaceUnitIds);
        const expandedId = this.expandedUnitCardId;
        const isCompact = this.isCompactWorkspaceViewport;
        return this.paginatedUnitCards.map((unit) => ({
            ...unit,
            isExpanded: unit.id === expandedId,
            ariaExpanded: isCompact ? String(unit.id === expandedId) : null,
            detailsHintLabel: unit.id === expandedId ? 'Hide details' : 'View details',
            gridItemClassName:
                unit.id === expandedId
                    ? 'workspace-unit-grid__item workspace-unit-grid__item--expanded'
                    : 'workspace-unit-grid__item',
            detailsClassName:
                unit.id === expandedId
                    ? 'unit-choice__mobile-details'
                    : 'unit-choice__mobile-details unit-choice__mobile-details--collapsed',
            workspaceClassName:
                (unit.id === selectedId ? 'unit-tile unit-tile--selected' : 'unit-tile') +
                (unit.id === expandedId ? ' unit-tile--expanded' : ''),
            workspaceShellClassName:
                (selectedForExport.has(unit.id)
                    ? 'unit-tile-shell unit-tile-shell--selected-for-offer'
                    : 'unit-tile-shell') +
                (unit.id === expandedId ? ' unit-tile-shell--expanded' : ''),
            ariaPressed: unit.id === selectedId,
            isSelectedForExport: selectedForExport.has(unit.id),
            selectionLabel: selectedForExport.has(unit.id)
                ? `Remove ${unit.name} from offer selection`
                : `Add ${unit.name} to offer selection`,
            selectionTooltipLabel: 'Add to offer',
            selectionTooltipId: `unit-offer-tooltip-${unit.id}`,
            selectionActionClassName: selectedForExport.has(unit.id)
                ? 'unit-selection-action unit-selection-action--selected'
                : 'unit-selection-action',
            tableSelectionActionClassName: selectedForExport.has(unit.id)
                ? 'unit-table-selection unit-table-selection--selected'
                : 'unit-table-selection',
            selectionActionIcon: selectedForExport.has(unit.id) ? '✓' : '+',
            previewLabel: `View ${unit.name}`,
            tableCells: this.unitTableColumns.map((column) => ({
                key: `${unit.id}-${column.fieldName}`,
                value: this.formatUnitFieldValue(unit.raw, column)
            }))
        }));
    }

    get selectedWorkspaceUnit() {
        if (!this.filteredUnitCards.length) return null;
        return (
            this.filteredUnitCards.find((unit) => unit.id === this.workspaceSelectedUnitId) ||
            this.filteredUnitCards[0]
        );
    }

    get hasWorkspaceSelectedUnit() {
        return this.selectedWorkspaceUnit !== null;
    }

    get showUnitsWorkspaceFooter() {
        if (!this.isUnitsWorkspace) return false;
        if (this.isCompactWorkspaceViewport) {
            // The footer hosts the only filter trigger on touch, so it stays
            // while any units exist - even when active filters empty the
            // visible list (the trigger is the way back). It yields the
            // bottom edge to the filter sheet while that is open, so the
            // sheet's Clear/Apply can never be painted over.
            if (this.unitFilterPanelOpen) return false;
            return this.unitCards.length > 0;
        }
        return this.hasWorkspaceSelectedUnit;
    }

    get hasSelectedWorkspaceUnits() {
        return this.selectedWorkspaceUnitIds.length > 0;
    }

    get generateOfferFooterLabel() {
        // Touch-only count: the +/check action is small and instant, so the
        // footer echoes every add. The desktop footer label stays frozen.
        const count = this.selectedWorkspaceUnitIds.length;
        if (this.isCompactWorkspaceViewport && count > 0) {
            return `Generate Offer (${count})`;
        }
        return 'Generate Offer';
    }

    get isUnitSelectionEmpty() {
        return !this.hasSelectedWorkspaceUnits;
    }

    get isGuidedOfferFromUnitsDisabled() {
        return !this.hasSelectedWorkspaceUnits;
    }

    get guidedOfferFromUnitsTooltipLabel() {
        return 'Add a unit to offer first';
    }

    get guidedOfferFromUnitsTooltipId() {
        return 'prepare-offer-disabled-tooltip';
    }

    get guidedOfferFromUnitsTooltipDescribedBy() {
        return this.isGuidedOfferFromUnitsDisabled ? this.guidedOfferFromUnitsTooltipId : null;
    }

    get guidedOfferFromUnitsTooltipTabIndex() {
        return this.isGuidedOfferFromUnitsDisabled ? '0' : '-1';
    }

    get isFilteredUnitEmpty() {
        return this.filteredUnitCards.length === 0;
    }

    get unitAppliedFilterCount() {
        const activeFilters = [
            this.unitTypeFilter,
            this.unitProjectFilter,
            this.unitBedroomFilter,
            this.unitStatusFilter
        ].filter((value) => value !== 'all').length;
        return activeFilters + (this.unitSortMode !== 'newest' ? 1 : 0);
    }

    get showUnitAppliedFilterCount() {
        return this.unitAppliedFilterCount > 0;
    }

    get unitFilterButtonClass() {
        return this.unitFilterPanelOpen || this.showUnitAppliedFilterCount
            ? 'unit-filter-trigger unit-filter-trigger--active'
            : 'unit-filter-trigger';
    }

    get unitFilterFooterButtonClass() {
        return `${this.unitFilterButtonClass} unit-filter-trigger--footer`;
    }

    get unitFilterTypeOptions() {
        const pendingValue = this.pendingUnitTypeFilter || this.unitTypeFilter || 'all';
        const availableKeys = new Set(this.pendingUnitTypeOptions.map((option) => option.key));
        const normalizedPendingValue = availableKeys.has(pendingValue) ? pendingValue : 'all';
        return this.pendingUnitTypeOptions.map((option) => ({
            ...option,
            className:
                option.key === normalizedPendingValue
                    ? 'unit-filter-choice unit-filter-choice--active'
                    : 'unit-filter-choice',
            isActive: option.key === normalizedPendingValue
        }));
    }

    get unitProjectOptions() {
        return this.buildOptions(this.unitCards, 'projectKey', 'projectLabel', 'All projects');
    }

    get pendingUnitProjectSelectOptions() {
        return this.withSelectedOption(this.pendingUnitProjectOptions, this.pendingUnitProjectFilter);
    }

    get pendingUnitProjectOptions() {
        return this.buildOptions(
            this.filterUnitCardsByCoreFilters(this.unitCards, {
                bedroomFilter: this.pendingUnitBedroomFilter,
                statusFilter: this.pendingUnitStatusFilter
            }),
            'projectKey',
            'projectLabel',
            'All projects'
        );
    }

    get unitBedroomOptions() {
        return this.buildBedroomOptions(this.unitCards);
    }

    get pendingUnitBedroomSelectOptions() {
        return this.withSelectedOption(this.pendingUnitBedroomOptions, this.pendingUnitBedroomFilter);
    }

    get pendingUnitBedroomOptions() {
        return this.buildBedroomOptions(
            this.filterUnitCardsByCoreFilters(this.unitCards, {
                projectFilter: this.pendingUnitProjectFilter,
                statusFilter: this.pendingUnitStatusFilter
            })
        );
    }

    get unitStatusOptions() {
        return this.buildOptions(this.unitCards, 'statusKey', 'statusLabel', 'All statuses');
    }

    get pendingUnitStatusSelectOptions() {
        return this.withSelectedOption(this.pendingUnitStatusOptions, this.pendingUnitStatusFilter);
    }

    get pendingUnitStatusOptions() {
        return this.buildOptions(
            this.filterUnitCardsByCoreFilters(this.unitCards, {
                projectFilter: this.pendingUnitProjectFilter,
                bedroomFilter: this.pendingUnitBedroomFilter
            }),
            'statusKey',
            'statusLabel',
            'All statuses'
        );
    }

    buildBedroomOptions(items) {
        const counts = {};
        items.forEach((unit) => {
            const key = String(unit.bedroomValue);
            const label = unit.bedroomLabel || 'Not specified';
            if (!counts[key]) counts[key] = { key, label, count: 0, sortValue: unit.bedroomValue };
            counts[key].count += 1;
        });
        return [
            { key: 'all', label: 'All bedrooms', count: items.length },
            ...Object.values(counts).sort((a, b) => a.sortValue - b.sortValue)
        ];
    }

    get pendingUnitSortSelectOptions() {
        return UNIT_SORT_OPTIONS.map((option) => ({
            ...option,
            isSelected: option.value === this.pendingUnitSortMode
        }));
    }

    get unitSortOptions() {
        return UNIT_SORT_OPTIONS.map((option) => ({
            ...option,
            isActive: option.value === this.unitSortMode
        }));
    }

    withSelectedOption(options, selectedValue) {
        const value = selectedValue || 'all';
        return options.map((option) => ({
            ...option,
            isSelected: option.key === value
        }));
    }

    get paginatedUnitCards() {
        const start = (this.unitPage - 1) * UNIT_PAGE_SIZE;
        return this.filteredUnitCards.slice(start, start + UNIT_PAGE_SIZE);
    }

    get unitTotalPages() {
        return Math.max(1, Math.ceil(this.filteredUnitCards.length / UNIT_PAGE_SIZE));
    }

    get unitPaginationLabel() {
        if (!this.filteredUnitCards.length) return '0 units';
        const start = (this.unitPage - 1) * UNIT_PAGE_SIZE + 1;
        const end = Math.min(this.unitPage * UNIT_PAGE_SIZE, this.filteredUnitCards.length);
        return `${start}-${end} of ${this.filteredUnitCards.length}`;
    }

    get isFirstUnitPage() {
        return this.unitPage <= 1;
    }

    get isLastUnitPage() {
        return this.unitPage >= this.unitTotalPages;
    }

    get activeUnitFilterChips() {
        const chips = [];
        if (this.searchQuery.trim()) chips.push({ key: 'search', label: `Search: ${this.searchQuery.trim()}` });
        this.addUnitChip(chips, 'type', this.unitTypeFilter, this.unitTypeOptions, 'Unit type');
        this.addUnitChip(chips, 'project', this.unitProjectFilter, this.unitProjectOptions, 'Project');
        this.addUnitChip(chips, 'bedrooms', this.unitBedroomFilter, this.unitBedroomOptions, 'Bedrooms');
        this.addUnitChip(chips, 'status', this.unitStatusFilter, this.unitStatusOptions, 'Status');
        if (this.unitSortMode !== 'newest') {
            const option = UNIT_SORT_OPTIONS.find((item) => item.value === this.unitSortMode);
            if (option) chips.push({ key: 'sort', label: `Sort: ${option.label}` });
        }
        return chips;
    }

    get showActiveUnitFilterChips() {
        return this.activeUnitFilterChips.length > 0;
    }

    buildOptions(items, keyProp, labelProp, allLabel) {
        const counts = {};
        items.forEach((item) => {
            const key = item[keyProp] || 'not-specified';
            if (!counts[key]) counts[key] = { key, label: item[labelProp] || 'Not specified', count: 0 };
            counts[key].count += 1;
        });
        return [
            { key: 'all', label: allLabel, count: items.length },
            ...Object.values(counts).sort((a, b) => a.label.localeCompare(b.label))
        ];
    }

    addUnitChip(chips, key, value, options, label) {
        if (value === 'all') return;
        const option = options.find((item) => item.key === value);
        if (option) chips.push({ key, label: `${label}: ${option.label}` });
    }

    handleExportSelectedUnits() {
        const selected = new Set(this.selectedWorkspaceUnitIds);
        const units = this.unitCards.filter((unit) => selected.has(unit.id));
        if (!units.length) return;
        this.downloadUnitCsv(units, 'modon-selected-units.csv');
    }

    handleExportAllUnits() {
        if (!this.filteredUnitCards.length) return;
        this.downloadUnitCsv(this.filteredUnitCards, 'modon-units.csv');
    }

    downloadUnitCsv(units, fileName) {
        if (this.hasUnitFieldSetColumns) {
            const columns = this.unitCsvColumns;
            const headers = columns.map((column) => column.label);
            const rows = units.map((unit) => columns.map((column) => this.formatUnitFieldValue(unit.raw, column)));
            const csv = [
                headers.map((value) => this.escapeCsvValue(value)).join(','),
                ...rows.map((row) => row.map((value) => this.escapeCsvValue(value)).join(','))
            ].join('\n');
            this.triggerDownload(new Blob([`\uFEFF${csv}`], { type: 'text/plain' }), fileName);
            return;
        }
        const headers = ['Unit', 'Project', 'View', 'Bedrooms', 'Area', 'Price', 'Status', 'Floor', 'Plan URL'];
        const rows = units.map((unit) => [
            unit.name,
            unit.phaseLabel,
            unit.viewLabel,
            unit.bedroomLabel,
            unit.totalAreaLabel,
            unit.priceFull,
            unit.statusLabel,
            unit.floorLabel,
            unit.tourUrl
        ]);
        const csv = [
            headers.map((value) => this.escapeCsvValue(value)).join(','),
            ...rows.map((row) => row.map((value) => this.escapeCsvValue(value)).join(','))
        ].join('\n');
        this.triggerDownload(new Blob([`\uFEFF${csv}`], { type: 'text/plain' }), fileName);
    }

    escapeCsvValue(value) {
        const text = String(value ?? '');
        return `"${text.replace(/"/g, '""')}"`;
    }

    /* ---------------------------------------------------------------- */
    /* Marketing library                                                */
    /* ---------------------------------------------------------------- */

    get isPropertiesUnitsTab() {
        return this.propertiesWorkspaceTab === 'units';
    }

    get isPropertiesMarketingTab() {
        return this.propertiesWorkspaceTab === 'marketing';
    }

    get propertiesUnitsTabClass() {
        return this.isPropertiesUnitsTab ? 'properties-tab properties-tab--active' : 'properties-tab';
    }

    get propertiesMarketingTabClass() {
        return this.isPropertiesMarketingTab ? 'properties-tab properties-tab--active' : 'properties-tab';
    }

    handlePropertiesTab(event) {
        const tab = event.currentTarget.dataset.tab || 'units';
        this.propertiesWorkspaceTab = tab;
        if (tab === 'marketing' && !this.marketingProjects.length && !this.marketingError) {
            this.loadMarketingProjects();
        }
    }

    get filteredMarketingProjects() {
        const query = this.marketingSearchQuery.trim().toLowerCase();
        return this.marketingProjects
            .filter((project) => !query || project.name.toLowerCase().includes(query))
            .map((project) => ({
                ...project,
                isActive: project.id === this.selectedMarketingProjectId,
                className:
                    project.id === this.selectedMarketingProjectId
                        ? 'marketing-project marketing-project--selected'
                        : 'marketing-project'
            }));
    }

    get selectedMarketingProject() {
        return this.marketingProjects.find((project) => project.id === this.selectedMarketingProjectId) || null;
    }

    get selectedMarketingProjectName() {
        return this.selectedMarketingProject ? this.selectedMarketingProject.name : 'Select a project';
    }

    get showMarketingProjectEmpty() {
        return !this.isMarketingLoading && !this.marketingError && this.marketingProjects.length === 0;
    }

    get showMarketingProjectNoMatch() {
        return !this.isMarketingLoading && this.marketingProjects.length > 0 && this.filteredMarketingProjects.length === 0;
    }

    get marketingSections() {
        return MARKETING_SECTION_CONFIG.map((config, index) => {
            const files = this.marketingDocuments[config.key]?.[0]?.files || [];
            const isSelected = this.selectedMarketingSections.includes(config.key);
            return {
                ...config,
                count: files.length,
                summary: files.length ? `${files.length} file${files.length === 1 ? '' : 's'} available` : config.emptyLabel,
                files: files.slice(0, 3),
                moreLabel: files.length > 3 ? `+${files.length - 3} more` : '',
                hasFiles: files.length > 0,
                isDisabled: files.length === 0,
                isSelected,
                className: isSelected ? 'marketing-section marketing-section--selected' : 'marketing-section',
                checkboxId: `marketing-section-${index}`,
                // BP-077
                linkUrl: this.isMarketingLinksProject ? marketingLinkFor(config.key) : '',
                linkDisabled: !(this.isMarketingLinksProject && marketingLinkFor(config.key))
            };
        });
    }

    // BP-077: the Dropbox buttons are live only for the project named in the label.
    get isMarketingLinksProject() {
        const selected = this.selectedMarketingProject;
        const target = String(MARKETING_LINKS_PROJECT || '').trim().toLowerCase();
        return Boolean(selected && target && String(selected.name || '').trim().toLowerCase() === target);
    }

    // BP-077: opens the section's Dropbox link in a new tab. Re-validates the link so a
    // disabled or tampered button can never open anything.
    handleOpenMarketingLink(event) {
        const key = event.currentTarget.dataset.section;
        if (!this.isMarketingLinksProject) return;
        const url = marketingLinkFor(key);
        if (!url) return;
        window.open(url, '_blank', 'noopener,noreferrer');
    }

    get hasMarketingFiles() {
        return this.marketingSections.some((section) => section.hasFiles);
    }

    get isMarketingSelectAllDisabled() {
        return this.isMarketingDocumentsLoading || !this.hasMarketingFiles;
    }

    get hasSelectedMarketingSections() {
        return this.selectedMarketingSections.length > 0;
    }

    get selectedMarketingSectionCountLabel() {
        const count = this.selectedMarketingSections.length;
        if (count === 0) return 'No sections selected';
        if (count === 1) return '1 section selected';
        return `${count} sections selected`;
    }

    get showMarketingWorkspaceFooter() {
        return this.isUnitsWorkspace && this.isPropertiesMarketingTab && this.hasSelectedMarketingSections;
    }

    get showMarketingDrawerFooter() {
        return this.isMarketingWorkspace && this.hasSelectedMarketingSections;
    }

    get marketingDownloadLabel() {
        return this.marketingDownloadBusy ? 'Preparing download' : 'Download selected';
    }

    handleMarketingSearchInput(event) {
        this.marketingSearchQuery = event.target.value || '';
    }

    handleMarketingSearchClear() {
        this.marketingSearchQuery = '';
        const input = this.template.querySelector('.marketing-search__input');
        if (input) input.focus();
    }

    handleRetryMarketingProjects() {
        this.loadMarketingProjects();
    }

    handleRetryMarketingDocuments() {
        this.loadMarketingDocuments(this.selectedMarketingProjectId);
    }

    handleSelectMarketingProject(event) {
        const id = event.currentTarget.dataset.id;
        if (!id || id === this.selectedMarketingProjectId) return;
        this.selectedMarketingProjectId = id;
        this.loadMarketingDocuments(id);
    }

    handleMarketingSectionToggle(event) {
        const section = event.target.dataset.section;
        if (!section) return;
        const selected = new Set(this.selectedMarketingSections);
        if (event.target.checked) {
            selected.add(section);
        } else {
            selected.delete(section);
        }
        this.selectedMarketingSections = [...selected];
    }

    handleMarketingSelectAll(event) {
        if (event.target.checked) {
            this.selectedMarketingSections = this.marketingSections
                .filter((section) => section.hasFiles)
                .map((section) => section.key);
        } else {
            this.selectedMarketingSections = [];
        }
    }

    get isMarketingAllSelected() {
        const available = this.marketingSections.filter((section) => section.hasFiles);
        return available.length > 0 && available.every((section) => this.selectedMarketingSections.includes(section.key));
    }

   async handleDownloadSelectedMarketing() {
    if (!this.hasSelectedMarketingSections || this.marketingDownloadBusy) return;
    this.marketingDownloadBusy = true;
    try {
        await this.ensureZipLoaded();
        const files = this.selectedMarketingSections.flatMap(
            (section) => this.marketingDocuments[section]?.[0]?.files || []
        );

        // Route large files to direct browser download instead of the zip pipeline
        const zippable = [];
        const large = [];
        files.forEach((f) => (f.contentSize > ZIP_SIZE_THRESHOLD ? large.push(f) : zippable.push(f)));

        large.forEach((f) => window.open(f.downloadUrl, '_blank'));

        if (zippable.length) {
            await this.downloadFilesAsZip(zippable, `${this.safeFileName(this.selectedMarketingProjectName)}_Marketing.zip`);
        }
    } finally {
        this.marketingDownloadBusy = false;
    }
}

    ensureZipLoaded() {
        if (window.JSZip) return Promise.resolve();
        if (!this._zipPromise) {
            this._zipPromise = loadScript(this, JSZIP);
        }
        return this._zipPromise;
    }

    async downloadFilesAsZip(files, fileName) {
        const zip = new window.JSZip();
        const folderName = this.safeFileName(this.selectedMarketingProjectName);
        const failedFiles = [];

        for (const file of files) {
            try {
                const response = await fetch(file.downloadUrl);
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
                const blob = await response.blob();
                const extension = file.fileExtension ? `.${file.fileExtension}` : '';
                zip.file(`${folderName}/${this.safeFileName(file.title)}${extension}`, await blob.arrayBuffer());
            } catch (error) {
                // Public Content Distribution download links can occasionally fail a
                // same-page fetch() (network hiccup, an expired/edge-case link, etc)
                // even though the link itself opens fine as a normal browser
                // navigation. Tracked here rather than dropped, so every file still
                // ends up in the same zip via the server-side fallback below.
                failedFiles.push(file);
            }
        }

        // Server-side fallback: Apex has direct access to ContentVersion.VersionData
        // regardless of any browser fetch restriction, so anything the browser
        // couldn't fetch itself gets pulled this way instead and merged into the
        // SAME zip — one single, complete Dropbox-style download every time,
        // never a partial zip plus separate tabs.
        if (failedFiles.length > 0) {
            try {
                const contentVersionIds = failedFiles.map((file) => file.contentVersionId).filter(Boolean);
                if (contentVersionIds.length > 0) {
                    const contents = await getFileContentAsBase64({ contentVersionIds });
                    const base64ByVersionId = new Map(
                        (Array.isArray(contents) ? contents : []).map((item) => [item.contentVersionId, item.base64Data])
                    );
                    failedFiles.forEach((file) => {
                        const base64Data = base64ByVersionId.get(file.contentVersionId);
                        if (!base64Data) return;
                        const extension = file.fileExtension ? `.${file.fileExtension}` : '';
                        zip.file(`${folderName}/${this.safeFileName(file.title)}${extension}`, base64Data, { base64: true });
                    });
                }
            } catch (error) {
                // If even the server-side fallback fails, those specific files are
                // simply absent from the zip rather than blocking the rest of it.
            }
        }

        // Only build/trigger the zip if at least one file actually made it in —
        // an empty zip is exactly the "nothing downloaded" symptom this replaces.
        if (Object.keys(zip.files).length > 0) {
            const content = await zip.generateAsync({ type: 'blob', mimeType: 'application/zip' });
            this.triggerDownload(content, fileName);
        }
    }

    triggerDownload(blob, fileName) {
        let url;
        try {
            url = URL.createObjectURL(blob);
            const anchor = document.createElement('a');
            anchor.href = url;
            anchor.download = fileName;
            anchor.style.display = 'none';
            document.body.appendChild(anchor);
            anchor.click();
            document.body.removeChild(anchor);
        } catch (error) {
            // Keep the portal stable if the browser or Lightning Web Security
            // rejects a generated file. The supported MIME types above should
            // prevent this path for CSV and ZIP downloads.
        } finally {
            if (url) {
                window.setTimeout(() => URL.revokeObjectURL(url), 0);
            }
        }
    }

    safeFileName(value) {
        return String(value || 'MODON')
            .trim()
            .replace(/[^a-z0-9-_]+/gi, '_')
            .replace(/^_+|_+$/g, '') || 'MODON';
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    /* ---------------------------------------------------------------- */
    /* Leads                                                            */
    /* ---------------------------------------------------------------- */

    /* BP-037: every reader of the home lead list goes through this getter. */
    get activeLeadRecords() {
        return this.leadRecords.filter((lead) => !isConvertedLead(lead));
    }

    get leadsCount() {
        return this.activeLeadRecords.length;
    }


    get leadPanelTitle() {
        return 'Leads';
    }

    get isAgencyLeadView() {
        return this.brokerType === 'Owner' || this.brokerType === 'Agency Admin';
    }

    get leadScopeLabel() {
        if (this.isAgencyLeadView) {
            return `${LEADS_PERIOD} agency activity`;
        }
        return `${LEADS_PERIOD} personal activity`;
    }

    get hasLeads() {
        return !this.isLeadsLoading && !this.leadsError && this.activeLeadRecords.length > 0;
    }

    get showLeadsEmpty() {
        return !this.isLeadsLoading && !this.leadsError && this.activeLeadRecords.length === 0;
    }

    get leadCards() {
        return this.activeLeadRecords.map((lead, index) => {
            const name = this.getLeadName(lead);
            const status = lead.Status || 'New';
            const project = lead.Project || lead.ProjectInterest;
            const meta = [project, lead.UnitType].filter(Boolean).join(' · ') || 'Requirement not specified';
            const childCount = Array.isArray(lead.children) ? lead.children.length : 0;
            return {
                id: lead.Id,
                key: lead.Id || `${name}-${index}`,
                name,
                initials: this.getInitials(name),
                leadNumber: lead.LeadNumber || 'Lead',
                statusLabel: leadStatusLabel(status),
                statusClass: this.getLeadStatusClass(status),
                statusTone: this.getLeadStatusTone(status),
                meta,
                agentName: lead.AgentName || '',
                createdLabel: this.formatShortDate(lead.CreatedDate),
                contactLabel: [lead.Email, lead.Mobile].filter(Boolean).join(' · ') || 'Contact details restricted',
                childCount,
                hasChildren: childCount > 1,
                childLabel: childCount > 1 ? `${childCount} related enquiries` : '',
                cardStyle: `--reveal-index: ${index}`
            };
        });
    }

    get recentLeadCards() {
        return this.leadCards.slice(0, 4);
    }

    get leadFocusCard() {
        return this.leadCards[0] || null;
    }

    get hasLeadFocusCard() {
        return this.leadFocusCard !== null;
    }

    get leadPrimaryStatusLabel() {
        const firstSegment = this.leadStatusSegments[0];
        if (!firstSegment) return 'No active status';
        return `${firstSegment.value} ${firstSegment.label}`;
    }

    get leadStatusSegments() {
        const counts = {};
        this.leadCards.forEach((lead) => {
            const status = lead.statusLabel || 'New';
            counts[status] = (counts[status] || 0) + 1;
        });

        return Object.keys(counts)
            .sort((a, b) => counts[b] - counts[a])
            .slice(0, 3)
            .map((label) => ({
                key: label,
                label,
                value: counts[label],
                className: this.getLeadStatusClass(label),
                tone: this.getLeadStatusTone(label)
            }));
    }


    getLeadName(lead) {
        const fullName = [lead.FirstName, lead.LastName].filter(Boolean).join(' ').trim();
        return fullName || lead.Name || 'Unnamed lead';
    }

    getLeadStatusClass(status) {
        return `lead-status lead-status--${this.getLeadStatusTone(status)}`;
    }

    getLeadStatusTone(status) {
        const key = String(status || '').toLowerCase();
        let tone = 'neutral';
        if (key.includes('new') || key.includes('open') || key.includes('working')) {
            tone = 'active';
        } else if (key.includes('qualified') || key.includes('converted')) {
            tone = 'success';
        } else if (key.includes('closed') || key.includes('retired') || key.includes('unqualified')) {
            tone = 'muted';
        }
        return tone;
    }

    getInitials(name) {
        return String(name || 'L')
            .split(/\s+/)
            .filter(Boolean)
            .slice(0, 2)
            .map((part) => part[0])
            .join('')
            .toUpperCase();
    }

    /* ---------------------------------------------------------------- */
    /* Navigation                                                       */
    /* ---------------------------------------------------------------- */

    handleQuickAccessKeydown(event) {
        if (event.key !== 'Escape') return;

        if (this.isAccountMenuOpen) {
            this.closeAccountMenu();
            event.currentTarget.focus();
            event.preventDefault();
        }
        this.dismissedQuickAccessTooltip = event.currentTarget.dataset.id || '';
        event.stopPropagation();
    }

    handleQuickAccessTooltipReset(event) {
        if (this.dismissedQuickAccessTooltip !== event.currentTarget.dataset.id) return;
        this.dismissedQuickAccessTooltip = '';
    }

    handleQuickAccessClick(event) {
        const action = event.currentTarget.dataset.action;
        if (action === 'theme') {
            this.handleThemeToggle();
            return;
        }
        if (action === 'accountMenu') {
            event.stopPropagation();
            this.activeUtilityPanel = null;
            this.isAccountMenuOpen = !this.isAccountMenuOpen;
            this.dismissedQuickAccessTooltip = this.isAccountMenuOpen ? 'profile' : '';
            return;
        }

        const panel = event.currentTarget.dataset.panel;
        if (!panel) return;
        if (!this.canOpenUtilityPanel(panel)) {
            this.closeAccountMenu();
            return;
        }
        this.closeAccountMenu();
        this._utilityLastFocusedElement = event.currentTarget;
        this.activeUtilityPanel = panel;
    }

    handleAccountMenuClick(event) {
        event.stopPropagation();
    }

    handleAccountMenuThemeToggle(event) {
        event.stopPropagation();
        this.handleThemeToggle();
    }

    closeAccountMenu() {
        this.isAccountMenuOpen = false;
        if (this.dismissedQuickAccessTooltip === 'profile') {
            this.dismissedQuickAccessTooltip = '';
        }
    }

    handleAccountMenuDocumentClick(event) {
        if (!this.isAccountMenuOpen && !this.isAspirePopoverOpen) return;
        const path = typeof event.composedPath === 'function' ? event.composedPath() : [];
        if (this.isAccountMenuOpen) {
            const clickedInsideMenu = path.some((node) => {
                const classList = node?.classList;
                return (
                    classList?.contains?.('quick-access__item--account') ||
                    classList?.contains?.('account-menu-card') ||
                    classList?.contains?.('account-menu-sheet')
                );
            });
            if (!clickedInsideMenu) {
                this.closeAccountMenu();
            }
        }
        if (this.isAspirePopoverOpen) {
            const clickedInsidePopover = path.some((node) => {
                const classList = node?.classList;
                return (
                    classList?.contains?.('aspire-pill-wrap') ||
                    classList?.contains?.('aspire-pop')
                );
            });
            if (!clickedInsidePopover) {
                this.closeAspirePopover(false);
            }
        }
    }

    /* A workspace child asking for a utility panel, currently commissions
       sending a broker to My Agency for a VAT certificate. The panel name is
       whitelisted against utilityPanelConfig rather than trusted.

       No opener is recorded: the request came from a dialog that has already
       closed, so _utilityLastFocusedElement is cleared rather than left
       pointing at a stale element. */
    handleOpenUtilityPanelRequest(event) {
        const panel = event && event.detail ? event.detail.panel : '';
        if (!panel || !Object.prototype.hasOwnProperty.call(UTILITY_PANELS, panel)) return;
        if (!this.canOpenUtilityPanel(panel)) return;
        this.closeAccountMenu();
        this._utilityLastFocusedElement = null;
        this.activeUtilityPanel = panel;
    }

    handleCloseUtilityPanel() {
        this.activeUtilityPanel = null;
        if (this._utilityLastFocusedElement && this._utilityLastFocusedElement.isConnected) {
            this._utilityLastFocusedElement.focus();
        }
        this._utilityLastFocusedElement = null;
    }

    handleOpenCommandWorkspace(event) {
        const workspace = event.currentTarget.dataset.workspace;
        if (!workspace) return;
        this._workspaceLastFocusedElement = event.currentTarget;
        this.activeUtilityPanel = null;
        this.salesWorkspaceIntent = '';
        this.salesWorkspaceIntentToken = '';
        this.activeCommandWorkspace = workspace;
        if (workspace === 'marketing') {
            this.ensureMarketingLibraryLoaded();
        }
        if (workspace === 'revenue') {
            this.revenueView = 'dashboard';
        }
        if (workspace === 'units') {
            this.propertiesWorkspaceTab = 'units';
            if (!this.workspaceSelectedUnitId && this.filteredUnitCards.length) {
                this.workspaceSelectedUnitId = this.filteredUnitCards[0].id;
            }
        }
    }

    handleCommandCardOpen(event) {
        if (this.shouldIgnoreCommandCardOpen(event)) return;
        this.openCommandWorkspaceFromElement(event.currentTarget);
    }

    handleCommandCardKeydown(event) {
        if (event.key !== 'Enter' && event.key !== ' ') return;
        if (this.shouldIgnoreCommandCardOpen(event)) return;
        event.preventDefault();
        this.openCommandWorkspaceFromElement(event.currentTarget);
    }

    shouldIgnoreCommandCardOpen(event) {
        const target = event.target;
        if (target?.closest?.('button, a, input, select, textarea, lightning-button, c-mbpr_empty-state')) {
            return true;
        }

        const workspace = event.currentTarget?.dataset?.workspace;
        if (workspace === 'units') {
            return this.isUnitsLoading || this.unitsError;
        }
        if (workspace === 'sales') {
            return this.isLeadsLoading || this.leadsError;
        }
        if (workspace === 'revenue') {
            return this.isSalesLoading || this.salesError;
        }
        return false;
    }

    openCommandWorkspaceFromElement(element) {
        const workspace = element?.dataset?.workspace;
        if (!workspace) return;
        // Fast-Track may open Leads only; Limited may open nothing.
        if (!this.canOpenCommandWorkspace(workspace)) return;
        this._workspaceLastFocusedElement = element;
        this.activeUtilityPanel = null;
        this.salesWorkspaceIntent = '';
        this.salesWorkspaceIntentToken = '';
        this.activeCommandWorkspace = workspace;
        if (workspace === 'marketing') {
            this.ensureMarketingLibraryLoaded();
        }
        if (workspace === 'revenue') {
            this.revenueView = 'dashboard';
        }
        if (workspace === 'units') {
            this.propertiesWorkspaceTab = 'units';
            if (!this.workspaceSelectedUnitId && this.filteredUnitCards.length) {
                this.workspaceSelectedUnitId = this.filteredUnitCards[0].id;
            }
        }
    }

    handleCloseCommandWorkspace() {
        this.expandedUnitCardId = '';
        this.activeCommandWorkspace = null;
        // The sales workspace unmounts on close, so its header chrome state
        // must reset with it - a reopen starts from the dashboard defaults.
        this.salesPerfChrome = { showAgentPicker: false, agentOptions: [], filterLabel: 'All Time', filterIsDefault: true };
        if (this._workspaceLastFocusedElement && this._workspaceLastFocusedElement.isConnected) {
            this._workspaceLastFocusedElement.focus();
        }
        this._workspaceLastFocusedElement = null;
    }

    get isUtilityDrawerOpen() {
        return this.activeUtilityPanel !== null;
    }

    get utilityPanelConfig() {
        return UTILITY_PANELS[this.activeUtilityPanel] || UTILITY_PANELS.help;
    }

    get utilityDrawerTitle() {
        return this.utilityPanelConfig.title;
    }

    get utilityDrawerEyebrow() {
        return this.utilityPanelConfig.eyebrow;
    }

    get utilityDrawerSubtitle() {
        return this.utilityPanelConfig.subtitle;
    }

    get utilityDrawerSize() {
        if (this.isUpdatesPanel) return 'wide';
        if (this.isMyAgencyPanel) return 'wide';
        if (this.isHelpPanel) return 'wide';
        return 'standard';
    }

    /** Marker class on the shared utility drawer. Only the Updates panel opts
     *  into the drawer's real-width hook (see the CSS rule of the same name);
     *  the other panels keep the drawer's default width. */
    get utilityDrawerClass() {
        return this.isUpdatesPanel ? 'utility-drawer utility-drawer--updates' : 'utility-drawer';
    }

    get isUpdatesPanel() {
        return this.activeUtilityPanel === 'updates';
    }

    get isMyAgencyPanel() {
        return this.activeUtilityPanel === 'myagency';
    }

    get isProfilePanel() {
        return this.activeUtilityPanel === 'profile';
    }

    get isHelpPanel() {
        return this.activeUtilityPanel === 'help';
    }

    get isTrainingPanel() {
        return this.activeUtilityPanel === 'training';
    }

    get brokerTypeLabel() {
        return this.brokerType || 'Broker partner';
    }

    get effectiveSignOutUrl() {
        if (this.signOutUrl) return this.signOutUrl;
        // The logout servlet must be hit on the SITE path (e.g.
        // /Brokers/secur/logout.jsp) - the domain-root servlet ends the org
        // session outside the community context and misses the site login.
        // basePath resolves per environment (sandbox/prod), no hardcoding.
        const sitePrefix = basePath || '';
        return `${sitePrefix}/secur/logout.jsp?retUrl=${encodeURIComponent(`${sitePrefix}/login`)}`;
    }

    get canSeeCommissionLanguage() {
        return (
            this.brokerContentAllowed &&
            !this.isLimitedUser &&
            (this.brokerType === 'Owner' || this.brokerType === 'Agency Admin')
        );
    }

    // Client rule (2026-08-08): Agents see nothing sales-related - no sales
    // card, no revenue workspace, no charts.
    get isOwnerBroker() {
        return this.brokerType === 'Owner';
    }

    // Client rule (2026-09-08): Aspire status is for Owners and Agency Admins;
    // Agents never see it. Same two types Draftstagecontroller.shouldShowAspireLogo
    // already uses for the header logo, so pill and logo agree.
    get isAspireEligibleBrokerType() {
        return this.brokerType === 'Owner' || this.brokerType === 'Agency Admin';
    }

    /* Reads the STORED classification (currentTier), not normalizedCurrentTier -
       that one promotes a broker client-side on sales volume, and a Standard
       agency the org never promoted must not see Aspire. Starts as 'Standard'
       until loadTier resolves, so nothing renders before the answer is known. */
    get isAspireMember() {
        return ASPIRE_TIERS.includes(this.normalizeTierName(this.currentTier));
    }

    get showAspireStatus() {
        return (
            this.isAspireEligibleBrokerType &&
            this.brokerContentAllowed &&
            !this.isLimitedUser &&
            this.isAspireMember
        );
    }

    get showSalesCard() {
        return this.canSeeCommissionLanguage;
    }

    // Legacy nav names, following the active view (Dashboard and
    // Commissions were separate destinations in the legacy portal).
    get revenueWorkspaceTitle() {
        return this.revenueView === 'commissions' ? 'Commissions' : 'Dashboard';
    }

    get isCommandWorkspaceOpen() {
        return this.activeCommandWorkspace !== null;
    }

    get commandWorkspaceConfig() {
        const configs = {
            units: {
                eyebrow: '',
                title: 'Available Units',
                subtitle: ''
            },
            sales: {
                eyebrow: '',
                title: 'Leads',
                subtitle: ''
            },
            marketing: {
                eyebrow: '',
                title: 'Marketing Library',
                subtitle: ''
            },
            eoi: {
                eyebrow: '',
                title: 'Expression of Interest',
                subtitle: ''
            },
            revenue: {
                eyebrow: '',
                title: this.revenueWorkspaceTitle,
                subtitle: ''
            }
        };
        return configs[this.activeCommandWorkspace] || configs.sales;
    }

    get commandWorkspaceTitle() {
        return this.commandWorkspaceConfig.title;
    }

    get commandWorkspaceEyebrow() {
        return this.commandWorkspaceConfig.eyebrow;
    }

    get commandWorkspaceSubtitle() {
        return this.commandWorkspaceConfig.subtitle;
    }

    get commandWorkspaceSize() {
        return this.isUnitsWorkspace ||
            this.isSalesWorkspace ||
            this.isMarketingWorkspace ||
            this.isEoiWorkspace ||
            (this.isRevenueWorkspace && this.canSeeCommissionLanguage)
            ? 'full'
            : 'large';
    }

    get isUnitsWorkspace() {
        return this.activeCommandWorkspace === 'units';
    }

    get isMarketingWorkspace() {
        return this.activeCommandWorkspace === 'marketing';
    }

    get isEoiWorkspace() {
        return this.activeCommandWorkspace === 'eoi';
    }

    get isRevenueDashboardView() {
        return this.revenueView !== 'commissions';
    }

    get revenueViewTabs() {
        return [
            { key: 'dashboard', label: 'Dashboard' },
            { key: 'commissions', label: 'Commissions' }
        ].map((tab) => ({
            ...tab,
            className:
                (tab.key === 'commissions') === !this.isRevenueDashboardView
                    ? 'revenue-tab revenue-tab--active'
                    : 'revenue-tab',
            ariaSelected: (tab.key === 'commissions') === !this.isRevenueDashboardView
        }));
    }

    handleRevenueViewChange(event) {
        const view = event.currentTarget.dataset.view;
        if (!view || view === this.revenueView) return;
        this.revenueView = view;
    }

    /* The revenue tabs live in the modal's header-actions slot, so the
       header row is the segmented control itself. The Filters chip proxies
       the dashboard child's own filter panel (label arrives by event). */
    revenueFilterLabel = '';
    revenueFilterIsDefault = true;

    get showRevenueHeaderActions() {
        return this.isRevenueWorkspace && this.canSeeCommissionLanguage;
    }

    get revenueFilterChipClass() {
        return this.revenueFilterIsDefault
            ? 'revenue-filter-chip'
            : 'revenue-filter-chip revenue-filter-chip--active';
    }

    handleRevenueFilterLabelChange(event) {
        const detail = event.detail || {};
        this.revenueFilterLabel = detail.label || '';
        this.revenueFilterIsDefault = detail.isDefault !== false;
    }

    handleRevenueFilterChipClick(event) {
        const dashboard = this.template.querySelector('c-mbpr_dashboard-workspace');
        if (dashboard && typeof dashboard.toggleFilters === 'function') {
            dashboard.toggleFilters(this.headerFilterAnchor(event));
        }
    }

    /* The chips live in this component's modal header while the popovers render
       inside the hosted dashboards, so the measured rect lets each panel open
       under its chip. Desktop only; compact keeps the dashboards' own layouts. */
    headerFilterAnchor(event) {
        if (this.isCompactWorkspaceViewport) return null;
        const chip = event && event.currentTarget;
        if (!chip || typeof chip.getBoundingClientRect !== 'function') return null;
        const rect = chip.getBoundingClientRect();
        return { bottom: rect.bottom, right: rect.right };
    }

    /* The child dispatches its tab state; on compact the modal header hosts the
       pills and proxies clicks back through setActiveTab. Desktop keeps the
       child's console bar, so the pills are compact-gated. */
    salesHeaderTabs = [];

    handleSalesTabsState(event) {
        const tabs = (event.detail && event.detail.tabs) || [];
        this.salesHeaderTabs = tabs.map((tab) => ({
            ...tab,
            label: String(tab.label || '').replace(/^Manage\s+/i, ''),
            className: tab.active ? 'sales-header-tab sales-header-tab--active' : 'sales-header-tab'
        }));
        // Leaving the Performance tab unmounts the dashboard, which returns
        // with defaults - so its header chrome resets alongside it.
        if (!tabs.some((tab) => tab.key === 'performance' && tab.active)) {
            this.salesPerfChrome = { showAgentPicker: false, agentOptions: [], filterLabel: 'All Time', filterIsDefault: true };
        }
    }

    get showSalesHeaderTabs() {
        return this.isSalesWorkspace && this.isCompactWorkspaceViewport && this.salesHeaderTabs.length > 0;
    }

    get hideWorkspaceTitleBlock() {
        return this.isRevenueWorkspace || this.showSalesHeaderTabs || this.showSalesDesktopHeader;
    }

    handleSalesHeaderTabClick(event) {
        const key = event.currentTarget.dataset.tab;
        const workspace = this.template.querySelector('c-mbpr_workspace-modal c-mbpr_sales-workspace');
        if (key && workspace && typeof workspace.setActiveTab === 'function') {
            workspace.setActiveTab(key);
        }
    }

    /* At 1200 and up the modal header becomes the whole console row: segmented
       tabs plus per-tab actions - the dashboard's agent picker and Filters
       chip via the salesperfchrome relay, Generate Offer on the record tabs,
       and Refresh always. */
    salesPerfChrome = { showAgentPicker: false, agentOptions: [], filterLabel: 'All Time', filterIsDefault: true };

    handleSalesPerfChrome(event) {
        const detail = event.detail || {};
        this.salesPerfChrome = {
            showAgentPicker: Boolean(detail.showAgentPicker),
            agentOptions: Array.isArray(detail.agentOptions) ? detail.agentOptions : [],
            filterLabel: detail.filterLabel || 'All Time',
            filterIsDefault: detail.filterIsDefault !== false
        };
    }

    get showSalesDesktopHeader() {
        return this.isSalesWorkspace && this.isDesktopWorkspaceViewport && this.salesHeaderTabs.length > 0;
    }

    get salesDesktopTabs() {
        return this.salesHeaderTabs.map((tab) => ({
            ...tab,
            className: tab.active ? 'sales-desktop-tab sales-desktop-tab--active' : 'sales-desktop-tab',
            ariaSelected: tab.active ? 'true' : 'false'
        }));
    }

    get salesHeaderPerfActive() {
        return this.salesHeaderTabs.some((tab) => tab.key === 'performance' && tab.active);
    }

    // BP-022 - mirrors salesHeaderPerfActive for the Opportunities tab
    get salesHeaderOpportunitiesActive() {
        return this.salesHeaderTabs.some((tab) => tab.key === 'opportunities' && tab.active);
    }

    get showSalesHeaderAgentPicker() {
        return (
            this.salesHeaderPerfActive &&
            this.salesPerfChrome.showAgentPicker &&
            this.salesPerfChrome.agentOptions.length > 1
        );
    }

    get showSalesHeaderOffer() {
        return !this.salesHeaderPerfActive && !this.salesHeaderOpportunitiesActive;
    }

    get salesPerfFilterLabel() {
        return this.salesPerfChrome.filterLabel;
    }

    get salesPerfFilterChipClass() {
        return this.salesPerfChrome.filterIsDefault
            ? 'sales-perf-filter-chip'
            : 'sales-perf-filter-chip sales-perf-filter-chip--active';
    }

    get salesWorkspaceChild() {
        return this.template.querySelector('c-mbpr_workspace-modal c-mbpr_sales-workspace');
    }

    /* ---------------------------------------------------------------- */
    /* Dashboard screenshots ( addendum): camera icon in both           */
    /* dashboard headers, desktop only. Same native Screen Capture      */
    /* engine as the chart lightbox: getDisplayMedia (user gesture +    */
    /* picker, OS-agnostic), one frame onto a canvas, PNG download.     */
    /* Chromium crops the stream to the workspace element via Region    */
    /* Capture; elsewhere a manual crop applies for same-tab captures,  */
    /* else the full frame saves. The capture targets are this          */
    /* template's own (slotted) children, so no shadow boundary is      */
    /* crossed.                                                         */
    /* ---------------------------------------------------------------- */

    get screenshotSupported() {
        return Boolean(
            typeof navigator !== 'undefined' &&
                navigator.mediaDevices &&
                navigator.mediaDevices.getDisplayMedia
        );
    }

    get showSalesHeaderScreenshot() {
        return this.salesHeaderPerfActive && this.screenshotSupported;
    }

    get showRevenueScreenshot() {
        return this.isRevenueDashboardView && this.screenshotSupported;
    }

    handleSalesDashboardScreenshot() {
        this.captureWorkspaceScreenshot(this.salesWorkspaceChild, 'Performance-Dashboard');
    }

    handleRevenueDashboardScreenshot() {
        this.captureWorkspaceScreenshot(
            this.template.querySelector('c-mbpr_dashboard-workspace'),
            'Total-Sales-Dashboard'
        );
    }

    async captureWorkspaceScreenshot(target, slug) {
        if (this._screenshotBusy || !this.screenshotSupported) return;
        this._screenshotBusy = true;
        let stream = null;
        const video = document.createElement('video');
        try {
            stream = await navigator.mediaDevices.getDisplayMedia({
                audio: false,
                video: { displaySurface: 'browser' },
                // Chromium extras; other browsers ignore unknown members.
                preferCurrentTab: true,
                selfBrowserSurface: 'include',
                surfaceSwitching: 'exclude'
            });
            const track = stream.getVideoTracks()[0];

            let regionCropped = false;
            if (
                target &&
                typeof window.CropTarget !== 'undefined' &&
                typeof window.CropTarget.fromElement === 'function' &&
                track &&
                typeof track.cropTo === 'function'
            ) {
                try {
                    const cropTarget = await window.CropTarget.fromElement(target);
                    await track.cropTo(cropTarget);
                    regionCropped = true;
                } catch (cropError) {
                    regionCropped = false;
                }
            }

            video.srcObject = stream;
            video.muted = true;
            await video.play();
            // Let the share UI settle and real frames arrive before sampling.
            await new Promise((resolve) => setTimeout(resolve, 350));

            const width = video.videoWidth;
            const height = video.videoHeight;
            if (!width || !height) throw new Error('No frame captured.');

            let sx = 0;
            let sy = 0;
            let sw = width;
            let sh = height;
            if (!regionCropped && target) {
                const scaleX = width / window.innerWidth;
                const scaleY = height / window.innerHeight;
                if (Math.abs(scaleX - scaleY) < 0.02) {
                    const rect = target.getBoundingClientRect();
                    sx = Math.max(0, Math.floor(rect.left * scaleX));
                    sy = Math.max(0, Math.floor(rect.top * scaleY));
                    sw = Math.max(1, Math.min(width - sx, Math.ceil(rect.width * scaleX)));
                    sh = Math.max(1, Math.min(height - sy, Math.ceil(rect.height * scaleY)));
                }
            }

            const canvas = document.createElement('canvas');
            canvas.width = sw;
            canvas.height = sh;
            canvas.getContext('2d').drawImage(video, sx, sy, sw, sh, 0, 0, sw, sh);

            const link = document.createElement('a');
            link.href = canvas.toDataURL('image/png');
            link.download = `${slug}-${new Date().toISOString().slice(0, 10)}.png`;
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } catch (error) {
            // Picker dismissed or capture blocked - nothing to save.
        } finally {
            try {
                video.pause();
                video.srcObject = null;
            } catch (cleanupError) {
                // ignore
            }
            if (stream) {
                stream.getTracks().forEach((mediaTrack) => mediaTrack.stop());
            }
            this._screenshotBusy = false;
        }
    }

    handleSalesPerfFilterChipClick(event) {
        const workspace = this.salesWorkspaceChild;
        if (workspace && typeof workspace.togglePerformanceFilters === 'function') {
            workspace.togglePerformanceFilters(this.headerFilterAnchor(event));
        }
    }

    /* Mirrors the in-dashboard picker. The options arrive from the performance
       dashboard through salesPerfChrome and picks are proxied back down
       through setPerformanceAgent. */
    get selectedSalesAgentLabel() {
        const options = this.salesPerfChrome.agentOptions || [];
        const selected = options.find((option) => option.selected);
        return selected ? selected.label : 'All agents';
    }

    get salesAgentInputValue() {
        return this.isSalesAgentPickerOpen ? this.salesAgentSearch : this.selectedSalesAgentLabel;
    }

    get salesAgentPickerExpanded() {
        return this.isSalesAgentPickerOpen ? 'true' : 'false';
    }

    get filteredSalesAgentOptions() {
        const query = String(this.salesAgentSearch || '')
            .trim()
            .toLowerCase();
        const tokens = query ? query.split(/\s+/).filter(Boolean) : [];
        return (this.salesPerfChrome.agentOptions || [])
            .filter((option) => {
                if (!tokens.length) return true;
                const haystack = String(option.label || '').toLowerCase();
                return tokens.every((token) => haystack.includes(token));
            })
            .map((option, index) => {
                const classes = ['sales-perf-agent-option'];
                if (option.selected) classes.push('sales-perf-agent-option--selected');
                if (index === this.salesAgentActiveIndex) classes.push('sales-perf-agent-option--active');
                return {
                    ...option,
                    index,
                    // '' (All agents) is falsy in the dataset guard.
                    pickValue: option.value || '__all__',
                    className: classes.join(' ')
                };
            });
    }

    get hasSalesAgentOptions() {
        return this.filteredSalesAgentOptions.length > 0;
    }

    handleSalesAgentFocus(event) {
        window.clearTimeout(this._salesAgentBlurTimeout);
        this.isSalesAgentPickerOpen = true;
        this.salesAgentSearch = '';
        this.salesAgentActiveIndex = 0;
        const input = event.currentTarget;
        window.requestAnimationFrame(() => {
            if (input && typeof input.select === 'function') input.select();
        });
    }

    handleSalesAgentInput(event) {
        this.isSalesAgentPickerOpen = true;
        this.salesAgentSearch = event.target.value || '';
        this.salesAgentActiveIndex = 0;
    }

    handleSalesAgentKeydown(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            // Keep Escape inside the picker - the workspace modal listens too.
            event.stopPropagation();
            this.closeSalesAgentPicker();
            event.currentTarget.blur();
            return;
        }
        if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp' && event.key !== 'Enter') return;
        const options = this.filteredSalesAgentOptions;
        if (!options.length) return;
        if (event.key === 'Enter') {
            event.preventDefault();
            const option = options[this.salesAgentActiveIndex] || options[0];
            this.pickSalesAgent(option.value);
            event.currentTarget.blur();
            return;
        }
        event.preventDefault();
        const step = event.key === 'ArrowDown' ? 1 : -1;
        this.salesAgentActiveIndex = (this.salesAgentActiveIndex + step + options.length) % options.length;
    }

    handleSalesAgentBlur() {
        window.clearTimeout(this._salesAgentBlurTimeout);
        this._salesAgentBlurTimeout = window.setTimeout(() => {
            this.closeSalesAgentPicker();
        }, 120);
    }

    handleSalesAgentOptionMouseDown(event) {
        event.preventDefault();
        const picked = event.currentTarget.dataset.value;
        if (!picked) return;
        this.pickSalesAgent(picked === '__all__' ? '' : picked);
    }

    pickSalesAgent(value) {
        this.closeSalesAgentPicker();
        const workspace = this.salesWorkspaceChild;
        if (workspace && typeof workspace.setPerformanceAgent === 'function') {
            workspace.setPerformanceAgent(value || '');
        }
    }

    closeSalesAgentPicker() {
        window.clearTimeout(this._salesAgentBlurTimeout);
        this.isSalesAgentPickerOpen = false;
        this.salesAgentSearch = '';
        this.salesAgentActiveIndex = 0;
    }

    handleSalesHeaderRefresh() {
        const workspace = this.salesWorkspaceChild;
        if (workspace && typeof workspace.refreshActiveTab === 'function') {
            workspace.refreshActiveTab();
        }
    }

    handleSalesHeaderGenerateOffer() {
        const workspace = this.salesWorkspaceChild;
        if (workspace && typeof workspace.openGuidedOffer === 'function') {
            workspace.openGuidedOffer();
        }
    }

    get isSalesWorkspace() {
        return this.activeCommandWorkspace === 'sales';
    }

    get isRevenueWorkspace() {
        return this.activeCommandWorkspace === 'revenue';
    }

    handleNavigate(event) {
        this.navigateToUrl(event.currentTarget.dataset.url);
    }

    navigateToUrl(url) {
        if (!url) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url }
        });
    }

    /* ---------------------------------------------------------------- */
    /* Formatting helpers                                               */
    /* ---------------------------------------------------------------- */

    toNumber(value) {
        const num = Number(value);
        return Number.isNaN(num) ? 0 : num;
    }

    formatBedrooms(value) {
        if (value === null || value === undefined || value === '') return '-';
        const num = Number(value);
        if (Number.isNaN(num)) return String(value);
        if (num === 0) return 'Studio';
        if (num === 1) return '1 Bedroom';
        return `${num} Bedrooms`;
    }

    formatBedroomsShort(value) {
        if (value === null || value === undefined || value === '') return '-';
        const num = Number(value);
        if (Number.isNaN(num)) return String(value);
        if (num === 0) return 'Studio';
        if (num === 1) return '1 BR';
        return `${num} BR`;
    }

    formatCurrencyCompact(amount) {
        if (amount === null || amount === undefined) return '-';
        const num = Number(amount);
        if (Number.isNaN(num)) return '-';
        const abs = Math.abs(num);
        /* Without a billions tier a 1.34bn total rendered as "AED 1344.6M" on
           the home card while the dashboard, same Apex and same period, showed
           "AED 1.3B". Same rounding as the tiers below. */
        if (abs >= 1000000000) {
            const value = num / 1000000000;
            return `AED ${value.toFixed(Math.abs(value % 1) < 0.05 ? 0 : 1)}B`;
        }
        if (abs >= 1000000) {
            const value = num / 1000000;
            return `AED ${value.toFixed(Math.abs(value % 1) < 0.05 ? 0 : 1)}M`;
        }
        if (abs >= 1000) {
            const value = num / 1000;
            return `AED ${value.toFixed(Math.abs(value % 1) < 0.05 ? 0 : 1)}K`;
        }
        return `AED ${num.toFixed(0)}`;
    }

    formatCurrencyFull(amount) {
        if (amount === null || amount === undefined) return 'Not available';
        const num = Number(amount);
        if (Number.isNaN(num)) return 'Not available';
        return new Intl.NumberFormat('en-AE', {
            style: 'currency',
            currency: 'AED',
            maximumFractionDigits: 0
        }).format(num);
    }

    formatDateForApex(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    formatShortDate(value) {
        if (!value) return '';
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return '';
        // Year added so a lead's Created date reads the same here as it does in
        // mbpr_salesWorkspace, which already renders "25 Aug 2026".
        return new Intl.DateTimeFormat('en-AE', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        }).format(date);
    }

    formatArea(value) {
        return this.formatAreaSqm(value);
    }

    formatAreaSqm(value) {
        if (value === null || value === undefined || value === '') return 'Not specified';
        const num = Number(value);
        if (Number.isNaN(num)) return String(value);
        return `${new Intl.NumberFormat('en-AE', { maximumFractionDigits: 2 }).format(num)} sqm`;
    }

    formatAreaSqft(value) {
        if (value === null || value === undefined || value === '') return 'Not specified';
        const num = Number(value);
        if (Number.isNaN(num)) return String(value);
        return `${new Intl.NumberFormat('en-AE', { maximumFractionDigits: 0 }).format(num)} sqft`;
    }

    formatPlanStatus(status, hasTour) {
        const key = this.normalizeKey(status);
        if (!key || key === 'unit') return hasTour ? 'Plan ready' : 'Plan unavailable';
        if (
            key.includes('not') ||
            key.includes('missing') ||
            key.includes('inactive') ||
            key.includes('unavailable') ||
            key.includes('failed') ||
            key.includes('error')
        ) {
            return 'Plan unavailable';
        }
        if (key.includes('ready') || key.includes('active') || key.includes('available')) return 'Plan ready';
        return hasTour ? 'Plan ready' : 'Plan unavailable';
    }

    normalizeKey(value) {
        return String(value || 'unit')
            .trim()
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-+|-+$/g, '') || 'unit';
    }

    normalizeTierName(value) {
        const candidate = String(value || '').trim().toLowerCase();
        return TIER_SEQUENCE.find((tier) => tier.toLowerCase() === candidate) || null;
    }

    tierRank(value) {
        const tier = this.normalizeTierName(value);
        const index = TIER_SEQUENCE.indexOf(tier);
        return index === -1 ? 0 : index;
    }

    normalizeHttpUrl(value) {
        const raw = String(value || '').trim();
        if (!raw) return '';
        if (/^https?:\/\//i.test(raw)) return raw;
        return '';
    }

    // Masterplan / DPG plan links are rendered inside the HTTPS portal. world.modon.com
    // 301-redirects a slash-less path down to plain http
    // (https://…/abu-dhabi/hudayriyat?x → http://…/abu-dhabi/hudayriyat/?x), and the
    // browser blocks that insecure hop as mixed content - Chrome renders
    // "This content is blocked. Contact the site owner to fix the issue." Normalising the
    // path here makes the frame request the final secure URL directly.
    normalizeTourUrl(value) {
        const raw = this.normalizeHttpUrl(value);
        if (!raw) return '';
        const parts = /^(https?:)(\/\/[^/?#]+)([^?#]*)([\s\S]*)$/i.exec(raw);
        if (!parts) return raw;
        const authority = parts[2];
        const path = parts[3] || '';
        const tail = parts[4] || '';
        const securePath = path.endsWith('/') ? path : `${path}/`;
        return `https:${authority}${securePath}${tail}`;
    }

    normalizeDownloadUrl(value) {
        const raw = String(value || '').trim();
        if (!raw) return '';
        if (/^https?:\/\//i.test(raw) || raw.startsWith('/')) return raw;
        return '';
    }

    prefersReducedMotion() {
        return (
            typeof window !== 'undefined' &&
            window.matchMedia &&
            window.matchMedia('(prefers-reduced-motion: reduce)').matches
        );
    }
}