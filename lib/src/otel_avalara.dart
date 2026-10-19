// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_avalara_suppression.dart';

const _tracerName = 'dartastic_otel_libs_avalara';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class AvalaraResult {
  /// Creates a result.
  const AvalaraResult({
    this.transactionId,
    this.code,
    this.status,
    this.type,
    this.committed,
    this.lineCount,
    this.totalTaxMinor,
    this.currency,
    this.companyId,
    this.country,
    this.rateLimitRemaining,
    this.requestId,
    this.statusCode,
  });

  /// `id` of the transaction.
  final int? transactionId;

  /// `code` (customer-supplied unique).
  final String? code;

  /// `Saved` / `Posted` / `Committed` / `Cancelled` / `Adjusted` /
  /// `Queued` / `PendingApproval` / `Locked`.
  final String? status;

  /// `SalesOrder` / `SalesInvoice` / `PurchaseOrder` / `PurchaseInvoice`
  /// / `ReverseChargeOrder` / `ReverseChargeInvoice` / `InventoryTransferOrder`
  /// / `InventoryTransferInvoice` / `ReturnOrder` / `ReturnInvoice`.
  /// Drives whether Avalara counts the transaction against the
  /// per-billing-period transaction allowance.
  final String? type;

  /// Whether this call was a `commit=true` request — Avalara only
  /// charges committed transactions against the allowance.
  final bool? committed;

  /// Lines on the transaction (Avalara's primary cost dim is
  /// committed-transaction count, but line count drives latency).
  final int? lineCount;

  /// Total tax in minor units.
  final int? totalTaxMinor;

  /// ISO 4217.
  final String? currency;

  /// `companyId`.
  final int? companyId;

  /// Ship-to country ISO.
  final String? country;

  /// `X-Avalara-Rate-Limit-Remaining`.
  final int? rateLimitRemaining;

  /// `X-Avalara-Trace-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class AvalaraCallResult<T> {
  /// Creates a call result.
  const AvalaraCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final AvalaraResult? result;
}

/// Wraps an Avalara AvaTax API call in a CLIENT span. [operation] is
/// one of `transactions.create`, `transactions.get`,
/// `transactions.commit`, `transactions.uncommit`,
/// `transactions.adjust`, `transactions.void`, `transactions.refund`,
/// `transactions.verify`, `companies.list`, `customers.list`,
/// `customers.create`, `exemption_certificates.list`,
/// `exemption_certificates.create`, `addresses.resolve`,
/// `nexus.list`, `definitions.tax_codes`, `batches.create`,
/// `reports.run`.
Future<T> tracedAvalara<T>({
  required String operation,
  required Future<AvalaraCallResult<T>> Function() invoke,
  String? environment,
}) async {
  if (avalaraInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'avalara',
    'rpc.method': operation,
    'avalara.operation': operation,
  };
  if (environment != null) m['avalara.environment'] = environment;

  final span = _tracer().startSpan(
    'avalara $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.transactionId != null) {
        extras.add(OTelAPI.attributeInt(
          'avalara.transaction.id',
          r.result!.transactionId!,
        ));
      }
      if (r.result!.code != null) {
        extras.add(OTelAPI.attributeString(
          'avalara.transaction.code',
          r.result!.code!,
        ));
      }
      if (r.result!.status != null) {
        extras.add(OTelAPI.attributeString(
          'avalara.transaction.status',
          r.result!.status!,
        ));
        if (r.result!.status == 'Cancelled') {
          span.setStatus(
            SpanStatusCode.Error,
            'Avalara transaction cancelled',
          );
        }
      }
      if (r.result!.type != null) {
        extras.add(OTelAPI.attributeString(
          'avalara.transaction.type',
          r.result!.type!,
        ));
      }
      if (r.result!.committed != null) {
        extras.add(OTelAPI.attributeBool(
          'avalara.transaction.committed',
          r.result!.committed!,
        ));
      }
      if (r.result!.lineCount != null) {
        extras.add(OTelAPI.attributeInt(
          'avalara.transaction.line_count',
          r.result!.lineCount!,
        ));
      }
      if (r.result!.totalTaxMinor != null) {
        extras.add(OTelAPI.attributeInt(
          'avalara.tax.total.minor',
          r.result!.totalTaxMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTelAPI.attributeString(
          'avalara.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.companyId != null) {
        extras.add(OTelAPI.attributeInt(
          'avalara.company.id',
          r.result!.companyId!,
        ));
      }
      if (r.result!.country != null) {
        extras.add(OTelAPI.attributeString(
          'avalara.country',
          r.result!.country!,
        ));
      }
      if (r.result!.rateLimitRemaining != null) {
        extras.add(OTelAPI.attributeInt(
          'avalara.rate_limit.remaining',
          r.result!.rateLimitRemaining!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'avalara.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Avalara HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
