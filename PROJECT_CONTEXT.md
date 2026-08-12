# JVA PROJECT TRACKER — PROJECT CONTEXT

## 1. Platform Overview

JVA Project Tracker is an internal AI-powered Business Operating System built for JV ALMA CIS.

The goal is NOT simply to track tenders.

The platform exists to help the company:

* Discover business opportunities
* Evaluate opportunities
* Decide which opportunities to pursue
* Generate proposals
* Manage submissions
* Manage awarded projects
* Capture organizational knowledge
* Learn from successful and unsuccessful opportunities
* Improve future AI recommendations

Every completed project should strengthen the organization's knowledge base.

Long-term, the platform may evolve into a SaaS platform for organizations managing opportunity discovery, proposal generation, project delivery, and organizational intelligence.

---

# 2. Company

## JV ALMA CIS

### Business Units

* Construction
* Agribusiness / Capacity Building / Community Empowerment
* Oil & Gas Services
* Information Technology

### Main Products

* CoffeeCore
* Kilimo Mkononi
* NyumbaSmart
* ALMA Works
* ALMA Hub

---

# 3. Technology Stack

## Frontend

* Flutter
* Material 3
* Riverpod

## Backend

* Firebase Authentication
* Cloud Firestore
* Cloud Functions
* Firebase Storage

## AI

* Gemini API

## Infrastructure

* Firebase Hosting
* Cloud Scheduler
* Firestore

## Languages

* Dart
* Node.js

---

# 4. Core Architecture Principles

## 4.1 Modular Architecture

Every major entity follows:

* Model
* Service
* Providers
* Screens / Workspace
* Reusable widgets where appropriate
* Tests

Do not introduce shortcuts or duplicate feature-specific architecture.

---

## 4.2 Riverpod

All providers belong in:

`lib/services/providers.dart`

Do not create feature-specific provider files unless explicitly approved as an architectural change.

---

## 4.3 Firestore

Each major entity has its own Firestore collection.

Whenever a new collection is introduced:

* Update Firestore rules
* Update indexes when required
* Update services
* Update providers
* Update tests
* Document deployment requirements

Never leave Firestore configuration incomplete.

---

## 4.4 Relationships

Relationships use:

`List<String>`

containing Firestore document IDs.

Never embed entire objects inside other entities.

Examples:

* businessUnitIds
* productIds
* serviceIds
* capabilityIds
* technologyIds
* industryIds
* experienceIds
* knowledgeArticleIds
* proposalIds
* submissionIds
* projectIds

---

# 5. Business Lifecycle

The platform follows one continuous business lifecycle:

Tender Sources

↓

Discovery Engine

↓

Opportunity Import

↓

AI Classification

↓

Company Intelligence Matching

↓

Capability / Experience / Technology Matching

↓

Strategic Review

↓

Opportunity Workspace

↓

Proposal Workspace

↓

Submission Workspace

↓

Client Evaluation

↓

Awarded / Lost

↓

Project Workspace

↓

Project Delivery

↓

Lessons Learned

↓

Experience

↓

Knowledge Articles

↓

Company Intelligence

↓

AI Learning

↓

Future Opportunity Discovery

The lifecycle is continuous rather than a collection of independent CRUD modules.

---

# 6. Company Intelligence Graph

Company Intelligence is the organization's reusable knowledge graph.

Core entities:

Business Units

↓

Products

↓

Services

↓

Capabilities

↓

Technologies

↓

Industries

↓

Experiences

↓

Knowledge Articles

↓

Documents

↓

Projects

↓

Opportunities

The graph is used by AI throughout the platform.

AI recommendations should use this graph rather than relying only on keyword matching.

---

# 7. Platform Modules

## 7.1 Dashboard

The Dashboard is the executive operating center.

It should answer quickly:

* What requires attention?
* What should we work on next?
* Which opportunities are strongest?
* Which proposals need work?
* Which submissions are blocked?
* Which projects require attention?
* What is AI recommending?
* How healthy is Company Intelligence?
* Which Tender Sources require attention?

Dashboard cards should navigate directly to the relevant Workspace.

