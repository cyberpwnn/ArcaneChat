import 'package:arcane_chat/arcane_connect.dart';
import 'package:arcane_chat/arcaneamount.dart';
import 'package:arcane_chat/constant.dart';
import 'package:arcane_chat/satchel.dart';
import 'package:arcane_chat/wallet_xt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:web3dart/web3dart.dart';

class ArcaneSend extends StatefulWidget {
  final Satchel satchel;
  final Wallet wallet;

  ArcaneSend({this.satchel, this.wallet});

  @override
  _ArcaneSendState createState() => _ArcaneSendState();
}

class _ArcaneSendState extends State<ArcaneSend> {
  TextEditingController tc = TextEditingController();
  TextEditingController tca = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Hero(
            child: Card(
              child: Padding(
                child: Container(
                  width: 350,
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      IconButton(
                          icon: Icon(Icons.arrow_back),
                          alignment: Alignment.topLeft,
                          onPressed: () => Navigator.pop(context)),
                      FutureBuilder<EtherAmount>(
                        future: ArcaneConnect.connect().getGasPrice(),
                        builder: (context, gas) {
                          if (!gas.hasData) {
                            return Container(
                              width: 0,
                              height: 0,
                            );
                          }
                          NumberFormat nf = NumberFormat();

                          return FutureBuilder<ArcaneAmount>(
                              future: widget.wallet.getArcaneBalance(),
                              builder: (context, amount) {
                                if (!amount.hasData) {
                                  return Container(
                                    width: 0,
                                    height: 0,
                                  );
                                }
                                int myMana = amount.data.getMana().toInt();
                                int setMana = int.tryParse(
                                        tca.value.text.replaceAll(",", "")) ??
                                    0;
                                int gasMana = (gas.data
                                            .getValueInUnit(EtherUnit.ether)
                                            .toDouble() *
                                        Constant.GAS_LIMIT_SEND.toDouble() *
                                        Constant.MANA_PER_ETH)
                                    .toInt();
                                int maxMana = myMana - gasMana;
                                int totalManaCost = setMana + gasMana;

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                        child: Icon(
                                      Icons.send_rounded,
                                      size: 86,
                                    )),
                                    Flexible(
                                        child: TextField(
                                      onChanged: (a) => setState(() {}),
                                      controller: tc,
                                      decoration: InputDecoration(
                                          hintText:
                                              "Wallet Address (0x123....abc)"),
                                    )),
                                    Flexible(
                                        child: TextField(
                                      onChanged: (a) => setState(() {
                                        setMana = int.tryParse(
                                                a.replaceAll(",", "")) ??
                                            0;
                                        if (setMana > maxMana) {
                                          tca.text = (nf.format(maxMana));
                                          tca.selection =
                                              TextSelection.fromPosition(
                                                  TextPosition(
                                                      offset: tca.text.length));
                                        }
                                      }),
                                      controller: tca,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'\d+')),
                                        // Fit the validating format.
                                        //fazer o formater para dinheiro
                                        CurrencyInputFormatter()
                                      ],
                                      style: TextStyle(fontSize: 48),
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                              signed: false, decimal: true),
                                      decoration: InputDecoration(
                                          helperText:
                                              "You can send up to ${nf.format(maxMana)} Mana",
                                          hintText: "0",
                                          suffix: Text("Mana")),
                                    )),
                                    Flexible(
                                        child: ListTile(
                                      title: Text("Transaction Fee"),
                                      leading:
                                          Icon(Icons.attach_money_outlined),
                                      subtitle: Text(
                                          "${nf.format(gasMana)} Mana (${setMana == 0 ? 0 : (((gasMana / setMana).toDouble() * 100).toInt())}%)"),
                                    )),
                                    Flexible(
                                        child: ListTile(
                                      title: Text("Total"),
                                      leading: Icon(Icons.send_sharp),
                                      subtitle: Text(
                                          "${nf.format(totalManaCost)} Mana"),
                                    )),
                                    Flexible(
                                        child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          child: Text(
                                              "Send ${nf.format(totalManaCost)} Mana"),
                                          onPressed: tc.text.length == 42 &&
                                                  setMana > 0 &&
                                                  totalManaCost <= myMana
                                              ? () => sendMana(
                                                          gasPrice: gas.data,
                                                          address: tc.text,
                                                          manaSend: setMana)
                                                      .then((value) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content:
                                                                Text(value)));
                                                    Navigator.pop(context);
                                                    print("Value was '$value'");
                                                  })
                                              : null,
                                        )
                                      ],
                                    ))
                                  ],
                                );
                              });
                        },
                      )
                    ],
                  ),
                ),
                padding: EdgeInsets.all(14),
              ),
            ),
            tag: "card",
          ),
        ),
      ),
    );
  }

  Future<String> sendMana(
      {String address, int manaSend, EtherAmount gasPrice}) {
    return widget.wallet.getAddress().then((value) {
      int gwei = EtherAmount.fromUnitAndValue(EtherUnit.ether, 1)
          .getValueInUnit(EtherUnit.gwei)
          .toInt();
      double sendEth =
          (manaSend.toDouble() / Constant.MANA_PER_ETH) * gwei.toDouble();

      return ArcaneConnect.connect().sendTransaction(
          widget.wallet.privateKey,
          Transaction(
              gasPrice: gasPrice,
              value:
                  EtherAmount.fromUnitAndValue(EtherUnit.gwei, sendEth.toInt()),
              maxGas: Constant.GAS_LIMIT_SEND.toInt(),
              from: value,
              to: EthereumAddress.fromHex(address)),
          chainId: Constant.CHAIN_ID);
    });
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  NumberFormat nf = NumberFormat();
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      print(true);
      return newValue;
    }

    double value = double.parse(newValue.text);

    String newText = nf.format(value);

    return newValue.copyWith(
        text: newText,
        selection: new TextSelection.collapsed(offset: newText.length));
  }
}
