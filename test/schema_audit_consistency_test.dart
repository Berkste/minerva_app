import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Does the audit script still describe the schema it audits?
///
/// The audit is only as good as its expectations, and they are written by
/// hand. A policy added to the schema and not to the audit produces a WARN
/// nobody reads; a policy the audit expects that the schema never creates is
/// worse, because it passes silently forever — an expectation about nothing.
///
/// Nothing compared these two files until this test existed. It is cheap, it
/// runs with every other test, and it is the reason the audit can be trusted
/// to mean something the next time somebody pastes it into the SQL editor.
void main() {
  final schema = File(
    'supabase/migrations/20260921120000_schema.sql',
  ).readAsStringSync();
  final audit = File(
    'supabase/checks/01_schema_audit.sql',
  ).readAsStringSync();

  Set<String> matches(String source, RegExp pattern, [int group = 1]) =>
      pattern.allMatches(source).map((m) => m.group(group)!).toSet();

  void agree(String label, Set<String> inSchema, Set<String> inAudit) {
    expect(
      inSchema.difference(inAudit),
      isEmpty,
      reason: '$label exist in the schema that the audit never checks',
    );
    expect(
      inAudit.difference(inSchema),
      isEmpty,
      reason: '$label the audit expects that the schema does not create',
    );
    expect(inSchema, isNotEmpty, reason: 'found no $label at all — '
        'the patterns below have probably gone stale');
  }

  test('every policy is accounted for on both sides', () {
    agree(
      'policies',
      matches(schema, RegExp(r'create policy (\w+)')),
      matches(
        audit,
        RegExp(
          r"\(\s*'\w+'\s*,\s*'(\w+)'\s*,\s*'(?:SELECT|INSERT|UPDATE|DELETE)'\s*\)",
        ),
      ),
    );
  });

  test('every trigger is accounted for on both sides', () {
    // A rule whose trigger is missing is a rule that is not enforced, and two
    // of them already went missing once — which is why the audit checks
    // triggers at all, and why this checks that it checks the right ones.
    agree(
      'triggers',
      matches(schema, RegExp(r'^create trigger (\w+)', multiLine: true)),
      matches(audit, RegExp(r"\(\s*'(\w+)'\s*,\s*(?:true|false)\s*\)")),
    );
  });

  test('every table is accounted for on both sides', () {
    agree(
      'tables',
      matches(schema, RegExp(r'create table public\.(\w+)')),
      matches(audit, RegExp(r"\('(\w+)'\)")),
    );
  });

  test('every function is accounted for on both sides', () {
    agree(
      'functions',
      matches(schema, RegExp(r'create or replace function public\.(\w+)')),
      matches(audit, RegExp(r"'public\.(\w+)\(")),
    );
  });

  test('every security definer function is on the audit\'s allowlist', () {
    // Definer functions bypass RLS, so the audit warns about any it does not
    // recognise. That warning is only useful while the allowlist is complete:
    // five expected functions flagged as suspicious is how you teach somebody
    // to skim past the section.
    final definers = <String>{};
    final header = RegExp(
      r'create or replace function public\.(\w+)\((?:[^)]*)\)([\s\S]*?)as \$\$',
    );

    for (final match in header.allMatches(schema)) {
      if (match.group(2)!.contains('security definer')) {
        definers.add(match.group(1)!);
      }
    }

    expect(definers, isNotEmpty, reason: 'found no definer functions — the '
        'pattern has gone stale');

    final allowlisted = RegExp(r"^\s+'(\w+)',?$", multiLine: true)
        .allMatches(audit)
        .map((m) => m.group(1)!)
        .toSet();

    expect(
      definers.difference(allowlisted),
      isEmpty,
      reason: 'the audit would report these expected functions as unexpected',
    );
  });
}
