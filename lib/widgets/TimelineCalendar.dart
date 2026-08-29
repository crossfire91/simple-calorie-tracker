import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class TimelineCalendar extends StatefulWidget {
  double? width;
  double? height;
  TextStyle? textStyle;
  Color? fontColor;
  Color? iconColor;
  var view;
  Function(String selectedDay) onDateSelected;

  bool isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  TimelineCalendar(this.onDateSelected, {this.width, this.height, this.textStyle, this.fontColor, this.iconColor, this.view});

  @override
  _TimelineCalendarState createState() {
    return _TimelineCalendarState(this.width, this.height, this.textStyle, this.fontColor, this.iconColor, this.view, this.onDateSelected);
  }
}

class _TimelineCalendarState extends State<TimelineCalendar> {
  double? width;
  double? height;
  TextStyle? textStyle;
  Color? fontColor;
  Color? iconColor;
  var view;
  Function(String selectedDay) onDateSelected;

  _TimelineCalendarState(this.width, this.height, this.textStyle, this.fontColor, this.iconColor, this.view, this.onDateSelected);

  Map translations = {
    "DE": {
      "Januar": "Januar",
      "Februar": "Februar",
      "März": "März",
      "April": "April",
      "Mai": "Mai",
      "Juni": "Juni",
      "Juli": "Juli",
      "August": "August",
      "September": "September",
      "Oktober": "Oktober",
      "November": "November",
      "Dezember": "Dezember",
      "Mo": "Mo",
      "Di": "Di",
      "Mi": "Mi",
      "Do": "Do",
      "Fr": "Fr",
      "Sa": "Sa",
      "So": "So",
      "[DAY].[MONTH]": "[DAY].[MONTH]",
    },
    "EN": {
      "Januar": "January",
      "Februar": "February",
      "März": "March",
      "April": "April",
      "Mai": "May",
      "Juni": "June",
      "Juli": "July",
      "August": "August",
      "September": "September",
      "Oktober": "October",
      "November": "November",
      "Dezember": "December",
      "Mo": "Mo",
      "Di": "Tue",
      "Mi": "Wed",
      "Do": "Thu",
      "Fr": "Fr",
      "Sa": "Sa",
      "So": "Su",
      "[DAY].[MONTH]": "[MONTH]/[DAY]",
    }
  };

  Map months = {
    1: "Januar",
    2: "Februar",
    3: "März",
    4: "April",
    5: "Mai",
    6: "Juni",
    7: "Juli",
    8: "August",
    9: "September",
    10: "Oktober",
    11: "November",
    12: "Dezember",
  };

  Map weekDays = {
    1: "Mo",
    2: "Di",
    3: "Mi",
    4: "Do",
    5: "Fr",
    6: "Sa",
    7: "So",
  };

  bool firstNewKw = false;

  int beginAt = 0;

  bool isInitialized = false;

  int index = 0;

  int month = DateTime.now().month;

  int year = DateTime.now().year;

  List lastKws = [];

  int weekNow = 1;

  bool setStatePermission = true;

  String selectedDay = "";

  int todayPosition = 0;

  void registerView(var view) {
    this.view = view;
  }

  void registerWidth(double width) {
    this.width = width;
  }

  String locale = "EN";

