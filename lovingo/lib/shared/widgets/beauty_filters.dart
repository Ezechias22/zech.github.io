import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Enum pour les types de filtres de beauté
enum BeautyFilterType {
  brightness,
  smoothness,
  redness,
  contrast,
  saturation,
  warmth,
}

class BeautyFiltersPanel extends StatefulWidget {
  final Function(BeautyFilterType, double)? onFilterChanged;
  final VoidCallback? onClose;
  final bool isVisible;

  const BeautyFiltersPanel({
    super.key,
    this.onFilterChanged,
    this.onClose,
    this.isVisible = true,
  });

  @override
  State<BeautyFiltersPanel> createState() => _BeautyFiltersPanelState();
}

class _BeautyFiltersPanelState extends State<BeautyFiltersPanel>
    with TickerProviderStateMixin {
  BeautyFilterType? _selectedFilter;
  
  // Valeurs des filtres
  double _brightness = 0.5;
  double _smoothness = 0.3;
  double _redness = 0.2;
  double _contrast = 0.5;
  double _saturation = 0.5;
  double _warmth = 0.4;
  
  // Controllers d'animation
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    if (widget.isVisible) {
      _slideController.forward();
      _fadeController.forward();
    }
  }

  @override
  void didUpdateWidget(BeautyFiltersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _slideController.forward();
        _fadeController.forward();
      } else {
        _slideController.reverse();
        _fadeController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 20,
      top: 200,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: _selectedFilter != null ? 300 : 70,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.3, 0.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: _selectedFilter == null 
                  ? _buildFilterButtons()
                  : _buildFilterSlider(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Column(
      key: const ValueKey('buttons'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.face,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Filtres',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        const Divider(color: Colors.white24, height: 16),
        
        // Boutons de filtres
        _buildFilterButton(
          icon: Icons.brightness_6, 
          tooltip: 'Luminosité',
          type: BeautyFilterType.brightness,
          isActive: _brightness != 0.5,
        ),
        const SizedBox(height: 12),
        
        _buildFilterButton(
          icon: Icons.blur_on, 
          tooltip: 'Lissage de peau',
          type: BeautyFilterType.smoothness,
          isActive: _smoothness > 0.0,
        ),
        const SizedBox(height: 12),
        
        _buildFilterButton(
          icon: Icons.color_lens, 
          tooltip: 'Teint rosé',
          type: BeautyFilterType.redness,
          isActive: _redness > 0.0,
        ),
        const SizedBox(height: 12),
        
        _buildFilterButton(
          icon: Icons.contrast, 
          tooltip: 'Contraste',
          type: BeautyFilterType.contrast,
          isActive: _contrast != 0.5,
        ),
        const SizedBox(height: 12),
        
        _buildFilterButton(
          icon: Icons.palette, 
          tooltip: 'Saturation',
          type: BeautyFilterType.saturation,
          isActive: _saturation != 0.5,
        ),
        const SizedBox(height: 12),
        
        _buildFilterButton(
          icon: Icons.wb_sunny, 
          tooltip: 'Température',
          type: BeautyFilterType.warmth,
          isActive: _warmth != 0.4,
        ),
        
        const SizedBox(height: 16),
        const Divider(color: Colors.white24, height: 16),
        
        // Boutons d'action
        Row(
          children: [
            // Reset tous les filtres
            Expanded(
              child: GestureDetector(
                onTap: _resetAllFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.orange,
                    size: 16,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Bouton fermer
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onClose?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterButton({
    required IconData icon, 
    required String tooltip,
    required BeautyFilterType type,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedFilter = type;
        });
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive 
                ? const Color(0xFFFF6B6B).withOpacity(0.9)
                : Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive 
                  ? const Color(0xFFFF6B6B)
                  : Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.white70,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSlider() {
    final filterInfo = _getFilterInfo(_selectedFilter!);
    
    return Column(
      key: const ValueKey('slider'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header avec titre et bouton retour
        Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedFilter = null;
                });
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                filterInfo['icon'],
                color: const Color(0xFFFF6B6B),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            
            Expanded(
              child: Text(
                filterInfo['title'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Slider avec valeur
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Intensité',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(filterInfo['value'] * 100).round()}%',
                      style: const TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFFF6B6B),
                  inactiveTrackColor: Colors.white.withOpacity(0.2),
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFFFF6B6B).withOpacity(0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                  trackHeight: 6,
                  activeTickMarkColor: Colors.transparent,
                  inactiveTickMarkColor: Colors.transparent,
                ),
                child: Slider(
                  value: filterInfo['value'],
                  min: filterInfo['min'],
                  max: filterInfo['max'],
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      switch (_selectedFilter!) {
                        case BeautyFilterType.brightness:
                          _brightness = value;
                          break;
                        case BeautyFilterType.smoothness:
                          _smoothness = value;
                          break;
                        case BeautyFilterType.redness:
                          _redness = value;
                          break;
                        case BeautyFilterType.contrast:
                          _contrast = value;
                          break;
                        case BeautyFilterType.saturation:
                          _saturation = value;
                          break;
                        case BeautyFilterType.warmth:
                          _warmth = value;
                          break;
                      }
                    });
                    
                    // Callback pour appliquer le filtre
                    widget.onFilterChanged?.call(_selectedFilter!, value);
                  },
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Boutons presets
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Presets rapides',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPresetButton('Aucun', filterInfo['min']),
                  _buildPresetButton('Léger', _getPresetValue(filterInfo, 0.3)),
                  _buildPresetButton('Moyen', _getPresetValue(filterInfo, 0.6)),
                  _buildPresetButton('Fort', filterInfo['max']),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, double value) {
    final isSelected = (_getCurrentFilterValue() - value).abs() < 0.05;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          switch (_selectedFilter!) {
            case BeautyFilterType.brightness:
              _brightness = value;
              break;
            case BeautyFilterType.smoothness:
              _smoothness = value;
              break;
            case BeautyFilterType.redness:
              _redness = value;
              break;
            case BeautyFilterType.contrast:
              _contrast = value;
              break;
            case BeautyFilterType.saturation:
              _saturation = value;
              break;
            case BeautyFilterType.warmth:
              _warmth = value;
              break;
          }
        });
        
        widget.onFilterChanged?.call(_selectedFilter!, value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFFF6B6B)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFFF6B6B)
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  double _getPresetValue(Map<String, dynamic> filterInfo, double ratio) {
    final min = filterInfo['min'] as double;
    final max = filterInfo['max'] as double;
    return min + (max - min) * ratio;
  }

  Map<String, dynamic> _getFilterInfo(BeautyFilterType type) {
    switch (type) {
      case BeautyFilterType.brightness:
        return {
          'title': 'Luminosité',
          'icon': Icons.brightness_6,
          'value': _brightness,
          'min': 0.0,
          'max': 1.0,
        };
      case BeautyFilterType.smoothness:
        return {
          'title': 'Lissage',
          'icon': Icons.blur_on,
          'value': _smoothness,
          'min': 0.0,
          'max': 1.0,
        };
      case BeautyFilterType.redness:
        return {
          'title': 'Teint rosé',
          'icon': Icons.color_lens,
          'value': _redness,
          'min': 0.0,
          'max': 0.8,
        };
      case BeautyFilterType.contrast:
        return {
          'title': 'Contraste',
          'icon': Icons.contrast,
          'value': _contrast,
          'min': 0.0,
          'max': 1.0,
        };
      case BeautyFilterType.saturation:
        return {
          'title': 'Saturation',
          'icon': Icons.palette,
          'value': _saturation,
          'min': 0.0,
          'max': 1.0,
        };
      case BeautyFilterType.warmth:
        return {
          'title': 'Température',
          'icon': Icons.wb_sunny,
          'value': _warmth,
          'min': 0.0,
          'max': 1.0,
        };
    }
  }

  double _getCurrentFilterValue() {
    switch (_selectedFilter!) {
      case BeautyFilterType.brightness:
        return _brightness;
      case BeautyFilterType.smoothness:
        return _smoothness;
      case BeautyFilterType.redness:
        return _redness;
      case BeautyFilterType.contrast:
        return _contrast;
      case BeautyFilterType.saturation:
        return _saturation;
      case BeautyFilterType.warmth:
        return _warmth;
    }
  }

  void _resetAllFilters() {
    HapticFeedback.mediumImpact();
    setState(() {
      _brightness = 0.5;
      _smoothness = 0.0;
      _redness = 0.0;
      _contrast = 0.5;
      _saturation = 0.5;
      _warmth = 0.4;
    });

    // Appliquer tous les resets
    for (final filterType in BeautyFilterType.values) {
      final value = _getCurrentFilterValueForType(filterType);
      widget.onFilterChanged?.call(filterType, value);
    }
  }

  double _getCurrentFilterValueForType(BeautyFilterType type) {
    switch (type) {
      case BeautyFilterType.brightness:
        return _brightness;
      case BeautyFilterType.smoothness:
        return _smoothness;
      case BeautyFilterType.redness:
        return _redness;
      case BeautyFilterType.contrast:
        return _contrast;
      case BeautyFilterType.saturation:
        return _saturation;
      case BeautyFilterType.warmth:
        return _warmth;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}