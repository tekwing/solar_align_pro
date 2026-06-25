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
      'parallelStrings': totalPanels,
      'panelsInSeries': 1,
      'unbalanced': 0,
      'voc': panelVoc,
      'imp': totalPanels * panelImp,
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
  Future<void> generateAndShareReport(Project project) async {
    final pdf = pw.Document();

    // 1. Load Site Photos from Device Storage into Memory
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

    // 2. Build the PDF Document Pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(),
        footer: (context) => _buildPdfFooter(context),
        build: (pw.Context context) {
          return [
            _buildClientInfo(project),
            pw.SizedBox(height: 24),

            // Side-by-side Layout for Telemetry and Estimation
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _buildTelemetry(project)),
                pw.SizedBox(width: 16),
                pw.Expanded(child: _buildEstimation(project)),
              ],
            ),
            pw.SizedBox(height: 24),

            _buildChecklist(project),
            pw.SizedBox(height: 24),

            if (photos.isNotEmpty) _buildPhotos(photos),
          ];
        },
      ),
    );

    // 3. Trigger native iOS/Android share and print dialog
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Solar_Survey_${project.customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  // --- PDF COMPONENT BUILDERS ---

  pw.Widget _buildPdfHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SOLAR ALIGN PRO',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'PROFESSIONAL ENGINEERING REPORT',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.blueGrey600,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
            pw.Text(
              'SITE SURVEY',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.amber600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(thickness: 2, color: PdfColors.amber500),
        pw.SizedBox(height: 24),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}  |  Generated by Solar Align Pro',
        style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10),
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: color.shade(0.3), thickness: 1.0),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildDataRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColors.blueGrey700,
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                color: isHighlight ? PdfColors.green800 : PdfColors.black,
                fontWeight: isHighlight
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildClientInfo(Project project) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Client & Project Information',
            PdfColors.blueGrey800,
          ),
          _buildDataRow('Customer Name', project.customerName),
          _buildDataRow('Contact Phone', project.phone),
          _buildDataRow('Installation Address', project.address),
          _buildDataRow(
            'Report Generated',
            DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.now()),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTelemetry(Project project) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.amber200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Site Telemetry', PdfColors.amber800),
          _buildDataRow(
            'GPS Coordinates',
            project.latitude != null
                ? '${project.latitude!.toStringAsFixed(5)}, \n${project.longitude!.toStringAsFixed(5)}'
                : 'Not recorded',
          ),
          _buildDataRow(
            'Target Roof Tilt',
            project.suggestedTilt != null
                ? '${project.suggestedTilt!.toStringAsFixed(1)}°'
                : 'Not recorded',
          ),
          _buildDataRow(
            'Final Panel Azimuth',
            project.finalAzimuth != null
                ? '${project.finalAzimuth!.toStringAsFixed(1)}°'
                : 'Pending Alignment',
          ),
        ],
      ),
    );
  }

  pw.Widget _buildEstimation(Project project) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'System Estimation & Topology',
            PdfColors.green800,
          ),
          if (project.estimatedSystemKw != null) ...[
            _buildDataRow(
              'Usable Roof Area',
              '${project.estimatedAreaSqM?.toStringAsFixed(1)} sq.m',
            ),
            _buildDataRow(
              'Max Panel Count',
              '${project.estimatedPanels} panels',
            ),
            _buildDataRow(
              'Est. System Size',
              '${project.estimatedSystemKw?.toStringAsFixed(1)} kW',
              isHighlight: true,
            ),
            _buildDataRow(
              'Projected Generation',
              '${project.estimatedGenerationKwh?.toStringAsFixed(0)} kWh/yr',
            ),
            _buildDataRow(
              'Utility Savings',
              '\$${project.estimatedSavings?.toStringAsFixed(0)} / yr',
              isHighlight: true,
            ),

            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.green200),
            pw.SizedBox(height: 8),

            // INJECTED TOPOLOGY DATA
            _buildDataRow(
              'Pattern Type',
              project.selectedTopologyName ?? 'Pending Selection',
              isHighlight: true,
            ),
            _buildDataRow(
              'String Layout',
              project.parallelStrings != null
                  ? '${project.parallelStrings} Parallel, ${project.panelsInSeries} Series'
                  : 'Pending Selection',
            ),
            _buildDataRow(
              'Array Voc',
              project.stringVoc != null
                  ? '${project.stringVoc!.toStringAsFixed(1)} V'
                  : 'Pending Selection',
            ),
            _buildDataRow(
              'Array Imp',
              project.arrayImp != null
                  ? '${project.arrayImp!.toStringAsFixed(1)} A'
                  : 'Pending Selection',
            ),
          ] else ...[
            pw.Text(
              'System capacity estimation has not been completed yet.',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildChecklist(Project project) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.deepPurple50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.deepPurple200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Engineering & Structural Checklist',
            PdfColors.deepPurple800,
          ),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Structural Column
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'STRUCTURAL DATA',
                      style: pw.TextStyle(
                        color: PdfColors.deepPurple600,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    _buildDataRow(
                      'Roof Material',
                      project.roofMaterial ?? 'Pending',
                    ),
                    _buildDataRow(
                      'Rafter Spacing',
                      project.rafterSpacing ?? 'Pending',
                    ),
                    _buildDataRow(
                      'Shading Impact',
                      project.shadingLossPercentage != null
                          ? '${project.shadingLossPercentage!.toInt()}% Output Loss'
                          : 'Pending',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              // Electrical Column
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ELECTRICAL DATA',
                      style: pw.TextStyle(
                        color: PdfColors.deepPurple600,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    _buildDataRow(
                      'Main Panel Amps',
                      project.mainPanelAmps != null
                          ? '${project.mainPanelAmps} A'
                          : 'Pending',
                    ),
                    // Ensuring values match what we displayed above
                    _buildDataRow(
                      'System Topology',
                      project.selectedTopologyName ?? 'Pending Selection',
                    ),
                    _buildDataRow(
                      'Inverter Type',
                      'Standard / Micro (Check Pattern)',
                    ),
                    _buildDataRow('Wire Gauge', 'Awaiting Final Spec'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPhotos(List<pw.MemoryImage> photos) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Site Documentation Photos', PdfColors.blue800),
        pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: photos.map((img) {
            return pw.Container(
              width: 155,
              height: 120,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 1.0),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.ClipRRect(
                horizontalRadius: 5,
                verticalRadius: 5,
                child: pw.Image(img, fit: pw.BoxFit.cover),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());
