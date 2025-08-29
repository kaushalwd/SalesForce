
SalesforceInteractions.init({
      cookieDomain: "northerntrailoutfitters.com",
      consents: [{
          purpose: SalesforceInteractions.mcis.ConsentPurpose.Personalization,
          provider: "Example Consent Manager",
          status: SalesforceInteractions.ConsentStatus.OptIn
      }]
  }).then(() => {
      const sitemapConfig = {
          global: {
              locale: "en_US",
              onActionEvent: (actionEvent) => {
                  const email = SalesforceInteractions.mcis.getValueFromNestedObject("window._etmc.user_info.email");
                  if (email) {
                      actionEvent.user = actionEvent.user || {};
                      actionEvent.user.identities = actionEvent.user.identities || {};
                      actionEvent.user.identities.emailAddress = email;
                  }
                  return actionEvent;
              },
              contentZones: [
                  { name: "global_infobar_top_of_page", selector: "header.site-header" },
                  { name: "global_infobar_bottom_of_page", selector: "footer.site-footer" }
              ],
              listeners: [
                  SalesforceInteractions.listener("submit", ".email-signup", () => {
                      const email = SalesforceInteractions.cashDom("#dwfrm_mcsubscribe_email").val();
                      if (email) {
                          SalesforceInteractions.sendEvent({
                              interaction: {
                                  name: "Email Sign Up - Footer"
                              },
                              user: {
                                  identities: {
                                      emailAddress: email
                                  }
                              }
                          });
                      }
                  })
              ],
          },
          pageTypeDefault: {
              name: "default",
              interaction: {
                  name: "Default Page"
              }
          },
          pageTypes: [
              {
                  name: "product_detail",
                  /*
                  The best practice for isMatch is to match as quickly as possible. If matching immediately is not an option, you can use a Promise.
                  The Promise should resolve true or false and not pend indefinitely. This Promise example uses a setTimeout to prevent the isMatch from pending indefinitely if the match condition is not met fast enough. In this scenario, we know that the match condition will be met within 50 milliseconds or not at all. Note that using a timeout like this might not be sufficient in all cases and if you are using a Promise it should be tailored to your specific use-case. 
                  */
                  isMatch: () => new Promise((resolve, reject) => {
                      let isMatchPDP = setTimeout(() => {
                          resolve(false);
                      }, 50);
                      return SalesforceInteractions.DisplayUtils.pageElementLoaded("div.page[data-action='Product-Show']", "html").then(() => {
                          clearTimeout(isMatchPDP);
                          resolve(true);
                      })
                  }),
                  interaction: {
                      name: SalesforceInteractions.CatalogObjectInteractionName.ViewCatalogObject,
                      catalogObject: {
                          type: "Product",
                          id: () => {
                              return SalesforceInteractions.util.resolveWhenTrue.bind(() => {
                                  const productId = SalesforceInteractions.cashDom(".product-id").first().text();
                                  const products = getProductsFromDataLayer();
                                  if (products && products.length > 0) {
                                      return products[0].id;
                                  } else if (productId) {
                                      return productId;
                                  } else {
                                      return false;
                                  }
                              })
                          },
                          attributes: {
                              sku: { id: SalesforceInteractions.cashDom(".product-detail[data-pid]").attr("data-pid") },
                              name: SalesforceInteractions.resolvers.fromJsonLd("name"),
                              description: SalesforceInteractions.resolvers.fromSelector(".short-description", (desc) => desc.trim()),
                              url: SalesforceInteractions.resolvers.fromHref(),
                              imageUrl: SalesforceInteractions.resolvers.fromSelectorAttribute(".product-carousel .carousel-item[data-slick-index='0'] img", "src",
                              (url) =>  window.location.origin + url),
                              inventoryCount: 1,
                              price: SalesforceInteractions.resolvers.fromSelector(".prices .price .value", (price) => parseFloat(price.replace(/[^0-9\.]+/g,"")))
                          },
                          relatedCatalogObjects: {
                              Category: SalesforceInteractions.DisplayUtils.pageElementLoaded(".container .product-breadcrumb .breadcrumb a", "html").then((ele) => {
                                  return SalesforceInteractions.resolvers.buildCategoryId(".container .product-breadcrumb .breadcrumb a", null, null, (categoryId) => [categoryId.toUpperCase()]);
                              }),
                              Gender: SalesforceInteractions.DisplayUtils.pageElementLoaded(".product-breadcrumb .breadcrumb a, h1.product-name", "html").then((ele) => {
                                  if (SalesforceInteractions.cashDom(".product-breadcrumb .breadcrumb a").first().text().toLowerCase() === "women" || 
                                  SalesforceInteractions.cashDom("h1.product-name").text().indexOf("Women") >= 0) {
                                      return ["WOMEN"];
                                  } else if (SalesforceInteractions.cashDom(".product-breadcrumb .breadcrumb a").first().text().toLowerCase() === "men" || 
                                  SalesforceInteractions.cashDom("h1.product-name").text().indexOf("Men") >= 0) {
                                      return ["MEN"];
                                  } else {
                                      return;
                                  }
                              }),
                              Color: SalesforceInteractions.DisplayUtils.pageElementLoaded(".attributes", "html").then((ele) => {
                                  return SalesforceInteractions.resolvers.fromSelectorAttributeMultiple(".color-value", "data-attr-value");
                              }),
                              Feature: SalesforceInteractions.DisplayUtils.pageElementLoaded(".features", "html").then((ele) => {
                                  return SalesforceInteractions.resolvers.fromSelectorMultiple(".long-description li", (features) => {
                                      return features.map((feature) => {
                                          return feature.trim().toUpperCase();
                                      })
                                  })
                              })
                          }
                      }
                  },
                  contentZones: [
                      { name: "product_detail_recs_row_1", selector: ".row.recommendations div[id*='cq']:nth-of-type(1)" },
                      { name: "product_detail_recs_row_2", selector: ".row.recommendations div[id*='cq']:nth-of-type(2)" },
                      { name: "product_detail_popup" },
                  ],
                  listeners: [
                      SalesforceInteractions.listener("click", ".add-to-cart", () => {
                          let lineItem = SalesforceInteractions.mcis.buildLineItemFromPageState("select.quantity-select option:checked");
                          SalesforceInteractions.sendEvent({
                              interaction: {
                                  name: SalesforceInteractions.CartInteractionName.AddToCart,
                                  lineItem: lineItem
                              }
                          })
                      })
                  ]
              },
              {
                  name: "category",
                  isMatch: () => new Promise((resolve, reject) => {
                      let isMatchCat = setTimeout(() => {
                          resolve(false);
                      }, 50);
                      return SalesforceInteractions.DisplayUtils.pageElementLoaded("#product-search-results", "html").then(() => {
                          clearTimeout(isMatchCat);
                          resolve(SalesforceInteractions.cashDom(".breadcrumb").length > 0);
                      });
                  }),
                  interaction: {
                      name: SalesforceInteractions.CatalogObjectInteractionName.ViewCatalogObject,
                      catalogObject: {
                          type: "Category",
                          id: SalesforceInteractions.DisplayUtils.pageElementLoaded(".breadcrumb .breadcrumb-item a", "html").then((ele) => {
                              return SalesforceInteractions.resolvers.buildCategoryId(".breadcrumb .breadcrumb-item a", 1, null, (categoryId) => categoryId.toUpperCase());
                          })
                      }
                  },
                  listeners: [
                      SalesforceInteractions.listener("click", ".quickview", (e) => {
                          const pid = SalesforceInteractions.cashDom(e.target).attr("href").split("pid=")[1];
                          if (!pid) {
                              return;
                          }
  
                          SalesforceInteractions.sendEvent({
                              interaction: {
                                  name: SalesforceInteractions.CatalogObjectInteractionName.QuickViewCatalogObject,
                                  catalogObject: {
                                      type: "Product",
                                      id: pid
                                  }
                              }
                          });
                      }),
                      SalesforceInteractions.listener("click", "body", (e) => {
                          if (SalesforceInteractions.cashDom(e.target).closest("button[data-dismiss='modal']").length > 0) {
                              SalesforceInteractions.sendEvent({
                                  interaction: {
                                      name: SalesforceInteractions.mcis.CatalogObjectInteractionName.StopQuickViewCatalogObject,
                                  }
                              });
                          } else if (SalesforceInteractions.cashDom(e.target).closest("#quickViewModal").length > 0 
                          && SalesforceInteractions.cashDom(e.target).find("#quickViewModal .modal-dialog").length > 0) {
                              SalesforceInteractions.sendEvent({
                                  interaction: {
                                      name: SalesforceInteractions.mcis.CatalogObjectInteractionName.StopQuickViewCatalogObject,
                                  }
                              });
                          }
                      })
                  ]
              },
              {
                  name: "login",
                  isMatch: () => /\/login/.test(window.location.href) && window.location.hostname !== "community.northerntrailoutfitters.com",
                  interaction: {
                      name: "Login"
                  },
                  listeners: [
                      SalesforceInteractions.listener("click", "form[name='login-form'] button", () => {
                          const email = SalesforceInteractions.cashDom("#login-form-email").val();
                          if (email) {
                              SalesforceInteractions.sendEvent({ interaction: { name: "Logged In" }, user: { identities: { emailAddress: email } } });
                          }
                      })
                  ]
              },
              {
                  name: "homepage",   
                  isMatch: () => /\/homepage/.test(window.location.href),
                  interaction: {
                      name: "Homepage"
                  },
                  contentZones: [
                      { name: "home_hero", selector: ".experience-carousel-bannerCarousel" },
                      { name: "home_sub_hero", selector: ".experience-carousel-bannerCarousel + .experience-component" },
                      { name: "home_popup" }
                  ]
              }
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