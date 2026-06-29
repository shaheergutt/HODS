import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import '../models/hostel_model.dart';
import '../models/room_model.dart';
import '../services/firestore_service.dart';

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final allHostelsProvider = StreamProvider<List<HostelModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getAllHostels();
});

final ownerHostelsProvider =
    StreamProvider.family<List<HostelModel>, String>((ref, ownerId) {
  return ref.watch(firestoreServiceProvider).getOwnerHostels(ownerId);
});

final hostelRoomsProvider =
    StreamProvider.family<List<RoomModel>, String>((ref, hostelId) {
  return ref.watch(firestoreServiceProvider).getHostelRooms(hostelId);
});

final ownerRoomsProvider =
    StreamProvider.family<List<RoomModel>, List<String>>((ref, hostelIds) {
  return ref.watch(firestoreServiceProvider).getOwnerRooms(hostelIds);
});

// Search + filter state
class HostelFilterState {
  final String query;
  final String city;
  final List<String> facilities;
  final int? maxPrice;
  final String gender;
  final String sortBy;

  const HostelFilterState({
    this.query = '',
    this.city = '',
    this.facilities = const [],
    this.maxPrice,
    this.gender = '',
    this.sortBy = 'recommended',
  });

  HostelFilterState copyWith({
    String? query,
    String? city,
    List<String>? facilities,
    int? maxPrice,
    String? gender,
    String? sortBy,
  }) {
    return HostelFilterState(
      query: query ?? this.query,
      city: city ?? this.city,
      facilities: facilities ?? this.facilities,
      maxPrice: maxPrice ?? this.maxPrice,
      gender: gender ?? this.gender,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class HostelFilterNotifier extends StateNotifier<HostelFilterState> {
  HostelFilterNotifier() : super(const HostelFilterState());

  void setQuery(String q) => state = state.copyWith(query: q);
  void setCity(String c) => state = state.copyWith(city: c);
  void setFacilities(List<String> f) => state = state.copyWith(facilities: f);
  void setMaxPrice(int? p) => state = state.copyWith(maxPrice: p);
  void setGender(String g) => state = state.copyWith(gender: g);
  void setSortBy(String s) => state = state.copyWith(sortBy: s);
  void reset() => state = const HostelFilterState();
}

final hostelFilterProvider =
    StateNotifierProvider<HostelFilterNotifier, HostelFilterState>(
  (ref) => HostelFilterNotifier(),
);

final filteredHostelsProvider =
    Provider.family<List<HostelModel>, List<HostelModel>>((ref, hostels) {
  final filter = ref.watch(hostelFilterProvider);

  var result = hostels.where((h) {
    if (filter.query.isNotEmpty) {
      final q = filter.query.toLowerCase();
      if (!h.name.toLowerCase().contains(q) &&
          !h.city.toLowerCase().contains(q) &&
          !h.location.toLowerCase().contains(q)) {
        return false;
      }
    }
    if (filter.city.isNotEmpty && h.city != filter.city) return false;
    if (filter.maxPrice != null && h.pricePerMonth > filter.maxPrice!) {
      return false;
    }
    if (filter.gender.isNotEmpty &&
        h.genderPolicy != 'Both' &&
        h.genderPolicy != filter.gender) {
      return false;
    }
    if (filter.facilities.isNotEmpty) {
      final hasAll = filter.facilities
          .every((f) => h.facilities.contains(f));
      if (!hasAll) return false;
    }
    return true;
  }).toList();

  switch (filter.sortBy) {
    case 'price_asc':
      result.sort((a, b) => a.pricePerMonth.compareTo(b.pricePerMonth));
      break;
    case 'price_desc':
      result.sort((a, b) => b.pricePerMonth.compareTo(a.pricePerMonth));
      break;
    case 'rating':
      result.sort((a, b) => b.rating.compareTo(a.rating));
      break;
    default:
      break;
  }

  return result;
});