The Dashboard must evolve whenever a major workspace is introduced.

The Dashboard should not become a second CRUD interface.

### Important

The existence of a workspace does NOT automatically mean the Dashboard is integrated with it.

A module is considered fully integrated only when:

* Dashboard entry points are correct
* Navigation points to the Workspace
* Command Palette points to the Workspace
* Contextual actions use the Workspace
* Legacy navigation is removed or deliberately retained
* The Workspace itself is functional
* Responsive behaviour is verified

---

# 8. Company Intelligence

Company Intelligence contains:

* Business Units
* Products
* Services
* Capabilities
* Technologies
* Industries
* Experiences
* Knowledge Articles
* Documents

These modules should behave as knowledge workspaces rather than basic CRUD screens.

Each subsection should provide:

* Entity information
* Related organizational knowledge
* Relevant relationships
* AI summaries where implemented
* Related projects/opportunities where applicable
* Contextual navigation

Do not create duplicate entities outside Company Intelligence.

Company Intelligence is the source of truth for organizational capabilities and experience.

---

# 9. AI Knowledge Extraction

The platform can convert historical project documentation into structured organizational knowledge.

Supported documents include:

* Technical Proposals
* Financial Proposals
* Contracts
* Award Letters
* Completion Certificates
* Progress Reports
* Bills of Quantities
* Client Correspondence
* Lessons Learned

### Workflow

Upload Project Document

↓

Gemini Extraction

↓

Human Review

↓

Approve

↓

Update Project

↓

Experience

↓

Knowledge Articles

↓

Company Intelligence

↓

Future AI Reasoning

AI must never publish extracted information automatically.

Human review is required before extracted information becomes organizational knowledge.

The purpose is to learn:

* What the company has delivered
* Who the company has worked with
* Contract values
* Project sectors
* Technologies used
* Capabilities demonstrated
* Business units involved
* Outcomes
* Risks
* Lessons learned
* Reasons for success
* Reasons for failure where available

---

# 10. Opportunity Intelligence

Opportunity Intelligence includes:

* Opportunity Discovery
* Opportunity Workspace
* AI Classification
* Match Analysis
* Strategic Review
* AI Recommendations
* Notifications
* Discovery Engine

An opportunity should be evaluated using Company Intelligence.

AI should consider:

* Business Unit fit
* Capability fit
* Technology fit
* Industry fit
* Experience
* Historical projects
* Risks
* Missing capabilities
* Potential partners
* Strategic value
* Estimated win probability

Recommendations must explain WHY.

---

# 11. Discovery Engine

The Discovery Engine is the procurement opportunity discovery platform.

It is NOT simply a URL management module.

It connects configurable Tender Sources to Opportunity Intelligence.

### Flow

Tender Sources

↓

Scheduled / Manual Discovery

↓

Opportunity Import

↓

Duplicate Detection

↓

AI Classification

↓

Company Intelligence Matching

↓

Opportunity Evaluation

↓

Opportunity Workspace

---

# 12. Tender Sources

Tender Sources are first-class entities.

Tender Sources are controlled by administrators.

Administrators can:

* Add sources
* Edit sources
* Disable sources
* Configure authentication
* Configure discovery methods
* Configure APIs
* Configure scraping
* Configure schedules
* Trigger synchronization

Regular users cannot modify Tender Sources.

### Tender Source Information

Each source may contain:

* Name
* Organization
* Category
* Country
* Sector
* Website
* Source Type
* Discovery Method
* Authentication
* Refresh Schedule
* Last Sync
* Sync Status
* Active/Inactive
* Tags
* Business Unit relationships
* Industry relationships
* Technology relationships
* Product relationships
* Service relationships
* AI confidence
* Historical success metrics

### Supported Discovery Methods

Architecture supports:

* REST APIs
* GraphQL APIs
* RSS
* XML
* HTML
* PDF
* Email
* Manual imports
* Scheduled imports

The architecture must remain extensible so additional connectors can be added without redesigning the Discovery Engine.

### Source Analytics

Track where supported:

