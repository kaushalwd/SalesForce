import { LightningElement, track } from 'lwc';
import portal from '@salesforce/apex/CommunicationController.portal';
import HEADER_IMAGE from '@salesforce/resourceUrl/Modon_EmailHeader';
import WHITE_LOGO from '@salesforce/resourceUrl/Modon_White_Logo';
import LINKEDIN_ICON from '@salesforce/resourceUrl/Modon_LinkedIn';
import INSTAGRAM_ICON from '@salesforce/resourceUrl/Modon_Instagram';
import TWITTER_ICON from '@salesforce/resourceUrl/Modon_Twitter';
import FACEBOOK_ICON from '@salesforce/resourceUrl/Modon_Facebook';
import YOUTUBE_ICON from '@salesforce/resourceUrl/Modon_Youtube';

export default class Mbpportalcommunications extends LightningElement {
    @track communications = [];
    @track selectedCommunication = null;
    @track selectedFilter = 'All';
    @track searchTerm = '';
    _htmlRendered = false;
    @track isMobile = false;
    _resizeHandler = null;

    // Update version 2.0 starts New Fields
    @track currentPage = 1;
    pageSize = 10;
// Update version 2.0 ends New Fields

    connectedCallback() {
        this.detectMobile();
        this._resizeHandler = this.handleResize.bind(this);
        window.addEventListener('resize', this._resizeHandler);
        this.loadCommunications();
    }
    disconnectedCallback() {
        if (this._resizeHandler) {
            window.removeEventListener('resize', this._resizeHandler);
        }
    }

    loadCommunications() {
        portal({
            action: 'getPortalCommunications',
            params: { filterType: this.selectedFilter }
        })
            .then((result) => {
                const list = Array.isArray(result) ? result : [];

                this.communications = list.map((item) => {
                    const createdDate = item.createdDate;

                    const rawAttachments = Array.isArray(item.attachments) ? item.attachments : [];

                    const nonBannerAttachments = rawAttachments
                        .filter((a) => !a?.isBanner)
                        .map((a) => ({
                            ...a,
                            formattedSize: this.formatFileSize(a.size)
                        }));

                    return {
                        ...item,
                        formattedDate: this.formatDate(createdDate),
                        displayDate: this.formatDisplayDate(createdDate),
                        timeAgo: this.getTimeAgo(createdDate),
                        cardClass: this.getCardClass(item),
                        attachments: nonBannerAttachments,
                        hasAttachments: nonBannerAttachments.length > 0,
                        isUnread: item.viewStatus !== 'Viewed',
                        mobileBodyClass: 'mobile-card-body',
                        mobileArrowClass: 'mobile-arrow',
                        fromText: item.fromAddress || item.createdByEmail || 'noreply@modon.com',
                        formattedTime: this.formatTime(createdDate)
                    };
                });

                if (this.communications.length > 0) {
                    this.selectCommunication(this.communications[0]);
                } else {
                    this.selectedCommunication = null;
                }
            })
            .catch((error) => {
                console.error('Error loading communications:', error);
                this.communications = [];
                this.selectedCommunication = null;
            });
    }

    handleFilterClick(event) {
        this.selectedFilter = event.currentTarget.dataset.filter;
        this.selectedCommunication = null;
        this._htmlRendered = false;
        this.loadCommunications();
    }

