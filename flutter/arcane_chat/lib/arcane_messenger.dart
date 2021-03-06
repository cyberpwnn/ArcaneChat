import 'package:arcane_chat/arcane_connect.dart';
import 'package:arcane_chat/arcane_encryption.dart';
import 'package:arcane_chat/arcaneamount.dart';
import 'package:arcane_chat/satchel.dart';
import 'package:arcane_chat/wallet_xt.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web3dart/credentials.dart';

class ArcaneMessage {
  EthereumAddress sender;
  int time = DateTime.now().millisecondsSinceEpoch;
  EthereumAddress recipient;
  String message;
  bool encrypted = true;
  bool pending = false;
}

class ArcaneBubble extends StatelessWidget {
  final String name;
  final String message;
  final bool pending;

  ArcaneBubble({this.name, this.message, this.pending});

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width / 4;
    return Padding(
      padding: EdgeInsets.only(
          left: name == null ? w : 7, right: name != null ? w : 7, top: 3),
      child: Card(
        color: name == null
            ? (pending
                ? Theme.of(context).primaryColor.withOpacity(0.8)
                : Theme.of(context).primaryColor)
            : null,
        shadowColor: name != null
            ? Theme.of(context).primaryColor.withOpacity(0.6)
            : null,
        elevation: name != null
            ? 4
            : pending
                ? 0
                : 12,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
          topRight: name != null ? Radius.circular(24) : Radius.circular(7),
          topLeft: name == null ? Radius.circular(24) : Radius.circular(7),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        )),
        child: Padding(
          child: Text(
            message,
            maxLines: 1000000,
            style: TextStyle(
                fontSize: 21, color: name == null ? Colors.white : null),
          ),
          padding: EdgeInsets.all(14),
        ),
      ),
    );
  }
}

class ArcaneMessenger extends StatefulWidget {
  final Wallet wallet;
  final Satchel satchel;
  final String recipientName;
  final EthereumAddress recipient;

  ArcaneMessenger(
      {this.wallet, this.satchel, this.recipient, this.recipientName});

  @override
  _ArcaneMessengerState createState() => _ArcaneMessengerState();
}

class _ArcaneMessengerState extends State<ArcaneMessenger> {
  bool loading = false;
  bool loadingComplete = false;
  ScrollController sc = ScrollController();
  List<ArcaneMessage> messages = List<ArcaneMessage>();
  TextEditingController tc = TextEditingController();
  FocusNode fn = FocusNode();
  int desync = 0;
  Messenger messenger;

  bool send() {
    desync++;
    String inmsg = tc.value.text.trim();
    if (inmsg.isEmpty) {
      return false;
    }
    String v = messenger.push(inmsg);
    fn.requestFocus();
    widget.wallet.privateKey.extractAddress().then((value) {
      Future<String> pend = ArcaneConnect.getContract()
          .sendMessage(widget.wallet, widget.recipient, v, null);
      ArcaneMessage aa = ArcaneMessage()
        ..sender = value
        ..encrypted = false
        ..recipient = widget.recipient
        ..message = inmsg
        ..pending = true;
      setState(() {
        messages.add(aa);
      });
      ArcaneConnect.waitForTx(pend).then((value) => setState(() {
            if (value) {
              aa.pending = false;
            } else {
              messages.removeWhere((element) =>
                  aa.message == element.message && aa.time == element.time);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to send Message")));
            }
          }));
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    try {
      Future.delayed(
          Duration(milliseconds: 100),
          () => sc.animateTo(sc.position.maxScrollExtent,
              duration: Duration(milliseconds: 1475),
              curve: Curves.easeInOutExpo));
    } catch (e) {}

    if (!loading) {
      loading = true;
      loadingComplete = false;
      Messenger.of(widget.wallet, widget.recipient)
          .then((value) => messenger = value)
          .then((value) => ArcaneConnect.getContract()
              .getMessages(
                  widget.wallet,
                  widget.recipient,
                  (progress) => print("Scanning Messages: $progress"),
                  messenger)
              .then((value) =>
                  value.listen((event) => setState(() => messages.add(event))))
              .then((value) => beginListening()))
          .then((value) => loadingComplete = true)
          .then((value) => Future.delayed(
              Duration(milliseconds: 500),
              () => sc.animateTo(sc.position.maxScrollExtent,
                  duration: Duration(milliseconds: 1475),
                  curve: Curves.easeInOutExpo)));
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          FutureBuilder<ArcaneAmount>(
            future: widget.wallet.getArcaneBalance(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return Container();
              }

              NumberFormat nf = NumberFormat();
              return Padding(
                padding: EdgeInsets.only(right: 14),
                child: Center(
                  child: Text(
                    nf.format(snap.data.getMana().toInt()) + " Mana",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              );
            },
          )
        ],
        title: Text(widget.recipientName),
      ),
      body: FutureBuilder<int>(
        future: ArcaneConnect.getManaFee(),
        builder: (context, manafee) {
          if (!manafee.hasData) {
            return Container();
          }

          return Column(
            children: [
              Flexible(
                  child: loadingComplete
                      ? ListView.builder(
                          controller: sc,
                          itemCount: messages.length,
                          itemBuilder: (context, pos) => ArcaneBubble(
                            pending: messages[pos].pending,
                            message: messages[pos].message,
                            name: messages[pos].sender == widget.recipient
                                ? widget.recipientName
                                : null,
                          ),
                        )
                      : Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(),
                          ),
                        )),
              loadingComplete
                  ? Flexible(
                      flex: 0,
                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(24))),
                        child: ClipRRect(
                            child: Padding(
                              child: Row(
                                children: [
                                  Flexible(
                                      child: TextField(
                                    controller: tc,
                                    focusNode: fn,
                                    autofocus: true,
                                    style: TextStyle(fontSize: 20),
                                    decoration: InputDecoration(
                                        hintText: "Type your message...",
                                        helperText:
                                            "     < ${manafee.data} Mana"),
                                    minLines: 1,
                                    maxLines: 5,
                                    keyboardType: TextInputType.name,
                                    maxLength: 1024,
                                    onSubmitted: (v) {
                                      if (send()) {
                                        tc.text = "";
                                      }
                                    },
                                  )),
                                  Flexible(
                                      child: IconButton(
                                          icon: Icon(Icons.send),
                                          onPressed: () {
                                            if (send()) {
                                              tc.text = "";
                                            }
                                          }),
                                      flex: 0)
                                ],
                              ),
                              padding: EdgeInsets.only(left: 7, right: 7),
                            ),
                            borderRadius:
                                BorderRadius.all(Radius.circular(24))),
                      ),
                    )
                  : Container()
            ],
          );
        },
      ),
    );
  }

  void beginListening() {
    ArcaneConnect.getContract().onMessageSingle(widget.wallet, widget.recipient,
        (msg) {
      setState(() {
        messages.add(msg);
        desync++;
      });
      beginListening();
    });
  }
}