* Opportunities discovered
* Qualified opportunities
* Pursued opportunities
* Submitted opportunities
* Wins
* Losses
* Win rate
* Average opportunity value
* AI confidence
* Source reliability
* Response/synchronization performance

### Initial Source Categories

The platform may be configured for:

#### Kenya

* PPIP
* KeNHA
* KeRRA
* KURA
* Kenya Power
* Kenya Pipeline
* Kenya Ports Authority
* Kenya Airports Authority
* National Irrigation Authority
* County procurement portals

#### East Africa

* Uganda procurement
* Tanzania procurement
* Rwanda procurement

#### Development Partners

* World Bank
* African Development Bank
* European Union
* GIZ
* JICA
* FCDO

#### United Nations

* UNGM
* UNDP
* UNICEF
* FAO
* WFP
* UNOPS
* UNEP

#### NGOs

* World Vision
* CARE
* Mercy Corps
* Save the Children
* SNV

#### Private Sector

* Safaricom
* East African Breweries
* Bamburi Cement

This list is configurable and must NOT be treated as a hardcoded permanent list.

---

# 13. Discovery Engine Workspaces

The Discovery Engine architecture includes:

* Tender Sources Workspace
* Discovery Dashboard
* Tender Source Workspace
* Discovery Analytics
* Tender Source Administration
* Connector Framework
* Opportunity Import Pipeline

The Discovery Engine milestones have been implemented as separate workstreams.

Do not recreate these components as a new module.

---

# 14. Proposal Workspace

Proposal is the stage between Opportunity and Submission.

### Flow

Opportunity

↓

Proposal Workspace

↓

AI Proposal Generation

↓

Human Review / Editing

↓

Document Preparation

↓

Submission Workspace

Proposal generation should use:

* Opportunity information
* Company Intelligence
* Capabilities
* Experiences
* Historical Projects
* Products
* Services
* Technologies
* Relevant knowledge

The Proposal Workspace should produce a submission-ready proposal rather than functioning as a generic document editor.

---

# 15. Submission Workspace

Submission is the operational stage after proposal preparation.

### Flow

Proposal Workspace

↓

Submission Workspace

↓

Submission Readiness

↓

Submission

↓

Client Evaluation

↓

Awarded / Lost

The Submission Workspace should manage information such as:

* Submission status
* Deadline
* Required documents
* Readiness
* Approvals
* Blockers
* Communications
* Submission history
* Evaluation status

Submission functionality should not be duplicated across unrelated screens.

Any legacy Applications implementation must not be assumed to be retired or deleted merely because the business workflow is now centered on Submission Workspace. Verify the current repository and architectural decision before removing legacy code.

---

# 16. Project Workspace

Projects represent awarded work after the opportunity/submission lifecycle.

### Flow

Awarded Opportunity

↓

Project Workspace

↓

Project Delivery

↓

Milestones

↓

Deliverables

↓

Risks

↓

Budget

↓

Team

↓

Lessons Learned

↓

Experience

↓

Company Intelligence

Projects should not be treated as a simple CRUD list.

The Project Workspace should become the operational center for project delivery.

Potential project workspace areas include:

* Project overview
* Progress
* Milestones
* Deliverables
* Risks
* Budget
* Team
* Documents
* AI insights
* Lessons learned
* Experience publishing

Do not assume a feature is implemented merely because the Project model or route exists. Verify each workspace capability before marking it complete.

---

# 17. AI Learning Loop

The platform should learn from:

* Won opportunities
* Lost opportunities
* Proposal quality
* Client preferences
* Submission outcomes
* Project outcomes
* Lessons Learned
* Experiences
* Knowledge Articles
* Historical project documents

The objective is to improve:

* Opportunity matching
* Win probability
* Proposal strategy
* Partner recommendations
* Risk identification
* Source prioritization
* Future discovery

AI recommendations should become increasingly accurate as organizational knowledge grows.

---

# 18. Administration

Administrators manage platform configuration.

Admin functionality may include:

