import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/project.dart';

// -------------------------------------------------------------
// SOLAR CALCULATOR SERVICE
// -------------------------------------------------------------
class SolarCalculatorService {
  double estimatePeakSunHours(double latitude) {
    double absLat = latitude.abs();
    if (absLat > 45) return 3.5;
    if (absLat > 35) return 4.2;
    if (absLat > 25) return 5.0;
    return 5.5;
  }

  List<Map<String, dynamic>> calculatePossibleTopologies(
    int totalPanels, {
    required double panelVoc,
    required double panelImp,
  }) {
    if (totalPanels <= 0) return [];

    List<Map<String, dynamic>> topologies = [];

    // OPTION 1: Standard String Inverter (max 500V) -> ~12 panels max per string
    int maxSeriesStandard = 12;
    int parallel1 = (totalPanels / maxSeriesStandard).ceil();
    int series1 = parallel1 > 0 ? totalPanels ~/ parallel1 : 0;
    int unb1 = parallel1 > 0 ? totalPanels % parallel1 : 0;

    topologies.add({
      'name': 'Standard String Inverter',
      'desc': 'Common residential setup (Max 500V DC Input)',
      'parallelStrings': parallel1,
      'panelsInSeries': series1,
      'unbalanced': unb1,
      'voc': series1 * panelVoc,
      'imp': parallel1 * panelImp,
    });

    // OPTION 2: High-Voltage String Inverter (max 1000V) -> ~24 panels max per string
    if (totalPanels > 12) {
      int maxSeriesHigh = 24;
      int parallel2 = (totalPanels / maxSeriesHigh).ceil();
      int series2 = parallel2 > 0 ? totalPanels ~/ parallel2 : 0;
      int unb2 = parallel2 > 0 ? totalPanels % parallel2 : 0;

      topologies.add({
        'name': 'High-Voltage String',
        'desc': 'Large residential / Commercial (Max 1000V DC Input)',
        'parallelStrings': parallel2,
        'panelsInSeries': series2,
        'unbalanced': unb2,
        'voc': series2 * panelVoc,
        'imp': parallel2 * panelImp,
      });
    }

    // OPTION 3: Microinverters
    topologies.add({
      'name': 'Microinverter System',
      'desc': 'Individual panel optimization (Parallel AC Output)',
      'parallelStrings': totalPanels, // All panels run in parallel
      'panelsInSeries': 1,
      'unbalanced': 0,
      'voc': panelVoc, // Voltage does not stack
      'imp': totalPanels * panelImp, // Current sums up on the trunk cable
    });

    return topologies;
  }
}

final solarCalculatorProvider = Provider<SolarCalculatorService>((ref) {
  return SolarCalculatorService();
});

// -------------------------------------------------------------
// PREMIUM PDF GENERATION SERVICE
// -------------------------------------------------------------
class PdfService {
  /// Generates a professional engineering report.
  /// Supports dynamic currency and unit conversions from user settings.
  Future<bool> generateAndShareReport(
    Project project, {
    bool downloadOnly = false,
    String currency = '\$',
    bool isMetric = true,
  }) async {
    final pdf = pw.Document();

    final List<pw.MemoryImage> photos = [];
    if (project.photoPaths != null && project.photoPaths!.isNotEmpty) {
      for (final path in project.photoPaths!) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          photos.add(pw.MemoryImage(bytes));
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildPdfHeader(),
        footer: (context) => _buildPdfFooter(context),
        build: (pw.Context context) {
          return [
            ..._buildClientInfo(project),
            pw.SizedBox(height: 16),

            ..._buildTelemetry(project),
            pw.SizedBox(height: 16),

            ..._buildEstimationRows(project, currency, isMetric),
            pw.SizedBox(height: 16),

            ..._buildChecklistRows(project),

            if (project.additionalNotes != null &&
                project.additionalNotes!.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              ..._buildNotes(project),
            ],

            if (photos.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              ..._buildPhotos(photos),
            ],
          ];
        },
      ),
    );

    final bytes = await pdf.save();

    // Appended Timestamp to filename to prevent OS caching old PDF files
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename =
        'Solar_Survey_${project.customerName.replaceAll(' ', '_')}_$timestamp.pdf';

