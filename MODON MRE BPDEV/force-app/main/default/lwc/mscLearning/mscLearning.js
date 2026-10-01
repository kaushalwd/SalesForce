/**
 * Learning pane.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Reads published Knowledge articles. The PoC's
 *                                   version was six hardcoded courses with invented
 *                                   scores and certificates; that is not ported.
 */

import { LightningElement, wire } from "lwc";
import getLearningArticles from "@salesforce/apex/SalesConsoleContentController.getLearningArticles";
import { formatDate, reduceError } from "c/modonSalesFormat";

export default class MscLearning extends LightningElement {
  articles = [];
  loading = true;
  errorMsg = "";
  search = "";

  @wire(getLearningArticles)
  wired({ data, error }) {
    if (data) {
      this.articles = data;
      this.loading = false;
    } else if (error) {
      this.errorMsg = reduceError(error);
      this.loading = false;
    }
  }

  get rows() {
    const term = this.search.trim().toLowerCase();
    return this.articles
      .filter(
        (a) =>
          !term ||
          (a.title || "").toLowerCase().indexOf(term) !== -1 ||
          (a.summary || "").toLowerCase().indexOf(term) !== -1
      )
      .map((a) => ({
        ...a,
        key: a.id,
        dateLabel: a.lastPublished ? formatDate(a.lastPublished) : ""
      }));
  }

  get hasRows() {
    return this.rows.length > 0;
  }
  get isEmpty() {
    return !this.loading && this.articles.length === 0;
  }
  get noMatch() {
    return !this.loading && this.articles.length > 0 && !this.hasRows;
  }
  get hasSearch() {
    return !!this.search;
  }
  handleSearch(e) {
    this.search = e.target.value;
  }
  clearSearch() {
    this.search = "";
  }
}