* Tender Sources
* Users
* Roles & Permissions
* AI Settings
* Gemini Configuration
* Prompt Templates
* Company Profile
* Business Units
* Products
* Notification Rules
* Discovery Schedules
* Integrations
* API Keys
* Email Accounts
* Document Templates
* System Health

Admin-only functionality must be protected through the platform's existing authentication and authorization architecture.

---

# 19. Current Implementation Status

Status must be understood using four different concepts:

### Implemented

The code/module exists.

### Integrated

The module is connected to the surrounding user experience and navigation.

### Verified

The module passes the relevant analyzer/tests and has been manually checked where appropriate.

### Deployed

Required Firebase/Cloud changes have actually been deployed.

Do NOT treat these terms as interchangeable.

---

## Phase 1 — Foundation

### Status: Implemented

Includes:

* Authentication
* Dashboard
* Navigation Shell
* Dashboard Command Center
* Opportunities

---

## Phase 2 — Company Intelligence

### Status: Implemented / Integration Continuing

Modules:

* Business Units
* Products
* Services
* Capabilities
* Technologies
* Industries
* Experiences
* Knowledge Articles

The architecture exists.

The continuing objective is to ensure every module behaves as a true knowledge workspace and is correctly connected to the rest of the platform.

AI Knowledge Extraction has also been added to support historical project knowledge ingestion.

---

## Phase 3 — Opportunity Discovery & Intelligence

### Status: Implemented

Includes:

* Opportunity Workspace
* AI Classification
* Match Analysis
* Strategic Review
* AI Recommendations
* Notifications
* Discovery Engine
* Tender Sources Workspace
* Discovery Dashboard
* Tender Source Workspace
* Discovery Analytics
* Connector Framework
* Tender Source Administration
* Opportunity Import Pipeline

The Discovery Engine should not be rebuilt as a new architecture.

Future work should extend the existing implementation.

---

## Phase 4 — Proposal & Submission

### Status: Implemented / Remaining Integration & Operational Work

Implemented:

* Proposal Workspace
* AI Proposal Generation
* Document Library
* Submission Workspace

Remaining/possible operational work:

* Submission Tracking
* Client Evaluation
* Final integration between proposal, submission and downstream project workflows
* Deployment/verification where required

Do not recreate Proposal or Submission as separate competing modules.

---

## Phase 5 — Project Delivery

### Status: In Progress

Project Workspace exists as part of the platform architecture.

The long-term Project Delivery scope includes:

* Project Workspace
* Delivery Tracking
* Milestones
* Deliverables
* Risks
* Budget
* Team Management
* Lessons Learned
* Experience Publishing
* Knowledge Publishing
* AI Project Insights

Do not mark every item above as implemented unless it has been verified in the repository.

---

## Phase 6 — Analytics & SaaS

### Status: Planned

Includes:

* Executive Analytics
* Revenue Forecasting
* Pipeline Analytics
* Win/Loss Analytics
* AI Insights
* Multi-company support
* Organizations
* Billing
* APIs
* Marketplace

Goal:

Transform the platform into a multi-tenant AI Business Operating System.

---

# 20. Dashboard Integration Rule

The Dashboard must remain synchronized with the platform architecture.

Whenever a major Workspace is introduced or materially changed, review:

* Dashboard cards
* Navigation
* Command Palette
* Quick Actions
* Notifications
* Contextual actions
* Routes
* Menus

The Dashboard should launch users into Workspaces rather than obsolete CRUD screens.

However:

**Do not create new Dashboard functionality merely because a Workspace exists.**

First determine whether the required information and providers already exist.

---

# 21. UX Principles

The platform should feel like a modern AI Business Operating System rather than a traditional tender-management application.

Prioritize:

* Executive-quality UX
* Material 3
* Responsive layouts
* Progressive disclosure
* Minimal cognitive load
* Strong visual hierarchy
* AI-first workflows
* Reusable components
* Contextual actions
* Intelligent summaries

Avoid:

* CRUD-heavy screens
* Long forms
* Dense tables
* Endless navigation
* Duplicate information
* Duplicate business logic
* Placeholder functionality

Prefer:

