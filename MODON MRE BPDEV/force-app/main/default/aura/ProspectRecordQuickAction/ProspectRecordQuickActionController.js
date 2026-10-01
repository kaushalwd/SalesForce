({
    handleClose : function(component, event) {
        // Guard to avoid double firing
        if (component.get("v.isClosing")) return;
        component.set("v.isClosing", true);

        // Get refresh flag (works for both LWC and Aura event shapes)
        let refresh = true;
        try {
            if (event.getParam && event.getParam('detail')) {
                refresh = !!event.getParam('detail').refresh;
            } else if (event.detail) {
                refresh = !!event.detail.refresh;
            }
        } catch (e) {
            refresh = false;
        }

        // 1) Close the quick action panel
        $A.get("e.force:closeQuickAction").fire();

        // 2) Refresh the page (standard + fallback navigate)
        if (refresh) {
           window.location.reload();
        }
    }
})