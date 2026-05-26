Centralized Document Repository and File Metadata Management in SAP
Overview

This project provides a centralized SAP-based platform for managing, versioning, analyzing, and auditing OData metadata documents across SAP Gateway SEGW OData V2 services and RAP OData V4 services.

The system captures historical $metadata snapshots, tracks schema evolution over time, enables XML comparison, and provides governance capabilities for SAP API lifecycle management.

Built using:

ABAP RESTful Application Programming Model (RAP)
SAPUI5 / Fiori Elements
SAP Gateway Metadata Engines
ABAP XML Processing APIs
Business Problem

In standard SAP environments:

OData metadata is only available at runtime through $metadata
No historical metadata versioning exists
No schema audit trail is available
Developers cannot easily:
track structural changes
compare schema evolution
rollback metadata versions
validate old integrations
restore historical metadata snapshots

This creates major issues when:

transports overwrite production metadata
integrations break unexpectedly
API structures change without traceability
auditors require historical API evidence
external consumers need schema validation

SAP Gateway only exposes the latest runtime metadata and does not provide:

point-in-time snapshots
metadata archives
structural history tracking
lifecycle governance
Proposed Solution

The system introduces a centralized metadata repository capable of:

registering OData services
creating immutable metadata versions
storing raw XML snapshots
analyzing metadata structures
comparing metadata versions
downloading historical metadata
tracking audit logs
viewing raw XML directly in SAPUI5

Supported service types:

SAP Gateway SEGW OData V2
RAP OData V4
Main Features
1. OData Service Registry

Register and manage OData services.

Supported Types
SEGW OData V2
RAP OData V4
Stored Information
Field	Description
Service ID	Unique service identifier
Service Name	Technical service name
Service Version	OData version
OData Type	SEGW / RAP
Namespace	Service namespace
Package	ABAP package
Owner	Registered developer
Status	Active / Inactive / Archived
Created Date	Registration date
Last Version Date	Latest version timestamp
2. Metadata Version Engine
   Create Version

Users can create metadata versions from registered services.

System Workflow
Call SAP internal metadata engine
Fetch raw $metadata
Convert XML to XSTRING
Compare checksum/hash
Compress payload
Create immutable version
Store timestamp
Write audit log
Characteristics
immutable versions
no overwrite allowed
historical traceability
schema rollback capability
Version Storage
Stored Data
raw metadata XML
version ID
created by
timestamp
compressed payload
Database Tables
Table	Purpose
ZODATA_VERSIONS	Store metadata versions
ZODATA_ROLE	Role management
ZODATA_LOG	Audit logging
3. Metadata Structural Analyzer

The analyzer parses metadata XML and extracts structural components.

Supported Objects
EntityType
EntitySet
Association
NavigationProperty
ComplexType
FunctionImport
Action
Annotation
Technology

Uses:

CL_OXML_DOM_DOCUMENT

and SAP iXML APIs.

Generated Statistics
Metric	Example
Entity Types	14
Navigation Properties	32
Associations	11
Actions	4
4. Metadata Viewer
   Inline XML Viewer

Users can:

open metadata versions
view raw XML
search text
scroll content
enable line wrapping

Implemented in:

SAPUI5
Fiori Elements
Metadata Download

Users can download exact historical metadata XML files.

Technology
RAP Streaming Capability
@Semantics.largeObject
Download Format
XML
5. Audit Log System

Tracks all important metadata lifecycle activities.

Logged Events
Register Service
Create Version
Download Metadata
Compare Version
Database Table
Table	Purpose
ZODATA_LOG	Audit lifecycle events
High-Level Architecture
[ SAPUI5 / Fiori Elements ]
│
▼
[ RAP Service Binding ]
│
▼
[ RAP Service Definition ]
│
▼
[ RAP Projection Layer ]
│
▼
[ RAP Behavior Definition ]
│
▼
[ RAP Implementation Class ]
│
├── SEGW Metadata Engine
│     /IWFND/CL_SODATA_EDM_PROVIDER
│
└── RAP V4 Metadata Engine
/IWFND/CL_V4_MED_ENG_FACAD
│
▼
[ Custom DB Tables ]
Technologies Used
Technology	Purpose
ABAP RAP	Backend architecture
SAPUI5	User interface
Fiori Elements	UI generation
SAP Gateway	OData metadata retrieval
iXML API	XML parsing
XSTRING / LOB	Metadata storage
GitHub	Source control
Example Use Cases
Use Case 1 — Version Tracking

A developer modifies an EntityType in an OData service.

The system automatically:

creates a new metadata version
tracks differences
stores the previous version
logs the activity
Use Case 2 — Integration Validation

An external consumer needs an old schema version.

The system allows:

downloading historical metadata XML
verifying compatibility
restoring old structures
Use Case 3 — Audit & Governance

Auditors request API lifecycle history.

The platform provides:

metadata history
schema evolution
audit trail
timestamp records
Sample Compare Engine

The project includes an ABAP-based XML compare engine capable of:

structural comparison
XML line diff
added/removed detection
metadata evolution tracking

Example outputs:

[+] Added EntityType
[-] Removed NavigationProperty
[~] Changed Property Precision
Project Objectives
Centralize metadata management
Improve API governance
Enable metadata rollback
Support audit compliance
Track schema evolution
Simplify OData lifecycle management
Future Enhancements
Git-style visual diff viewer
Transport integration
Version approval workflow
Real-time metadata monitoring
AI-assisted schema analysis
Multi-system synchronization
Authors

SAP ABAP RAP Development Team

Project Topic:

ABAP9 – Centralized Document Repository and File Metadata Management in SAP

License

Academic / Educational Project

Screenshots

(Add SAPUI5 screenshots here)

/docs/screenshots/
Repository Structure
SAP09_BE/
│
├── programs/
├── classes/
├── cds/
├── behavior/
├── service/
├── docs/
└── README.md