    if (downloadOnly) {
      try {
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(bytes);
          return true; // Success
        }
      } catch (e) {
        // Fallback to share if directory access fails
      }
    }

    await Printing.sharePdf(bytes: bytes, filename: filename);
    return true;
  }

  pw.Widget _buildPdfHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      margin: const pw.EdgeInsets.only(bottom: 24),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blue900, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SOLAR ALIGN PRO',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'PROFESSIONAL SITE SURVEY & ENGINEERING REPORT',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'CONFIDENTIAL',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red700,
                  letterSpacing: 1.0,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                DateFormat('MMM dd, yyyy').format(DateTime.now()),
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by Solar Align Pro',
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: PdfColors.blueGrey800,
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  pw.Widget _buildSubHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 4, left: 8, right: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.blueGrey800,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _buildDataRow(
    String label,
    String value, {
    bool isBold = false,
    bool isAlt = false,
  }) {
    return pw.Container(
      color: isAlt ? PdfColors.grey100 : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 10),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                color: isBold ? PdfColors.blue900 : PdfColors.grey900,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildClientInfo(Project project) {
    return [
      _buildSectionTitle('Client & Project Information'),
      _buildDataRow('Customer Name', project.customerName, isAlt: true),
      _buildDataRow('Contact Phone', project.phone, isAlt: false),
      _buildDataRow('Installation Address', project.address, isAlt: true),
      _buildDataRow(
        'Report Generated',
        DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.now()),
        isAlt: false,
      ),
    ];
  }

  List<pw.Widget> _buildTelemetry(Project project) {
    return [
      _buildSectionTitle('Site Telemetry & Alignment'),
      _buildDataRow(
        'GPS Coordinates',
        project.latitude != null
            ? '${project.latitude!.toStringAsFixed(5)}, ${project.longitude!.toStringAsFixed(5)}'
            : 'Not recorded',
        isAlt: true,
      ),
      _buildDataRow(
        'Target Roof Tilt',
        project.suggestedTilt != null
            ? '${project.suggestedTilt!.toStringAsFixed(1)}°'
            : 'Not recorded',
        isAlt: false,
      ),
      _buildDataRow(
        'Final Panel Azimuth',
        project.finalAzimuth != null
            ? '${project.finalAzimuth!.toStringAsFixed(1)}°'
            : '180.0° (Target)',
        isBold: project.finalAzimuth != null,
        isAlt: true,
      ),
    ];
  }

  List<pw.Widget> _buildEstimationRows(
    Project project,
    String currency,
    bool isMetric,
  ) {
    if (project.estimatedSystemKw == null) {
      return [
        _buildSectionTitle('System Estimation (Auto-Generated)'),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            'System capacity estimation has not been completed yet.',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
          ),
        ),
      ];
    }

    double areaVal = project.estimatedAreaSqM ?? 0.0;
    if (!isMetric) areaVal = areaVal * 10.7639;
    String areaLabel = isMetric ? 'sq.m' : 'sq.ft';

    double gen = project.estimatedGenerationKwh ?? 0.0;
    double sav = project.estimatedSavings ?? 0.0;

    // Dynamically rebuild the exact topology string based on saved numbers to guarantee it's never "Pending" if data exists.
    int parallel = project.parallelStrings ?? 0;
    int series = project.panelsInSeries ?? 0;
    String patternType = "Pending Selection";

    if (parallel == 1 && series > 1) {
      patternType = "All Series Configuration";
    } else if (series == 1 && parallel > 1) {
      patternType = "All Parallel Configuration";
    } else if (parallel > 1 && series > 1) {
      patternType = "Series and Parallel Configuration";
    } else if (parallel == 1 && series == 1) {
      patternType = "Single Panel Configuration";
    }

    return [
      _buildSectionTitle('System Estimation (Auto-Generated)'),

      _buildSubHeader('CAPACITY & PRODUCTION'),
      _buildDataRow(
        'Usable Roof Area',
        '${areaVal.toStringAsFixed(1)} $areaLabel',
        isAlt: true,
      ),
      _buildDataRow(
        'Max Panel Count',
        '${project.estimatedPanels} panels',
        isAlt: false,
      ),
      _buildDataRow(
        'Est. System Size',
        '${project.estimatedSystemKw?.toStringAsFixed(1)} kW',
        isBold: true,
        isAlt: true,
      ),
      _buildDataRow(
        'Annual Generation',
        '${gen.toStringAsFixed(0)} kWh/unit/yr',
        isAlt: false,
      ),
      _buildDataRow(
        'Monthly Avg Gen.',
        '≈ ${(gen / 12).toStringAsFixed(0)} kWh/unit/mo',
        isBold: true,
        isAlt: true,
      ),
      _buildDataRow(
        'Annual Savings',
        '$currency${sav.toStringAsFixed(0)} / yr',
        isAlt: false,
      ),
      _buildDataRow(
        'Monthly Avg Sav.',
        '≈ $currency${(sav / 12).toStringAsFixed(0)} / mo',
        isBold: true,
        isAlt: true,
      ),

      _buildSubHeader('ELECTRICAL TOPOLOGY'),
      _buildDataRow('Pattern Type', patternType, isBold: true, isAlt: false),
      _buildDataRow(
        'String Layout',
        project.parallelStrings != null
            ? '${project.parallelStrings} Parallel, ${project.panelsInSeries} Series'
            : 'Pending Selection',
        isAlt: true,
      ),
      _buildDataRow(
        'Array Voc',
        project.stringVoc != null
            ? '${project.stringVoc!.toStringAsFixed(1)} V'
            : 'Pending Selection',
        isAlt: false,
      ),
      _buildDataRow(
        'Array Imp',
        project.arrayImp != null
            ? '${project.arrayImp!.toStringAsFixed(1)} A'
            : 'Pending Selection',
        isAlt: true,
      ),
    ];
  }

  List<pw.Widget> _buildChecklistRows(Project project) {
    return [
      _buildSectionTitle('Final Installation Plan (User Verified)'),

      _buildSubHeader('STRUCTURAL DATA'),
      _buildDataRow(
        'Roof Material',
        project.roofMaterial ?? 'Pending',
        isAlt: true,
      ),
      _buildDataRow(
        'Rafter Spacing',
        project.rafterSpacing ?? 'Pending',
        isAlt: false,
      ),
      _buildDataRow(
        'Shading Impact',
        project.shadingLossPercentage != null
            ? '${project.shadingLossPercentage!.toInt()}% Output Loss'
            : 'Pending',
        isAlt: true,
      ),

      _buildSubHeader('ELECTRICAL DATA'),
      _buildDataRow(
        'Main Panel Amps',
        project.mainPanelAmps != null
            ? '${project.mainPanelAmps} A'
            : 'Pending',
        isAlt: false,
      ),
      _buildDataRow(
        'Inverter Type',
        project.inverterType ?? 'Pending',
        isAlt: true,
      ),
      _buildDataRow(
        'Inverter Power',
        project.inverterPowerKw != null
            ? '${project.inverterPowerKw} kW'
            : 'Pending',
        isAlt: false,
      ),
      _buildDataRow(
        'Inverter Voltage',
        project.inverterVoltage != null
            ? '${project.inverterVoltage} V'
            : 'Pending',
        isAlt: true,
      ),
      _buildDataRow(
        'DC Run Wire Gauge',
        project.wireGauge ?? 'Pending',
        isAlt: false,
      ),

      _buildSubHeader('ENERGY STORAGE'),
      _buildDataRow('Battery Type', project.batteryType ?? 'None', isAlt: true),
      _buildDataRow(
        'Capacity',
        project.batteryCapacityKwh != null
            ? '${project.batteryCapacityKwh} kWh'
            : 'N/A',
        isAlt: false,
      ),
      _buildDataRow(
        'Voltage',
        project.batteryVoltage != null ? '${project.batteryVoltage} V' : 'N/A',
        isAlt: true,
      ),
    ];
  }

  List<pw.Widget> _buildNotes(Project project) {
    return [
      _buildSectionTitle('Site Notes & Hazards'),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        color: PdfColors.grey50,
        child: pw.Text(
          project.additionalNotes!,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey900,
            lineSpacing: 1.5,
          ),
        ),
      ),
    ];
  }

  List<pw.Widget> _buildPhotos(List<pw.MemoryImage> photos) {
    return [
      _buildSectionTitle('Site Documentation Photos'),
      pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: photos.map((img) {
            return pw.Container(
              width: 145,
              height: 110,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey300, width: 1.0),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.ClipRRect(
                horizontalRadius: 3,
                verticalRadius: 3,
                child: pw.Image(img, fit: pw.BoxFit.cover),
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }
}

final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());
