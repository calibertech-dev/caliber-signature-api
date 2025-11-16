# Caliber SignatureAPI Integration

The **Caliber SignatureAPI Integration** package provides a complete, extensible, production-grade digital signature engine for the **Caliber Platform**.  
It orchestrates creation, routing, sending, signing, event processing, and document retrieval through a unified, metadata-driven model that supports **Flow**, **Apex**, and **LWC** clients.

This package is designed for commercial use: fully configurable, scalable, and ready for managed packaging and AppExchange distribution.

---

## Overview

This integration enables Salesforce records—such as **Contracts**, **Contract Amendments**, and **Proposals**—to be sent to SignatureAPI for digital signatures using a flexible template system.

The package provides:

- Custom objects for envelope templates, recipients, places, and events  
- Builder and orchestration Apex services  
- A webhook processor for SignatureAPI events  
- Flow-invocable actions for low-code automation  
- Automatic document download and publishing  
- Parent record linking and polymorphic naming  
- Error handling using Caliber Core’s ErrorLog framework  

The result is a signature automation engine suitable for both internal business use and commercial resale.

---

## Core Features

### Template-Driven Envelope Generation
- **Envelope_Template__c** defines routing mode (Sequential or Parallel) and ceremony creation (Manual or Automatic).  
- **Envelope_Place_Template__c** controls signer positions, styles, fields, and capture settings (signature, initials, text input, checkboxes, etc.).  
- Validation rules enforce field compatibility based on `Place_Type__c`.

### Recipients & Routing
- Metadata-driven recipient templates  
- Support for sequential and parallel workflows  
- Supports manual vs automatic ceremony creation  
- LWC/Flow can dynamically supply recipients

### Document Handling
- Multiple modes supported:
  - **ContentVersion** (Salesforce files)  
  - **Document URL** (Google Drive, OneDrive, Box, etc.)  
  - **File ID** (for supported document stores)  
- Future support: automatic upload of LINK files

### Flow Actions
The package exposes invocable actions:
- `SignatureApiCreateEnvelopeAction`
- `SignatureApiCreateCeremonyAction`
- `SignatureApiDownloadAction`

These allow no-code automation for:
- Envelope creation  
- Ceremony creation (per recipient)  
- Downloading completed deliverables into Salesforce  

### Webhook Processor
A robust queueable handler:
- Captures **all SignatureAPI webhook events**  
- Writes them as `Envelope_Event__c`  
- Updates Envelope__c / Envelope_Recipient__c status  
- Optionally triggers document download  
- Idempotent and retry-safe

### Error Logging
All classes integrate with **Caliber Core’s ErrorLogService**, giving:
- Correlation IDs  
- Exception type and stack trace  
- Structured payload logging  
- Parent record linking for traceability  

---

## Package Dependencies

### Required
- **Caliber Core**  
  - ErrorLogService  
  - PolymorphicRecordNameUtil  
  - Infrastructure fields (Parent_Record_* metadata)  

### Optional
- **Caliber Commerce**  
  - For documents coming from Contracts / Proposals  
- **Caliber Restoration**, **Caliber Project Management**, etc.  
  - If envelopes originate from domain-specific objects

---

## Installation & Setup

1. Install dependencies:
   1. `Caliber Core`
   2. `Caliber SignatureAPI Integration`

2. Assign permission sets:
   - `SignatureAPI Admin`
   - `SignatureAPI User`

3. Configure Named Credential:
   - Maps to your SignatureAPI base endpoint  
   - Includes API key or OAuth auth mechanism  
   - Test connectivity using Upcoming Setup LWC  

4. Configure Webhook:
   - Copy endpoint URL: `/services/apexrest/signatureAPIWebhook`
   - Paste into your SignatureAPI “Developer → Webhooks” settings  
   - Point it to your Salesforce Named Credential URL

5. Create Envelope Templates & Place Templates
   - Define routing mode  
   - Configure ceremony creation  
   - Add place templates (Signature, Initials, Text Input, etc.)

6. Build automation using:
   - Flow  
   - Apex  
   - The Envelope Orchestration LWC (on roadmap)

---

## Data Model

