browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.name === "selectedText") {
        browser.runtime.sendNativeMessage("application.id", request, (response) => {
            console.log("Received response: ", response);
        });
    }
});
