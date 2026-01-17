import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LiquidGlassApp());
}

class LiquidGlassApp extends StatelessWidget {
  const LiquidGlassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  // Animation for background
  late AnimationController _bgController;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  // State
  Map<String, double> _rates = {
    'TJS': 10.96, // Fallback
    'USD': 1.0,   
    'UZS': 12400.0,
    'RUB': 88.5,
    'EUR': 0.92,
  };
  
  bool _isLoading = false;
  String _lastUpdated = "Checking...";
  
  final List<String> _currencyOrder = ['TJS', 'USD', 'UZS', 'RUB', 'EUR'];
  
  String _activeCurrency = 'USD';
  String _inputExpression = "0";
  bool _vibrationEnabled = true; // Vibration state
  double _bankFee = 0.0; // Commission percentage
  
  // Flag assets
  final Map<String, String> _flags = {
    'TJS': '🇹🇯',
    'USD': '🇺🇸',
    'UZS': '🇺🇿',
    'RUB': '🇷🇺',
    'EUR': '🇪🇺',
  };

  @override
  void initState() {
    super.initState();
    _fetchRates();
    
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
    ]).animate(_bgController);

    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
    ]).animate(_bgController);
  }
  
  Future<void> _fetchRates() async {
      if (_isLoading) return;
      setState(() => _isLoading = true);
      try {
          // User provided key: 86159c25027e9d4fd32790e7
          final response = await http.get(Uri.parse('https://v6.exchangerate-api.com/v6/86159c25027e9d4fd32790e7/latest/USD'));
          if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final rates = data['conversion_rates'];
              
              // Use local time to show when WE fetched it, satisfying user's need to see it update
              DateTime now = DateTime.now();
              String day = now.day.toString().padLeft(2, '0');
              String month = now.month.toString().padLeft(2, '0');
              String year = (now.year % 100).toString();
              String hour = now.hour.toString().padLeft(2, '0');
              String minute = now.minute.toString().padLeft(2, '0');
              
              String timeStr = "$day/$month/$year $hour:$minute";
              
              setState(() {
                  if (rates['TJS'] != null) _rates['TJS'] = (rates['TJS'] as num).toDouble();
                  if (rates['UZS'] != null) _rates['UZS'] = (rates['UZS'] as num).toDouble();
                  if (rates['RUB'] != null) _rates['RUB'] = (rates['RUB'] as num).toDouble();
                  if (rates['EUR'] != null) _rates['EUR'] = (rates['EUR'] as num).toDouble();
                  _lastUpdated = "Updated: $timeStr";
              });
          }
      } catch (e) {
          debugPrint("Error fetching rates: $e");
          setState(() => _lastUpdated = "Offline");
      } finally {
          if (mounted) setState(() => _isLoading = false);
      }
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  // LOGIC
  void _onKeyPressed(String key) {
    setState(() {
      if (key == 'C') {
        _inputExpression = "0";
      } else if (key == '⌫') { // Backspace
         if (_inputExpression.length > 1) {
           _inputExpression = _inputExpression.substring(0, _inputExpression.length - 1);
         } else {
           _inputExpression = "0";
         }
      } else if (['+', '-', 'x', '/', '%'].contains(key)) {
         // Prevent double operators
         if (!['+', '-', 'x', '/', '%'].contains(_inputExpression[_inputExpression.length - 1])) {
             _inputExpression += key;
         }
      } else if (key == '.') {
          // specific dot logic could be added, simplified here
        if (!_inputExpression.endsWith('.')) {
          _inputExpression += key;
        }
      } else if (key == '=') {
         // Evaluate
         try {
           _inputExpression = _evaluate(_inputExpression).toString();
           // Remove trailing .0
           if (_inputExpression.endsWith(".0")) {
             _inputExpression = _inputExpression.substring(0, _inputExpression.length - 2);
           }
         } catch (e) {
           // ignore error
         }
      } else {
        // Digits
        if (_inputExpression == "0") {
          _inputExpression = key;
        } else {
          _inputExpression += key;
        }
      }
    });
  }

  String _formatNumber(String value) {
      if (value.isEmpty) return "";
      try {
          // Check if it's an expression or final number. 
          // If it contains operators, don't format yet.
          if (value.contains(RegExp(r'[+\-x/%]'))) return value;
          
          double numVal = double.parse(value);
          // Manual formatting for thousands space
          List<String> parts = numVal.toStringAsFixed(2).split('.');
          String whole = parts[0];
          String decimal = parts.length > 1 ? "." + parts[1] : "";
          
          RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
          Function mathFunc = (Match match) => '${match[1]} ';
          String result = whole.replaceAllMapped(reg, (Match m) => "${m[1]} ");
          
          return "$result$decimal";
      } catch (e) {
          return value;
      }
  }

  double _evaluate(String expression) {
    // Simple parser manually since we can't use external libraries like math_expressions easily in single file without deps
    // This is a very basic evaluation for demo purposes.
    // Handles simple sequences like 10 + 20 - 5 * 2
    // Correct order of operations is complex to implement from scratch in one function,
    // so we will do a simple left-to-right pass or basic PEMDAS if possible.
    // For simplicity: replace 'x' with '*' 
    String cleanExp = expression.replaceAll('x', '*').replaceAll('%', '/100');
    
    try {
      // NOTE: true parsing is hard. We will use a basic trick: 
      // Split by operators and simple eval. 
      // Ideally we'd use a library. 
      // Let's implement a very basic recursive parser for +,-,*,/
      return _parseMath(cleanExp);
    } catch (e) {
      return 0.0;
    }
  }

  // Basic recursive parser
  double _parseMath(String expr) {
    // Remove spaces
    expr = expr.replaceAll(' ', '');
    // Handle addition
    int lastPlus = _findLastOperator(expr, '+');
    if (lastPlus != -1) {
      return _parseMath(expr.substring(0, lastPlus)) + _parseMath(expr.substring(lastPlus + 1));
    }
    // Handle subtraction
    int lastMinus = _findLastOperator(expr, '-');
    if (lastMinus != -1) {
      // Check if it's negative number start
      if (lastMinus == 0) return -_parseMath(expr.substring(1)); 
      return _parseMath(expr.substring(0, lastMinus)) - _parseMath(expr.substring(lastMinus + 1));
    }
    // Handle multiplication
    int lastMul = _findLastOperator(expr, '*');
    if (lastMul != -1) {
      return _parseMath(expr.substring(0, lastMul)) * _parseMath(expr.substring(lastMul + 1));
    }
    // Handle division
    int lastDiv = _findLastOperator(expr, '/');
    if (lastDiv != -1) {
      double right = _parseMath(expr.substring(lastDiv + 1));
      if (right == 0) return 0.0;
      return _parseMath(expr.substring(0, lastDiv)) / right;
    }
    
    return double.tryParse(expr) ?? 0.0;
  }
  
  int _findLastOperator(String expr, String op) {
      // Ignores operators inside potential parentheses (not impl here)
      // Ignores first char for -
      for (int i = expr.length - 1; i >= 1; i--) {
          if (expr[i] == op) return i;
      }
      return -1;
  }

  double _getSafeValue() {
      // Evaluate current expression for active currency
      return _evaluate(_inputExpression);
  }

  String _getDisplayValueFor(String currency) {
      if (currency == _activeCurrency) {
          return _formatNumber(_inputExpression);
      }
      // Convert
      double baseValueUSD = _getSafeValue() / (_rates[_activeCurrency]!); // Convert active to USD
      double targetValue = baseValueUSD * (_rates[currency]!); // Convert USD to Target
      
      // Apply Bank Fee
      if (_bankFee > 0) {
          targetValue = targetValue * (1 - (_bankFee / 100));
      }
      
      return _formatNumber(targetValue.toString()); // format adds precision if needed inside
  }

  void _showBankDialog(BuildContext context) {
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) {
              return StatefulBuilder(
                  builder: (context, setModalState) {
                      return GlassContainer(
                          borderRadius: 30,
                          color: Colors.black.withOpacity(0.9),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  const Icon(Icons.account_balance, color: Colors.orangeAccent, size: 40),
                                  const SizedBox(height: 10),
                                  const Text("Bank Commission", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text("${_bankFee.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.greenAccent, fontSize: 28)),
                                  const SizedBox(height: 20),
                                  const Text("Simulate exchange fees:", style: TextStyle(color: Colors.grey)),
                                  Slider(
                                      value: _bankFee,
                                      min: 0.0,
                                      max: 10.0,
                                      divisions: 20,
                                      activeColor: Colors.orangeAccent,
                                      label: "${_bankFee.toStringAsFixed(1)}%",
                                      onChanged: (val) {
                                          setModalState(() => _bankFee = val);
                                          setState(() => _bankFee = val);
                                      },
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [0.0, 1.0, 3.0, 5.0].map((fee) {
                                          return GestureDetector(
                                              onTap: () {
                                                  setModalState(() => _bankFee = fee);
                                                  setState(() => _bankFee = fee);
                                              },
                                              child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  decoration: BoxDecoration(
                                                      color: _bankFee == fee ? Colors.orangeAccent : Colors.white10,
                                                      borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text("${fee.toInt()}%", style: const TextStyle(color: Colors.white)),
                                              ),
                                          );
                                      }).toList(),
                                  ),
                                  const SizedBox(height: 30),
                              ],
                          ),
                      );
                  }
              );
          }
      );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return GlassContainer(
               borderRadius: 30,
               color: Colors.black.withOpacity(0.8),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Container(
                     width: 40, height: 4, 
                     margin: const EdgeInsets.only(bottom: 20),
                     decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)),
                   ),
                   const Text("Settings", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 20),
                   SwitchListTile(
                     title: const Text("Haptic Feedback", style: TextStyle(color: Colors.white)),
                     subtitle: const Text("Vibration on key press", style: TextStyle(color: Colors.grey)),
                     value: _vibrationEnabled,
                     activeColor: Colors.orangeAccent,
                     onChanged: (val) {
                       // Update both local modal state and main app state
                       setModalState(() => _vibrationEnabled = val);
                       setState(() => _vibrationEnabled = val);
                     },
                   ),
                   const Divider(color: Colors.white12),
                   const ListTile(
                     leading: Icon(Icons.info_outline, color: Colors.white),
                     title: Text("About Converter", style: TextStyle(color: Colors.white)),
                     subtitle: Text("v1.0.0 • Liquid Glass Design", style: TextStyle(color: Colors.grey)),
                   ),
                   const SizedBox(height: 20),
                 ],
               ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [
                       Colors.black,
                       Color(0xFF1B1B1B), 
                       Color(0xFF0D0D0D),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
          // Orbs
          Positioned(top: -100, left: -50, child: _buildOrb(const Color(0xFFE94560), 300)),
          Positioned(bottom: 200, right: -100, child: _buildOrb(const Color(0xFF533483), 300)),

          SafeArea(
            child: Column(
              children: [
                // Header (App Title)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            const Text("Converter", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(_lastUpdated, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                         ],
                       ),
                       Row(
                         children: [
                            // Refresh Button
                            if (_isLoading)
                                const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(color: Colors.orangeAccent, strokeWidth: 2)
                                )
                            else
                                GestureDetector(
                                    onTap: _fetchRates,
                                    child: const Icon(Icons.refresh, color: Colors.orangeAccent),
                                ),
                            
                            const SizedBox(width: 20),
                            GestureDetector(
                                onTap: () => _showBankDialog(context),
                                child: Icon(Icons.account_balance, color: _bankFee > 0 ? Colors.redAccent : Colors.orangeAccent), 
                            ),
                            const SizedBox(width: 20),
                            GestureDetector(
                                onTap: () => _showSettings(context),
                                child: const Icon(Icons.settings, color: Colors.orangeAccent),
                            ),
                         ],
                       )
                    ],
                  ),
                ),
                
                // Currency List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _currencyOrder.length,
                    itemBuilder: (context, index) {
                      final currency = _currencyOrder[index];
                      final bool isActive = currency == _activeCurrency;
                      
                      return GestureDetector(
                        onTap: () {
                           setState(() {
                               // When switching, we take the CURRENT calculated value of the old active currency, 
                               // convert it to the NEW currency, and set that as the static start value for editing.
                               // Simplified: Just reset expression to the converted value of this row
                               double currentVal = double.tryParse(_getDisplayValueFor(currency)) ?? 0;
                               _inputExpression = currentVal.toString();
                               if (_inputExpression.endsWith('.00')) {
                                   _inputExpression = _inputExpression.substring(0, _inputExpression.length - 3);
                               } else if (_inputExpression.endsWith('.0')) {
                                   _inputExpression = _inputExpression.substring(0, _inputExpression.length - 2);
                               }
                               _activeCurrency = currency;
                           });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: isActive ? Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1) : null,
                          ),
                          child: Row(
                            children: [
                               // Flag
                               Text(_flags[currency]!, style: const TextStyle(fontSize: 32)),
                               const SizedBox(width: 12),
                               // Code
                               Text(currency, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                               const SizedBox(width: 16),
                               // Input Field
                               Expanded(
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                   decoration: BoxDecoration(
                                     color: isActive ? Colors.transparent : const Color(0xFF2C2C2C),
                                     borderRadius: BorderRadius.circular(12),
                                   ),
                                   alignment: Alignment.centerRight,
                                   child: Text(
                                     _getDisplayValueFor(currency),
                                     style: TextStyle(
                                       color: isActive ? Colors.white : Colors.white70, 
                                       fontSize: 24,
                                       fontWeight: isActive ? FontWeight.w400 : FontWeight.w300
                                     ),
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                 ),
                               ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Keypad
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: LayoutBuilder(
                      builder: (context, constraints) {
                          double gap = 12;
                          // Ensure we don't overflow horizontally
                          double availableWidth = constraints.maxWidth - (gap * 3);
                          double btnSize = availableWidth / 4;
                          
                          // Clamp button size to avoid massive buttons on desktop or tiny on small phones
                          // But strictly sticking to width division ensures fit.
                          
                          return Column(
                              children: [
                                  Row(children: [
                                      _buildBtn("C", btnSize, gap, color: Colors.grey[800]!), 
                                      SizedBox(width: gap),
                                      _buildBtn("⌫", btnSize, gap, color: Colors.grey[800]!),
                                      SizedBox(width: gap),
                                      _buildBtn("%", btnSize, gap, color: Colors.grey[800]!),
                                      SizedBox(width: gap),
                                      _buildBtn("/", btnSize, gap, color: Colors.orange),
                                  ]),
                                  SizedBox(height: gap),
                                  Row(children: [
                                      _buildBtn("7", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("8", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("9", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("x", btnSize, gap, color: Colors.orange),
                                  ]),
                                  SizedBox(height: gap),
                                  Row(children: [
                                      _buildBtn("4", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("5", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("6", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("-", btnSize, gap, color: Colors.orange),
                                  ]),
                                  SizedBox(height: gap),
                                  Row(children: [
                                      _buildBtn("1", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("2", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("3", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("+", btnSize, gap, color: Colors.orange),
                                  ]),
                                  SizedBox(height: gap),
                                  Row(children: [
                                      _buildBtn("0", btnSize, gap, width: (btnSize * 2) + gap),
                                      SizedBox(width: gap),
                                      _buildBtn(".", btnSize, gap),
                                      SizedBox(width: gap),
                                      _buildBtn("=", btnSize, gap, color: Colors.orange),
                                  ]),
                              ],
                          );
                      }
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildBtn(String text, double size, double gap, {Color color = const Color(0xFF333333), double? width}) {
      return SizedBox(
          width: width ?? size,
          height: size / 1.1, // Aspect ratio
          child: ScaleButton(
              onTap: () => _onKeyPressed(text),
              enableFeedback: _vibrationEnabled,
              child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 5,
                          offset: const Offset(2, 2),
                        )
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.05))
                  ),
                  child: Text(
                      text,
                      style: TextStyle(
                          fontSize: 28, 
                          color: ['C', '⌫', '%'].contains(text) ? Colors.white : Colors.white, 
                          fontWeight: FontWeight.w400
                      ),
                  ),
              ),
          ),
      );
  }
}

class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enableFeedback;

  const ScaleButton({
    super.key, 
    required this.child, 
    required this.onTap,
    this.enableFeedback = true,
  });

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.enableFeedback) HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color color;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.color = Colors.white10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: color,
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}
