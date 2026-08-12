import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/services/proposal_section_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProposalSectionService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ProposalSectionService(firestore: firestore);
  });

  ProposalSection buildSection({
    required String proposalId,
    required int order,
    required DateTime now,
    ProposalSectionType type = ProposalSectionType.custom,
    String title = 'Section',
  }) {
    return ProposalSection(
      id: '',
      proposalId: proposalId,
      order: order,
      type: type,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('create writes a section that watchByProposalId then returns', () async {
    final now = DateTime.utc(2024, 8, 1);
    await service.create(
      buildSection(proposalId: 'proposal-1', order: 0, now: now),
    );

    final sections = await service.watchByProposalId('proposal-1').first;
    expect(sections, hasLength(1));
    expect(sections.single.proposalId, 'proposal-1');
  });

  test('watchByProposalId orders sections by order ascending', () async {
    final now = DateTime.utc(2024, 8, 1);
    await service.create(
      buildSection(
        proposalId: 'proposal-1',
        order: 2,
        now: now,
        title: 'Third',
      ),
    );
    await service.create(
      buildSection(
        proposalId: 'proposal-1',
        order: 0,
        now: now,
        title: 'First',
      ),
    );
    await service.create(
      buildSection(
        proposalId: 'proposal-1',
        order: 1,
        now: now,
        title: 'Second',
      ),
    );

    final sections = await service.watchByProposalId('proposal-1').first;
    expect(sections.map((s) => s.title), ['First', 'Second', 'Third']);
  });

  test(
    'watchByProposalId only returns the matching proposal\'s sections',
    () async {
      final now = DateTime.utc(2024, 8, 1);
      await service.create(
        buildSection(proposalId: 'proposal-1', order: 0, now: now),
      );
      await service.create(
        buildSection(proposalId: 'proposal-2', order: 0, now: now),
      );

      final sections = await service.watchByProposalId('proposal-1').first;
      expect(sections, hasLength(1));
      expect(sections.single.proposalId, 'proposal-1');
    },
  );

  test('updateContent sets content and marks the section edited', () async {
    final now = DateTime.utc(2024, 8, 1);
    final id = await service.create(
      buildSection(proposalId: 'proposal-1', order: 0, now: now),
    );

    await service.updateContent(id, 'New content here.');

    final sections = await service.watchByProposalId('proposal-1').first;
    expect(sections.single.content, 'New content here.');
    expect(sections.single.status, ProposalSectionStatus.edited);
  });

  test('updateStatus updates the status', () async {
    final now = DateTime.utc(2024, 8, 1);
    final id = await service.create(
      buildSection(proposalId: 'proposal-1', order: 0, now: now),
    );

    await service.updateStatus(id, ProposalSectionStatus.approved);

    final sections = await service.watchByProposalId('proposal-1').first;
    expect(sections.single.status, ProposalSectionStatus.approved);
  });

  test('reorder persists a new order across all affected sections', () async {
    final now = DateTime.utc(2024, 8, 1);
    final firstId = await service.create(
      buildSection(
        proposalId: 'proposal-1',
        order: 0,
        now: now,
        title: 'First',
      ),
    );
    final secondId = await service.create(
      buildSection(
        proposalId: 'proposal-1',
        order: 1,
        now: now,
        title: 'Second',
      ),
    );

    await service.reorder([secondId, firstId]);

    final sections = await service.watchByProposalId('proposal-1').first;
    expect(sections.map((s) => s.title), ['Second', 'First']);
  });

  test('updateAssignedTo sets the section owner', () async {
    final now = DateTime.utc(2024, 8, 1);
    final id = await service.create(
      buildSection(proposalId: 'proposal-1', order: 0, now: now),
    );

    await service.updateAssignedTo(id, 'jane@example.com');

    final sections = await service.watchByProposalId('proposal-1').first;
    expect(sections.single.assignedTo, 'jane@example.com');
  });

  test(
    'restorePreviousVersion swaps previousContent/previousStatus back in and clears the slot',
    () async {
      final now = DateTime.utc(2024, 8, 1);
      final id = await service.create(
        buildSection(proposalId: 'proposal-1', order: 0, now: now),
      );
      await service.updateContent(id, 'AI-generated content.');

      final section = ProposalSection(
        id: id,
        proposalId: 'proposal-1',
        order: 0,
        type: ProposalSectionType.custom,
        title: 'Section',
        content: 'AI-generated content.',
        status: ProposalSectionStatus.aiDrafted,
        previousContent: 'Old human-written content.',
        previousStatus: ProposalSectionStatus.edited,
        createdAt: now,
        updatedAt: now,
      );

      await service.restorePreviousVersion(section);

      final sections = await service.watchByProposalId('proposal-1').first;
      expect(sections.single.content, 'Old human-written content.');
      expect(sections.single.status, ProposalSectionStatus.edited);
      expect(sections.single.previousContent, isNull);
      expect(sections.single.previousStatus, isNull);
    },
  );

  test(
    'restorePreviousVersion is a no-op when there is nothing to restore',
    () async {
      final now = DateTime.utc(2024, 8, 1);
      final id = await service.create(
        buildSection(proposalId: 'proposal-1', order: 0, now: now),
      );
      await service.updateContent(id, 'Current content.');

      final section = ProposalSection(
        id: id,
        proposalId: 'proposal-1',
        order: 0,
        type: ProposalSectionType.custom,
        title: 'Section',
        content: 'Current content.',
        createdAt: now,
        updatedAt: now,
      );

      await service.restorePreviousVersion(section);

      final sections = await service.watchByProposalId('proposal-1').first;
      expect(sections.single.content, 'Current content.');
    },
  );

  test('delete removes the section', () async {
    final now = DateTime.utc(2024, 8, 1);
    final id = await service.create(
      buildSection(proposalId: 'proposal-1', order: 0, now: now),
    );

    await service.delete(id);

    final sections = await service.watchByProposalId('proposal-1').first;
    expect(sections, isEmpty);
  });
}
