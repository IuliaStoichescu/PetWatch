import 'package:flutter/material.dart';
import 'package:pet_watch/home_page.dart';
import 'package:pet_watch/onboardingscreens/firstpage.dart';
import 'package:pet_watch/onboardingscreens/seocondpage.dart';
import 'package:pet_watch/onboardingscreens/thirdpage.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onDone; // ✅ Add this line

  const OnboardingScreen({super.key, this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isOnLastPage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                isOnLastPage = (index == 2);
              });
            },
            children: [
              FirstPage(),
              SecondPage(),
              ThirdPage(),
            ],
          ),
          Container(
            alignment: Alignment(0, 0.85),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Skip button
                GestureDetector(
                  onTap: () {
                    _controller.jumpToPage(2);
                  },
                  child: SizedBox(
                    width: 80,
                    height: 35,
                    child: TextButton(
                      onPressed: () {
                        _controller.jumpToPage(2);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 108, 76, 87),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      ),
                      child: const Text(
                        "Skip",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 10),

                SmoothPageIndicator(
                  controller: _controller,
                  count: 3,
                  effect: ExpandingDotsEffect(
                    dotColor: Colors.white,
                    activeDotColor: const Color.fromARGB(255, 108, 76, 87),
                  ),
                ),

                SizedBox(width: 10),

                // Next or Done button
                isOnLastPage
                    ? GestureDetector(
                        onTap: () {
                          if (widget.onDone != null) {
                            widget.onDone!(); // ✅ Call the callback when onboarding is done
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => HomePage()),
                            );
                          }
                        },
                        child: SizedBox(
                          width: 80,
                          height: 35,
                          child: TextButton(
                            onPressed: () {
                              if (widget.onDone != null) {
                                widget.onDone!(); // ✅ Call the callback
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => HomePage()),
                                );
                              }
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 108, 76, 87),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            ),
                            child: const Text(
                              "Done",
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: () {
                          _controller.nextPage(duration: Duration(milliseconds: 500), curve: Curves.easeIn);
                        },
                        child: SizedBox(
                          width: 80,
                          height: 35,
                          child: TextButton(
                            onPressed: () {
                              _controller.nextPage(duration: Duration(milliseconds: 500), curve: Curves.easeIn);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 108, 76, 87),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            ),
                            child: const Text(
                              "Next",
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
