// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_avalara_suppression.dart';

const _tracerName = 'dartastic_otel_libs_avalara';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class AvalaraResult {
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

class AvalaraCallResult<T> {
  const AvalaraCallResult({required this.value, this.result});
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
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.transactionId != null) {
        extras.add(OTel.attributeInt(
          'avalara.transaction.id',
          r.result!.transactionId!,
        ));
      }
      if (r.result!.code != null) {
        extras.add(OTel.attributeString(
          'avalara.transaction.code',
          r.result!.code!,
        ));
      }
      if (r.result!.status != null) {
        extras.add(OTel.attributeString(
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
        extras.add(OTel.attributeString(
          'avalara.transaction.type',
          r.result!.type!,
        ));
      }
      if (r.result!.committed != null) {
        extras.add(OTel.attributeBool(
          'avalara.transaction.committed',
          r.result!.committed!,
        ));
      }
      if (r.result!.lineCount != null) {
        extras.add(OTel.attributeInt(
          'avalara.transaction.line_count',
          r.result!.lineCount!,
        ));
      }
      if (r.result!.totalTaxMinor != null) {
        extras.add(OTel.attributeInt(
          'avalara.tax.total.minor',
          r.result!.totalTaxMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTel.attributeString(
          'avalara.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.companyId != null) {
        extras.add(OTel.attributeInt(
          'avalara.company.id',
          r.result!.companyId!,
        ));
      }
      if (r.result!.country != null) {
        extras.add(OTel.attributeString(
          'avalara.country',
          r.result!.country!,
        ));
      }
      if (r.result!.rateLimitRemaining != null) {
        extras.add(OTel.attributeInt(
          'avalara.rate_limit.remaining',
          r.result!.rateLimitRemaining!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'avalara.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
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
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
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
