// lib/features/calls/live_guests_grid.dart
import 'package:flutter/material.dart';
import '../../core/models/live_models.dart';

class LiveGuestsGrid extends StatelessWidget {
  final List<LiveGuest> guests;
  final Map<String, dynamic> renderers;
  final bool isHost;
  final Function(String) onRemoveGuest;

  const LiveGuestsGrid({
    super.key,
    required this.guests,
    required this.renderers,
    required this.isHost,
    required this.onRemoveGuest,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: guests.length,
      itemBuilder: (context, index) {
        final guest = guests[index];
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(
                  'https://ui-avatars.com/api/?name=${guest.userId}',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                guest.userId,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${guest.joinedAt.hour}:${guest.joinedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              if (isHost)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                  onPressed: () => onRemoveGuest(guest.userId),
                ),
            ],
          ),
        );
      },
    );
  }
}