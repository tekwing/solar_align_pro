import 'dart:io';
import 'package:flutter/material.dart'
    show Colors; // Just for color mapping if needed
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';

class PdfService {
  Future<void> generateAndShareReport(Project project) async {
    final pdf = pw.Document();

    // Status Logic
    final bool hasGps = project.latitude != null;
    final bool isAligned = project.finalAzimuth != null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- Header ---
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 2),
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
                          'Site Survey & Alignment Report',
                          style: const pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      DateFormat('MMMM d, yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // --- Customer Details ---
              pw.Text(
                'CLIENT INFORMATION',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildDataRow('Name:', project.customerName),
              _buildDataRow('Phone:', project.phone),
              _buildDataRow('Address:', project.address),
              pw.SizedBox(height: 30),

              // --- Environmental & Location Data ---
              pw.Text(
                'SITE TELEMETRY',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  children: [
                    _buildDataRow(
                      'GPS Latitude:',
                      hasGps
                          ? '${project.latitude!.toStringAsFixed(4)}°'
                          : 'Not Recorded',
                    ),
                    _buildDataRow(
                      'GPS Longitude:',
                      hasGps
                          ? '${project.longitude!.toStringAsFixed(4)}°'
                          : 'Not Recorded',
                    ),
                    pw.Divider(color: PdfColors.grey300),
                    _buildDataRow(
                      'Target Optimal Tilt:',
                      hasGps
                          ? '${project.suggestedTilt!.toStringAsFixed(1)}°'
                          : 'N/A',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              // NEW: System Estimation Section for PDF
              if (project.estimatedSystemKw != null) ...[
                pw.Text(
                  'SYSTEM ESTIMATION & ROI',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(color: PdfColors.green200),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      _buildDataRow(
                        'Usable Roof Area:',
                        '${project.estimatedAreaSqM?.toStringAsFixed(1)} sq.m',
                      ),
                      _buildDataRow(
                        'Max Panels Capacity:',
                        '${project.estimatedPanels} panels',
                      ),
                      _buildDataRow(
                        'Est. System Size:',
                        '${project.estimatedSystemKw?.toStringAsFixed(1)} kW',
                      ),
                      pw.Divider(color: PdfColors.green200),
                      _buildDataRow(
                        'Annual Generation:',
                        '${project.estimatedGenerationKwh?.toStringAsFixed(0)} kWh/yr',
                      ),
                      _buildDataRow(
                        'Estimated Savings:',
                        '\$${project.estimatedSavings?.toStringAsFixed(0)}/yr',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
              ],
              // --- Final Alignment Status ---
              pw.Text(
                'HARDWARE ALIGNMENT',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: isAligned ? PdfColors.green500 : PdfColors.orange500,
                    width: 2,
                  ),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isAligned ? 'ALIGNMENT LOCKED' : 'ALIGNMENT PENDING',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: isAligned
                            ? PdfColors.green700
                            : PdfColors.orange700,
                      ),
                    ),
                    pw.Text(
                      isAligned
                          ? '${project.finalAzimuth!.toStringAsFixed(1)}° Azimuth'
                          : '--',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),

              // --- Footer ---
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Generated automatically by Solar Align Pro field software.',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // 1. Get the temporary directory of the device
    final output = await getTemporaryDirectory();

    // 2. Format a clean filename
    final safeName = project.customerName.replaceAll(' ', '_').toLowerCase();
    final file = File('${output.path}/solar_report_$safeName.pdf');

    // 3. Save the PDF file
    await file.writeAsBytes(await pdf.save());

    // 4. Trigger the native Share sheet (WhatsApp, Email, Drive, etc.)
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Site Survey Report for ${project.customerName}');
  }

  // Helper method to keep the layout clean
  pw.Widget _buildDataRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}
