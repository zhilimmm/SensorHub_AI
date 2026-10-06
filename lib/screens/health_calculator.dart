import 'dart:math';

class HealthCalculator {
  static Map<String, dynamic> calculate({
    double? temp,
    double? humid,
    int? moist,
    double? ph,
    int? light,
  }) {
    // If core sensors are offline, return 0
    if (temp == null || humid == null || moist == null) {
      return {'score': 0, 'status': 'Standby', 'message': 'Waiting for sensor data'};
    }

    // Gaussian scoring function: gives 1.0 at target, and drops off smoothly based on tolerance
    double getScore(num value, num target, num tolerance) {
      return exp(-(pow(value - target, 2)) / (2 * pow(tolerance, 2)));
    }

    // Apply your sweet potato optimal targets and weights
    double moistScore = getScore(moist, 80, 10) * 30; // 30% weight, target 80%
    double humidScore = getScore(humid, 80, 8) * 25;  // 25% weight, target 80%
    double tempScore = getScore(temp, 25, 3) * 25;    // 25% weight, target 25°C
    double phScore = getScore(ph ?? 6.5, 6.5, 0.5) * 15; // 15% weight, target 6.5
    
    // Light is tricky indoors, give it 100% if it's above 2000, else scale it
    double lightScore = ((light ?? 0) >= 2000 ? 1.0 : (light ?? 0) / 2000.0) * 5; // 5% weight

    int finalScore = (moistScore + humidScore + tempScore + phScore + lightScore).clamp(0, 100).round();

    String status;
    String message;
    if (finalScore >= 90) {
      status = 'Excellent';
      message = 'Optimal growth detected';
    } else if (finalScore >= 75) {
      status = 'Good';
      message = 'Conditions are stable';
    } else if (finalScore >= 60) {
      status = 'Fair';
      message = 'Stress factors detected';
    } else {
      status = 'Poor';
      message = 'Critical environment drift';
    }

    return {'score': finalScore, 'status': status, 'message': message};
  }
}