window.addEventListener('keydown', function (event) {
    if (event.key !== 'Enter' || !contractState || document.getElementById('contractOverlay').classList.contains('hidden')) return;
    const target = event.target;
    if (target && ['INPUT', 'TEXTAREA', 'BUTTON'].includes(target.tagName)) return;
    event.preventDefault();
    if (contractState.status === 'draft') submitSellerSignature();
    else if (contractState.status === 'seller_signed') submitBuyerSignature();
    else if (contractState.status === 'buyer_signed') submitToDMV();
});
