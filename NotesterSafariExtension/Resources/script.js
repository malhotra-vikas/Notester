document.addEventListener("contextmenu", handleContextMenu);

function handleContextMenu(event) {
    const selectedText = window.getSelection().toString().trim();
    if (selectedText) {
        browser.runtime.sendMessage({
            name: "selectedText",
            text: selectedText,
            sourceURL: window.location.href
        });
    }
}