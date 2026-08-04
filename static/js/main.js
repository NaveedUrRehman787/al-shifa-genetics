let currentMembers = [];
let reservedFamilyId = null; // Locked in when first member is added for a new family

function showToast(message, type = 'success') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    
    let icon = type === 'success' ? '<i class="fa-solid fa-check-circle" style="color:var(--success-color); font-size:1.2rem;"></i>' 
                                  : '<i class="fa-solid fa-circle-exclamation" style="color:var(--danger-color); font-size:1.2rem;"></i>';
                                  
    toast.innerHTML = `${icon} <div>${message}</div>`;
    container.appendChild(toast);
    
    setTimeout(() => {
        toast.style.animation = 'slideIn 0.3s reverse forwards';
        setTimeout(() => toast.remove(), 300);
    }, 4000);
}

// Add Family Logic
function toggleMode() {
    const isExisting = document.querySelector('input[name="family_mode"]:checked').value === 'existing';
    document.getElementById('existing_family_group').style.display = isExisting ? 'block' : 'none';
    // Reset reserved ID when switching mode
    reservedFamilyId = null;
    currentMembers = [];
    renderPreviewTable();
}

function clearForm() {
    document.getElementById('memberForm').reset();
}

function addMember(e) {
    e.preventDefault();
    
    const member = {
        MRNumber: document.getElementById('mr_number').value,
        Name: document.getElementById('name').value,
        CNIC: document.getElementById('cnic').value,
        Age: document.getElementById('age').value,
        Gender: document.getElementById('gender').value,
        BatchNumber: document.getElementById('batch_number').value,
        Doctor: document.getElementById('dr_name').value,
        Department: document.getElementById('department').value,
        Disease: document.getElementById('disease').value,
        Sequencing: document.getElementById('sequencing').value,
        Affected: document.querySelector('input[name="affected"]:checked').value,
        Consanguinity: document.querySelector('input[name="consanguinity"]:checked').value,
        Category: document.querySelector('input[name="category"]:checked').value,
        FamilyHistory: document.querySelector('input[name="family_history"]:checked').value
    };
    
    const mode = document.querySelector('input[name="family_mode"]:checked').value;
    
    // For a new family, fetch and lock the Family ID on the FIRST member add
    if (mode === 'new' && reservedFamilyId === null) {
        fetch('/api/reserve_family_id')
        .then(res => res.json())
        .then(data => {
            reservedFamilyId = data.family_id;
            currentMembers.push(member);
            renderPreviewTable();
            clearForm();
            showToast(`Member added. Family ID: ${reservedFamilyId}`, "success");
        })
        .catch(() => {
            showToast("Could not reserve a Family ID. Is the server running?", "error");
        });
    } else {
        currentMembers.push(member);
        renderPreviewTable();
        clearForm();
        showToast("Member added to preview list", "success");
    }
}

function removeMember(index) {
    currentMembers.splice(index, 1);
    renderPreviewTable();
}

