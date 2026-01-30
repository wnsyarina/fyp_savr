import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_savr/data/services/super_admin_service.dart';
import 'package:fyp_savr/data/services/firebase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class VerificationDetailPage extends StatefulWidget {
  final String restaurantId;
  final Map<String, dynamic> restaurantData;

  const VerificationDetailPage({
    super.key,
    required this.restaurantId,
    required this.restaurantData,
  });

  @override
  State<VerificationDetailPage> createState() => _VerificationDetailPageState();
}

class _VerificationDetailPageState extends State<VerificationDetailPage> {
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.restaurantData['adminNotes'] ?? '';
  }

  Future<void> _updateVerificationStatus(String status) async {
    if (status == 'rejected' && _notesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide reason for rejection')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final superAdmin = FirebaseService.auth.currentUser!;
      final superAdminDoc = await FirebaseService.users.doc(superAdmin.uid).get();
      final superAdminData = superAdminDoc.data() as Map<String, dynamic>;

      await SuperAdminService.updateVerificationStatus(
        restaurantId: widget.restaurantId,
        status: status,
        superAdminId: superAdmin.uid,
        superAdminName: superAdminData['name'],
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restaurant $status successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildDocumentView(String title, String? documentUrl) {
    final isGoogleDriveUrl = documentUrl?.contains('drive.google.com') ?? false;
    final isValidUrl = documentUrl != null && documentUrl.isNotEmpty &&
        (documentUrl.startsWith('http://') ||
            documentUrl.startsWith('https://'));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (isValidUrl)
              Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isGoogleDriveUrl ? Icons.drive_folder_upload : Icons.link,
                      color: Colors.blue,
                    ),
                    title: Text(
                      isGoogleDriveUrl ? 'Google Drive Link' : 'Document Link',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          documentUrl!.length > 60
                              ? '${documentUrl.substring(0, 60)}...'
                              : documentUrl,
                          style: const TextStyle(color: Colors.blue),
                        ),
                        if (isGoogleDriveUrl)
                          const SizedBox(height: 4),
                        if (isGoogleDriveUrl)
                          const Text(
                            'Click to view document',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _launchUrl(documentUrl),
                    ),
                    onTap: () => _launchUrl(documentUrl),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _launchUrl(documentUrl),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.link_off,
                        color: Colors.grey[400],
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No document link provided',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> documents = {};
    dynamic rawDocuments = widget.restaurantData['documents'];

    if (rawDocuments != null) {
      if (rawDocuments is Map<String, dynamic>) {
        documents = rawDocuments;
      } else if (rawDocuments is Map) {
        documents = Map<String, dynamic>.from(rawDocuments);
      }
    }

    final businessRegistration = documents['businessRegistration']?.toString();
    final ownerId = documents['ownerId']?.toString();
    final healthPermit = documents['healthPermit']?.toString();
    final restaurantPhoto = documents['restaurantPhoto']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantData['name'] ?? 'Restaurant Verification'),
        backgroundColor: Colors.purple,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.restaurantData['name'] ?? 'Unnamed Restaurant',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.phone, widget.restaurantData['phone'] ?? 'No phone'),
                    _buildInfoRow(Icons.location_on, widget.restaurantData['address'] ?? 'No address'),
                    _buildInfoRow(Icons.restaurant,
                        (widget.restaurantData['cuisineTypes'] as List?)?.join(', ') ?? 'No cuisine types'),
                    _buildInfoRow(Icons.person,
                        'Merchant ID: ${widget.restaurantData['merchantId'] ?? 'N/A'}'),
                    _buildInfoRow(Icons.calendar_today,
                        'Applied: ${_formatDate(widget.restaurantData['createdAt'])}'),
                    if (widget.restaurantData['description'] != null)
                      _buildInfoRow(Icons.description, widget.restaurantData['description']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Submitted Documents (Google Drive Links)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Click on any link to verify the document',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),

            _buildDocumentView(
              'Business Registration Certificate',
              businessRegistration,
            ),
            const SizedBox(height: 16),

            _buildDocumentView(
              'Owner Identification',
              ownerId,
            ),
            const SizedBox(height: 16),

            if (healthPermit != null && healthPermit.isNotEmpty)
              Column(
                children: [
                  _buildDocumentView(
                    'Health Permit',
                    healthPermit,
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            if (restaurantPhoto != null && restaurantPhoto.isNotEmpty)
              Column(
                children: [
                  _buildDocumentView(
                    'Restaurant Photo',
                    restaurantPhoto,
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Notes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These notes will be included in the email to the merchant:',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: 'Enter approval notes or rejection reason...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (widget.restaurantData['verificationStatus'] == 'pending')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateVerificationStatus('approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('APPROVE APPLICATION'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateVerificationStatus('rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.cancel),
                      label: const Text('REJECT APPLICATION'),
                    ),
                  ),
                ],
              )
            else
              Card(
                color: widget.restaurantData['verificationStatus'] == 'approved'
                    ? Colors.green[50]
                    : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Application ${widget.restaurantData['verificationStatus']!.toString().toUpperCase()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.restaurantData['verificationStatus'] == 'approved'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      if (widget.restaurantData['verifiedByName'] != null)
                        Text('By: ${widget.restaurantData['verifiedByName']}'),
                      if (widget.restaurantData['verifiedAt'] != null)
                        Text('On: ${_formatDate(widget.restaurantData['verifiedAt'])}'),
                      if (widget.restaurantData['adminNotes'] != null &&
                          widget.restaurantData['adminNotes'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Notes: ${widget.restaurantData['adminNotes']}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}