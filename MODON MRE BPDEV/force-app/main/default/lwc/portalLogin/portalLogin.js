import { LightningElement, api } from 'lwc';
import login from '@salesforce/apex/PortalLoginController.login';

export default class PortalLogin extends LightningElement {
    // Set these in Experience Builder.
    @api portalUrl = '/';          // start URL after a successful login
    @api registerOwnerUrl = '#';
    @api registerSpUrl = '#';

    username = '';
    password = '';
    error = '';
    loading = false;

    handleUser(event) { this.username = event.target.value; }
    handlePass(event) { this.password = event.target.value; }

    async handleLogin(event) {
        event.preventDefault();
        this.error = '';
        if (!this.username || !this.password) {
            this.error = 'Please enter your email and password.';
            return;
        }
        this.loading = true;
        try {
            const url = await login({
                username: this.username,
                password: this.password,
                startUrl: this.portalUrl
            });
            if (url) {
                window.location.href = url;
            } else {
                this.error = 'Invalid credentials. Please try again.';
            }
        } catch (err) {
            this.error = err?.body?.message || 'Sign in failed. Please try again.';
        } finally {
            this.loading = false;
        }
    }
}