function renderPreviewTable() {
    const tbody = document.querySelector('#previewTable tbody');
    tbody.innerHTML = '';
    
    if (currentMembers.length === 0) {
        tbody.innerHTML = '<tr id="emptyRow"><td colspan="6" style="text-align: center;">No members added yet</td></tr>';
        return;
    }
    
    const mode = document.querySelector('input[name="family_mode"]:checked').value;
    const existingFamilyId = document.getElementById('existing_family').value;
    
    let familyLabel;
    if (mode === 'existing' && existingFamilyId) {
        familyLabel = `<span style="font-size:0.78rem; color:var(--primary-color);">${existingFamilyId}</span>`;
    } else if (reservedFamilyId) {
        familyLabel = `<span style="font-size:0.78rem; color:var(--success-color); font-weight:600;">${reservedFamilyId}</span>`;
    } else {
        familyLabel = `<span style="font-size:0.78rem; color:var(--text-light); font-style:italic;">Add first member...</span>`;
    }
    
    currentMembers.forEach((member, idx) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${familyLabel}</td>
            <td>${member.Name}</td>
            <td>${member.Age}</td>
            <td>${member.BatchNumber}</td>
            <td>${member.Disease}</td>
            <td>
                <button type="button" class="btn btn-danger" style="padding: 6px 12px; font-size: 0.8rem;" onclick="removeMember(${idx})">
                    <i class="fa-solid fa-trash"></i>
                </button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function submitFamily() {
    if (currentMembers.length === 0) {
        showToast("No members to submit. Please add a member first.", "error");
        return;
    }
    
    const mode = document.querySelector('input[name="family_mode"]:checked').value;
    const existingFamilyId = document.getElementById('existing_family').value;
    
    if (mode === 'existing' && !existingFamilyId) {
        showToast("Please select an existing family from the dropdown.", "error");
        return;
    }
    
    const payload = {
        mode: mode,
        existing_family_id: existingFamilyId,
        reserved_family_id: reservedFamilyId,  // Pass the already-reserved ID
        members: currentMembers
    };
    
    fetch('/api/submit_family', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    })
    .then(res => res.json())
    .then(data => {
        if (data.success) {
            showToast(data.message, "success");
            currentMembers = [];
            reservedFamilyId = null;
            renderPreviewTable();
            if (mode === 'new') {
                setTimeout(() => window.location.reload(), 1500);
            }
        } else {
            showToast(data.message, "error");
        }
    })
    .catch(err => {
        console.error(err);
        showToast("An error occurred during submission.", "error");
    });
}

// Global functions for View Records and Analysis Queue
let globalRecords = [];

window.loadRecords = function() {
    fetch('/api/records?processed=1')
    .then(res => res.json())
    .then(data => {
        globalRecords = data;
        window.renderRecordsTable();
    })
    .catch(err => console.error(err));
};

window.renderRecordsTable = function() {
    const thead = document.getElementById('recordsHead');
    const tbody = document.getElementById('recordsBody');
    const modeSelect = document.getElementById('displayMode');
    
    if (!thead || !tbody) return;
    
    const mode = modeSelect ? modeSelect.value : 'essential';
    
    thead.innerHTML = '';
    tbody.innerHTML = '';
    
    if (globalRecords.length === 0) {
        tbody.innerHTML = '<tr><td colspan="100%" style="text-align: center;">No records found</td></tr>';
        return;
    }
    
    let columns = [];
    if (mode === 'essential') {
        columns = [
            { key: 'IndividualID', label: 'Individual ID' },
            { key: 'MRNumber', label: 'MR Number' },
            { key: 'Name', label: 'Name' },
            { key: 'Age', label: 'Age' },
            { key: 'Doctor', label: 'Doctor' },
            { key: 'Disease', label: 'Disease' },
            { key: 'AnalysisStatus', label: 'Status' },
            { key: '_processed', label: 'Processed' },
            { key: '_edit', label: 'Edit' }
        ];
    } else {
        columns = [
            { key: 'FamilyID', label: 'Family ID' },
            { key: 'IndividualID', label: 'Individual ID' },
            { key: 'MRNumber', label: 'MR Number' },
            { key: 'Name', label: 'Name' },
            { key: 'CNIC', label: 'CNIC' },
            { key: 'Age', label: 'Age' },
            { key: 'Gender', label: 'Gender' },
            { key: 'BatchNumber', label: 'Batch Number' },
            { key: 'Doctor', label: 'Doctor' },
            { key: 'Department', label: 'Department' },
            { key: 'Disease', label: 'Disease' },
            { key: 'Sequencing', label: 'Sequencing' },
            { key: 'SampleCollected', label: 'Sample' },
            { key: 'Affected', label: 'Affected' },
            { key: 'Consanguinity', label: 'Consang' },
            { key: 'Category', label: 'Category' },
            { key: 'FamilyHistory', label: 'Family History' },
            { key: 'AnalysisStatus', label: 'Status' },
            { key: '_processed', label: 'Processed' },
            { key: '_edit', label: 'Edit' }
        ];
    }
    
    // Render Header
    const trHead = document.createElement('tr');
    columns.forEach(col => {
        trHead.innerHTML += `<th>${col.label}</th>`;
    });
    thead.appendChild(trHead);
    
    // Render Body
    globalRecords.forEach(row => {
        const tr = document.createElement('tr');
        columns.forEach(col => {
            if (col.key === '_edit') {
                tr.innerHTML += `<td>
                    <button class="btn btn-primary" style="padding:5px 10px; font-size:0.8rem;"
                        onclick="openEditModal('${row.IndividualID}')">
                        <i class="fa-solid fa-pen"></i>
                    </button>
                </td>`;
            } else if (col.key === '_processed') {
                const isProcessed = row.AnalysisStatus === 'Bioinformatics Analysis Complete';
                tr.innerHTML += `<td>${isProcessed
                    ? '<span class="status-badge complete"><i class="fa-solid fa-check"></i> Yes</span>'
                    : '<span class="status-badge pending">No</span>'}</td>`;
            } else if (col.key === 'AnalysisStatus') {
                tr.innerHTML += `<td><span style="padding:4px 8px; border-radius:4px; font-size:0.8rem; background:rgba(1,87,155,0.1); color:var(--primary-color); white-space:nowrap;">${row[col.key] || ''}</span></td>`;
            } else {
                tr.innerHTML += `<td>${row[col.key] || ''}</td>`;
            }
        });
        tbody.appendChild(tr);
    });
    
    // Re-apply search filter if there's any text
    window.filterRecords();
};

// All Samples tab
let globalSamples = [];

window.loadAllSamples = function() {
    fetch('/api/records')
    .then(res => res.json())
    .then(data => {
        globalSamples = data;
        window.renderAllSamplesTable();
    })
    .catch(err => console.error(err));
};

window.renderAllSamplesTable = function() {
    const thead = document.getElementById('samplesHead');
    const tbody = document.getElementById('samplesBody');
    const modeSelect = document.getElementById('samplesDisplayMode');
    
    if (!thead || !tbody) return;
    
    const mode = modeSelect ? modeSelect.value : 'essential';
    
    thead.innerHTML = '';
    tbody.innerHTML = '';
    
    if (globalSamples.length === 0) {
        tbody.innerHTML = '<tr><td colspan="100%" style="text-align: center;">No samples found</td></tr>';
        return;
    }
    
    let columns = [];
    if (mode === 'essential') {
        columns = [
            { key: 'IndividualID', label: 'Individual ID' },
            { key: 'MRNumber', label: 'MR Number' },
            { key: 'Name', label: 'Name' },
            { key: 'Age', label: 'Age' },
            { key: 'Doctor', label: 'Doctor' },
            { key: 'Disease', label: 'Disease' },
            { key: 'AnalysisStatus', label: 'Status' },
            { key: '_processed', label: 'Processed' },
            { key: '_action', label: 'Action' }
        ];
    } else {
        columns = [
            { key: 'FamilyID', label: 'Family ID' },
            { key: 'IndividualID', label: 'Individual ID' },
            { key: 'MRNumber', label: 'MR Number' },
            { key: 'Name', label: 'Name' },
            { key: 'CNIC', label: 'CNIC' },
            { key: 'Age', label: 'Age' },
            { key: 'Gender', label: 'Gender' },
            { key: 'BatchNumber', label: 'Batch Number' },
            { key: 'Doctor', label: 'Doctor' },
            { key: 'Department', label: 'Department' },
            { key: 'Disease', label: 'Disease' },
            { key: 'Sequencing', label: 'Sequencing' },
            { key: 'SampleCollected', label: 'Sample' },
            { key: 'Affected', label: 'Affected' },
            { key: 'Consanguinity', label: 'Consang' },
            { key: 'Category', label: 'Category' },
            { key: 'FamilyHistory', label: 'Family History' },
            { key: 'AnalysisStatus', label: 'Status' },
            { key: '_processed', label: 'Processed' },
            { key: '_action', label: 'Action' }
        ];
    }
    
    const trHead = document.createElement('tr');
    columns.forEach(col => {
        trHead.innerHTML += `<th>${col.label}</th>`;
    });
    thead.appendChild(trHead);
    
    globalSamples.forEach(row => {
        const tr = document.createElement('tr');
        const isProcessed = row.AnalysisStatus === 'Bioinformatics Analysis Complete';
        columns.forEach(col => {
            if (col.key === '_action') {
                tr.innerHTML += `<td>${isProcessed
                    ? '<span class="status-badge complete"><i class="fa-solid fa-check"></i> Processed</span>'
                    : `<button class="btn btn-success" style="padding:5px 12px; font-size:0.8rem; white-space:nowrap;" onclick="addToProcessed('${row.IndividualID}')">
                            <i class="fa-solid fa-check"></i> Add to Processed
                       </button>`}</td>`;
            } else if (col.key === '_processed') {
                tr.innerHTML += `<td>${isProcessed
                    ? '<span class="status-badge complete"><i class="fa-solid fa-check"></i> Yes</span>'
                    : '<span class="status-badge pending">No</span>'}</td>`;
            } else if (col.key === 'AnalysisStatus') {
                tr.innerHTML += `<td><span style="padding:4px 8px; border-radius:4px; font-size:0.8rem; background:rgba(1,87,155,0.1); color:var(--primary-color); white-space:nowrap;">${row[col.key] || ''}</span></td>`;
            } else {
                tr.innerHTML += `<td>${row[col.key] || ''}</td>`;
            }
        });
        tbody.appendChild(tr);
    });
    
    window.filterSamples();
};

window.addToProcessed = function(individualId) {
    fetch('/api/mark_processed', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ individual_id: individualId })
    })
    .then(res => res.json())
    .then(data => {
        if (data.success) {
            showToast(data.message, "success");
            window.loadAllSamples();
        } else {
            showToast(data.message, "error");
        }
    })
    .catch(err => {
        console.error(err);
        showToast("An error occurred while processing the sample.", "error");
    });
};