    handleCommunicationClick(event) {
        const commId = event.currentTarget.dataset.id;
        const commIndex = this.communications.findIndex((c) => c.id === commId);

        if (commIndex === -1) return;

        const comm = this.communications[commIndex];
        this.selectCommunication(comm);

        if (comm.viewStatus !== 'Viewed') {
            const updatedComm = {
                ...comm,
                viewStatus: 'Viewed'
            };
            updatedComm.cardClass = this.getCardClass(updatedComm);

            if (this.selectedFilter === 'Unread') {
                this.communications.splice(commIndex, 1);
            } else {
                this.communications[commIndex] = updatedComm;
            }

            this.communications = [...this.communications];

            portal({
                action: 'markCommunicationViewed',
                params: { communicationId: comm.id }
            }).catch((error) => {
                console.error('Failed to mark communication viewed:', error);
            });
        }
    }

selectCommunication(comm) {
    this.selectedCommunication = {
        ...comm,
        htmlBody: this.replacePortalResourceTokens(comm.htmlBody),
        formattedTime: this.formatTime(comm.createdDate),
        fromText: comm.fromAddress || comm.createdByEmail || 'noreply@modon.com',
        hasAttachments: comm.attachments && comm.attachments.length > 0,
        attachments: comm.attachments || []
    };

    this._htmlRendered = false;
}

    handleDownload(event) {
        event.preventDefault();
        event.stopPropagation();

        const downloadUrl = event.currentTarget.dataset.url;

        if (!downloadUrl) {
            return;
        }

        const absoluteUrl = downloadUrl.startsWith('http')
            ? downloadUrl
            : window.location.origin + downloadUrl;

        window.open(absoluteUrl, '_blank');
    }

handleSearch(event) {
    this.searchTerm = (event.target.value || '').toLowerCase();

    // Update version 2.0 starts New Fields
    this.currentPage = 1;
    // Update version 2.0 ends New Fields
}

    get filteredCommunications() {
        let data = this.communications;

        if (this.searchTerm) {
            const q = this.searchTerm;
            data = data.filter((comm) => {
                return (
                    (comm.subject && comm.subject.toLowerCase().includes(q)) ||
                    (comm.createdByName && comm.createdByName.toLowerCase().includes(q))
                );
            });
        }

        // Update version 2.0 starts New Fields
        if (this.isMobile) {
            const start = (this.currentPage - 1) * this.pageSize;
            const end = start + this.pageSize;
            return data.slice(start, end);
        }
        // Update version 2.0 ends New Fields

        return data;
    }

    get noCommunications() {
        return this.communications.length === 0;
    }

   renderedCallback() {
        const container = this.template.querySelector('[data-id="emailBody"]');
        if (container) {
            container.innerHTML = this.selectedCommunication?.htmlBody || '';
        }
        if (this.isMobile) {
            this.communications.forEach((comm) => {
                if (comm.isOpen) {
                    const mobileBody = this.template.querySelector(`[data-bodyid="${comm.id}"]`);
                    if (mobileBody && !mobileBody._injected) {
                        mobileBody.innerHTML = this.replacePortalResourceTokens(comm.htmlBody) || '';
                        mobileBody._injected = true;
                    }
                }
            });
        }
    }

    getCardClass(item) {
        let classes = 'comm-card';

        if (item.sentOption === 'Save As Draft' && item.emailSent === false) {
            classes += ' draft';
        } else if (item.emailSent === true) {
            classes += ' sent';
        } else if (item.viewStatus === 'Viewed') {
            classes += ' viewed';
        } else {
            classes += ' unread';
        }

        return classes;
    }

    formatDate(dateTime) {
        if (!dateTime) return '';
        const date = new Date(dateTime);
        return date.toLocaleDateString('en-US', {
            month: 'long',
            day: 'numeric',
            year: 'numeric'
        });
    }

    formatDisplayDate(dateTime) {
        if (!dateTime) return '';
        const date = new Date(dateTime);
        return date.toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }

    formatTime(dateTime) {
        if (!dateTime) return '';
        const date = new Date(dateTime);
        const hours = date.getHours();
        const minutes = date.getMinutes();
        const ampm = hours >= 12 ? 'PM' : 'AM';
        const formattedHours = hours % 12 || 12;
        const formattedMinutes = minutes < 10 ? '0' + minutes : minutes;
        return `${formattedHours}:${formattedMinutes} ${ampm}`;
    }

