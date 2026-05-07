import 'package:flutter/material.dart';

const double kCosteEnvio = 3.99;
const double kMaxContentWidth = 560;
const Duration kAnimFast = Duration(milliseconds: 200);
const Duration kAnimMed = Duration(milliseconds: 250);
const BorderRadius kRadiusEntrega = BorderRadius.all(Radius.circular(12));

double hPad(BoxConstraints c) =>
    (c.maxWidth - c.maxWidth.clamp(0.0, kMaxContentWidth)) / 2 + 20;
