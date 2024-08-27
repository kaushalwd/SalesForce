const state = 'dev';

const log = (key, value) => {
    if (state == 'dev') {
        console.log(key, value);
    }
}

const isValidEmail = (email) => {
    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    return emailRegex.test(email);
}

const isValidPhoneNumber = (number) => {
    const numAsString = number.toString();
    return numAsString.length >= 9 && numAsString.length <= 10;
}

const sendContactFormData = (selector, interactionName) => {
    const FirstName = SalesforceInteractions.cashDom(`${selector} input[data-field-type="FirstName"]`).val();
    const LastName = SalesforceInteractions.cashDom(`${selector} input[data-field-type="LastName"]`).val();
    const Company = SalesforceInteractions.cashDom(`${selector} input[data-field-type="Company"]`).val();
    let emailAddress = SalesforceInteractions.cashDom(`${selector} input[data-field-type="Email"]`).val();
    const contactNumber = SalesforceInteractions.cashDom(`${selector} input[data-field-type="Phone"]`).val();
    const countryCode = SalesforceInteractions.cashDom(`${selector} div[class="iti__selected-dial-code"]`).text();

    log('FirstName', FirstName);
    log('LastName', LastName);
    log('Company', Company);
    log('emailAddress', emailAddress);
    log('contactNumber', contactNumber);
    log('countryCode', countryCode);

    /* 
    The website containes a lot of select elements with the same name attribute but different ids
    so to deal with this in a genric fashion we are capturing all the select tags and then looping through
    it and taking out value form the visible one. 
    */
    let interestPickList = document.querySelectorAll(`${selector} select[data-field-type="Service_Line__c"]`);
    let interest = '-1';
    log('BUGFIX:', interestPickList);
    if (interestPickList.length > 1) {
        interestPickList.forEach(ele => {
            if (ele.style.display != 'none') {
                interest = ele.value;
            }
        })
    } else {
        interest = interestPickList[0]?.value
    }
    log('BUGFIX:', interest);
    if (FirstName &&
        LastName &&
        Company &&
        isValidEmail(emailAddress) &&
        isValidPhoneNumber(contactNumber) &&
        interest != '-1') {

        log('Process', 'MCP EVENT');
        emailAddress = emailAddress.toLowerCase();

        let digitalLearningInteractionFormName = null;
        if (selector == '.modal.chatPopup.show form.contact-us-overlay' &&
            window.location.pathname.toLowerCase().includes('/digital-learning')) {

            if (SalesforceInteractions.cashDom('div#book-a-demo').length > 0 &&
                SalesforceInteractions.cashDom('div#book-a-demo')[0]?.style?.display == 'block') {
                digitalLearningInteractionFormName = 'Digital Learning Demo Form Submitted';
            }

            if (SalesforceInteractions.cashDom('div#demo-form').length > 0 &&
                SalesforceInteractions.cashDom('div#demo-form')[0]?.style?.display == 'block') {
                digitalLearningInteractionFormName = 'Digital Learning Program Demo Form Submitted';
            }

            if (SalesforceInteractions.cashDom('div#proposal-form').length > 0 &&
                SalesforceInteractions.cashDom('div#proposal-form')[0]?.style?.display == 'block') {
                digitalLearningInteractionFormName = 'Digital Learning Program Proposal Form Submitted';
            }
        }

        if (digitalLearningInteractionFormName) {
            log('Here', 'Book a Demo');
            SalesforceInteractions.cashDom(`#evg-infobar-with-cta`).remove();
            SalesforceInteractions.cashDom("body").css({ "margin-top": "0", "margin-bottom": "0" });
            SalesforceInteractions.cashDom("header.fixed-top").css({ "top": "0" });
            SalesforceInteractions.sendEvent({
                interaction: {
                    name: digitalLearningInteractionFormName,
                },
                user: {
                    identities: { emailAddress },
                    attributes: {
                        FirstName,
                        Company,
                        contactNumber: countryCode + contactNumber,
                        LastName,
                        interest
                    }
                },
            });
        } else {
            SalesforceInteractions.sendEvent({
                interaction: {
                    name: interactionName,
                },
                user: {
                    identities: { emailAddress },
                    attributes: {
                        FirstName,
                        Company,
                        contactNumber: countryCode + contactNumber,
                        LastName,
                        interest
                    }
                },
            });
        }
    }
}

const categoryResolution = (category) => {
    const categoryMap = {
        digital_learning: 'Digital Learning – eduZ',
        strategy_consulting: 'Strategy Consulting',
        training_development: 'Training and Development',
        talent_assessment: 'Talent Assessments',
    }

    return categoryMap[category];
}