    getTimeAgo(dateTime) {
        if (!dateTime) return '';

        const now = new Date();
        const date = new Date(dateTime);
        const diffMs = now - date;
        const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

        if (diffDays === 0) return 'Today';
        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays} days ago`;
        if (diffDays < 30) {
            const weeks = Math.floor(diffDays / 7);
            return `${weeks} ${weeks === 1 ? 'week ago' : 'weeks ago'}`;
        }

        return this.formatDisplayDate(dateTime);
    }

    formatFileSize(bytes) {
        const b = Number(bytes);
        if (!b || b <= 0) return '0 Bytes';

        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(b) / Math.log(k));

        return `${parseFloat((b / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
    }

    replacePortalResourceTokens(html) {
    if (!html) {
        return '';
    }

    return html
        .replaceAll('__HEADER_IMAGE__', HEADER_IMAGE)
        .replaceAll('__WHITE_LOGO__', WHITE_LOGO)
        .replaceAll('__LINKEDIN_ICON__', LINKEDIN_ICON)
        .replaceAll('__INSTAGRAM_ICON__', INSTAGRAM_ICON)
        .replaceAll('__TWITTER_ICON__', TWITTER_ICON)
        .replaceAll('__FACEBOOK_ICON__', FACEBOOK_ICON)
        .replaceAll('__YOUTUBE_ICON__', YOUTUBE_ICON);
}

    // ==================== NEW: Mobile methods ====================
    detectMobile() {
        this.isMobile = window.innerWidth <= 768;
    }

handleResize() {
    this.detectMobile();

    // Update version 2.0 starts New Fields
    this.currentPage = 1;
    // Update version 2.0 ends New Fields
}

    handleMobileCardToggle(event) {
        const commId = event.currentTarget.dataset.id;
        const commIndex = this.communications.findIndex((c) => c.id === commId);
        if (commIndex === -1) return;

        const comm = this.communications[commIndex];
        const newOpen = !comm.isOpen;
        this.communications = this.communications.map((c) => {
            if (c.id === commId) {
                return {
                    ...c,
                    isOpen: newOpen,
                    mobileBodyClass: newOpen ? 'mobile-card-body open' : 'mobile-card-body',
                    mobileArrowClass: newOpen ? 'mobile-arrow open' : 'mobile-arrow'
                };
            }
            return c;
        });

        if (newOpen) {
            setTimeout(() => {
                const mobileBody = this.template.querySelector(`[data-bodyid="${commId}"]`);
                if (mobileBody) {
                    mobileBody.innerHTML = this.replacePortalResourceTokens(comm.htmlBody) || '';
                    mobileBody._injected = true;
                }
            }, 0);
        }
        if (comm.viewStatus !== 'Viewed') {
            this.communications = this.communications.map((c) => {
                if (c.id === commId) {
                    return {
                        ...c,
                        viewStatus: 'Viewed',
                        isUnread: false
                    };
                }
                return c;
            });

            if (this.selectedFilter === 'Unread') {
                this.communications = this.communications.filter((c) => c.id !== commId);
            }

            portal({
                action: 'markCommunicationViewed',
                params: { communicationId: commId }
            }).catch((error) => {
                console.error('Failed to mark communication viewed:', error);
            });
        }
    }


    // Update version 2.0 starts New Fields
get totalPages() {
    const total = this.searchTerm
        ? this.communications.filter((comm) =>
              (comm.subject && comm.subject.toLowerCase().includes(this.searchTerm)) ||
              (comm.createdByName && comm.createdByName.toLowerCase().includes(this.searchTerm))
          ).length
        : this.communications.length;

    return Math.ceil(total / this.pageSize) || 1;
}

get isFirstPage() {
    return this.currentPage === 1;
}

get isLastPage() {
    return this.currentPage >= this.totalPages;
}

handleNextPage() {
    if (!this.isLastPage) {
        this.currentPage++;
    }
}

handlePrevPage() {
    if (!this.isFirstPage) {
        this.currentPage--;
    }
}
// Update version 2.0 ends New Fields

}