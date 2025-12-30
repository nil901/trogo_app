class LeaderBoardResponse {
  final List<UserData> data;
  final List<UserData> custData;
  final List<LeaderboardPrice> leaderboardPrices;
  final String message;

  LeaderBoardResponse({
    required this.data,
    required this.custData,
    required this.leaderboardPrices,
    required this.message,
  });

  factory LeaderBoardResponse.fromJson(Map<String, dynamic> json) {
    return LeaderBoardResponse(
      data: List<UserData>.from(json['result']['data'].map((x) => UserData.fromJson(x))),
      custData: List<UserData>.from(json['result']['cust_data'].map((x) => UserData.fromJson(x))),
      leaderboardPrices: List<LeaderboardPrice>.from(json['result']['leaderboard_prices'].map((x) => LeaderboardPrice.fromJson(x))),
      message: json['message'],
    );
  }
}

class UserData {
  final int id;
  final String name;
  final String email;
  final String img;
  final String mobile;
  final int points;
  final int rank;
  final double amount;

  UserData({
    required this.id,
    required this.name,
    required this.email,
    required this.img,
    required this.mobile,
    required this.points,
    required this.rank,
    required this.amount,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      img: json['img'],
      mobile: json['mobile'],
      points: json['points'],
      rank: json['rank'],
      amount: json['amount'].toDouble(),
    );
  }
}

class LeaderboardPrice {
  final int id;
  final int startRange;
  final int endRange;
  final double prices;
  final int leaderboardId;

  LeaderboardPrice({
    required this.id,
    required this.startRange,
    required this.endRange,
    required this.prices,
    required this.leaderboardId,
  });

  factory LeaderboardPrice.fromJson(Map<String, dynamic> json) {
    return LeaderboardPrice(
      id: json['id'],
      startRange: json['start_range'],
      endRange: json['end_range'],
      prices: json['prices'].toDouble(),
      leaderboardId: json['leaderboard_id'],
    );
  }
}
