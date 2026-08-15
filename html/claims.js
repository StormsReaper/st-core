let stClaimVehicles = [];
function stOpenClaimUI(vehicles) {
    stClaimVehicles = vehicles || [];
    const eligible = stClaimVehicles.filter(v => v.policy_id && v.insurance_status === 'active' && Number(v.insurance_expires_at || 0) >= Math.floor(Date.now() / 1000));
    const options = eligible.map((v, i) => `<label class="selection-card"><input type="radio" name="claimVehicle" value="${i}"><span><strong>${esc(v.vehicle || 'Vehicle')}</strong><small>${esc(v.plate)} · ${esc(v.insurance_plan || 'Insured')}</small></span></label>`).join('');
    openModal('Insurance Claim', 'Report an incident involving one of your insured vehicles.', `<div class="service-form"><h3>Insured vehicle</h3>${options ? `<div class="selection-list">${options}</div>` : '<div class="empty">You have no active insured vehicles available for a claim.</div>'}<label class="form-label">Incident type<select id="claimType" class="text-input"><option value="collision">Collision</option><option value="theft">Theft</option><option value="vandalism">Vandalism</option><option value="weather">Weather damage</option><option value="other">Other</option></select></label><label class="form-label">Incident location<input id="claimLocation" class="text-input" maxlength="200" placeholder="Where did it happen?"></label><label class="form-label">Estimated damage<input id="claimDamage" class="text-input" type="number" min="0" step="1" placeholder="0"></label><label class="form-label">What happened?<textarea id="claimDescription" class="text-input" maxlength="2000" rows="6" placeholder="Describe the incident in detail..."></textarea></label><div class="notice"><strong>Claim submission</strong><span>Ownership and active insurance are verified again by the server. A claim submission does not automatically approve a payout.</span></div><div class="actions"><button class="action secondary" onclick="closeModal()">Cancel</button><button class="action" onclick="stSubmitClaim()" ${eligible.length ? '' : 'disabled'}>Submit claim</button></div></div>`);
}
function stSubmitClaim() {
    const selected = document.querySelector('input[name="claimVehicle"]:checked');
    if (!selected) return toast('Select an insured vehicle.');
    const vehicle = stClaimVehicles[Number(selected.value)];
    const description = document.getElementById('claimDescription').value.trim();
    if (description.length < 10) return toast('Provide at least 10 characters describing the incident.');
    nui('submitInsuranceClaim', { plate: vehicle.plate, incidentType: document.getElementById('claimType').value, location: document.getElementById('claimLocation').value.trim(), damageEstimate: Number(document.getElementById('claimDamage').value || 0), description });
}
window.addEventListener('message', function(e) {
    const d = e.data || {};
    if (d.action === 'openClaim') stOpenClaimUI([]);
    if (d.action === 'claimVehicles') stOpenClaimUI(d.vehicles || []);
    if (d.action === 'claimResult') {
        if (d.success) { toast(`Claim ${d.result?.claim_number || ''} submitted successfully.`); closeModal(); }
        else toast(`Claim could not be submitted: ${String(d.result || 'Unknown error').replaceAll('_', ' ')}`);
    }
});
