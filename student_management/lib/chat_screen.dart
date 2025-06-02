import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserType;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserType,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;
  String? _editingMessageId;
  bool _isEditing = false;

  // For real-time combined stream
  final _combinedMessagesController = StreamController<List<QueryDocumentSnapshot>>.broadcast();
  StreamSubscription<QuerySnapshot>? _sentMessagesSubscription;
  StreamSubscription<QuerySnapshot>? _receivedMessagesSubscription;
  QuerySnapshot? _latestSentSnapshot;
  QuerySnapshot? _latestReceivedSnapshot;

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _sentMessagesSubscription = _firestore
        .collection('messages')
        .where('senderId', isEqualTo: widget.currentUserId)
        .where('recipientId', isEqualTo: widget.otherUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _latestSentSnapshot = snapshot;
      _updateCombinedMessages();
    });

    _receivedMessagesSubscription = _firestore
        .collection('messages')
        .where('senderId', isEqualTo: widget.otherUserId)
        .where('recipientId', isEqualTo: widget.currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _latestReceivedSnapshot = snapshot;
      print('Received messages snapshot: ${snapshot.docs.length} documents');
      _updateCombinedMessages();
    });
  }

  void _updateCombinedMessages() {
    List<QueryDocumentSnapshot> allDocs = [];
    if (_latestSentSnapshot != null) {
      allDocs.addAll(_latestSentSnapshot!.docs);
      print('Sent messages in combined: ${_latestSentSnapshot!.docs.length}');
    }
    if (_latestReceivedSnapshot != null) {
      allDocs.addAll(_latestReceivedSnapshot!.docs);
      print('Received messages in combined: ${_latestReceivedSnapshot!.docs.length}');
    }
    allDocs.sort((a, b) {
      final timestampA = a['timestamp'] as Timestamp?;
      final timestampB = b['timestamp'] as Timestamp?;

      // Handle null timestamps: nulls come last in ascending order (or first in descending)
      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1; // A is null, B is not: A comes after B
      if (timestampB == null) return -1; // B is null, A is not: B comes before A

      // For descending order, swap compareTo arguments
      return timestampB.compareTo(timestampA);
    });
    _combinedMessagesController.add(allDocs);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _sentMessagesSubscription?.cancel();
    _receivedMessagesSubscription?.cancel();
    _combinedMessagesController.close();
    super.dispose();
  }

  void _showMessageOptions(Map<String, dynamic> messageData, String messageId) {
    final bool isCurrentUser = messageData['senderId'] == widget.currentUserId;
    final bool isAttachment = messageData['isAttachment'] ?? false;

    if (!isCurrentUser) return; // Only show options for user's own messages

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isAttachment) ...[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Message'),
              onTap: () {
                Navigator.pop(context);
                _startEditing(messageData, messageId);
              },
            ),
            const Divider(height: 0),
          ],
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteMessage(messageId, messageData);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _startEditing(Map<String, dynamic> messageData, String messageId) {
    setState(() {
      _isEditing = true;
      _editingMessageId = messageId;
      _messageController.text = messageData['content'];
    });
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
    FocusScope.of(context).requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  Future<void> _deleteMessage(String messageId, Map<String, dynamic> messageData) async {
    try {
      // If it's an attachment, delete the file from storage first
      if (messageData['isAttachment'] == true) {
        final attachmentInfo = messageData['attachmentInfo'] as Map<String, dynamic>;
        if (attachmentInfo['storagePath'] != null) {
          await _storage.ref(attachmentInfo['storagePath']).delete();
        }
      }

      // Delete the message from Firestore
      await _firestore.collection('messages').doc(messageId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting message: $e')),
      );
    }
  }

  Future<void> _updateMessage(String messageId, String newContent) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'content': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });

      _cancelEditing();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating message: $e')),
      );
    }
  }

  Future<void> _handleAttachment() async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'files',
        extensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      
      if (file == null) return;

      setState(() => _isUploading = true);

      final String fileName = file.name;
      final String fileSize = await _getFileSize(file);
      final String fileType = fileName.split('.').last.toLowerCase();

      // Upload file to Firebase Storage
      final String storagePath = 'chat_attachments/${widget.currentUserId}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final Reference storageRef = _storage.ref().child(storagePath);
      
      final UploadTask uploadTask = storageRef.putFile(File(file.path));
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Send message with file info
      await _firestore.collection('messages').add({
        'senderId': widget.currentUserId,
        'senderName': widget.currentUserName,
        'senderType': widget.currentUserType,
        'recipientId': widget.otherUserId,
        'recipientName': widget.otherUserName,
        'recipientType': widget.currentUserType == 'teacher' ? 'student' : 'teacher',
        'content': 'Attached file: $fileName',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'isAttachment': true,
        'attachmentInfo': {
          'fileName': fileName,
          'fileSize': fileSize,
          'fileType': fileType,
          'downloadUrl': downloadUrl,
          'storagePath': storagePath,
        },
      });

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error attaching file: $e')),
      );
    }
    finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadAndOpenFile(Map<String, dynamic> attachmentInfo) async {
    try {
      final String fileName = attachmentInfo['fileName'];
      final String downloadUrl = attachmentInfo['downloadUrl'];
      final String fileType = attachmentInfo['fileType'];

      // Show preview for images
      if (['jpg', 'jpeg', 'png'].contains(fileType)) {
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(fileName),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _saveFile(downloadUrl, fileName),
                    ),
                  ],
                ),
                Flexible(
                  child: CachedNetworkImage(
                    imageUrl: downloadUrl,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // For non-image files, download and open
        await _saveFile(downloadUrl, fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  Future<void> _saveFile(String downloadUrl, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final File file = File('${dir.path}/$fileName');
      
      // Show download progress
      final downloadTask = _storage.refFromURL(downloadUrl).writeToFile(file);
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StreamBuilder<TaskSnapshot>(
          stream: downloadTask.snapshotEvents,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final TaskSnapshot? data = snapshot.data;
              final progress = data?.bytesTransferred.toDouble() ?? 0.0;
              final total = data?.totalBytes.toDouble() ?? 1.0;
              
              return AlertDialog(
                title: const Text('Downloading...'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress / total),
                    const SizedBox(height: 8),
                    Text('${((progress / total) * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }
            return const AlertDialog(
              title: Text('Preparing download...'),
              content: CircularProgressIndicator(),
            );
          },
        ),
      );

      await downloadTask;
      Navigator.pop(context); // Close progress dialog

      // Open the file
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        throw result.message;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
      );
    }
  }

  Future<String> _getFileSize(XFile file) async {
    final int bytes = await File(file.path).length();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty && !_isEditing) return;

    final messageContent = _messageController.text.trim();

    _messageController.clear(); // Clear input immediately for optimistic UI
    _scrollToBottom(); // Scroll to bottom immediately for optimistic UI

    await _firestore.collection('messages').add({
      'senderId': widget.currentUserId,
      'senderName': widget.currentUserName,
      'senderType': widget.currentUserType,
      'recipientId': widget.otherUserId,
      'recipientName': widget.otherUserName,
      'recipientType': widget.currentUserType == 'teacher' ? 'student' : 'teacher',
      'content': messageContent,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'isAttachment': false,
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData, bool isCurrentUser, String messageId) {
    final timestamp = messageData['timestamp'] as Timestamp?;
    final isAttachment = messageData['isAttachment'] ?? false;
    final isEdited = messageData['isEdited'] ?? false;
    final status = messageData['status'] as String? ?? 'sent'; // Get message status

    Widget messageContent;
    if (isAttachment) {
      final attachmentInfo = messageData['attachmentInfo'] as Map<String, dynamic>;
      final fileType = attachmentInfo['fileType'] as String;
      final isImage = ['jpg', 'jpeg', 'png'].contains(fileType);

      messageContent = InkWell(
        onTap: () => _downloadAndOpenFile(attachmentInfo),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImage && attachmentInfo['downloadUrl'] != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: attachmentInfo['downloadUrl'],
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              const SizedBox(width: 8),
            ] else
              Icon(
                _getFileIcon(fileType),
                color: isCurrentUser ? Colors.white : Colors.deepPurple,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachmentInfo['fileName'],
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    attachmentInfo['fileSize'],
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      messageContent = Text(
        messageData['content'] as String,
        style: TextStyle(
          color: isCurrentUser ? Colors.white : Colors.black87,
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(messageData, messageId),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: isCurrentUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isCurrentUser) ...[
              CircleAvatar(
                backgroundColor: Colors.deepPurple[100],
                radius: 16,
                child: Text(
                  widget.otherUserName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Colors.deepPurple
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  messageContent,
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timestamp != null
                            ? DateFormat.jm().format(timestamp.toDate())
                            : '',
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrentUser
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      if (isEdited) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(edited)',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: isCurrentUser
                                ? Colors.white70
                                : Colors.black54,
                          ),
                        ),
                      ],
                      if (isCurrentUser) // Display status only for current user's messages
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(
                            status == 'sent'
                                ? Icons.done
                                : Icons.done_all, // Customize icons based on status
                            size: 15,
                            color: status == 'read'
                                ? Colors.blue
                                : Colors.grey, // Customize color based on status
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Online',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[200],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Add options menu here
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isEditing)
            Container(
              color: Colors.deepPurple[50],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  const Text('Editing message'),
                  const Spacer(),
                  TextButton(
                    onPressed: _cancelEditing,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _combinedMessagesController.stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final messageData = messageDoc.data() as Map<String, dynamic>;
                    final isCurrentUser = messageData['senderId'] == widget.currentUserId;

                    return _buildMessageBubble(messageData, isCurrentUser, messageDoc.id);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _isUploading ? null : _handleAttachment,
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _isEditing ? 'Edit message...' : 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) {
                      if (_isEditing && _editingMessageId != null) {
                        _updateMessage(_editingMessageId!, _messageController.text.trim());
                      } else {
                        _sendMessage();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isEditing ? Icons.check : Icons.send),
                  color: Colors.deepPurple,
                  onPressed: () {
                    if (_isEditing && _editingMessageId != null) {
                      _updateMessage(_editingMessageId!, _messageController.text.trim());
                    } else {
                      _sendMessage();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNewMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Message',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300, // Fixed height for the list
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('students').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final students = snapshot.data!.docs;

                    if (students.isEmpty) {
                      return const Center(child: Text('No students found'));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final studentDoc = students[index];
                        final studentData = studentDoc.data() as Map<String, dynamic>;
                        final studentName = studentData['name'] as String? ?? 'Unknown';
                        final studentId = studentDoc.id;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple[100],
                            child: Text(
                              studentName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.deepPurple),
                            ),
                          ),
                          title: Text(studentName),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  currentUserId: widget.currentUserId,
                                  currentUserName: widget.currentUserName,
                                  currentUserType: widget.currentUserType,
                                  otherUserId: studentId,
                                  otherUserName: studentName,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