### Signature Entities

| Object | Description |
|--------|-------------|
| **Envelope__c** | Represents a sent or pending signature envelope. Stores routing mode, status, parent record, and SignatureAPI Envelope Id. |
| **Envelope_Recipient__c** | Represents each signer in the envelope workflow. Includes status, email, signing URL, and optional Contact/User linkage. |
| **Envelope_Place_Template__c** | Defines signer prompts: signature boxes, text fields, checkboxes, recipient-linked fields, formatting, etc. |
| **Envelope_Template__c** | Master configuration for routing mode, ceremony creation, and place templates. |
| **Envelope_Event__c** | Stores every webhook event from SignatureAPI for audit and automation. |

### Document Templates

| Object | Description |
|--------|-------------|
| **Document_Template__c** | Links parent objects (Contract, Proposal, etc.) to Envelope Templates. Controls document sourcing (Salesforce file or external URL). |

---

## Workflow Summary

### Envelope Creation Flow
1. User (or Flow) selects parent record  
2. Document Template resolves linked Envelope Template  
3. Envelope Builder:
   - Loads template  
   - Loads recipients  
   - Assembles signing payload  
   - Uploads document to SignatureAPI  
   - Creates envelope  
   - Optionally creates first ceremony (manual/automatic)  
4. Notification service sends ceremony links  

### Webhook Flow
1. SignatureAPI triggers events  
2. Webhook Receiver creates Envelope_Event__c  
3. Queueable Processor:
   - Updates recipients  
   - Updates envelope status  
   - Creates next ceremony in sequential flows  
   - Downloads completed files  

---

## Planned Features (Roadmap)

The following enhancements are planned for full v1.0 market readiness:

### 🔧 Configuration & Setup
- **LWC Setup Wizard**  
  - Named Credential configuration  
  - Webhook validation tester  
  - Account connection status  
- **Custom Metadata: SignatureApi_Settings__mdt**  
  - Routing defaults  
  - Ceremony defaults  
  - Debug logging options  
  - Auto-retry settings  

### 🧩 Document Processing
- Add full **LINK file support** (Google Drive, OneDrive)  
- Multi-document envelope support  
- Automatic PDF merging for multi-doc envelopes

### 👥 Recipient Enhancements
- Role-based recipient templates (Client, Contractor, Manager, Witness)  
- Automatic Contact/User linking  
- Reminders & escalation

### 🔄 Event & Automation
- Publish **Platform Events** for:
  - Envelope Completed  
  - Recipient Completed  
  - Deliverable Generated  
- Scheduled “stuck envelope” repair job  
- Retry queue for download failures

### 📄 UI Enhancements
- Admin Dashboard LWC  
  - Webhook health  
  - Envelope queue  
  - Error log viewer  
- Envelope Builder LWC  
  - Drag-and-drop recipients  
  - Document selection  
  - “Send Envelope” button  
- Recipient signing timeline component

### 📦 Packaging & Distribution
- Managed package namespace integration  
- Post-install script to auto-create baseline templates  
- Guided onboarding flow  
- Sample Contract/Proposal Flows  
- Full admin + dev documentation

---

## Roadmap Summary (TODO List)

**Core Productization**
- [ ] LWC Setup Wizard  
- [ ] Custom Metadata settings framework  
- [ ] Permission sets  
- [ ] Lightning App  
- [ ] Example Flows  
- [ ] Full documentation package

**Functional Enhancements**
- [ ] Platform Events  
- [ ] Multi-doc envelope support  
- [ ] Retry & repair jobs  
- [ ] Recipient role templates  
- [ ] LINK File support

**UX Enhancements**
- [ ] Admin Dashboard  
- [ ] Envelope Builder LWC  
- [ ] Recipient Timeline component

**Packaging**
- [ ] Post-install configuration script  
- [ ] Namespace cleanup  
- [ ] Test isolation improvements  
- [ ] Validation of webhook and named credential setup

---

## License

This project is licensed under the terms described in the [LICENSE.md](./LICENSE.md) file.

© 2025 Caliber Technologies LLC  
For commercial inquiries: **dev@calibertech.net**
