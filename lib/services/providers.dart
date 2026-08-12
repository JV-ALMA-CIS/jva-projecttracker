/// Barrel file re-exporting every Riverpod provider in the app, split into
/// domain-based files under `lib/services/<domain>/`. Existing code
/// continues to do `import 'package:jva_projecttracker/services/providers.dart';`
/// and see every provider name unchanged — see each domain file for the
/// providers, controllers, and doc comments that used to live here.
library;

export 'core/auth_providers.dart';
export 'core/settings_providers.dart';
export 'core/navigation_providers.dart';
export 'core/notification_providers.dart';
export 'opportunities/opportunity_providers.dart';
export 'proposals/proposal_providers.dart';
export 'submissions/submission_providers.dart';
export 'projects/project_providers.dart';
export 'company_intelligence/business_unit_providers.dart';
export 'company_intelligence/product_providers.dart';
export 'company_intelligence/service_providers.dart';
export 'company_intelligence/capability_providers.dart';
export 'company_intelligence/technology_providers.dart';
export 'company_intelligence/industry_providers.dart';
export 'company_intelligence/experience_providers.dart';
export 'company_intelligence/knowledge_article_providers.dart';
export 'company_intelligence/knowledge_summary_providers.dart';
export 'library/library_document_providers.dart';
export 'discovery/discovery_providers.dart';
export 'discovery/tender_providers.dart';
export 'recommendations/recommendation_providers.dart';
