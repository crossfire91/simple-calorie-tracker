import 'package:flutter/material.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenController.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenModel.dart';
import 'package:simple_calorie_tracker/CalorieSummaryScreen/CalorieSummaryScreenView.dart';

class CalorieSummaryScreenAccess extends StatelessWidget {
  const CalorieSummaryScreenAccess({super.key});

  @override
  Widget build(BuildContext context) {

    var view = CalorieSummaryScreenView();
    var model = CalorieSummaryScreenModel();

    var controller = CalorieSummaryScreenController(view, model);

    view.registerObserver(controller);

    return view;
  }
}