  bool isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  List<Widget> generateWrapChildrenList(int month, int year, bool widthMonth, bool widthPadding, bool oneRowFormat) {

    var lastDayDateTime = (month < 12) ? new DateTime(year, month + 1, 0) : new DateTime(year + 1, 1, 0);

    var lastMonth = DateTime.utc(month - 1 == 0 ? year - 1 : year, month - 1 == 0 ? 12 : month - 1);
    var lastDayDateTimeLastMonth = (lastMonth.month < 12) ? new DateTime(lastMonth.year, lastMonth.month + 1, 0) : new DateTime(lastMonth.year + 1, 1, 0);

    List<Widget> result = [];

    int weekday = DateTime.utc(year, month, 1).weekday;

    int lastDayDateTimeLastMonth_day = lastDayDateTimeLastMonth.day - (weekday - 2);

    bool stopCountingTodayPosition = false;
    todayPosition = 0;
    if (oneRowFormat == true) {
      todayPosition++;
      result.add(
        GestureDetector(
          child: Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: 20,
          ),
          onTap: () {
            view.setState(() {
              this.month--;
              index = 0;
              if (this.month <= 0) {
                this.year--;
                this.month = 12;
              }
              var lastDay = (this.month < 12) ? new DateTime(this.year, this.month + 1, 0) : new DateTime(this.year + 1, 1, 0);
              selectedDay = "${lastDay.day}.${this.month.toString()}.${this.year.toString()}";
              view.scrollController.jumpTo((((DateTime.utc(this.year, this.month, 1).weekday - 1) + lastDay.day) - 4) * (74.0));
            });
          },
        ),
      );
    }

    Color weekdayFontColor = Colors.black;

