// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_avalara/otel_avalara.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_avalara-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('transactions.commit records type + committed + line count', () async {
    await tracedAvalara<String>(
      operation: 'transactions.commit',
      environment: 'production',
      invoke: () async => const AvalaraCallResult(
        value: 'ok',
        result: AvalaraResult(
          transactionId: 12345,
          code: 'INV-1',
          status: 'Committed',
          type: 'SalesInvoice',
          committed: true,
          lineCount: 8,
          totalTaxMinor: 1234,
          currency: 'USD',
          companyId: 7,
          country: 'US',
          rateLimitRemaining: 192,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('avalara transactions.commit')!);
    expect(a['avalara.environment'], 'production');
    expect(a['avalara.transaction.committed'], true);
    expect(a['avalara.transaction.type'], 'SalesInvoice');
    expect(a['avalara.transaction.line_count'], 8);
    expect(a['avalara.tax.total.minor'], 1234);
  });

  test('Cancelled sets span error', () async {
    await tracedAvalara<String>(
      operation: 'transactions.void',
      invoke: () async => const AvalaraCallResult(
        value: 'ok',
        result: AvalaraResult(status: 'Cancelled'),
      ),
    );
    expect(
      spans.findSpanByName('avalara transactions.void')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutAvalaraInstrumentationAsync(() async {
      await tracedAvalara<String>(
        operation: 'addresses.resolve',
        invoke: () async => const AvalaraCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('avalara '), isEmpty);
  });
}
