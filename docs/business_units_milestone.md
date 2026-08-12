# Milestone 2.1 — Business Units

This milestone introduces the first Company Intelligence entity: business units.

## Scope
- Add a new Firestore collection: `businessUnits`
- Create a business-unit model and service
- Provide a responsive list/detail UI for managing business units
- Expose the feature from the main application navigation
- Keep the implementation aligned with the existing Riverpod + Firestore architecture

## Firestore schema
Each business unit document stores:
- `name`
- `slug`
- `summary`
- `description`
- `status`
- `productIds`
- `serviceIds`
- `capabilityIds`
- `industryIds`
- `technologyIds`
- `pastProjectIds`
- `createdAt`
- `updatedAt`

The structure is intentionally forward-compatible for later milestones without coupling the UI to those future entities yet.

## Security model
Access follows the same authenticated-user pattern as the rest of the platform:
- authenticated users may read and write business units
- the collection is not weakened beyond the existing app-wide access model

## Products milestone note
The product layer introduces a second collection, `products`, linked to `businessUnits` through `businessUnitId`. This keeps the data normalized while still supporting future AI prompt generation and relationship-based views.

## Services milestone note
The services layer introduces a third collection, `services`, linked to one or more business units through `businessUnitIds`. This keeps professional-service offerings distinct from product offerings while preserving a consistent future-facing knowledge graph.

## Capabilities milestone note
The capabilities layer introduces a fourth collection, `capabilities`, designed as reusable organizational competencies that can later be linked to products, services, industries, technologies, past projects, and opportunities.

## Technologies milestone note
The technologies layer introduces a fifth collection, `technologies`, focused on platforms, frameworks, standards, and engineering tools that implement the company’s capabilities.
