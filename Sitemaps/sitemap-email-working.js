SalesforceInteractions.init({
    cookieDomain: "northerntrailoutfitters.com"
  }).then(() => {
    const sitemapConfig = {
        global: {
            contentZones: [
                { name: "global_infobar_top_of_page", selector: "header.site-header" },
                { name: "global_infobar_bottom_of_page", selector: "footer.site-footer" }
            ],
            listeners: [
                SalesforceInteractions.listener("submit", ".email-signup", () => {
                    const email = SalesforceInteractions.cashDom("#dwfrm_mcsubscribe_email").val();
                    if (email) {
                        SalesforceInteractions.sendEvent({
                            action: "Email Sign Up - Footer",
                            user: {
                                id: email
                            }
                        });
                    }
                }),
            ],
        },
        pageTypeDefault: {
            name: "default"
        },
        pageTypes: [
            {
                name: "login",
                action: "EmailCapture",
                isMatch: () => {
                    return SalesforceInteractions.cashDom(".page[data-action='Login-Show']").length > 0;
                },
                listeners: [
                    SalesforceInteractions.listener("submit", ".login", () => {
                        const email = SalesforceInteractions.cashDom("#login-form-email").val();
                        console.log("Email ==> ", email);
                        if (email) {
                            SalesforceInteractions.sendEvent({
                                interaction: {
                                    name: 'Logged In',
                                },
                                user: {
                                    identities: {
                                        emailAddress: email
                                    }
                                }
                            });
                        }
                    })
                ]
            },
            {
                name: "home",
                action: "Homepage",
                isMatch: () => /\/homepage/.test(window.location.href),
                contentZones: [
                    { name: "home_hero", selector: ".experience-carousel-bannerCarousel" },
                    { name: "home_sub_hero", selector: ".experience-carousel-bannerCarousel + .experience-component" },
                    { name: "home_popup" }
                ]
            },
        ]
    };

    const getProductsFromDataLayer = () => {
        if (window.dataLayer) {
            for (let i = 0; i < window.dataLayer.length; i++) {
                if ((window.dataLayer[i].ecommerce && window.dataLayer[i].ecommerce.detail || {}).products) {
                    return window.dataLayer[i].ecommerce.detail.products;
                }
            }
        }
    };

    SalesforceInteractions.initSitemap(sitemapConfig);

});