import 'dart:convert';
import 'dart:developer';

import 'package:dotted_line/dotted_line.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:orient_ai_chatbot/utils/hex_color.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cross_file/cross_file.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> messages = [];
  final emailRegex =
  RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,7}\b');
  List<XFile> selectedFiles = [];
  List<String> fileDetails = [];

  bool isLoading = false;
  bool isUploading = false;
  String? uploadStatus;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  late FlutterTts flutterTts;
  bool isPlaying = false;
  String _currentColor = "black";
  String get currentColorName =>_currentColor;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    initTts();

    flutterTts.setStartHandler(() {
      setState(() {
        isPlaying = true;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        isPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _stopListening();
    flutterTts.stop();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  initTts() async {
    flutterTts = FlutterTts();
  }

  void _startListening() async {
    _stopListening();

    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      _controller.text = _lastWords;
      log(_lastWords);
    });
  }

  Future<void> _readColorName(String text) async {
    await flutterTts.setVolume(1);
    await flutterTts.setSpeechRate(1);
    await flutterTts.setPitch(1);

    var result = await flutterTts.speak(text);
    if (result == 1) {
      setState(() {
        isPlaying = true;
      });
    }
  }

  Future<void> sendMessage(String message) async {
    // First, add the user's message to the UI
    setState(() {
      isLoading = true;
      messages.add({'role': 'user', 'message': message});
    });

    // Then, clear the text field
    _controller.clear();

    final url = Uri.parse(
      // 'https://epzx5i6m13.execute-api.ap-south-1.amazonaws.com/Dev/chat'
      // 'https://um3gi3o3l5.execute-api.ap-south-1.amazonaws.com/prod/chatbot'
        'https://w5bjm1jhse.execute-api.ap-south-1.amazonaws.com/staging/chat'
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "queryStringParameters": {"query": message},
        }),
      );

      final responseData = json.decode(response.body);
      final responseBody = json.decode(responseData['body']);

      print(responseBody);

      if (response.statusCode == 200) {
        setState(() {
          messages.add({
            'role': 'bot',
            'message': responseBody['response'],
            'documents': json.encode(responseBody['documents']),
            'showRegenerate': false, // Hide regenerate button
            'originalMessage': message,
          });
        });
      } else {
        setState(() {
          messages.add({
            'role': 'bot',
            'message': 'Error: Unable to get response from the server.',
            'showRegenerate': true, // Show regenerate button
            'originalMessage': message,
          });
          Future.delayed(Duration(milliseconds: 100), () {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          });
        });
      }
    } catch (error) {
      setState(() {
        messages.add({
          'role': 'bot',
          'message': 'Error: Something went wrong. Please try again later.',
          'showRegenerate': true, // Show regenerate button
        });
        Future.delayed(Duration(milliseconds: 100), () {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      });
    } finally {
      setState(() {
        isLoading = false; // Set loading to false when done
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: HexColor("#F9F9F9"),
        child: Column(
          children: [
            // const Header(),
            // Main content area with centered text
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 115, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _chatMessages(),
                      if (emailSentStatus.isNotEmpty)
                        AnimatedContainer(
                          height: 56,
                          width: MediaQuery.of(context).size.width,
                          color: HexColor('#FFFFFF'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            emailSentStatus,
                            style: TextStyle(
                                fontFamily: "Roboto",
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: HexColor('#222222')),
                          ),
                        ),
                      if (uploadStatus != null)
                        AnimatedContainer(
                          height: 56,
                          width: MediaQuery.of(context).size.width,
                          color: HexColor('#FFFFFF'),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          duration: const Duration(milliseconds: 300),
                          child: Row(
                            children: [
                              Text(uploadStatus!,
                                style: TextStyle(
                                    fontFamily: "Roboto",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: HexColor('#FF3636')),
                              ),
                              const Spacer(),
                              Text("Try again",
                                style: TextStyle(
                                    fontFamily: "Roboto",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: HexColor('#00A3E4')),
                              ),
                            ],
                          ),
                        ),
                      if (fileDetails.isEmpty)
                        const SizedBox()
                      else
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 105, // Reduced height
                          ),
                          decoration: BoxDecoration(
                            color: HexColor('#FFFFFF'),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(0, -4),
                                blurRadius: 8,
                                spreadRadius: -4,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(-4, 0),
                                blurRadius: 8,
                                spreadRadius: -4,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                offset: const Offset(4, 0),
                                blurRadius: 8,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width,
                                color: HexColor('#FFFFFF'),
                                padding: const EdgeInsets.only(left: 20, top: 10, right: 20, bottom: 5),
                                child: Text(
                                  "Document To Be Added",
                                  style: TextStyle(
                                      fontFamily: "Poppins-Bold",
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: HexColor('#222222')
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: fileDetails
                                        .map((detail) => Container(
                                      width: MediaQuery.of(context).size.width,
                                      color: HexColor('#FFFFFF'),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              detail,
                                              style: TextStyle(
                                                  fontFamily: "Poppins-Regular",
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: HexColor('#222222')
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  int index = fileDetails.indexOf(detail);
                                                  if (index != -1) {
                                                    fileDetails.removeAt(index);
                                                    selectedFiles.removeAt(index);
                                                  }
                                                });
                                              },
                                              child: const Icon(Icons.cancel, color: Colors.red)
                                          ),
                                          const SizedBox(width: 15),
                                          GestureDetector(
                                              onTap: () {
                                                uploadSingleFile(detail);
                                              },
                                              child: Icon(
                                                  Icons.check_circle,
                                                  color: isUploading ? Colors.grey : Colors.green
                                              )
                                          ),
                                        ],
                                      ),
                                    ))
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      (messages.isNotEmpty) ? _inputField() : const SizedBox()
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          height: 56,
          child: TextFormField(
            controller: _controller,
            cursorColor: Colors.black54,
            decoration: InputDecoration(
              prefixIcon: GestureDetector(
                onTap: selectFile,
                child: Image.asset("assets/images/attach_file.png",
                  height: 20,
                  width: 11,
                  color: HexColor('#222222'),
                ),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Image.asset(
                      "assets/images/language_circle.png",
                      height: 24,
                      width: 24,
                      color: HexColor('#292D32'),
                    ),
                  ),

                  // GestureDetector(
                  //   onTap: (){
                  //     _speechToText.isNotListening ? _startListening : _stopListening;
                  //   },
                  //   child: Padding(
                  //     padding: const EdgeInsets.only(right: 12),
                  //     child: Image.asset(
                  //       "assets/images/mic.png",
                  //       height: 24,
                  //       width: 24,
                  //       color: HexColor('#292D32'),
                  //     ),
                  //   ),
                  //
                  // ),
                  FloatingActionButton(
                    onPressed:
                    // If not yet listening for speech start, otherwise stop
                    _speechToText.isNotListening ? _startListening : _stopListening,
                    tooltip: 'Listen',
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
                  ),
                  GestureDetector(
                    onTap: () {
                      // if (isUploading) {
                      //   return;
                      // } else if (_controller.text.isNotEmpty) {
                      sendMessage(_controller.text);
                      //   _controller.clear();
                      // }
                      // print("Clicked");
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Image.asset(
                        "assets/images/arrow_right.png",
                        height: 24,
                        width: 24,
                        color: HexColor('#292D32'),
                      ),
                    ),
                  ),
                ],
              ),
              // labelText: 'Type your message...',
              hintStyle: TextStyle(
                  fontFamily: "Roboto",
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: HexColor('#222222').withOpacity(0.4)),
              hintText: 'Enter your message here',
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HexColor('#F3F3F3')),
                  borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HexColor('#F3F3F3')),
                  borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: HexColor('#F3F3F3'),
              hoverColor: HexColor('#F3F3F3'),
              // contentPadding: const EdgeInsets.symmetric(
              //     horizontal: 20, vertical: 14)
            ),
            onFieldSubmitted: (value) {
              // uploadFile;
              if (value.isNotEmpty) {
                sendMessage(value);
              }
            },
          ),
        ),
        Text(
          'PolyAI can make mistakes, so double check the information.',
          style: TextStyle(
              fontFamily: "Roboto",
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: HexColor('#222222').withOpacity(0.4)),
        ),
      ],
    );
  }

  Widget _chatMessages() {
    return Expanded(
      child: messages.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'How can I help you today?',
              style: TextStyle(
                  fontFamily: "Roboto",
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: HexColor('#222222')),
            ),
            _inputField()
          ],
        ),
      )
          : ListView.builder(
        controller: _scrollController,
        itemCount: messages.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length && isLoading) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Image.asset("assets/images/orient_logo.png",
                    height: 36,
                    width: 36,
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: const LoadingIndicator(
                          indicatorType: Indicator.ballPulse,
                          colors: [Colors.grey],
                          strokeWidth: 8,
                        ),
                      )),
                ],
              ),
            );
          }
          final message = messages[index];
          return Column(
            children: [
              Container(
                // color: Colors.red,
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                alignment: message['role'] == 'user'
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: message['role'] == 'user'
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message['role'] == 'bot')
                      Image.asset("assets/images/orient_logo.png",
                        height: 36,
                        width: 36,
                      ),
                    if (message['role'] == 'bot')
                      const SizedBox(
                        width: 12,
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 582),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                            color: message['role'] == 'user'
                                ? HexColor('#E9E9EB')
                                : HexColor('#F9F9F9'),
                            // : Colors.amber,
                            borderRadius: message['role'] == 'user'
                                ? BorderRadius.circular(8)
                                : BorderRadius.circular(8),
                            border: message['role'] == 'user'
                                ? Border.all(
                                width: 1, color: HexColor('#E9E9EB'))
                                : null),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            SelectableText.rich(
                              TextSpan(
                                children: _processMessage(
                                    message['message'] ?? ''),
                              ),
                            ),
                            message['role'] == 'bot'
                                ? const SizedBox(
                              height: 16,
                            )
                                : const SizedBox(),
                            message['role'] == 'bot'
                                ? Row(
                              children: [
                                GestureDetector(
                                  child: Image.asset(
                                    "assets/images/copy.png",
                                    height: 24,
                                    width: 24,
                                    color: HexColor('#222222'),
                                  ),
                                  onTap: () {
                                    _copyToClipboard(context,
                                        message['message'] ?? '');
                                  },
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    final documents = json.decode(
                                        message['documents'] ??
                                            "[]");
                                    showDialog(
                                      context: context,
                                      builder:
                                          (BuildContext context) {
                                        return Dialog(
                                          shape:
                                          RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius
                                                .circular(8),
                                          ),
                                          child: SizedBox(
                                            width: 612,
                                            // width: MediaQuery.of(
                                            //             context)
                                            //         .size
                                            //         .width *
                                            //     0.4, // Set a fixed width
                                            child: Padding(
                                              padding:
                                              const EdgeInsets
                                                  .all(20),
                                              child: Column(
                                                mainAxisSize:
                                                MainAxisSize
                                                    .min, // Ensures the dialog takes up only as much space as needed
                                                children: [
                                                  Padding(
                                                    padding:
                                                    const EdgeInsets
                                                        .only(
                                                        left:
                                                        10,
                                                        right:
                                                        10,
                                                        top: 12,
                                                        bottom:
                                                        24),
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          'Uploaded Documents',
                                                          style: TextStyle(
                                                              fontFamily:
                                                              "Roboto",
                                                              fontSize:
                                                              16,
                                                              fontWeight: FontWeight
                                                                  .w500,
                                                              color:
                                                              HexColor('#222222')),
                                                        ),
                                                        const Spacer(),
                                                        GestureDetector(
                                                          onTap:
                                                              () {
                                                            Navigator.of(context)
                                                                .pop();
                                                          },
                                                          child: Image
                                                              .asset(
                                                            "assets/images/close-circle.png",
                                                            height:
                                                            24,
                                                            width:
                                                            24,
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                  DottedLine(
                                                    dashColor: HexColor(
                                                        '#222222')
                                                        .withOpacity(
                                                        0.12),
                                                  ),
                                                  ConstrainedBox(
                                                    constraints:
                                                    BoxConstraints(
                                                      maxHeight: MediaQuery.of(
                                                          context)
                                                          .size
                                                          .height *
                                                          0.4, // Set a max height
                                                    ),
                                                    child: ListView
                                                        .builder(
                                                      shrinkWrap:
                                                      true,
                                                      itemCount:
                                                      documents
                                                          .length,
                                                      itemBuilder:
                                                          (BuildContext
                                                      context,
                                                          int index) {
                                                        final document =
                                                        documents[
                                                        index];
                                                        return ExpansionTile(
                                                          title: Text(
                                                            'Source ${index + 1}',
                                                            style: TextStyle(
                                                              color: HexColor('#222222'),
                                                              fontFamily: "Roboto",
                                                              fontSize: 14,
                                                              fontWeight:
                                                              FontWeight.w400,
                                                            ),
                                                          ),
                                                          children: [
                                                            Padding(
                                                              padding: const EdgeInsets
                                                                  .all(
                                                                  16.0),
                                                              child:
                                                              Column(
                                                                crossAxisAlignment:
                                                                CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    'Content:',
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      color: HexColor('#222222'),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(height: 8),
                                                                  Text(
                                                                    document['excerpt'] ?? 'No content available',
                                                                    style: TextStyle(
                                                                      color: HexColor('#222222'),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(height: 16),
                                                                  Text(
                                                                    'Source:',
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      color: HexColor('#222222'),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(height: 8),
                                                                  GestureDetector(
                                                                    onTap: () async{
                                                                      final url = document['document_name'];
                                                                      _launchInBrowser(url);
                                                                    },
                                                                    child: Text(
                                                                      document['document_name'] ?? 'No source available',
                                                                      style: TextStyle(
                                                                        color: HexColor('#00A3E4'),
                                                                        decoration: TextDecoration.underline,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Image.asset(
                                    "assets/images/info_circle.png",
                                    height: 24,
                                    width: 24,
                                    color: HexColor('#222222'),
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    var speech = message['message'] ?? '';
                                    _readColorName(speech);
                                  },
                                  child: Image.asset(
                                    "assets/images/speak.png",
                                    height: 24,
                                    width: 24,
                                    color: HexColor('#222222'),
                                  ),
                                )
                              ],
                            )
                                : const SizedBox(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (message['showRegenerate'] == true)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "There was an error in generating a response.",
                      style: TextStyle(
                          color: HexColor('#222222'),
                          fontFamily: "Roboto",
                          fontSize: 14,
                          fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    GestureDetector(
                      onTap: () {
                        // Call sendMessage with the previous message to regenerate
                        sendMessage(message['originalMessage']);
                      },
                      child: Container(
                        // height: 20,
                          width: MediaQuery.of(context).size.width * 0.1,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: HexColor('#00A3E4'),
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text(
                                'Regenerate',
                                style: TextStyle(
                                    color: HexColor('#FFFFFF'),
                                    fontFamily: "Roboto",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              Image.asset(
                                "assets/images/repeate_music.png",
                                height: 20,
                                width: 20,
                              )
                            ],
                          )),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  String emailSentStatus = '';
  List<TextSpan> _processMessage(String message) {
    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    // Find all matches of the email in the message
    final matches = emailRegex.allMatches(message);

    for (final match in matches) {
      final email = match.group(0) ?? '';

      // Add text before the match (if any)
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: message.substring(lastMatchEnd, match.start),
          style: TextStyle(
              color: HexColor('#222222'),
              fontFamily: "Roboto",
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5),
        ));
      }

      // Add the clickable email
      spans.add(TextSpan(
        text: email,
        style: TextStyle(
            color: HexColor('#222222'),
            fontFamily: "Roboto",
            fontSize: 14,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.underline,
            height: 1.5),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            print('Clicked email: $email');
            // String? result = await showDialog<String>(
            //   context: context,
            //   builder: (context) {
            //     return EmailDialog(toEmail: email);
            //   },
            // );
            // if (result != null) {
            //   setState(() {
            //     emailSentStatus = result; // Update the status here
            //   });
            // }
          },
      ));

      // Update the end position of the last match
      lastMatchEnd = match.end;
    }

    // Add the remaining text after the last match
    if (lastMatchEnd < message.length) {
      spans.add(TextSpan(
        text: message.substring(lastMatchEnd),
        style: TextStyle(
            color: HexColor('#222222'),
            fontFamily: "Roboto",
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5),
      ));
    }

    return spans;
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Copied to clipboard',
          style: TextStyle(
              color: Colors.white,
              fontFamily: "Poppins",
              fontSize: 14,
              fontWeight: FontWeight.w400),
        ),
        backgroundColor: Colors.cyan,
        behavior: SnackBarBehavior.floating,
        width: 200,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(12),
          ),
        ),
      ),
    );
  }

  void _launchInBrowser(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          // Process each file and sanitize its name
          selectedFiles = result.files.map((file) {
            // Split the file name and extension
            final fileNameParts = file.name.split('.');
            final extension = fileNameParts.length > 1 ? fileNameParts.last : '';
            final nameWithoutExtension = fileNameParts.sublist(0, fileNameParts.length - 1).join('.');

            // Sanitize the file name: replace special characters and spaces with underscore
            final sanitizedFileName = nameWithoutExtension
                .replaceAll(RegExp(r'[^\w\s]'), '_')  // Replace special chars with _
                .replaceAll(RegExp(r'\s+'), '_');     // Replace spaces with _

            // Reconstruct the file name with extension
            final newFileName = '$sanitizedFileName.$extension';

            return XFile.fromData(file.bytes!, name: newFileName);
          }).toList();

          // Update fileDetails with sanitized names
          fileDetails = selectedFiles.map((file) => file.name).toList();
        });
        print('Selected files: ${selectedFiles.length}');
      } else {
        print("No files selected");
      }
    } catch (e) {
      print("Error in file selection: $e");
    }
  }

  Future<void> uploadSingleFile(String fileName) async {
    int fileIndex = fileDetails.indexOf(fileName);
    if (fileIndex == -1) return;

    setState(() {
      isUploading = true;
      uploadStatus = null;
    });

    try {
      XFile file = selectedFiles[fileIndex];
      final fileType = file.mimeType ?? 'application/octet-stream';

      final requestBody = jsonEncode({
        'body': jsonEncode({
          'file_type': fileType,
          'file_name': fileName,
        })
      });

      final response = await http.put(
        Uri.parse(
          // 'https://k2eq3bfw14.execute-api.ap-south-1.amazonaws.com/prod/upload'
            'https://w5bjm1jhse.execute-api.ap-south-1.amazonaws.com/staging/file-upload'
        ),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('Response from API: ${response.body}');
      print('File Type: $fileType');
      print('File Type: $file');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final uploadUrl = jsonDecode(responseBody['body'])['upload_url'];

        final uploadResponse = await http.put(
          Uri.parse(uploadUrl),
          headers: {'Content-Type': fileType},
          body: await file.readAsBytes(),
        );

        print('Upload Response: ${uploadResponse.body}');
        if (uploadResponse.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'File uploaded successfully',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: "Poppins",
                    fontSize: 14,
                    fontWeight: FontWeight.w400),
              ),
              backgroundColor: Colors.cyan,
              behavior: SnackBarBehavior.floating,
              width: 230,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(12),
                ),
              ),
            ),
          );
          print("File uploaded successfully");
          setState(() {
            fileDetails.removeAt(fileIndex);
            selectedFiles.removeAt(fileIndex);
          });
        } else {
          uploadStatus =
          "Failed to upload the file. Status Code: ${uploadResponse.statusCode}";
          print(uploadStatus);
        }
      } else {
        uploadStatus =
        "Failed to get upload URL. Status Code: ${response.statusCode}";
        print(uploadStatus);
      }

      // setState(() {
      //   // Remove the uploaded file from lists
      //   fileDetails.removeAt(fileIndex);
      //   selectedFiles.removeAt(fileIndex);
      // });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File uploaded successfully',
            style: TextStyle(
                color: Colors.white,
                fontFamily: "Poppins",
                fontSize: 14,
                fontWeight: FontWeight.w400
            ),
          ),
          backgroundColor: Colors.cyan,
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 240),
          width: 230,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    }


    catch (e) {
      setState(() {
        uploadStatus = "An error occurred while uploading the file: $e";
      });
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }
}
