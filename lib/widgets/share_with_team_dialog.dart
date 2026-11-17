import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// "Share with team": anyone can push an opportunity to everyone's devices
/// with an optional note, or copy a link to forward on WhatsApp / email.
Future<void> showShareWithTeamDialog(
  BuildContext context,
  Opportunity opportunity,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareWithTeamDialog(opportunity: opportunity),
  );
}

class _ShareWithTeamDialog extends ConsumerStatefulWidget {
  const _ShareWithTeamDialog({required this.opportunity});

  final Opportunity opportunity;

  @override
  ConsumerState<_ShareWithTeamDialog> createState() =>
      _ShareWithTeamDialogState();
}

class _ShareWithTeamDialogState extends ConsumerState<_ShareWithTeamDialog> {
  final _noteController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final strings = ref.read(appStringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      final recipients = await ref
          .read(teamShareServiceProvider)
          .share(widget.opportunity.id, note: _noteController.text.trim());
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(strings.sharedWithTeamMessage(recipients))),
      );
    } catch (e) {
      developer.log('Share with team failed', name: 'ShareDialog', error: e);
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(strings.errorPrefix(e))));
    }
  }

  Future<void> _copyLink() async {
    final strings = ref.read(appStringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(
        text:
            '${widget.opportunity.title}\n'
            '${opportunityShareLink(widget.opportunity.id)}',
      ),
    );
    messenger.showSnackBar(SnackBar(content: Text(strings.linkCopiedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    return AlertDialog(
      title: Text(strings.shareWithTeamButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.opportunity.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(strings.shareWithTeamExplainer),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _noteController,
            maxLength: 280,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(hintText: strings.shareNoteHint),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _copyLink,
          icon: const Icon(Icons.link),
          label: Text(strings.copyLinkButton),
        ),
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _share,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.campaign_outlined),
          label: Text(strings.shareButtonShort),
        ),
      ],
    );
  }
}
