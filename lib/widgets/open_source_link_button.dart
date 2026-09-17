import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/utils/external_url.dart';
import 'package:url_launcher/url_launcher.dart';

/// A [TextButton] that validates a raw URL string is well-formed
/// ([normalizeExternalUrl]) before opening it in a new browser tab/window.
/// Deliberately does NOT pre-flight the URL with a client-side HTTP request:
/// that was tried and was unreliable (Flutter Web blocks most cross-origin
/// HEAD/GET calls via CORS, and many government/embassy sites reject
/// bot-like requests outright), producing false "this link appears broken"
/// errors for links that opened fine in a real browser tab.
///
/// Instead, reachability is checked once, server-side, at discovery time
/// (`createOpportunitiesFromCandidates` in functions/connectors/
/// tenderSourceConnector.js — a real server environment, not a
/// CORS-restricted browser) and the result is passed in here as [verified].
/// When `verified == false`, a warning icon/tooltip is shown next to the
/// button instead of silently presenting a possibly-fabricated AI-search
/// link as equally trustworthy as a confirmed one — [onMarkVerified], if
/// given, offers a manual override for the false-negative case where a real
/// site simply blocks the automated check but works fine for a human.
/// [verified] is `null` for callers that don't track verification at all
/// (e.g. `Product.storeUrl`, a human-entered link that was never a
/// fabrication risk) — in which case no badge/override is shown.
class OpenSourceLinkButton extends ConsumerStatefulWidget {
  const OpenSourceLinkButton({
    super.key,
    required this.rawUrl,
    required this.label,
    this.icon,
    this.verified,
    this.onMarkVerified,
  });

  final String rawUrl;
  final String label;
  final IconData? icon;

  /// Null when the caller doesn't track verification (see class doc).
  final bool? verified;

  /// Called when the user confirms an unverified link actually works.
  /// Ignored when [verified] is null or already true.
  final Future<void> Function()? onMarkVerified;

  @override
  ConsumerState<OpenSourceLinkButton> createState() =>
      _OpenSourceLinkButtonState();
}

class _OpenSourceLinkButtonState extends ConsumerState<OpenSourceLinkButton> {
  bool _marking = false;

  Future<void> _open() async {
    final strings = ref.read(appStringsProvider);
    final uri = normalizeExternalUrl(widget.rawUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noValidExternalLinkMessage)),
      );
      return;
    }

    // An unverified link — never confirmed to actually load, either because
    // the discovery-time reachability check failed or hasn't run at all —
    // gets one extra confirmation step before opening, rather than being
    // launched exactly as trustingly as a confirmed link. [verified] is only
    // ever explicitly `false` here (`null` callers, which don't track
    // verification at all, skip straight to launching, same as `true`).
    if (widget.verified == false) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.unverifiedLinkDialogTitle),
          content: Text(strings.unverifiedLinkDialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.openAnywayButton),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _markVerified() async {
    if (widget.onMarkVerified == null || _marking) return;
    setState(() => _marking = true);
    await widget.onMarkVerified!();
    if (!mounted) return;
    setState(() => _marking = false);
    final strings = ref.read(appStringsProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.linkMarkedVerifiedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final button = widget.icon == null
        ? TextButton(onPressed: _open, child: Text(widget.label))
        : TextButton.icon(
            onPressed: _open,
            icon: Icon(widget.icon, size: 16),
            label: Text(widget.label),
          );

    if (widget.verified != false) return button;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      children: [
        button,
        Tooltip(
          message: strings.unverifiedSourceLinkTooltip,
          child: const Icon(
            Icons.warning_amber_outlined,
            size: 16,
            color: AppStatusColors.warning,
          ),
        ),
        if (widget.onMarkVerified != null)
          _marking
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _markVerified,
                  child: Text(strings.markLinkVerifiedButton),
                ),
      ],
    );
  }
}
