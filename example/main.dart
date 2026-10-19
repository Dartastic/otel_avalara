// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_avalara/otel_avalara.dart';

/// Traces Avalara AvaTax calls with OpenTelemetry.
///
/// `otel_avalara` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Avalara AvaTax call in
/// [tracedAvalara]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'avalara-example');

  // Wraps an Avalara AvaTax API call in a CLIENT span.
  final avalaraId = await tracedAvalara<String>(
    operation: 'transactions.create',
    environment: 'example',
    invoke: () async {
      // Make the Avalara AvaTax call here, then report what it returned.
      const id = 'avalara_8f3a2c';
      return const AvalaraCallResult(
          value: id,
          result: AvalaraResult(
              transactionId: 1,
              code: 'example',
              status: 'Saved',
              type: 'SalesOrder',
              committed: true,
              lineCount: 3,
              totalTaxMinor: 1,
              currency: 'usd',
              companyId: 1,
              country: 'example',
              rateLimitRemaining: 25,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedAvalara transactions.create returned $avalaraId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutAvalaraInstrumentationAsync.
  await runWithoutAvalaraInstrumentationAsync(
    () => tracedAvalara<String>(
      operation: 'transactions.create',
      environment: 'example',
      invoke: () async {
        const id = 'avalara_8f3a2c';
        return const AvalaraCallResult(
            value: id,
            result: AvalaraResult(
                transactionId: 1,
                code: 'example',
                status: 'Saved',
                type: 'SalesOrder',
                committed: true,
                lineCount: 3,
                totalTaxMinor: 1,
                currency: 'usd',
                companyId: 1,
                country: 'example',
                rateLimitRemaining: 25,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