* Workspaces
* Dashboards
* Cards
* Progress indicators
* Expandable panels
* Timelines
* AI summaries
* Smart empty states
* Side panels
* Status chips
* Context-aware actions

Editing should be secondary to understanding.

---

# 22. AI Design Philosophy

AI must reason using Company Intelligence.

AI should NOT rely only on keyword matching.

Every important recommendation should explain:

* What is being recommended
* Why it is being recommended
* What evidence supports it
* Confidence level
* Relevant Company Intelligence
* Relevant historical experience

Confidence scores must be explainable.

AI must not invent company capabilities, experiences, projects, clients, technologies or relationships.

When extracting information from documents, human approval is required before the information becomes organizational knowledge.

---

# 23. Coding Standards

Always:

* Preserve architecture
* Preserve naming consistency
* Write clean code
* Update localization
* Update tests
* Update providers
* Update Firestore rules
* Update Firestore indexes when required
* Reuse existing services and providers
* Reuse existing Workspaces
* Maintain responsive behaviour
* Verify navigation

Never:

* Duplicate code
* Create duplicate entities
* Create duplicate business logic
* Hardcode relationships
* Skip tests
* Leave TODOs for required functionality
* Create placeholder implementations
* Replace an existing architecture without approval
* Remove a module based only on its name
* Assume a screen is integrated because a route exists
* Mark a feature complete without verification

---

# 24. Verification Requirements

Every milestone must run:

* `flutter analyze`
* `flutter test`
* `dart format`

When applicable:

* `node --check functions/index.js`
* Firebase deployment verification
* Manual browser verification
* Responsive layout verification

A milestone report must include:

1. Modified files
2. Features implemented
3. Navigation/integration changes
4. Verification results
5. Firestore rules/index changes
6. Deployment requirements
7. Known limitations
8. Remaining disconnected areas

A clean `flutter analyze` does NOT prove that the UI works correctly.

Manual runtime verification is required for UI, navigation and responsive behaviour.

---

# 25. Claude Development Workflow

For every milestone:

1. Read this Project Context first.
2. Analyze the existing architecture.
3. Search for existing implementations before creating anything.
4. Determine whether the requested functionality already exists.
5. Reuse existing models, services, providers and widgets where possible.
6. Implement only the requested milestone.
7. Keep changes isolated.
8. Preserve architecture.
9. Do not duplicate existing functionality.
10. Run `flutter analyze`.
11. Run `flutter test`.
12. Run formatting.
13. Report modified files.
14. Report deployment requirements.
15. Report remaining integration gaps.
16. Stop and wait for approval.

Never continue automatically into another milestone.

---

# 26. Critical Rule — Do Not Rebuild Existing Functionality

Before implementing any requested feature:

Search the project for:

* Existing models
* Existing services
* Existing providers
* Existing screens
* Existing Workspace screens
* Existing routes
* Existing Firestore collections
* Existing Cloud Functions
* Existing tests
* Existing localization strings

If the functionality already exists, integrate or repair it.

Do not create a second implementation.

If two implementations already exist, stop and report the duplication before choosing which one to keep.

---

# 27. Critical Rule — Built vs Integrated

A feature is NOT considered complete merely because:

* A Dart file exists
* A model exists
* A route exists
* A Workspace exists
* `flutter analyze` passes

A feature is considered operational only when:

* The feature exists
* Its dependencies exist
* Its providers work
* Its data loads
* Navigation reaches it
* The UI renders
* Important actions work
* It is responsive
* Tests pass
* Required backend configuration exists
* Required deployment has been completed

---

# 28. Long-Term Goal

Build an AI Business Operating System that enables JV ALMA CIS to:

* Discover opportunities
* Evaluate opportunities
* Generate proposals
* Manage submissions
* Deliver projects
* Capture organizational knowledge
* Learn from historical projects
* Improve opportunity discovery
* Improve proposal strategy
* Improve win probability
* Identify organizational capability gaps
* Continuously improve AI decision-making
* Eventually scale into a multi-tenant SaaS platform

The fundamental loop is:

**Discover → Evaluate → Propose → Submit → Win/Lose → Deliver → Learn → Improve → Discover Again**
