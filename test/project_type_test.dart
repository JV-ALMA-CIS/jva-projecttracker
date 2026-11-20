import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/project.dart';

void main() {
  final Timestamp ts = Timestamp.fromDate(DateTime.utc(2026, 11, 20));

  test('a project saved before project types existed reads as Construction, '
      'with all its data unchanged', () {
    final Project p = Project.fromMap('old', {
      'name': 'CPAR Ross I',
      'description': 'Roofing for 16 Type E houses at Rosslyn Ridge',
      'client': 'US Embassy',
      'status': 'past',
      'category': 'residential',
      'contractorRole': 'mainContractor',
      'projectSize': '16 houses',
      'scopeOfWorks': 'Roof replacement',
      'contractValueAmount': 120000,
      'contractValueCurrency': 'USD',
      'createdAt': ts,
      'updatedAt': ts,
    });
    expect(p.projectType, ProjectType.construction);
    expect(p.category, ProjectCategory.residential);
    expect(p.projectSize, '16 houses');
    expect(p.contractValueAmount, 120000);
    expect(p.digitalCategory, isNull);
    expect(p.deliveryModel, isNull);
    expect(p.techStack, isEmpty);
  });

  test('IT project fields save and load', () {
    final Project p = Project(
      id: 'km',
      name: 'Kilimo Mkononi',
      description: 'Digital agriculture platform',
      client: 'JV ALMA CIS',
      status: ProjectStatus.running,
      createdAt: ts.toDate(),
      updatedAt: ts.toDate(),
      projectType: ProjectType.agritech,
      digitalCategory: DigitalCategory.mobileApp,
      deliveryModel: DeliveryModel.inHouseProduct,
      techStack: const ['Flutter', 'Firebase'],
      productUrl: 'https://play.google.com/store/apps/details?id=x',
      usersScale: '1,200 farmers',
    );
    final Map<String, dynamic> map = p.toMap()
      ..['createdAt'] = ts
      ..['updatedAt'] = ts;
    final Project back = Project.fromMap('km', map);
    expect(back.projectType, ProjectType.agritech);
    expect(back.projectType.isDigital, isTrue);
    expect(back.digitalCategory, DigitalCategory.mobileApp);
    expect(back.deliveryModel, DeliveryModel.inHouseProduct);
    expect(back.techStack, ['Flutter', 'Firebase']);
    expect(back.usersScale, '1,200 farmers');
  });

  test('editing keeps fields the form does not touch (copyWith)', () {
    final Project p = Project.fromMap('og', {
      'name': 'Depot tank inspection',
      'description': '',
      'client': 'Private terminal',
      'status': 'past',
      'projectType': 'oilGasInspection',
      'inspectionType': 'Tank inspection',
      'inspectionStandard': 'API 653',
      'facility': 'Depot',
      'lessonsLearned': 'Plan shutdown windows early',
      'createdAt': ts,
      'updatedAt': ts,
    });
    final Project edited = p.copyWith(name: 'Depot tank inspection 2025');
    expect(edited.inspectionStandard, 'API 653');
    expect(edited.lessonsLearned, 'Plan shutdown windows early');
    expect(edited.projectType, ProjectType.oilGasInspection);
  });
}
