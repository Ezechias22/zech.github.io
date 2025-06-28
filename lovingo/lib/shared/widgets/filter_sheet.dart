import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key, required Null Function(dynamic filters) onFiltersApplied});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  RangeValues _ageRange = const RangeValues(18, 35);
  double _distance = 50;
  List<String> _selectedInterests = [];

  final List<String> _interests = [
    'Sport', 'Musique', 'Voyage', 'Cuisine', 'Lecture',
    'Cinéma', 'Art', 'Danse', 'Technologie', 'Nature'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Titre
          const Text(
            'Filtres de recherche',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Âge
          const Text(
            'Tranche d\'âge',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          RangeSlider(
            values: _ageRange,
            min: 18,
            max: 80,
            divisions: 62,
            labels: RangeLabels(
              _ageRange.start.round().toString(),
              _ageRange.end.round().toString(),
            ),
            onChanged: (RangeValues values) {
              setState(() {
                _ageRange = values;
              });
            },
          ),
          Text(
            'De ${_ageRange.start.round()} à ${_ageRange.end.round()} ans',
            style: TextStyle(color: Colors.grey[600]),
          ),
          
          const SizedBox(height: 30),
          
          // Distance
          const Text(
            'Distance maximale',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Slider(
            value: _distance,
            min: 1,
            max: 100,
            divisions: 99,
            label: '${_distance.round()} km',
            onChanged: (double value) {
              setState(() {
                _distance = value;
              });
            },
          ),
          Text(
            'Dans un rayon de ${_distance.round()} km',
            style: TextStyle(color: Colors.grey[600]),
          ),
          
          const SizedBox(height: 30),
          
          // Centres d'intérêt
          const Text(
            'Centres d\'intérêt',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedInterests.add(interest);
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          
          // Boutons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _ageRange = const RangeValues(18, 35);
                      _distance = 50;
                      _selectedInterests.clear();
                    });
                  },
                  child: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Appliquer les filtres
                    Navigator.pop(context, {
                      'ageRange': _ageRange,
                      'distance': _distance,
                      'interests': _selectedInterests,
                    });
                  },
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
