import 'package:catapp/screens/petDetail.dart';
import 'package:flutter/material.dart';

class Recommendation {
  int? catId;
  String? catName;
  String? catPhotoUrl;
  String? userChoice;

  Recommendation({this.catId, this.catName, this.catPhotoUrl, this.userChoice});
}

class CatRecommendationScreen extends StatefulWidget {
  const CatRecommendationScreen({Key? key}) : super(key: key);

  @override
  _CatRecommendationScreenState createState() =>
      _CatRecommendationScreenState();
}

class _CatRecommendationScreenState extends State<CatRecommendationScreen> {
  String _selectedChoice = '?';
  bool _isLoading = true; // Simulate loading data
  bool _notEnoughData = false; // Simulate not enough data

  final List<Recommendation> _recommendations = List.generate(100, (index) {
    return Recommendation(
      catId: index,
      catName: 'Cat Name $index',
      catPhotoUrl:
          'https://www.aspca.org/sites/default/files/apple-touch-icon-precomposed_1.png', // Replace with the actual image URL for the cat
      userChoice: '?',
    );
  });

  void _updateResponse(int index, String response) {
    setState(() {
      _recommendations[index].userChoice = response;
    });
  }

  @override
  void initState() {
    super.initState();
    // Simulate loading data
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });
    });

    // Simulate not enough data
    if (_recommendations
        .every((recommendation) => recommendation.userChoice == '?')) {
      setState(() {
        _notEnoughData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cat Recommendations'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.thumb_up_alt_outlined,
              color: _selectedChoice == 'A'
                  ? const Color.fromARGB(255, 23, 206, 32)
                  : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _selectedChoice = 'A';
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.thumb_down_alt_outlined,
              color: _selectedChoice == 'D' ? Colors.red : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _selectedChoice = 'D';
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator()) // Display spinner while loading data
          : _notEnoughData
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "There is not enough data to make recommendations.",
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "This feature works by you liking cats by tapping the heart button at the top of the adoption screen.\nPlease like some more cats and I will be able to make recommendations.",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _recommendations.length,
                  itemBuilder: (context, index) {
                    final recommendation = _recommendations[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  petDetail(recommendation.catId.toString())),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.network(
                                  recommendation.catPhotoUrl ?? "",
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${index + 1}.',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                  Text(
                                    recommendation.catName ?? "",
                                    style:
                                        const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.thumb_up,
                                      color: recommendation.userChoice == 'A'
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    onPressed: () {
                                      _updateResponse(index, 'A');
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.thumb_down,
                                      color: recommendation.userChoice == 'D'
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                    onPressed: () {
                                      _updateResponse(index, 'D');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