const sitemapConfig = {
    global: {
        listeners: [
            SalesforceInteractions.listener("click", "form#subscribe-form button[type='submit']", async () => {
                const email = SalesforceInteractions.cashDom('form#subscribe-form input[type="email"]').val();
                log('Email', email);
                if (email) {
                    await SalesforceInteractions.sendEvent({
                        interaction: { name: "Email Subscribe Form - Footer" },
                        user: { identities: { emailAddress: email } },
                    });
                }
            }),
            SalesforceInteractions.listener("click", "form.contact-us button[type='submit']", () => {
                sendContactFormData('form.contact-us', 'Contact us form Submitted');
            }),
            SalesforceInteractions.listener("click", "form.contact-us-overlay button[type='submit']", () => {
                sendContactFormData('.modal.chatPopup.show form.contact-us-overlay', 'Contact us form overlay Submitted');
            }),
            SalesforceInteractions.listener('click', 'div.timeline-body-header a.utag-tag', async (event) => {
                event.preventDefault();
                await SalesforceInteractions.sendEvent({
                    interaction: { name: `Meet Our Consultants Clicked` }
                });
            }),
            SalesforceInteractions.listener('click', '.navbar a#language-selector', (e) => {
                // e.preventDefault();
                SalesforceInteractions.sendEvent({
                    interaction: { name: 'Language Switcher Clicked' }
                })
            })
        ],
        contentZones: [
            {
                name: "global_infobar_top_of_page", selector: "header.fixed-top"
            }
        ]
    },
    pageTypeDefault: {
        name: "default",
        interaction: {
            name: 'Default Page Visited'
        }
    },
    pageTypes: [
        {
            name: "home",
            isMatch: () => {
                return (window.location.pathname.toLowerCase() == '/' ||
                    window.location.pathname.toLowerCase() == '/en' ||
                    window.location.pathname.toLowerCase() == '/en/' ||
                    window.location.pathname.toLowerCase() == '/ar' ||
                    window.location.pathname.toLowerCase().includes('/home'))
            },
            interaction: {
                name: 'Home Page Visited'
            },
            contentZones: [
                {
                    name: "featured_blog",
                    selector: ".insighs-Events .industry-insight"
                },
                {
                    name: "blogs_and_case_study",
                    selector: ".insighs-Events .row.mobile-layer.swiper-wrapper"
                },
                {
                    name: "home_hero_banner_image",
                    selector: "div.slider-section picture.banner:first-child"
                },
            ]
        },
        {
            name: "about",
            isMatch: () => window.location.pathname.toLowerCase().includes('/about'),
            interaction: {
                name: 'About us Page Visited'
            },
            listeners: [
                SalesforceInteractions.listener("click", "form[data-form_type='get in touch'] button[type='submit']", () => {
                    sendContactFormData('form[data-form_type="get in touch"]', 'Contact us form Submitted');
                })
            ]
        },
        {
            name: "case-study-detail",
            isMatch: () => (window.location.pathname.toLowerCase().includes('/case-studies/challenges/') ||
                window.location.pathname.toLowerCase().includes('/case-studies/solutions/') ||
                window.location.pathname.toLowerCase().includes('/case-studies/industries/')),
            interaction: {
                name: SalesforceInteractions.CatalogObjectInteractionName.ViewCatalogObject,
                catalogObject: {
                    type: 'Article',
                    id: utag?.data?.content_id.substring(utag?.data?.content_id.indexOf('{') + 1, utag?.data?.content_id.indexOf('}')),
                    attributes: {
                        name: utag?.data?.content_name,
                        url: SalesforceInteractions.resolvers.fromHref(),
                        imageUrl: utag?.data?.image_url,
                        description: utag?.data?.description
                    },
                    relatedCatalogObjects: {
                        Category: () => {
                            return [categoryResolution(utag?.data?.content_category)]
                        }
                    }
                }
            }
        },
        {
            name: "challenges",
            isMatch: () => window.location.pathname.toLowerCase().includes('/challenges'),
            interaction: {
                name: 'Challenges Page Visited'
            },
            listeners: [
                SalesforceInteractions.listener('click', 'section.explore-solution a.utag-tag[data-form-type="challenge-form"]', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Get in Touch Clicked` }
                    });
                })
            ]
        },
        {
            name: "solutions",
            isMatch: () => window.location.pathname.toLowerCase().includes('/solutions'),
            interaction: {
                name: 'Solutions Page Visited'
            },
            contentZones: [
                { name: "case_study_cards", selector: ".learn-more div.swiper-wrapper" },
            ],
            listeners: [
                SalesforceInteractions.listener('click', 'div.our-strength-left a.utag-tag', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Meet Our Consultants Clicked` }
                    });
                }),
                SalesforceInteractions.listener('click', 'div.slider-section a.utag-tag', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Get in Touch Clicked` }
                    });
                }),
                SalesforceInteractions.listener('click', 'section.explore-solution a.utag-tag[data-form-type="solution-form"]', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Get in Touch Clicked` }
                    });
                }),
                SalesforceInteractions.listener('click', 'div.featured-layer a.utag-tag', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Get in Touch Clicked` }
                    });
                }),
                SalesforceInteractions.listener('click', 'div.propose-request a.utag-tag[data-form-type="proposal-form"]', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Request a Proposal Clicked` }
                    });
                })
            ]
        },
        {
            name: "industries",
            isMatch: () => window.location.pathname.toLowerCase().includes('/industries'),
            interaction: {
                name: 'Industries Page Visited'
            },
            listeners: [
                SalesforceInteractions.listener('click', 'div.expertise-layer a.utag-tag', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Meet Our Consultants Clicked` }
                    });
                }),
                SalesforceInteractions.listener('click', 'div.slider-section a.utag-tag[data-form-type="industry-form"]', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Get in Touch Clicked` }
                    });
                }),
                SalesforceInteractions.listener('click', 'div.featured-layer a.utag-tag[data-form-type="industry-form"]', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Get in Touch Clicked` }
                    });
                }),
                SalesforceInteractions.listener('click', 'section.explore-solution a.utag-tag[data-form-type="industry-form"]', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Get in Touch Clicked` }
                    });
                })
            ]
        },
        {
            name: "digital-learning-business-course",
            isMatch: () => window.location.pathname.toLowerCase().includes('/digital-learning/'),
            listeners: [
                SalesforceInteractions.listener("click", "form.request-a-proposal button[type='submit']", () => {
                    sendContactFormData('form.request-a-proposal', 'Digital Learning Program Proposal Form Submitted');
                })
            ],
            interaction: {
                name: SalesforceInteractions.CatalogObjectInteractionName.ViewCatalogObject,
                catalogObject: {
                    type: 'Product',
                    id: utag?.data?.content_id.substring(utag?.data?.content_id.indexOf('{') + 1, utag?.data?.content_id.indexOf('}')),
                    attributes: {
                        name: utag?.data?.content_name,
                        url: SalesforceInteractions.resolvers.fromHref(),
                        imageUrl: utag?.data?.image_url,
                        description: utag?.data?.description
                    },
                    relatedCatalogObjects: {
                        Category: () => {
                            return [categoryResolution(utag?.data?.content_category)]
                        }
                    }
                }
            }
        },
        {
            name: "digital-learning",
            isMatch: () => {
                let pageMatch = window.location.pathname.toLowerCase().includes('/digital-learning');
                if (pageMatch) {
                    let loadDemoForm = localStorage.getItem("evg_demoForm");
                    if (loadDemoForm == 'true') {
                        SalesforceInteractions.cashDom('a[data-form-type="demo-form"]')[0]?.click();
                        localStorage.removeItem("evg_demoForm");
                    }
                }
                return pageMatch;
            },
            interaction: {
                name: 'Digital Learning Page Visited'
            },
            listeners: [
                SalesforceInteractions.listener('click', 'div.leading-thinkers-layer button.utag-tag', (event) => {
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Meet Our Consultants Clicked` }
                    });
                }),
                SalesforceInteractions.listener('click', "form.request-for-proposal button[type='submit']", () => {
                    sendContactFormData('form.request-for-proposal', 'Digital Learning Form Submitted');
                }),
                SalesforceInteractions.listener('click', 'a.utag-tag[data-form-type="digital-learning-form"]', (event) => {
                    event.preventDefault();
                    let ctaLabel = event?.target?.textContent?.trim();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `${ctaLabel} Clicked` }
                    });
                }),
                SalesforceInteractions.listener('click', 'a.utag-tag[data-form-type="demo-form"]', (event) => {
                    event.preventDefault();
                    SalesforceInteractions.sendEvent({
                        interaction: { name: `Book a Demo Clicked` }
                    });
                })
            ]
        },
        {
            name: "blog-detail",
            isMatch: () => utag.data.content_type === 'insights' && window.location.pathname.includes('/insights/'),
            interaction: {
                name: SalesforceInteractions.CatalogObjectInteractionName.ViewCatalogObject,
                catalogObject: {
                    type: 'Blog',
                    id: utag?.data?.content_id.substring(utag?.data?.content_id.indexOf('{') + 1, utag?.data?.content_id.indexOf('}')),
                    attributes: {
                        name: utag?.data?.content_name,
                        url: SalesforceInteractions.resolvers.fromHref(),
                        imageUrl: utag?.data?.image_url,
                        description: utag?.data?.description
                    },
                    relatedCatalogObjects: {
                        Category: () => {
                            return [categoryResolution(utag?.data?.content_category)]
                        }
                    }
                }
            }
        },
        {
            name: "blogs",
            isMatch: () => window.location.pathname.includes('/insights'),
            interaction: {
                name: 'Insights and Events Page Visited'
            }
        },
        {
            name: "contact",
            isMatch: () => window.location.pathname.toLowerCase().includes('/contact'),
            interaction: {
                name: 'Contact Us Page Visited'
            }
        },
        {
            name: "IELTS Page",
            isMatch: () => SalesforceInteractions.resolvers.fromHref()().includes('/ielts'),
            interaction: {
                name: 'IELTS Page Visited'
            },
            listeners: [
                SalesforceInteractions.listener("click", "form.ielts-register-form button[type='submit']", () => {
                    sendContactFormData('form.ielts-register-form', 'IELTS Form Submitted');
                })
            ],

        },
    ]
};
SalesforceInteractions.init({
    cookieDomain: "kgc.com"
})
    .then(() => {
        SalesforceInteractions.initSitemap(sitemapConfig);
    })
    .catch(() => {
        log('ERROR:', 'Initiating the SalesforceInteractions');
    })