window.filterSamples = function() {
    const term = document.getElementById('samplesSearchInput').value.toLowerCase();
    const rows = document.querySelectorAll('#allSamplesTable tbody tr');
    
    rows.forEach(row => {
        if (row.id === 'emptyRow') return;
        const text = row.textContent.toLowerCase();
        row.style.display = text.includes(term) ? '' : 'none';
    });
};

window.loadAnalysisQueue = function() {
    fetch('/api/analysis_queue')
    .then(res => res.json())
    .then(data => {
        const select = document.getElementById('analysis_individual');
        if (!select) return;
        
        select.innerHTML = '<option value="">Select an individual...</option>';
        data.queue.forEach(item => {
            select.innerHTML += `<option value="${item.IndividualID}">${item.Name} (${item.IndividualID})</option>`;
        });
        
        const tbody = document.querySelector('#queueTable tbody');
        tbody.innerHTML = '';
        if (data.queue.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" style="text-align: center;">No pending analysis</td></tr>';
        } else {
            data.queue.forEach(row => {
                tbody.innerHTML += `
                    <tr>
                        <td>${row.IndividualID}</td>
                        <td>${row.Name}</td>
                        <td>${row.Disease}</td>
                        <td>${row.Sequencing}</td>
                    </tr>
                `;
            });
        }
        
        document.getElementById('pending_count').textContent = data.stats.pending;
        document.getElementById('completed_count').textContent = data.stats.completed;
        document.getElementById('total_count').textContent = data.stats.total;
    });
};

window.startAnalysis = function() {
    const ind_id = document.getElementById('analysis_individual').value;
    const type = document.getElementById('analysis_type').value;
    
    if (!ind_id || !type) {
        showToast("Please select both an individual and analysis type", "error");
        return;
    }
    
    fetch('/api/start_analysis', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ individual_id: ind_id, analysis_type: type })
    })
    .then(res => res.json())
    .then(data => {
        if (data.success) {
            showToast(data.message, "success");
            window.loadAnalysisQueue();
        } else {
            showToast(data.message, "error");
        }
    });
};

window.clearData = function() {
    if (confirm("Are you sure you want to clear all data? This cannot be undone.")) {
        fetch('/api/clear_data', { method: 'POST' })
        .then(res => res.json())
        .then(data => {
            if (data.success) {
                showToast(data.message, "success");
            } else {
                showToast(data.message, "error");
            }
        });
    }
};

window.filterRecords = function() {
    const term = document.getElementById('searchInput').value.toLowerCase();
    const rows = document.querySelectorAll('#recordsTable tbody tr');
    
    rows.forEach(row => {
        if (row.id === 'emptyRow') return;
        const text = row.textContent.toLowerCase();
        row.style.display = text.includes(term) ? '' : 'none';
    });
};