    result.addAll(List.generate(weekday - 1, (index) {
      todayPosition++;
      return Padding(
        padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
        child: GestureDetector(
          child: new AnimatedContainer(
            duration: Duration(milliseconds: 100),
            width: oneRowFormat ? 70 : 70,
            height: 70,
            child: new Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  new Text(
                    "${weekDays[DateTime.utc(month - 1 <= 0 ? year - 1 : year, (month - 1 <= 0 ? 12 : month - 1), lastDayDateTimeLastMonth_day + index).weekday]}",
                    style: new TextStyle(
                        color: oneRowFormat
                                ? Colors.grey
                                : Colors.grey),
                  ),
                  new Text(
                    //"${translations[locale]["[DAY].[MONTH]"].toString().replaceAll("[DAY]", "${(lastDayDateTimeLastMonth_day + index).toString().padLeft(2, "0")}").replaceAll("[MONTH]", "${(month - 1 <= 0 ? 12 : month - 1).toString().padLeft(2, "0")}")}",
                    "${(lastDayDateTimeLastMonth_day + index).toString().padLeft(2, "0")}${widthMonth ? ".${(month - 1 <= 0 ? 12 : month - 1).toString().padLeft(2, "0")}" : ""}",
                    style: new TextStyle(
                        color: oneRowFormat
                                ? Colors.grey
                                : Colors.grey),
                  ),
                ],
              ),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(2.0)),
              color: selectedDay == "${(lastDayDateTimeLastMonth_day + index).toString()}.${(month - 1 <= 0 ? 12 : month - 1).toString()}.${this.year.toString()}"
                  ? (Colors.amber[700])
                  : null,
            ),
          ),
          onTap: oneRowFormat
              ? () {
                  
                  view.setState(() {
                    this.month--;
                    index = 0;
                    if (this.month <= 0) {
                      this.year--;
                      this.month = 12;
                    }
                    selectedDay = "${(lastDayDateTimeLastMonth_day + index).toString()}.${(month - 1 <= 0 ? 12 : month - 1).toString()}.${this.year.toString()}";
                    onDateSelected(selectedDay);
                    int length = generateWrapChildrenList(
                            month, year, true, false, true)
                        .length;
                    view.scrollController.jumpTo(((length) * ((width ?? 1) / 6)) - 500);
                  });
                }
              : null,
        ),
      );
    }));

    if (year == DateTime.now().year) {
      int day = result.length + DateTime.now().day;
      weekNow = int.parse((day / 6).toStringAsFixed(0)) < result.length / 6 ? int.parse((day / 6).toStringAsFixed(0)) + 1 : int.parse((day / 6).toStringAsFixed(0));
    } else {
      weekNow = 100;
    }

    //view.setState(() {
    weekNow = weekNow;

    //});
    result.addAll(List.generate(lastDayDateTime.day, (index) {
      if (index + 1 == DateTime.now().day && month == DateTime.now().month && year == DateTime.now().year) {
        stopCountingTodayPosition = true;
      }
      if (!stopCountingTodayPosition) {
        todayPosition++;
      }
      return Padding(
        padding: EdgeInsets.only(left: 4.0, bottom: 4.0, top: index + 1 == DateTime.now().day && month == DateTime.now().month && year == DateTime.now().year && widthPadding ? 8.0 : 0.0),
        child: new GestureDetector(
          child: new AnimatedContainer(
            duration: Duration(milliseconds: 100),
            width: oneRowFormat ? 70 : 70,
            height: oneRowFormat ? 75 : 70,
            child: new Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  translations[locale]["${weekDays[DateTime.utc(year, month, index + 1).weekday]}"],
                  style: new TextStyle(
                      color: oneRowFormat
                          ? selectedDay == "${(index + 1).toString()}.${(month).toString()}.${this.year.toString()}"
                              ? (Colors.white)
                              : (index + 1 == DateTime.now().day && month == DateTime.now().month && year == DateTime.now().year)
                                  ? (Colors.white)
                                  : weekdayFontColor
                          : (Colors.grey)),
                ),
                Text(
                  translations[locale]["[DAY].[MONTH]"].toString().replaceAll("[DAY]", "${(index + 1).toString().padLeft(2, "0")}").replaceAll("[MONTH]", "${(month).toString().padLeft(2, "0")}"),
                  //"${(index + 1).toString().padLeft(2, "0")}${widthMonth ? ".${(month).toString().padLeft(2, "0")}" : ""}",
                  style: new TextStyle(
                      color: (index + 1 == DateTime.now().day && month == DateTime.now().month && year == DateTime.now().year)
                          /* ||
                              index == int + 1*/
                          ? (Colors.white)
                          : selectedDay == "${(index + 1).toString()}.${(month).toString()}.${this.year.toString()}"
                              ? (Colors.white)
                              : (fontColor)),
                ),
              ],
            )),
            decoration: new BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(2.0)),
              color: selectedDay == "${(index + 1).toString()}.${(month).toString()}.${this.year.toString()}"
                  ? (Colors.amber[700])
                  : index + 1 == DateTime.now().day && month == DateTime.now().month && year == DateTime.now().year
                      ? (Colors.red)
                      : /*index == int + 1 ? Colors.green : */ Colors.transparent,
            ),
          ),
          onTap: oneRowFormat
              ? () {
                  f() async {
                    selectedDay = "${(index + 1).toString()}.${(month).toString()}.${this.year.toString()}";
                    onDateSelected(selectedDay);
                    view.setState(() {
                      selectedDay = selectedDay;
                    });
                  }

                  f();
                }
              : () {
                  view.setState(() {
                    index = index + 1;
                  });
                },
        ),
      );
    }));

    for (int i = 1; result.length % 7 != 0; i++) {
      result.add(Padding(
        padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
        child: GestureDetector(
          child: new AnimatedContainer(
            duration: Duration(milliseconds: 100),
            width: oneRowFormat ? 70 : 70,
            height: oneRowFormat ? 70 : 70,
            child: new Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  new Text(
                    "${weekDays[DateTime.utc(month + 1 > 12 ? year + 1 : year, month + 1 > 12 ? 1 : month + 1, i).weekday]}",
                    style: new TextStyle(
                        color: oneRowFormat
                            ? weekdayFontColor
                            : Colors.grey),
                  ),
                  new Text(
                    "${i.toString().padLeft(2, "0")}${widthMonth ? ".${(month + 1 >= 13 ? 1 : month + 1).toString().padLeft(2, "0")}" : ""}",
                    style: new TextStyle(color: oneRowFormat ? (Colors.black) : (Colors.grey)),
                  )
                ],
              ),
            ),
            decoration: BoxDecoration(
              color: selectedDay == "${i.toString()}.${(month + 1 >= 13 ? 1 : month + 1).toString()}.${this.year.toString()}" ? (Colors.amber[700]) : null,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          onTap: oneRowFormat
              ? () {
                  f() async {
                    view.setState(() {
                      this.month++;
                      index = 0;
                      if (this.month >= 13) {
                        this.year++;
                        this.month = 1;
                      }
                      selectedDay = "${i.toString()}.${(month + 1 >= 13 ? 1 : month + 1).toString()}.${this.year.toString()}";
                      view.observer.refreshScreen(view);
                      int length = generateWrapChildrenList(
                              month, year, true, false, true)
                          .length;
                      view.scrollController.jumpTo((length * ((width ?? 1) / 6)) / length * ((index + 1) + 2.5));
                    });
                  }

                  f();
                }
              : null,
        ),
      ));
    }
    if (oneRowFormat == true) {
      result.add(GestureDetector(
        child: Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 20,
        ),
        onTap: () {
          //setState(() {
          this.month++;
          index = 0;
          if (this.month >= 13) {
            this.year++;
            this.month = 1;
          }
          //});
          view.setState(() {
            this.month = this.month;
            index = index;
            this.year = this.year;
            var lastDay = (this.month < 12) ? new DateTime(this.year, this.month + 1, 0) : new DateTime(this.year + 1, 1, 0);
            selectedDay = "1.${this.month.toString()}.${this.year.toString()}";
            view.scrollController.jumpTo((((DateTime.utc(this.year, this.month, 1).weekday - 1))) * (74.0));
          });
        },
      ));
    }

    lastKws.clear();

    for (int i = 1; i <= month; i++) {
      List test = [];
      int weekday = DateTime.utc(year, i, 1).weekday;
      var lastDayDateTime = (i < 12) ? new DateTime(year, i + 1, 0) : new DateTime(year + 1, 1, 0);
      test.addAll(List.generate(weekday - 1, (int) {}));
      firstNewKw = test.length <= 0;
      for (int i = 1; (test.length + lastDayDateTime.day) % 7 != 0; i++) {
        test.add(Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
          child: new AnimatedContainer(
            duration: Duration(milliseconds: 100),
            width: (width ?? 1) / 8,
            height: (width ?? 1) / 8,
            child: new Center(
              child: new Text(
                "$i",
                style: new TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ));
      }

      if (lastDayDateTime.day + test.length < 35) {
        if (i == 1) {
          lastKws.add(1);
          lastKws.add(2);
          lastKws.add(3);
          lastKws.add(4);
        } else {
          if (firstNewKw) {
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
          } else {
            lastKws.add(lastKws[lastKws.length - 1]);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
          }
        }
      } else if (lastDayDateTime.day + test.length == 35) {
        if (i == 1) {
          lastKws.add(1);
          lastKws.add(2);
          lastKws.add(3);
          lastKws.add(4);
          lastKws.add(5);
        } else {
          if (firstNewKw) {
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
          } else {
            lastKws.add(lastKws[lastKws.length - 1]);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
          }
        }
      } else if (lastDayDateTime.day + test.length > 35) {
        if (i == 1) {
          lastKws.add(1);
          lastKws.add(2);
          lastKws.add(3);
          lastKws.add(4);
          lastKws.add(5);
          lastKws.add(6);
        } else {
          if (firstNewKw) {
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
          } else {
            lastKws.add(lastKws[lastKws.length - 1]);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
            lastKws.add(lastKws[lastKws.length - 1] + 1);
          }
        }
      }
    }

    List lastKwsVorbereitung = [];

    if (oneRowFormat) {
      if (result.length <= 29) {
        for (int i = 1; i <= 4; i++) {
          lastKwsVorbereitung.add(lastKws[lastKws.length - i]);
        }
      } else if (result.length <= 36) {
        for (int i = 1; i <= 5; i++) {
          lastKwsVorbereitung.add(lastKws[lastKws.length - i]);
        }
      } else if (result.length > 36) {
        //Todo: unsafe bugfix if problem with the dates in the day todos look here old code was: for (int i = 1; i <= 6; i++) {
        for (int i = 1; i <= lastKws.length; i++) {
          lastKwsVorbereitung.add(lastKws[lastKws.length - i]);
        }
      }
    } else {
      if (result.length == 29) {
        for (int i = 1; i <= 4; i++) {
          lastKwsVorbereitung.add(lastKws[lastKws.length - i]);
        }
      } else if (result.length == 36) {
        for (int i = 1; i <= 5; i++) {
          lastKwsVorbereitung.add(lastKws[lastKws.length - i]);
        }
      } else if (result.length > 36) {
        for (int i = 1; i <= 6; i++) {
          lastKwsVorbereitung.add(lastKws[lastKws.length - i]);
        }
      }
    }

    lastKws.clear();

    for (int i = 0; i < lastKwsVorbereitung.length; i++) {
      lastKws.add(lastKwsVorbereitung[lastKwsVorbereitung.length - 1 - i]);
    }

    if (oneRowFormat) {
      f() async {
        if (selectedDay == "") {
          selectedDay = "${DateTime.now().day.toString()}.${DateTime.now().month.toString()}.${DateTime.now().year.toString()}";
        }
        int day = int.parse(selectedDay.toString().split(".")[0].toString());
        int month = int.parse(selectedDay.toString().split(".")[1].toString());
        int year = int.parse(selectedDay.toString().split(".")[2].toString());
        
        view.week = 1;
        for (int i = 1; i < day; i++) {
          if (DateTime.utc(year, month, i).weekday == 7) {
            view.week++;
          }
        }

        /*view.Wochenziele["Woche${view.week}"].add({
          "ID": 10000000,
          "Ziel": "Sonstige",
          "verknuepfteMonatsziele": "null",
          "done": 0,
          "woche": "null",
          "kw": "null",
          "monthAndYear": "null",
          "color": "transparent",
          "rang": 10000000,
          "year": 2019
        });*/
        if (view.Wochenziele.toString() != view.setStatetWochenziele.toString()) {
          view.setState(() {
            view.Wochenziele = view.Wochenziele;
          });
        }
      }

      f();
    }

    return result;
  }

  List<Widget> generateWeekdays() {
    int nowWeekday = 0;

    return List.generate(7, (int) {
      nowWeekday++;
      return Padding(
          padding: const EdgeInsets.only(left: 0.0, top: 12.0),
          child: new Container(
            width: 70,
            child: new Center(
              child: new Text(
                "${weekDays[nowWeekday]}",
                textAlign: TextAlign.center,
                style: new TextStyle(color: Colors.white),
              ),
            ),
          ));
    });
  }

  var db;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    f() async {
      String locale = WidgetsBinding.instance.platformDispatcher.locale
          .toLanguageTag()
          .replaceAll('-', '_');
      this.locale = locale.split("_")[0].toString().toUpperCase();
      this.locale = this.locale != "DE" && this.locale != "EN" ? "EN" : this.locale;

      months = {
        1: translations[locale]["Januar"],
        2: translations[locale]["Februar"],
        3: translations[locale]["März"],
        4: translations[locale]["April"],
        5: translations[locale]["Mai"],
        6: translations[locale]["Juni"],
        7: translations[locale]["Juli"],
        8: translations[locale]["August"],
        9: translations[locale]["September"],
        10: translations[locale]["Oktober"],
        11: translations[locale]["November"],
        12: translations[locale]["Dezember"],
      };

      weekDays = {
        1: translations[locale]["Mo"],
        2: translations[locale]["Di"],
        3: translations[locale]["Mi"],
        4: translations[locale]["Do"],
        5: translations[locale]["Fr"],
        6: translations[locale]["Sa"],
        7: translations[locale]["So"],
      };

      
      view.setState(() {
        selectedDay = "${DateTime.now().day.toString()}.${DateTime.now().month.toString()}.${DateTime.now().year.toString()}";
      });
    }

    f();
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      child: Column(
        children: <Widget>[
          new Row(
            children: generateWeekdays(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Wrap(
              children: generateWrapChildrenList(month, year, false, false, true),
            ),
          )
        ],
      ),
      width: width,
    );
  }
}
